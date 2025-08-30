# Neither Interesting Nor Curious

```mdoc
.Pa exception_lists/check_rtime
```
Doors used to be their own library, but have since been migrated
into libc.

```mdoc
.Pa exception_lists/packaging
```
The `exception_lists/packaging` file is used by package
validation for some purpose, and since it mentions a lot of
headers, it has many references to the word 'door'.

```mdoc
.Pa usr/src/cmd/abi/appcert/etc/etc.scoped.in
```
The `abi` command has a bunch of hardcoded symbols in it, and
some of these symbols have to do with doors, or exist within the
old `libdoor.so.1` library.


```mdoc
.Pa usr/src/cmd/bart/create.c
```
the `bart(8)` command checks whether a path is a door.
