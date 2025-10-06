# [`HOTPLUG(8)`](https://www.illumos.org/man/8/hotplug)
*configure hotplug connectors and ports*

*Note*: there does not seem to be a man page for `hotplugd(8)` even though it is referenced in other pages.

* .Pa usr/src/cmd/hotplugd/hotplugd_door.c

Use of [Static File Descriptor](static_file_descriptor.md) pattern. This allows the `door_server_init` function to run and create the door as follows:

* Create the "door file" (jamb)
  * Assume the service is running if `open` returns `EEXIST` -- but that might not be reliable.
  * close the file descriptor for the jamb if it is created successfully
* Create the door descriptor (with `REFUSE_DESC` and `NO_CANCEL` and no cookied, which are reasonable defaults)
* `fdetach` the jamb, even though it was only recently created? How could there be stale door associations already? How could `open(O_CREAT|O_EXCL|O_RDONLY)` succeed if the door jamb already had door associations?
* `fattach` the jamb, revoking and detaching (and resetting the global descriptor) in the event of `fattach` failure.

`door_server_init` is not idempotent, though `door_server_fini` does seem to be.

The server procedure uses
[`LIBNVPAIR(3LIB)`](https://www.illumos.org/man/3LIB/libnvpair) to unpack
name-value pairs provided by the client. It also uses a [Request
Switching](switching_table.md) table. via the `hp_cmd_t` type. However, there is
a secret case that is triggered when the payload size is the size of `uint64_t`:

```c
	/* Special case to free a results buffer */
	if (sz == sizeof (uint64_t)) {
		free_buffer(*(uint64_t *)(uintptr_t)argp);
		(void) door_return(NULL, 0, NULL, 0);
		return;
	}
```

So the interface is both the commands provided *and* the size of the payload
provided, which isn't pretty. It looks like the idea is for the client to pass a
index number (not a pointer) for a structure in a list that is then freed by the
server. This sounds like a good avenue for a denial of service attack,
especially since `/var/run/hotplugd_door` is created with world-read
permissions. Any user on the system could just free all the results buffers.

If one client is using a buffer, can another client delete it out from under
them and cause problems, or merely cause a delay while the resources are
re-allocated?
