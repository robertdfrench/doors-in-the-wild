# [`IDMAP(8)`](https://illumos.org/man/8/idmap)
*configure and manage the Native Identity Mapping service*

* [`usr/src/cmd/idmap/idmapd/adspriv_impl.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/idmap/idmapd/adspriv_impl.c)
* [`usr/src/cmd/idmap/idmapd/idmap_config.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/idmap/idmapd/idmap_config.c)

The `adspriv_impl.c` file calls `svc_door_create` with a reference to a function
called `adspriv_program_1`. This function does not have the signature of a
server procedure.

There is also a function called `svc_control` which is used to attempt to "limit
RPC request size" -- is this to do with the maximum size of a door payload?

The `idmap_config.c` file defines `MAX_THREADS_DEFAULT` to set an upper bound on
the number of simultaneous door calls. Why? Is there some data structure that is
as wide as this number?
