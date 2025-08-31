# `DEVFSADM(8)` - administration command for /dev

* [`usr/src/cmd/devfsadm/devfsadm_impl.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/devfsadm/devfsadm_impl.h)
* [`usr/src/cmd/devfsadm/devfsadm.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/devfsadm/devfsadm.c)
* [`usr/src/cmd/devfsadm/devfsadm.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/devfsadm/devfsadm.h)
* [`usr/src/cmd/devfsadm/message.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/devfsadm/message.h)

Based on the header, looks like there will be two server procedures:

* `devname_lookup_handler`
* `sync_handler`

What role does `attr_root` play? It is used in constructing a path to the
`door_file` in the `daemon_update` function, seems like it is just a root
working directory for this daemon.

The [Static File Descriptor]({{< ref
"docs/tradecraft/static_file_descriptor.md" >}}) pattern is in use here,
together with a filesystem path variable called `lookup_door_path`. This pattern
is so common, I wonder why there isn't a struct like:

```c
struct DoorFile {
    int fd;
    char path[255];
};
```

The `DEVFSADM_SERVICE_DOOR` macro is interesting, because it puts the door file
in `/etc` rather than `/var`, which is more typical (at least on other
platforms) for sockets that might be used for interaction with daemons:

```c
#define	DEVFSADM_SERVICE_DOOR	"/etc/sysevent/devfsadm_event_channel"
```

Contrast this with the `DEVNAME_LOOKUP_DOOR` macro which specifies only a
relative file path (and a hidden one at that):

```c
#define	DEVNAME_LOOKUP_DOOR	".devname_lookup_door"
```

Door cleanup is also different than we've seen in previous sightings; The
`revoke_lookip_door` function does check that the door's fd is -1, and does
check whether `door_revoke` fails, but there does not seem to be any attempt to
detach the door from the filesystem. So the cleanup would leave a filesystem
entry that points to no door.

Now here's some wild shit:
```c
	(void) s_unlink(door_file);
	if ((fd = open(door_file, O_RDWR | O_CREAT, SYNCH_DOOR_PERMS)) == -1) {
		err_print(CANT_CREATE_DOOR, door_file, strerror(errno));
		devfsadm_exit(1);
		/*NOTREACHED*/
	}
	(void) close(fd);

	if ((fd = door_create(sync_handler, NULL,
	    DOOR_REFUSE_DESC | DOOR_NO_CANCEL)) == -1) {
		err_print(CANT_CREATE_DOOR, door_file, strerror(errno));
		(void) s_unlink(door_file);
		devfsadm_exit(1);
		/*NOTREACHED*/
	}

	if (fattach(fd, door_file) == -1) {
		err_print(CANT_CREATE_DOOR, door_file, strerror(errno));
		(void) s_unlink(door_file);
		devfsadm_exit(1);
		/*NOTREACHED*/
	}
```
this code from the `daemon_update` function checks to see if the door file can be
opened (as a regular read-write file) under the  `SYNCH_DOOR_PERMS` permissions.
If it **CAN**, the file is immediately closed, a door is created, and then
fattach is used to assign the door to that path.

This is clearly a TOCTOU issue, but there seems to be no uniform approach to
determining whether a given path is usable as a door file. A bit later on, it
does the same thing for the `devname_lookup_door`.

`devname_kcall` is used to pass a door path into the kernel.

The `sync_handler` server procedure checks `door_cred`s to require the user to
be root before taking *any* other action. If the user is not root, it calls
`goto out;` where `out` is a door return.

This uses `modctl` to communicate with a kernel module (presumably one for
defvs) whenever the lookup door is used.

The `devname_lookup_handler` has a one-liner for checking whether the caller is
root:

```c
    if (door_cred(&cred) != 0 || cred.dc_euid != 0) {
        /* cannot confirm client is root */
```

Here is how it validates that the door payload is legit, just that it is
nonzeo:
```c
	if (argp == NULL || arg_size == 0) {
		vprint(DEVNAME_MID, "devname_lookup_handler: argp wrong\n");
		error = DEVFSADM_RUN_INVALID;
		goto done;
	}
```

The [Switching Table]({{<ref "docs/tradecraft/switching_table.md" >}}) here (a
`case` statement) only contains one entry. Looks like more were anticipated but
never materialized. If a client calls the door with a payload that doesn't
specify this command, the `default` case will run and the response payload will
contain an error:

```c
	default:
		/* log an error here? */
		error = DEVFSADM_RUN_NOTSUP;
		break;
	}

done:
	vprint(DEVNAME_MID, "devname_lookup_handler: error %d\n", error);
	res.devfsadm_error = error;
	(void) door_return((char *)&res, sizeof (struct sdev_door_res),
	    NULL, 0);
```

The `message.h` header ctains a bunch of error macros, one of which is for
complaining about not being able to create an event door.
