# Uninteresting Things
*for the sake of completeness*

```mdoc
.Pa exception_lists/check_rtime
```
Doors used to be their own library, but have since been migrated into libc.

```mdoc
.Pa exception_lists/packaging
```
The `exception_lists/packaging` file is used by package validation for some
purpose, and since it mentions a lot of headers, it has many references to the
word 'door'.

```mdoc
.Pa usr/src/cmd/abi/appcert/etc/etc.scoped.in
```
The `abi` command has a bunch of hardcoded symbols in it, and some of these
symbols have to do with doors, or exist within the old `libdoor.so.1` library.

```mdoc
.Pa usr/src/cmd/audio/samples/au/Makefile
```
There are audiofiles (or were) for the desktop environment, and one if them is a
"doorbell".

```mdoc
.Pa usr/src/cmd/bart/create.c
```
the `bart(8)` command checks whether a path is a door.

```mdoc
.Pa usr/src/cmd/bhyve/common/pci_nvme.c
.Pa usr/src/cmd/bhyve/common/pci_xhci.c
```
bhyve doorbells are a notification mechanism for VM guests, and they are
unrelated to illumos doors. These doorbells also exist in the FreeBSD
implementation of bhyve.

```mdoc
.Pa usr/src/cmd/bnu/Devices
```
`bnu` devices mention something called a "garage/door" but this seems to be in
the context of serial modems.
