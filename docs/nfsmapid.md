# [`NFSMAPID(8)`](https://www.illumos.org/man/8/nfsmapid)
*NFS user and group id mapping daemon*

* [`usr/src/cmd/fs.d/nfs/nfsmapid/nfsmapid_server.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/nfsmapid/nfsmapid_server.c)
* [`usr/src/cmd/fs.d/nfs/nfsmapid/nfsmapid_test.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/nfsmapid/nfsmapid_test.c)

```c
/*
 * Door server routines for nfsmapid daemon
 * Translate NFSv4 users and groups between numeric and string values
 */
```

The `idmap_kcall` function takes either a door descritor as an argument, or `-1`
(which is never a valid file descriptor) as a signal to flush any idmap-related
caches that the kernel may be holding. This is utlimately forwarded to the
kernel via the `_nfssys` system call.


## Command Switching
`nfsmpaid_func` is a server procedure which simulataneously casts the door
arguments to two different types: `refd_door_args_t` and `mapid_arg`. As a
`mapid_arg`, the payload's `cmd` field is switched among functions that map
between group names and ids or user names and ids. Only in one case does
the server use the `refd_door_args_t` form of the payload, this in order to
serve some kind of network statistics.

So this is an example of both a [Switching Table](switching_table.md) and
[Payload Polymorphism](payload_polymorphism.md) (though for the latter, not in
the usual sense).

Part of the validation of the user-provided payload is to ensure that the number
of bytes transferred is *at least* the size of the struct into which we will
cast that payload:

```c
	if (arg_size < sizeof (refd_door_args_t)) {
		syslog(LOG_ERR,
		    "nfsmapid_server_netinfo failed: Invalid data\n");
        door_return(NULL, 0, NULL, 0);
	}
```

There is also an appearance of utf8 decoding here (see `decode_args` and
`xdr_utf8string`), which falls under the category (not always practiced!) of
validating user-provided input.


## Expecting `door_return` failure

```c
	/*
	 * There is a chance that the door_return will fail because the
	 * resulting string is too large, try to indicate that if possible
	 */
	if (door_return((char *)resp,
	    MAPID_RES_LEN(resp->u_res.len), NULL, 0) == -1) {
		resp->status = NFSMAPID_INTERNAL;
		resp->u_res.len = 0;
		(void) door_return((char *)&result, sizeof (struct mapid_res),
		    NULL, 0);
	}
```

Why is it that we are so confident the second `door_return` call will succeed?
What is the size above which we begin to worry about `door_return` failures?

Here we explicitly check to see if `door_return` returned `E2BIG` to complain
about the payload being too big:

```c
send_response:
	srsz = res_size;
	errno = 0;

	error = door_return(res, res_size, NULL, 0);
	if (errno == E2BIG) {
		failed_res.res_status = EOVERFLOW;
		failed_res.xdr_len = srsz;
		res = (caddr_t)&failed_res;
		res_size = sizeof (refd_door_res_t);
	} else {
		res = NULL;
		res_size = 0;
	}

	door_return(res, res_size, NULL, 0);
```


## Tests
The `nfsmapid_test.c` file contains tests which actually place door calls. This
does not seem to be a common pattern.

Instead of using a global [Static File Descriptor](static_file_descriptor.md)
for the door, the function `nfs_idmap_doorget()` declares a local static
descriptor; this function will attempt to open the door if one has not already
been opened, but otherwise return the opened doorfd:

```c
int
nfs_idmap_doorget()
{
	static int doorfd = -1;

	if (doorfd != -1)
		return (doorfd);

	if ((doorfd = open(NFSMAPID_DOOR, O_RDWR)) == -1) {
		perror(NFSMAPID_DOOR);
		exit(1);
	}
	return (doorfd);
}
```

This function will exit rather than returning `-1`. However, all callers check
for this return value anyhow:

```c
    /* from nfs_idmap_uid_str() */
	if ((doorfd = nfs_idmap_doorget()) == -1) {
        fprintf(stderr, "nfs_idmap_uid_str: Can't "
            "communicate with mapping daemon nfsmapid\n");
	}
```


### Unmapping `rbuf`
All the tests unmap the returned buffer *iff* the returned buffer has a
different address than the buffer provided to the `door_call`:

```c
out:
	if (resp != mapresp)
		munmap(door_args.rbuf, door_args.rsize);
	return (error);
```

### Anticipating `door_call` failure
This code anticipates that `door_call` itself will fail, rather than the door
server returning an error. This is good defense against the server dying, but it
does not seem to be used all over the place:

```c
	if (door_call(doorfd, &door_args) == -1) {
		perror("door_call failed");
	}
```
