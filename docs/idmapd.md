# [`IDMAP(8)`](https://illumos.org/man/8/idmap)
*configure and manage the Native Identity Mapping service*

* [`usr/src/cmd/idmap/idmapd/adspriv_impl.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/idmap/idmapd/adspriv_impl.c)
* [`usr/src/cmd/idmap/idmapd/idmap_config.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/idmap/idmapd/idmap_config.c)
* [`usr/src/cmd/idmap/idmapd/idmap_lsa.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/idmap/idmapd/idmap_lsa.c)
* [`usr/src/cmd/idmap/idmapd/idmapd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/idmap/idmapd/idmapd.c)


The `adspriv_impl.c` file calls `svc_door_create` with a reference to a function
called `adspriv_program_1`. This function does not have the signature of a
server procedure.

There is also a function called `svc_control` which is used to attempt to "limit
RPC request size" -- is this to do with the maximum size of a door payload?

The `idmap_config.c` file defines `MAX_THREADS_DEFAULT` to set an upper bound on
the number of simultaneous door calls. Why? Is there some data structure that is
as wide as this number?

`idmap_lsa.c` defines a function called `notify_dc_changed` which uses
`smb_notify_dc_changed()` to issue a door call to
[`SMBD(8)`](https://www.illumos.org/man/8/smbd). The comment is curious:

```
/*
 * This exists just so we can avoid exposing all of idmapd to libsmb.h.
 * Like the above functions, it's a door call over to smbd.
 */
```

What is gained by limiting this exposure? What does "exposure" actually mean
here? And since this is a wrapper around a door call, why does the use of doors
need to be state explicitly -- isn't that an implementation detail?

The `idmapd.c` file uses the [Static File Descriptor](static_file_descriptor.md)
pattern.

Custom door thread init is used to disable cancellation:
`idmapd_door_thread_start` and `idmapd_door_thread_create`.

The `pthread_setspecific` function is used to ensure that a destructor is run
(but how?). The `idmapd_door_thread_cleanup` function seems to be this
destructor, and it only decrements the number of active threads.

`idmapd_door_thread_create` refuses to create a door if the maximum number of
threads (`MAX_THREADS_DEFAULT`??) is exceeded.

## Main thread wastage
In the `main` function of `idmapd.c`, this comment gets to the heart of a common
problem: when a daemon does nothing but serve doors, the "main" thread seems to
go unused

```c
	/* With doors RPC this just wastes this thread, oh well */
	svc_run();
	return (0);
```
