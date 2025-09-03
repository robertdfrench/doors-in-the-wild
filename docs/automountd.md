# [`AUTOMOUNTD(8)`](https://illumos.org/man/8/automountd)

* [`vim`](https://github.com/illumos/illumos-gate/blob/master/vim)

`autofs_doorfunc` is the server procedure.

`decode_args` and `encode_res` seem to be doing serialization and
deserialization, which is good to see.

Hardcoded `AUTOFS_DOOR` path.

Automount handlers can be different programs, so server procedures need to be
able to fork and/or exec. See the following server procedures:

* `automountd_do_fork_exec`
* `automountd_do_exec_map`

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

The `did_fork_exec` and `did_exec_map` doors have to be revoked separately.

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
