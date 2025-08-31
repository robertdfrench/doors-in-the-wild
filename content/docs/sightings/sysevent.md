# `SYSEVENTD(8)`
* .Ny usr/src/lib/libsysevent/libsysevent.c

There are **two** (2) consecutive calls to `door_return` at the bottom of the
`event_deliver_service` server procedure:

```c
return_from_door:
	(void) door_return((void *)&ret, sizeof (ret), NULL, 0);
	(void) door_return(NULL, 0, NULL, 0);
}
```

This procedure is replete with `goto return_from_door;` statements. Perhaps the
first call is expected to fail for some reason, and the second is either
infallible or a Hail Mary pass?
