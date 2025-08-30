# IKED

```mdoc
.Pa usr/src/cmd/cmd-inet/usr.sbin/ipsecutils/ikeadm.c
.Pa usr/src/lib/libipsecutil/common/ipsec_util.c
.Pa usr/src/lib/libipsecutil/common/ikedoor.h
```

## Notes
Awareness of doors for debugging information. Alongside other application state,
consider doors. Specific debug flags for providing state information *only* for
doors, or doors in addition to other entities.

Version numbers for door protocols. Increment version numbers whenever
structures change, so that clients and servers do not become confused when
exchanging old versions of a payload.

Hardcode the door's filesystem path as a macro. (This door lives in `/var/run`).

Macros that round up a door payload size to the next power of 2 (up to sizeof
`unit64_t`)

Within a translation unit, set a static door descriptor to -1 at compile time.
Any code needing to access this at runtime will need to check whether it is
positive first:

```c
static int	doorfd = -1;

/* ... */

static int
open_door(void)
{
	if (doorfd >= 0)
		(void) close(doorfd);
	doorfd = open(DOORNM, O_RDONLY);
	return (doorfd);
}
```

Retry opening a door if a `door_call` fails, and then try calling the door again
until we hit some upper limit of retries:

```c
retry:
	if (door_call(doorfd, &arg) < 0) {
		if ((errno == EBADF) && ((++retries < 2) &&
		    (open_door() >= 0)))
			goto retry;
		(void) fprintf(stderr,
		    gettext("Unable to communicate with in.iked\n"));
		Bail("door_call failed");
	}
```

Use-case-specific wrapper functions for door calls. For example, `ikedoor_call`
takes all door arguments except the return buffer, which it sets to null.
Additionally, it incorporates the retry scheme above. So every door upcall
within iked has this same recovery pattern.

Structures passed back from door calls should have fields that describe whether
the upcall encountered an error:

```c
	rtn = ikedoor_call((char *)&sreq, sizeof (ike_statreq_t), NULL, 0);
	if ((rtn == NULL) || (rtn->svc_err.cmd == IKE_SVC_ERROR)) {
		ikeadm_err_exit(&rtn->svc_err, gettext("error getting stats"));
	}
```

where `rtn->svc_err` is an enum that describes errors which can occur within the
door server.

Conditional logic in the custom wrapper to inspect door attributes and make
application-level descisions based on how the door is configured:

```c
	if ((ndesc > 0) && (descp->d_attributes & DOOR_RELEASE) &&
	    ((errno == EBADF) || (errno == EFAULT))) {
		/* callers assume passed fds will be closed no matter what */
		(void) close(descp->d_data.d_desc.d_descriptor);
	}
```

ikeadm seems to use the same door descriptor for everything, and relies on
fields in the door payload struct to differentiate between requests. Ikeadm is
mostly concerned with modifying or removing variables known to the ike service.

Have the client open a user-specified file and pass the resulting fd to the door
server rather than passing a user-specified path to the door server and asking
the server to open that. This allows clients to grant the (unprivileged?) server
access to files that only they can open.

Document what door payload structures should look like before a `door_call` and
what they will look like after `door_return`.
