# [`SMBIOD(8)`](https://illumos.org/man/8/smbiod)
*SMB Client I/O Daemon*


## SMBFS I/O Daemon
* [`usr/src/cmd/fs.d/smbclnt/smbiod-svc/smbiod-svc.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/smbclnt/smbiod-svc/smbiod-svc.c)

static string to hold the path of the door jamb even though it is defined as a
macro elsewhere:

```c
static const char door_path[] = SMBIOD_SVC_DOOR;
```

Server procedure `svc_dispatch` allows a null argument (see the [Liveness
Check](liveness_check.md) pattern).

```c
void
svc_dispatch(void *cookie, char *argp, size_t argsz,
    door_desc_t *dp, uint_t n_desc)
{
	if (argp == NULL) {
        int32_t rc = 0;
        door_return((void *)&rc, sizeof (rc), NULL, 0);
	}

    /* ... actual code ... */
}
```

## SMB Development Tool
* [`usr/src/cmd/fs.d/smbclnt/fksmbcl/fkiod_cl.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/smbclnt/fksmbcl/fkiod_cl.c)
* [`usr/src/cmd/fs.d/smbclnt/fksmbcl/fknewvc.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/smbclnt/fksmbcl/fknewvc.c)

This tool doesn't seem to have a manual entry, but here is the issue which
introduces it: [https://www.illumos.org/issues/9874](https://www.illumos.org/issues/9874)

Because this is a testing tool, it has some hardcoded "mock" behavior:

```c
/*
 * Make sure we don't call the real IOD here.
 */
int
smb_iod_open_door(int *fdp)
{
	*fdp = -1;
	return (ENOTSUP);
}
```

Since doors have such unusual control flow, resources (including the door
itself) may be cleaned up at non-obvious times:

```c

	/*
	 * In the error case, the caller may try again
	 * with new auth. info, so keep the door open.
	 * Error return will close in smb_ctx_done.
	 */
	return (err);
```
