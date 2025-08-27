# Uninteresting references
*for the sake of completeness*

```mdoc
.Pa exception_lists/check_rtime
.Pa exception_lists/packaging
.Pa usr/src/cmd/abi/appcert/etc/etc.scoped.in
.Pa usr/src/cmd/audio/samples/au/Makefile
```

Doors used to be their own library, but have since been migrated into libc.

The `exception_lists/packaging` file is used by package validation for some
purpose, and since it mentions a lot of headers, it has many references to the
word 'door'.

The `abi` command has a bunch of hardcoded symbols in it, and some of these
symbols have to do with doors, or exist within the old `libdoor.so.1` library.

There are audiofiles (or were) for the desktop environment, and one if them is a
"doorbell".
