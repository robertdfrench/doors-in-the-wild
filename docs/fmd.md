# [`FMD(8)`](https://illumos.org/man/8/fmd)
*Fault Manager Daemon*

* [`usr/src/cmd/fm/fmd/common/fmd_api.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_api.c)
* [`usr/src/cmd/fm/fmd/common/fmd_api.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_api.h)
* [`usr/src/cmd/fm/fmd/common/fmd_api.map`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_api.map)
* [`usr/src/cmd/fm/fmd/common/fmd_mdb.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_mdb.c)
* [`usr/src/cmd/fm/fmd/common/fmd_module.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_module.h)
* [`usr/src/cmd/fm/fmd/common/fmd_module.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_module.c)
* [`usr/src/cmd/fm/fmd/common/fmd_rpc.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_rpc.c)
* [`usr/src/cmd/fm/fmd/common/fmd_sysevent.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_sysevent.c)
* [`usr/src/cmd/fm/fmd/common/fmd_thread.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_thread.c)
* [`usr/src/cmd/fm/fmd/common/fmd_thread.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd_thread.h)
* [`usr/src/cmd/fm/fmd/common/fmd.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd.c)
* [`usr/src/cmd/fm/fmd/common/fmd.h`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/fmd/common/fmd.h)
* [`usr/src/cmd/fm/modules/common/ext-event-transport/fmevt_inbound.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/modules/common/ext-event-transport/fmevt_inbound.c)
* [`usr/src/cmd/fm/modules/common/sw-diag-response/common/sw_main_cmn.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fm/modules/common/sw-diag-response/common/sw_main_cmn.c)

## Custom thread pools

All door threads seem to be marked as non-cancellable, and this is because the
door threads are created by a custom thread pool.

There is some notion of "private" vs "non-private" doors (See `DOOR_PRIVATE`
flag in [`door_create(3C)`](https://smartos.org/man/3C/door_create)). This has
something to do with how `fmd` reserves some threads for modules (what modules
exist for this, and how do they use doors?).  This means that it needs its own
thread cancelling logic (see `fmd_module_thrcancel`) in order to avoid
cancelling private door threads:

```c
	if (tp->thr_isdoor) {
		fmd_dprintf(FMD_DBG_MOD, "not cancelling %s private door "
		    "thread %u\n", mp->mod_name, tp->thr_tid);
		fmd_thread_destroy(tp, FMD_THREAD_NOJOIN);
		return;
	}
```

The undocumented [`door_xcreate(3C)`](https://www.illumos.org/issues/818) is
mentioned in `fmd_doorthr_create`, though not used.

Confusingly, these two functions have nearly the same name:

* `fmd_doorthr_create`
* `fmd_doorthread_create`

The first is likely used by
[`door_server_create(3C)`](https://smartos.org/man/3C/door_server_create) to
control how door threads are created. It then calls into the second one for more
specific work (based on the module in question). This seems to allow each module
to have its own door thread pool. It is also called under some other murky
circumstances:

```c
	 /*
	 * If dip == NULL we're being called as part of the
	 * sysevent_bind_subscriber hack - see comments there.
	 */
```

The `fmd_api.h` header defines the door thread creation / setup functions using
`door_xcreate` types:

```c
extern door_xcreate_server_func_t fmd_doorthr_create;
extern door_xcreate_thrsetup_func_t fmd_doorthr_setup;
```

The sysevent stuff registers these functions as sysevent callbacks or something?

```c
	sysevent_subattr_thrcreate(subattr, fmd_doorthr_create, NULL);
	sysevent_subattr_thrsetup(subattr, fmd_doorthr_setup, NULL);
```

All threading logic in fmd seems to need to be aware whether it is a door thread
or not, and if so, what thread pool it belongs to. Case in point, lots of logic
in `fmd_thread.c` checks for boolean `is_door` flags to treat thread creation /
destruction differently for door threads. This allows common thread creation
logic, such as in `fmd_thread_create_cmn`.

This comment from `sw_main_cmn.c` is a good reminder that, while some logic in a
door server might appear to be single threaded, door threads share our address
space and may want to access some of our data structures (this, we should use
locks judiciously):

```c
	/*
	 * Look for a slot.  Module entry points are single-threaded
	 * in nature, but if someone installs a timer from a door
	 * service function we're contended.
	 */
	(void) pthread_mutex_lock(&msinfo->swms_timerlock);
```

## Module statistics
Because this is an API for other code (fmd modules) to use, it exposes custom
door thread setup logic in a symbol map file (`fmd_api.map`):

```
$mapfile_version 2

SYMBOL_SCOPE {
    /*... */
	fmd_doorthr_create		{ TYPE = function; FLAGS = extern };
	fmd_doorthr_setup		{ TYPE = function; FLAGS = extern };
    /*... */
};
```

The total number of door threads and the upper limit of door threads are both
reported to [`mdb(1)`](https://www.illumos.org/man/1/mdb). These statistics are
also trackable per fmd module.

## RPC
The RPC stuff mentions
[`svc_door_create(3NSL)`](https://smartos.org/man/3nsl/svc_door_create).
Apparently [`svc_control(3NSL)`](https://illumos.org/man/3NSL/svc_control) can
be used to enforce maximum request / receive sizes for door payloads.

The door rendezvous path contains program name and version information:

```c
	    snprintf(door, sizeof (door), RPC_DOOR_RENDEZVOUS, prog, vers);
```

where `RPC_DOOR_RENDEZVOUS` is defined elsewhere as
`/var/run/rpc_door/rpc_%d.%d`.


