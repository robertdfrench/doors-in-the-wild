# [`MOUNTD(8)`](https://illumos.org/man/8/mountd)

* [`usr/src/cmd/fs.d/nfs/lib/nfs_resolve.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/lib/nfs_resolve.c)
* [`usr/src/cmd/fs.d/nfs/mountd/mountd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/mountd.c)
* [`usr/src/cmd/fs.d/nfs/mountd/mountd.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/mountd.h)
* [`usr/src/cmd/fs.d/nfs/mountd/nfs_cmd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/nfs_cmd.c)


The `_nfssys` call can be used to pass door descriptors into the kernel (likely
for the nfs module).

Thread parking rather than binding to a thread pool:

```c
	/*
	 * Wait for incoming calls
	 */
	/*CONSTCOND*/
	for (;;)
		(void) pause();
```

The functions that create the doors are each called in their own threads and
then parked in a pause loop (as above):

```c
	/*
	 * Create the cmd service thread with same signal disposition
	 * as the main thread. We need to create a separate thread
	 * since mountd() will be both an RPC server (for remote
	 * traffic) _and_ a doors server (for kernel upcalls).
	 */
	if (thr_create(NULL, 0, cmd_svc, 0, thr_flags, &cmd_thread)) {
		syslog(LOG_ERR, gettext("Failed to create CMD svc thread"));
		exit(2);
	}

	/*
	 * Create an additional thread to service the rmtab and
	 * audit_mountd_mount logging for mount requests. Use the same
	 * signal disposition as the main thread. We create
	 * a separate thread to allow the mount request threads to
	 * clear as soon as possible.
	 */
	if (thr_create(NULL, 0, logging_svc, 0, thr_flags, &logging_thread)) {
		syslog(LOG_ERR, gettext("Failed to create LOGGING svc thread"));
		exit(2);
	}
```

Why on earth is this necessary? Who cares about the signal disposition when the
thread is only going to wait in a loop, and the door threads are not
cancellable?

`door_ki_open` is mentioned.

Common error handling for door calls:

```c
static void
nfscmd_err(door_desc_t *dp, nfscmd_arg_t *args, int err)
{
	nfscmd_res_t res;

	res.version = NFSCMD_VERS_1;
	res.cmd = NFSCMD_ERROR;
	res.error = err;
	(void) door_return((char *)&res, sizeof (nfscmd_res_t), NULL, 0);
	(void) door_return(NULL, 0, NULL, 0);
	/* NOTREACHED */

}
```

curiously that throws away door descriptors and args, which makes sense, but
it's a very misleading interface. Or is the idea to make it difficult for
someone to call this unless they are in posession of these values (I.e.
originally invoked from a server procedure)?

Seems kindof common in `nfs_cmd.c` to pass the descriptors around even as
arguments to functions that do not use them.
