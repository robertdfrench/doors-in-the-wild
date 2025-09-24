# Liveness Check
Sometimes clients will check whether a door server is running by making an
"empty" door call:

```c
/* client */
door_arg_t params = { 0 };
int rc = door_call(door_fd, NULL);
if (rc == 0) {
    /* The door call did not fail, so the door server is alive */
}
```

And the server procedure would look something like this:

```c
/* server */
void
sp(void *cookie, char *argp, size_t argsz,
    door_desc_t *dp, uint_t n_desc)
{
	/*
	 * Allow a NULL arg call to check if this
	 * daemon is running.
	 */
	if (argp == NULL) {
        door_return(NULL, 0, NULL, 0);
	}

    /* Other code that actually implements real behavior */
}
```

By checking for null arguments at the outset, the liveness check pattern can
return quickly before handling any other business logic. This is also a good
defense against client programming errors.
