# [`MOUNTD(8)`](https://illumos.org/man/8/mountd)

* [`usr/src/cmd/fs.d/nfs/lib/nfs_resolve.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/lib/nfs_resolve.c)
* [`usr/src/cmd/fs.d/nfs/mountd/mountd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/mountd.c)
* [`usr/src/cmd/fs.d/nfs/mountd/mountd.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/mountd.h)
* [`usr/src/cmd/fs.d/nfs/mountd/nfs_cmd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/nfs_cmd.c)
* [`usr/src/cmd/fs.d/nfs/mountd/nfsauth.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/nfsauth.c)


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


## `nfsauth_func`
This is a server procedure in `nfsauth.c`. Uses the "double return" pattern
where a `door_return` with a payload is expected to fail, but a `door_return`
with no payload is expected to succeed?

```c

out:
	(void) door_return((char *)rbuf, rbsz, NULL, 0);
	(void) door_return(NULL, 0, NULL, 0);
	/* NOTREACHED */
```

It uses `xdrmem_create` to decode the incoming door data, writes an error to
syslog if the data can't be decoded, and then uses `xdrmem_create` again to
*encode* the result.

The logic at the bottom of this function is crazy. There are goto labels that
occur inside an if statement, so that goto has a sortof "branch but branch a
little further down" effect:

```c
	/*
	 * Encode the results before passing thru door.
	 */
	rbsz = xdr_sizeof(xdr_nfsauth_res, &res);
	if (rbsz == 0)
		goto failed;
	rbuf = alloca(rbsz);

	xdrmem_create(&xdrs_r, rbuf, rbsz, XDR_ENCODE);
	if (!xdr_nfsauth_res(&xdrs_r, &res)) {
		xdr_destroy(&xdrs_r);
failed:
		xdr_free(xdr_nfsauth_res, (char *)&res);
		/*
		 * return only the status code
		 */
		res.stat = NFSAUTH_DR_EFAIL;
		rbsz = sizeof (uint_t);
		rbuf = (caddr_t)&res.stat;

		goto out;
	}
	xdr_destroy(&xdrs_r);
	xdr_free(xdr_nfsauth_res, (char *)&res);

out:
	(void) door_return((char *)rbuf, rbsz, NULL, 0);
	(void) door_return(NULL, 0, NULL, 0);
	/* NOTREACHED */
```
