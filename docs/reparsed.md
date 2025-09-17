# reparsed
* [`usr/src/cmd/fs.d/reparsed/reparsed.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/reparsed/reparsed.c)

## `door_return` or else...
The `reparsed_door_call_error` function is decorated with `__NORETURN`:

```c
__NORETURN static void
reparsed_door_call_error(int error, int buflen)
{
	reparsed_door_res_t rpd_res;

	memset(&rpd_res, 0, sizeof (reparsed_door_res_t));
	rpd_res.res_status = error;
	rpd_res.res_len = buflen;
	(void) door_return((char *)&rpd_res,
	    sizeof (reparsed_door_res_t), NULL, 0);

	(void) door_return(NULL, 0, NULL, 0);
	abort();
}
```

Why do we try so hard to recover from `door_return`, even when it is passing
nothing? Also, why are the calls being cast to `void`?

This is interesting, because it a single server thread fails to call
`door_return`, then [`abort(3C)`](https://www.illumos.org/man/3C/abort) will
stop the entire process.

## Unusual payload
The payload to the `reparsed_doorfunc` server procedure has an unusual format:
it is a string immediately followed by a struct. So the server procedure uses
[`strchr(3C)`](https://www.illumos.org/man/3C/strchr) to find the end of the
"string" part (by treating ':' as a terminal character) and then the rest of the
buffer is assumed to be a `reparsed_door_res_t` structure. This is made apparent
by the `DOOR_RESULT_BUFSZ` macro:

```c
#define	DOOR_RESULT_BUFSZ	(MAXPATHLEN + sizeof (reparsed_door_res_t))
```

## Stack allocation
Again, the admonishment to use
[`alloca(3C)`](https://www.illumos.org/man/3C/alloca) to allocate memory on the
stack rather than the heap so that we don't create leaks when returing to the
door client:

```c
		 /*
		 * We cannot use malloc() here because door_return() never
		 * returns, and memory allocated by malloc() would get leaked.
		 */
		sbuf = alloca(bufsz + sizeof (reparsed_door_res_t));
```

## Server Initialization
The `start_reparsed_svcs` function follows the usual pattern of:

* Create a door fd
* Create (if not exists) a door jamb with appropriate permissions
* Detach any stale doors from the jamb
* Attach the new door to the jamb (and then close the fd for the jamb file)
* Wait for incoming calls

This uses a common wait pattern:

```c
	/*
	 * Wait for incoming calls
	 */
	while (1)
		(void) pause();
```

[`pause(2)`](https://www.illumos.org/man/2/pause) suspends the process until it
is interrupted by a signal, but this loop effectively just discards that
interruption and goes back to the pause state. How does this compare to binding
the current thread to the door pool (via `door_return`)?
