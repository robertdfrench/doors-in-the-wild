# [`AUTOMOUNTD(8)`](https://illumos.org/man/8/automountd)

* .Pa vim usr/src/cmd/fs.d/autofs/autod_main.c

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
