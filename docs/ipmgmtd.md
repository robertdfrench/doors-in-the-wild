# ipmgmtd

* [`usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_door.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_door.c)
* [`usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_impl.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_impl.h)
* [`usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_main.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_main.c)
* [`usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_persist.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/lib/ipmgmtd/ipmgmt_persist.c)
* [`usr/src/cmd/cmd-inet/lib/ipmgmtd/Makefile`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/cmd-inet/lib/ipmgmtd/Makefile)

`libipadm.co` acts as a door client that calls into ipmgmtd.

ipmgmtd uses a single handler for incoming door calls, and routes them to
different "sub-handlers" depending on the value of the incoming command. Each
individual handler is responsible for calling `door_return`. This requires a
table of commands (constants) which map to handlers (function pointers):

```c
/* maps door commands to door handler functions */
static ipmgmt_door_info_t i_ipmgmt_door_info_tbl[] = {
	{ IPMGMT_CMD_SETPROP,		B_TRUE,  ipmgmt_setprop_handler },
	{ IPMGMT_CMD_SETIF,		B_TRUE,  ipmgmt_setif_handler },
	{ IPMGMT_CMD_SETADDR,		B_TRUE,  ipmgmt_setaddr_handler },
    /* yadda yadda ... */
	{ IPMGMT_CMD_AOBJNAME2ADDROBJ,	B_FALSE, ipmgmt_aobjop_handler },
	{ IPMGMT_CMD_LIF2ADDROBJ,	B_FALSE, ipmgmt_aobjop_handler },
	{ IPMGMT_CMD_IPMP_UPDATE,	B_FALSE, ipmgmt_ipmp_update_handler},
	{ 0, 0, NULL },
};
```

Much like routes in a web application, this provides the opportunity to enforce
uniform access controls for before any handler is actually invoked. For example,
ipmgmtd needs to ensure that the user has the `solaris.network.interface.config`
entitlement (via
[`chkauthattr`](https://www.illumos.org/man/3SECDB/chkauthattr)) before doing
*any* work:

```c
	/* check for solaris.network.interface.config authorization */
    /* Look up user with door_ucred, passwd entry, elided... */

    if (chkauthattr(NETWORK_INTERFACE_CONFIG_AUTH,
        pwd.pw_name) != 1) {
        err = EPERM;
        ipmgmt_log(LOG_ERR, "Not authorized for operation.");
        goto fail;
    }
    ucred_free(cred);

	/* individual handlers take care of calling door_return */
	infop->idi_handler((void *)argp);
	return;

fail:
	ucred_free(cred);
	retval.ir_err = err;
	(void) door_return((char *)&retval, sizeof (retval), NULL, 0);
```

Additionally, some handlers validates that they were invoked with the appropriate
command, possibly as an "error checking in depth" measure? This happens even
though `ipmgmt_handler` only dispatches functions based on the
`i_ipmgmt_door_info_tbl` table. 

```c
static void
ipmgmt_getprop_handler(void *argp)
{
	ipmgmt_prop_arg_t	*pargp = argp;

	assert(pargp->ia_cmd == IPMGMT_CMD_GETPROP);

    /* ... */
}

static void
ipmgmt_setprop_handler(void *argp)
{
	ipmgmt_prop_arg_t	*pargp = argp;

	assert(pargp->ia_cmd == IPMGMT_CMD_SETPROP);
    
    /* ... */
}
```

It is also the case that different handlers expect different argument
structures. Since they are all called generically, every handler must accept
`void *argp` as an argument and then cast this pointer to the type which they
expect (`ipmgmt_setaddr_arg_t`, `ipmgmt_prop_arg_t`, etc).

Many handlers allocate an `ipmgmt_retval_t` yet do not assign anything to it
before returning it in `door_return`. Sometimes all they assign to it as an
error code (since this struct has an error field).

Never call malloc in a server procedure without either freeing it before calling
`door_return` or establishing some other garbage collection mechanism.
`door_return` never... returns... so calls to malloc could end up producing
memeory leaks. Instead, impgmt uses
[`alloca(3C)`](https://smartos.org/man/3C/memalign) instead.

Goto statements, when used inside server procedures, must always end with a call
to `door_return`. 

ipmgmtd also uses the "global static door descriptor" pattern. If attempts to
set up the door fail, cleanup should a) call `door_revoke` and b) reset the
global static descriptor to -1.

This is useful for starting a daemon even when a door file already exists on the
filesystem (such as when the previous daemon died before cleaning up):

```c
/*
 * fdetach first in case a previous daemon instance exited
 * ungracefully.
 */
(void) fdetach(IPMGMT_DOOR);
if (fattach(ipmgmt_door_fd, IPMGMT_DOOR) != 0) {
    err = errno;
    ipmgmt_log(LOG_ERR, "failed to attach door to %s: %s",
        IPMGMT_DOOR, strerror(err));
    goto fail;
}
```

It's worth logging failures to attach or detach a door, as that could become an
operational concern, and a log message providing evidence would go a long way in
such a case.

Sometimes it's good to build up shared data structures or do other preparatory
work *before* any doors are opened so that this work can be done without
applying locks.
