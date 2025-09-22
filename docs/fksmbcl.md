# SMB Development Tool
* [`usr/src/cmd/fs.d/smbclnt/fksmbcl/fkiod_cl.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/smbclnt/fksmbcl/fkiod_cl.c)

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
