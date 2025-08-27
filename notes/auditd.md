# AuditD

```mdoc
.Pa usr/src/cmd/auditd/doorway.c
.Pa /usr/src/cmd/auditd/auditd.c
```

Static doorfd descriptor set to -1 at compile time, so that the command startw
with an invalid door descriptor (that is presumably reset on first failure)

Use of `door_revoke`


Purposefully stall the door server until some other resource is available:

```c
/*
 * wait_a_while() -- timed wait in the door server to allow output
 * time to catch up.
 */
static void
wait_a_while()
{
	struct timespec delay = {0, 500000000};	/* 1/2 second */;

	(void) pthread_mutex_lock(&(in_thr.thd_mutex));
	in_thr.thd_waiting = 1;
	(void) pthread_cond_reltimedwait_np(&(in_thr.thd_cv),
	    &(in_thr.thd_mutex), &delay);
	in_thr.thd_waiting = 0;
	(void) pthread_mutex_unlock(&(in_thr.thd_mutex));
}

// ^ called from inside the `input` door server procedure
```

Use of `DOOR_REFUSE_DESC` to prevent descriptors from being passed.

Use of `DOOR_NO_CANCEL`

The door server here is non-reentrant. The main daemon launches a door server
thread in response to signal events, and seems to configure the door (via
pthreads) to avoid launching additional server threads? See `main` in `auditd.c`
and `auditd_thread_init` in `doorway.c`.

The `input` server procedure in `doorway.c` has a comment stating that it is not
reentrant.
