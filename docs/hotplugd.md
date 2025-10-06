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
