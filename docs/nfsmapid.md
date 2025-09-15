# [`NFSMAPID(8)`](https://www.illumos.org/man/8/nfsmapid)
*NFS user and group id mapping daemon*

* .Pa usr/src/cmd/fs.d/nfs/nfsmapid/nfsmapid_server.c

```c
/*
 * Door server routines for nfsmapid daemon
 * Translate NFSv4 users and groups between numeric and string values
 */
```

The `idmap_kcall` function takes either a door descritor as an argument, or `-1`
(which is never a valid file descriptor) as a signal to flush any idmap-related
caches that the kernel may be holding. This is utlimately forwarded to the
kernel via the `_nfssys` system call.


## Command Switching
`nfsmpaid_func` is a server procedure which simulataneously casts the door
arguments to two different types: `refd_door_args_t` and `mapid_arg`. As a
`mapid_arg`, the payload's `cmd` field is switched among functions that map
between group names and ids or user names and ids. Only in one case does
the server use the `refd_door_args_t` form of the payload, this in order to
serve some kind of network statistics.
