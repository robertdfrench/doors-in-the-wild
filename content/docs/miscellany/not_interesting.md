# Neither Interesting Nor Curious

* [`exception_lists/check_rtime`](https://github.com/illumos/illumos-gate/blob/master/exception_lists/check_rtime)
Doors used to be their own library, but have since been migrated
into libc.

* [`exception_lists/packaging`](https://github.com/illumos/illumos-gate/blob/master/exception_lists/packaging)
The `exception_lists/packaging` file is used by package
validation for some purpose, and since it mentions a lot of
headers, it has many references to the word 'door'.

* [`usr/src/cmd/abi/appcert/etc/etc.scoped.in`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/abi/appcert/etc/etc.scoped.in)
The `abi` command has a bunch of hardcoded symbols in it, and
some of these symbols have to do with doors, or exist within the
old `libdoor.so.1` library.


* [`usr/src/cmd/bart/create.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/bart/create.c)
the `bart(8)` command checks whether a path is a door.

* [`usr/src/cmd/diff/diff.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/diff/diff.c)
`diff(1)` must be able to complain about being told to compare a
door to a text file, or vice versa.
