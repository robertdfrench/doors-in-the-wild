# Net Config Daemon / Network Auto-Magic Daemon

```mdoc
.Pa usr/src/cmd/cmd-inet/lib/netcfgd/netcfgd.c
.Pa usr/src/cmd/cmd-inet/lib/nwamd/door_if.c
.Pa usr/src/cmd/cmd-inet/lib/nwamd/events.h
.Pa usr/src/cmd/cmd-inet/lib/nwamd/main.c
.Pa usr/src/cmd/cmd-inet/lib/nwamd/Makefile
.Pa usr/src/cmd/cmd-inet/lib/nwamd/objects.h
.Pa usr/src/cmd/cmd-inet/lib/nwamd/README
.Pa usr/src/cmd/cmd-inet/lib/nwamd/util.h
```

## Notes
Initialization of the daemon creates a door that `libnwam` calls can use.
Comment from `door_if.c`:

> This file exports two functions, `nwamd_door_initialize()` (which sets up
> the door) and `nwamd_door_fini()`, which removes it.
>
> It sets up the static routine `nwamd_door_switch()` to be called when a client
> calls the door (via `door_call(3C)`).  The structure `nwam_request_t` is
> passed as data and contains data to specify the type of action requested
> and any data need to meet that request.  A table consisting of entries
> for each door request, the associated authorization and the function to
> process that request is used to handle the various requests.

So this is another pattern where requests are routed (switched?) based on
metadata in the `door_call` payload. A table called `door_req_table` is created
which contains the "door command" (used for request routing), minimum
authorization levels, and a function pointer to handle the request.

Global `doorfd` descriptor is set to -1 when `nwamd` is loaded.

The `nwamd_door_req_state` function uses `pthread_mutext_lock` to protect access
to a variable called `active_ncp` -- it uses a variable called
`active_ncp_mutex` to do this. This prevents door server threads from clobbering
each other.

The `nwamd_door_switch` function is the actual server procedure. It uses
`door_ucred` to get the uid, then `getpwuid` to get the /etc/password entry, and
then uses `chkauthattr` to compare the calling user's authorizations against the
authorization specified in the `door_req_table`.

After the request has been handled, the door ucreds are freed and so is the
reference to the /etc/passwd database (via `ucred_free` and `endpwent`
respectively).

Rather than make each handler call `door_return` on its own, `nwamd_door_switch`
handles this as its final act (writing a log error if door return does not
succeed).

The nwamd door is constructed with `DOOR_NO_CANCEL` and `DOOR_REFUSE_DESC`
options. It calls `pfail` if the door cannot be created, and overwrites the
global `doorfd` value if it is created.

Everyone seems to have a slightly different way of dealing with the fact that
door creation and "door-attachment-to-the-filesystem" are distinct actions. In
this case, `nwamd` uses `creat` to create the door iff it doesn't already exist:


```c
	if (stat(NWAM_DOOR, &buf) < 0) {
		int nwam_door_fd;

		if ((nwam_door_fd = creat(NWAM_DOOR, door_mode)) < 0) {
			int err = errno;
			(void) door_revoke(doorfd);
			doorfd = -1;
			pfail("Couldn't create door: %s", strerror(err));
		}
		(void) close(nwam_door_fd);
    }
```

It also calls `fdetach` on the door path unconditionally before calling
`fattach` to make the new door available at that location on the filesystem.

The `nwamd_door_fini` function acts as a destructor and illustrates the point of
the global static `doorfd` variable: it only calls `door_revoke` on that fd it
if is not already set to -1. So it is an idempotent destructor.

nwamd blocks signal handling outside of a dedicated signal-handling thread. It
does this by creating a "signal set" and passing that to `pthread_sigmask`.

Apparently forking twice will make sure you are not a group leader, and not a
member of a session controlling a terminal, and can therefore never control a
terminal again:

> A little bit of magic here.  By the first fork+setsid, we
> disconnect from our current controlling terminal and become
> a session group leader.  By forking again without calling
> setsid again, we make certain that we are not the session
> group leader and can never reacquire a controlling terminal.


The `usr/src/cmd/cmd-inet/lib/nwamd/README` file reads like someone was trying
to introduce door concepts to posterity. It explains its own use of doors, and
comments on door behavior in general.

nwamd allows clients to subscribe to events by calling a door request that gets
routed to `nwam_events_register`. This returns a SysV message queue that the
client can use to receive events.
