# DRD
*What the hell is a 'sun4v DR daemon'??*

* [`usr/src/cmd/drd/drd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/drd/drd.c)

It is designed to support multiple
"backends" (door call handlers?) but currently is hardcoded to just one, rather
than using a switching table.

The main thread loops forever after initializing the door server:

```c
	/* loop forever */
	for (;;) {
		pause();
	}
```

What is the advantage of this, or is there any advantage, over called
[`door_bind`](https://www.illumos.org/man/3C/door_bind) to lend this thread to
the server pool? Otherwise it will just take up space in the scheduler.

Before the door server is initialized, this program opens the `DRCTL_DEV`
character device. When the door server is initialized, it uses `ioctl` to send
the door descriptor to that device. Here is a summary, sans error handling:

```c
drd_init_door_server() {
	/* open the drctl device (static fd) */
	drctl_fd = open(DRCTL_DEV, O_RDWR);

	/* create the door */
	door_fd = door_create(drd_door_server, NULL, 0);

    /* send the door descriptor to drctl */
    ioctl(drctl_fd, DRCTL_IOCTL_CONNECT_SERVER, door_fd);
}
```

This allows the drctl device (in the kernel) to place door calls into the drd
daemon (in userspace). In this case, no filesystem representationfor this door
is necessary.

(This daemon does support a `--standalone` flag for testing purposes, which
attaches the door at `/tmp/drd_door`.) 
