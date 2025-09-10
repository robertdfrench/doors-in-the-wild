# [`AUTOMOUNTD(8)`](https://illumos.org/man/8/automountd)

* [`usr/src/cmd/fs.d/autofs/autod_main.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/autofs/autod_main.c)
* [`usr/src/cmd/fs.d/autofs/autod_mount.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/autofs/autod_mount.c)
* [`usr/src/cmd/fs.d/autofs/automount.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/autofs/automount.h)
* [`usr/src/cmd/fs.d/autofs/ns_files.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/autofs/ns_files.c)
* [`usr/src/cmd/fs.d/nfs/lib/nfs_resolve.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/lib/nfs_resolve.c)
* [`usr/src/cmd/fs.d/nfs/mountd/mountd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/mountd.c)
* [`usr/src/cmd/fs.d/nfs/mountd/mountd.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/mountd.h)
* [`usr/src/cmd/fs.d/nfs/mountd/nfs_cmd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/nfs/mountd/nfs_cmd.c)

`autofs_doorfunc` is the server procedure.

`decode_args` and `encode_res` seem to be doing serialization and
deserialization, which is good to see.

Hardcoded `AUTOFS_DOOR` path.

Automount handlers can be different programs, so server procedures need to be
able to fork and/or exec. See the following server procedures:

* [`automountd_do_fork_exec`](#automountd_do_fork_exec)
* [`automountd_do_exec_map`](#automountd_do_exec_map)

A warning about forking and door threads:

```c
	/*
	 * Before we become multithreaded we fork allowing the parent
	 * to become a door server to handle all mount and unmount
	 * requests. This works around a potential hang in using
	 * fork1() within a multithreaded environment
	 */

	pid = fork1();
	if (pid < 0) {
		syslog(LOG_ERR,
			"can't fork the automountd mount process %m");
		if (door_revoke(did_fork_exec) == -1) {
			syslog(LOG_ERR, "failed to door_revoke(%d) %m",
				did_fork_exec);
		}
		if (door_revoke(did_exec_map) == -1) {
			syslog(LOG_ERR, "failed to door_revoke(%d) %m",
				did_exec_map);
		}
		exit(1);
	} else if (pid > 0) {
		/* this is the door server process */
		automountd_wait_for_cleanup(pid);
	}
```

Mentions of `door_ki_open`.

Attaches the door to a filesystem path ONLY if the `DEBUG` macro is true.

The `did_fork_exec` and `did_exec_map` doors have to be revoked separately. The
follow the [Static File Descriptor](static_file_descriptor.md) pattern.

The encoding and decoding functions take "lambdas" to deal with (perhaps) more
specific type-based encoding rules. Observe that `encode_res` and `decode_args`
both take an argument called `xdrfunc` which is a function pointer that will
return true or false depending on whether the payload could be successfully
(de)serialized.

Uses a switch/case statement based on the `cmd` field of the
`autofs_door_args_t` type to determine how to handle each request. Each of these
commands has its own payload decoding function:

| cmd | decoder |
| --- | ------- |
| `AUTOFS_LOOKUP` | `xdr_autofs_lookupargs` |
| `AUTOFS_MNTINFO` | `xdr_autofs_lookupargs` |
| `AUTOFS_UNMOUNT` | `xdr_umntrequest` |
| `AUTOFS_READDIR` | `xdr_autofs_rddirargs` |
| etc... | etc... |

Curiously, there are parts of the code that anticipate failure from
`door_return`:

```c
		error = door_return((char *)&failed_res,
		    sizeof (autofs_door_res_t), NULL, 0);
		/*
		 * If we got here the door_return() failed.
		 */
		syslog(LOG_ERR, "Bad argument, door_return failure %d", error);
```

and

```c
#ifdef MALLOC_DEBUG
	case AUTOFS_DUMP_DEBUG:
			check_leaks("/var/tmp/automountd.leak");
			error = door_return(NULL, 0, NULL, 0);
			/*
			 * If we got here, door_return() failed
			 */
			syslog(LOG_ERR, "dump debug door_return failure %d",
			    error);
			return;
#endif
```

and

```c
	srsz = res_size;

	errno = 0;
	error = door_return(res, res_size, NULL, 0);

	if (errno == E2BIG) {
		/*
		 * Failed due to encoded results being bigger than the
		 * kernel expected bufsize.
         */
```

## `automountd_do_fork_exec`
Door cookie is unused, as are door desriptors.

Payload size enforcement is handled by casting the door payload to a local
`command_t` struct and then comparing the size of the command struct to the
`arg_size` provided to the server procedure:

```c
	command = (command_t *)argp;
	if (sizeof (*command) != arg_size) {
		res = EINVAL;
		door_return((char *)&res, sizeof (res), NULL, 0);
	}
```

This server procedure forks and then the child executes (via
[`execv(2)`](https://www.illumos.org/man/2/execv)) a command string provided in
the `command` struct.

The child's stdin and stdout is attached either to `/dev/console` or `dev/null`
based on flags in the `command` struct. The parent waits for the child to
finish, and then calls `door_return` with the child's exit status.

Again, we see that the authors anticipate failure from `door_return`:

```c
	door_return((char *)&res, sizeof (res), NULL, 0);
	trace_prt(1, "automountd_do_fork_exec, door return failed %s, %s\n",
	    command->file, strerror(errno));
	door_return(NULL, 0, NULL, 0);
```

## `automountd_do_exec_map`
This function exists in `usr/src/cmd/fs.d/autofs/ns_files.c`. Same payload size
enforcement strategy as above, no additional validation. It will call
`read_execout` with the door arguments as an exec-style (shell command) payload.

The `read_execout` function describes itself as "A simpler, multithreaded
implementation of `popen()`". It reds the output of the subcommand into a buffer
provided by the server procedure, which is returned to the door client on
success.

YET AGAIN, we see logic that expects `door_return` to fail:
```c
	if (rc != 0) {
		door_return((char *)&rc, sizeof (rc), NULL, 0);
	} else {
		door_return((char *)line, LINESZ, NULL, 0);
	}

    /* how does this even happen */
	trace_prt(1, "automountd_do_exec_map, door return failed %s, %s\n",
	    command->file, strerror(errno));
	door_return(NULL, 0, NULL, 0);
```

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
