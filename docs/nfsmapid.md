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
