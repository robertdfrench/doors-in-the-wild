# Door Return Failure

Occasionally server procedures *expect* their calls to `door_return` to be
fallible. For example in
[`usr/src/cmd/fs.d/autofs/ns_files.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/fs.d/autofs/ns_files.c):

```c
	if (rc != 0) {
		door_return((char *)&rc, sizeof (rc), NULL, 0);
	} else {
		door_return((char *)line, LINESZ, NULL, 0);
	}

    /* how does this even happen */
	trace_prt(1, "automountd_do_exec_map, door return failed %s, %s\n",
	    command->file, strerror(errno));
	door_return(NULL, 0, NULL, 0);
```

in [`usr/src/lib/libsysevent/libsysevent.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/lib/libsysevent/libsysevent.c):

```c
return_from_door:
	(void) door_return((void *)&ret, sizeof (ret), NULL, 0);
	(void) door_return(NULL, 0, NULL, 0);
}
```

and other examples in [automountd](automountd.md).
