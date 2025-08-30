# Bridging Control Daemon

* [`usr/src/cmd/cmd-inet/usr.lib/bridged/door.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/usr.lib/bridged/door.c)
* [`usr/src/cmd/cmd-inet/usr.lib/bridged/main.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/usr.lib/bridged/main.c)
* [`usr/src/cmd/cmd-inet/usr.lib/bridged/global.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/usr.lib/bridged/global.h)
* [`usr/src/cmd/cmd-inet/usr.lib/bridged/Makefile`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/usr.lib/bridged/Makefile)

Makes use of the static `door_fd` convention, also a static
`doorname` string (which is implicitly initialized to `'\0'`).
This allows cleanup code to run conditionally, so that invoking
the following cleanup function is idempotent:

```c
static void
cleanup_door(void)
{
	if (door_fd != -1) {
		(void) door_revoke(door_fd);
		door_fd = -1;
	}
	if (doorname[0] != '\0') {
		(void) unlink(doorname);
		doorname[0] = '\0';
	}
}
```

(note that this code is not necessarily *reentrant* -- it is
idempotent if and only if one thread invokes it at a time)

modes for door directory and file are defined as macros; Though
this begs the question of whether "read" or "write" modes have
any difference on a door.

The `bridge_door_server` procedure seems to be focused on
locking or unlocking some engine -- the engine must be locked
before the server procedure does any work, and must be unlocked
before `door_return` is called.

If the engine cannot be locked, the procedure returns
immediately. There seems to be no error-handling when when the
engine cannot be unlocked; presumably this is infallible. 

Rather than using a routing table, this procedure relies on case
statements that switch based on the `bdc_type` field of a
`bridge_door_cmd_t` structure. So it still sticks to the notion
of having a "command" payload.

There is cleanup code at the end of the server procedure that
makes sure the engine is unlocked and `door_return` is called
even if a case statement exits early due to a `break`.

No one seems to care here if `door_return` actually returns. Why
is this important in some places but not in others?

A curiosity in the `init_door` function is the way that the door
path is computed:

```c
/* Each instance gets a separate door. */
(void) snprintf(doorname, sizeof (doorname), "%s/%s", DOOR_DIRNAME,
    instance_name);

fd = open(doorname, ...);
```

In `main.c`, a constant called `instance_name` is declared with
the value "default". When `bridged(8)` is executed, an instance
name must be passed via `argv`, which is assigned to
`instance_name` and then used by `init_door` to compute the
path. This seems to be a bizarre way of passing an argument...
