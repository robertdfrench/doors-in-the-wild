---
title: "WPA Supplicant"
---
# WPA Supplicant

* [`usr/src/cmd/cmd-inet/usr.lib/wpad/wpa_supplicant.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/usr.lib/wpad/wpa_supplicant.c)
* [`usr/src/cmd/cmd-inet/usr.lib/wpad/eloop.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/usr.lib/wpad/eloop.c)

Uses the [Static File Descriptor]({{< ref
"docs/tradecraft/static_file_descriptor.md" >}}) pattern.

The `wpa_supplicant_door_destroy` function logs a message if a door fails to be
revoked or detached. Not all door servers do this.

In `main`, we infer the path of the door file from the name of the wifi link
device, as provided on the command line by `smf(7)`:

```c
	/*
	 * Get the device name of the link, which will be used as the door
	 * file name used to communicate with the driver. Note that different
	 * links use different doors.
	 */
	if (dladm_phys_info(handle, linkid, &dpa, DLADM_OPT_ACTIVE) !=
	    DLADM_STATUS_OK) {
		wpa_printf(MSG_ERROR,
		    "Failed to get device name of link '%s'.", link);
		dladm_close(handle);
		dlpi_close(dh);
		return (-1);
	}
	(void) snprintf(door_file, MAXPATHLEN, "%s_%s", WPA_DOOR, dpa.dp_dev);
```

Presumably, each driver also knows this convention, and will use this path to
open a door into the appropriate `wpad` daemon.

Cookies are used here! A `wpa_supplicant` struct is created by main (on its
stack??) and its address is used as a cookie when the door is created. This
struct is then used in the `wpa_event_handler` function whenever the server
procedure is invoked (by the driver?).

The `main` function initializes some event loop data with this WPA supplicant
struct by calling `eloop_init`. When the main function that calls the
`eloop_run` function to hang out in the event loop, that's what keeps the
process from terminating (and this what keeps the `wpa_s` struct alive in the
stack). This also allows event loop handling to reference the same struct that
is available to the server procedure.

The cleanup for an `fattach` failure is interesting. It will detach the door
from the filesystem only if `fattach` returns an error *other than* `EBUSY`. So
can `fattach` succeed (associate the door with a filesystem path) but still
claim to be busy?

```c
	if (fattach(door_id, doorname) < 0) {
		if ((errno != EBUSY) || (fdetach(doorname) < 0) ||
		    (fattach(door_id, doorname) < 0)) {
			(void) door_revoke(door_id);
			door_id = -1;
			error = -1;

			goto out;
		}
	}

out:
	return (error);
```
