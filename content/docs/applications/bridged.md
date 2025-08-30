# Bridging Control Daemon

* [`usr/src/cmd/cmd-inet/usr.lib/bridged/door.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/usr.lib/bridged/door.c)

MAkes use of the static `door_fd` convention, also a static
`doorname` string (though it is not assigned before runtime).

The `bridge_door_server` procedure seems to be focused on
locking or unlocking some engine -- the engine must be locked
before the server procedure does any work, and must be unlocked
before `door_return` is called.

No one seems to care here if `door_return` actually returns. Why
is this important in some places but not in others?
