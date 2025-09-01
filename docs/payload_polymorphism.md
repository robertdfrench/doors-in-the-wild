# Payload Polymorphism
Sometimes a single server procedure will accept more than one data structure as
input. This is often the case when a [Switching
Table](switching_table.md) is used.

The server procedure will check a "header" field within the payload, to
determine what "type" the payload is, or at least which handler should accept
it. Once this decision has been made, the struct is recast to a more specific
type that (hopefully) aligns with the data provided by the user.

The following illustration of this idea is taken from
[`usr/src/cmd/dlmgmtd/dlmgmt_door.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/dlmgmtd/dlmgmt_door.c):

```c
static void
dlmgmt_remapid(void *argp, void *retp, size_t *sz, zoneid_t zoneid,
    ucred_t *cred)
{
	dlmgmt_door_remapid_t	*remapid = argp;
	dlmgmt_remapid_retval_t	*retvalp = retp;
	dlmgmt_link_t		*linkp;
	char			oldname[MAXLINKNAMELEN];
	boolean_t		renamed = B_FALSE;
	int			err = 0;
    /* etc */
}
```

Even the return value has a type that is specific to the handler.
