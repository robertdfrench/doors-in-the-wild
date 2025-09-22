# SMB Development Tool
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
