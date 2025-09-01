# [`DLMGMTD(8)`](https://illumos.org/man/8/dlmgmtd)
*The Datalink Management Daemon*

* [`usr/src/cmd/dlmgmtd/dlmgmt_db.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/dlmgmtd/dlmgmt_db.c)
* [`usr/src/cmd/dlmgmtd/dlmgmt_door.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/dlmgmtd/dlmgmt_door.c)
* [`usr/src/cmd/dlmgmtd/dlmgmt_impl.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/dlmgmtd/dlmgmt_impl.h)

First, a comment about deadlocks:

> Because of the upcall architecture of dlmgmtd this can lead to deadlock
> with the following scenario:
>    a) the thread preparing to fork will have acquired the malloc locks
>       then attempt to suspend every thread in preparation to fork.
>    b) all of the upcalls will be blocked in `door_ucred()` trying to malloc()
>       and get the credentials of their caller.
>    c) we can't suspend the in-kernel thread making the upcall.
>
> Thus, we cannot serve door requests because we're blocked in malloc()
> which fork() owns, but fork() is in turn blocked on the in-kernel thread
> making the door upcall.  **This is a fundamental architectural problem with
> any server handling upcalls and also trying to fork()**.

Door clients can be either userland or kernel.

This door server has to be aware of zones, because links can be
created in one zone but assigned to another for use. The goal is
for door clients to be restricted to viewing information about
links associated with their zone, and restricted to modifying
information about links created in their zone.

The handler struct (for building out the [Switching
Table](switching_table.md)
specifices that each handler takes a `zoneid_t` struct so it can
meet these goals.

door clients have to have multiple privileges in order to work
with links:

* `PRIV_SYS_IPTUN_CONFIG`
* `PRIV_SYS_DL_CONFIG`
* `PRIV_SYS_NET_CONFIG`

There is a common AVL tree containing link information, called
`dlmgmt_id_avl`.  Write access to this tree has to be protected
by a lock by calling `dlmgmt_table_lock`.

[Payload Polymorphism](payload_polymorphism.md) is used, and of
course no serialization or deserialization is done. However,
some properties of the payload are validated after casting:

```c
static void
dlmgmt_remapid(void *argp, void *retp, size_t *sz, zoneid_t zoneid,
    ucred_t *cred)
{
	dlmgmt_door_remapid_t	*remapid = argp;
	dlmgmt_remapid_retval_t	*retvalp = retp;
    /* blah blah */

	if (!dladm_valid_linkname(remapid->ld_link)) {
		retvalp->lr_err = EINVAL;
		return;
	}
```

To support poylmorphism, the switching talbe specifies the size
of the expected input and return types for each handler.

Also of interest is that each handler seems to have its own
separate lock for the data structues that it affects (which
makes sense). This allows the door server to handle unrelated
calls concurrently.

Always a good idea to free a credential object after use, since
this memory is allocated by the call to `door_ucred`:

```c
	ucred_t			*cred = NULL;
    /* ... */

	if (door_ucred(&cred) != 0 || (zoneid = ucred_getzoneid(cred)) == -1) {
		err = errno;
		goto done;
	}
    /* ... */

done:
	if (cred != NULL)
		ucred_free(cred);
```

If any handler returns the `ENOSPC` error, it gets invoked
again, but this time the desired `acksz` is specified by the
handler, and `alloca` will hook us up with the reight amount of
space:

```c
again:
	retvalp = alloca(acksz);
	sz = acksz;
	infop->di_handler(argp, retvalp, &acksz, zoneid, cred);
	if (acksz > sz) {
		/*
		 * If the specified buffer size is not big enough to hold the
		 * return value, reallocate the buffer and try to get the
		 * result one more time.
		 */
		assert(((dlmgmt_retval_t *)retvalp)->lr_err == ENOSPC);
		goto again;
	}
```

Of course, we see the warning about not mixing `malloc` and
`door_return`:

> Note that malloc() cannot be used here because `door_return`
> never returns, and memory allocated by malloc() would get leaked.
> Use alloca() instead.

The [Static File Descriptor](static_file_descriptor.md) pattern is used,
and mentions some conflict about putting the handle in the
libdladm code. The `dlmgmt_door_fd` variable seems to be the one in play.

`dlmgmt_door_fini` is an idempotent cleanup function, though it doesn't attempt
to remove any door paths from the filesystem.

`dlmgmt_door_attach` attaches a door *inside of another zone* which is pretty
cool. It also tries to `fdetach` the existing door path first in case a previous
`dlmgmtd` exited uncleanly.
