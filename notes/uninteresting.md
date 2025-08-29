# Uninteresting references
*for the sake of completeness*

```mdoc
.Pa exception_lists/check_rtime
.Pa exception_lists/packaging
.Pa usr/src/cmd/abi/appcert/etc/etc.scoped.in
.Pa usr/src/cmd/audio/samples/au/Makefile
.Pa usr/src/cmd/bart/create.c
.Pa usr/src/cmd/bhyve/common/pci_nvme.c
.Pa usr/src/cmd/bhyve/common/pci_xhci.c
.Pa usr/src/cmd/bnu/Devices
```

Doors used to be their own library, but have since been migrated into libc.

The `exception_lists/packaging` file is used by package validation for some
purpose, and since it mentions a lot of headers, it has many references to the
word 'door'.

The `abi` command has a bunch of hardcoded symbols in it, and some of these
symbols have to do with doors, or exist within the old `libdoor.so.1` library.

There are audiofiles (or were) for the desktop environment, and one if them is a
"doorbell".

the `bart(8)` command checks whether a path is a door.

bhyve doorbells are a notification mechanism for VM guests, and they are
unrelated to illumos doors. These doorbells also exist in the FreeBSD
implementation of bhyve.

`bnu` devices mention something called a "garage/door" but this seems to be in
the context of serial modems.
