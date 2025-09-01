# Request Switching
Door servers sometimes expose a single door that forwards its
payload to one or more "handler" functions based on some
sentinal value.

This approach usually involves setting up a static table
consisting of the sentinal values and function pointers for each
associated handler. For example:

```c
static switching_entry_t switching_tbl[] = {
    { DOOR_CMD_CREATE,  create_handler },
    { DOOR_CMD_DELETE,  delete_handler },
    { DOOR_CMD_WRITE,   write_handler },
    /* ... *./
    { 0, NULL } /* To halt iteration, see below */
};
```

This implies the existence of handler functions that look
something like this:

```c
void create_handler(door_payload_t* argp) {
    /* Create some useful based on the door payload */
}

void delete_handler(door_payload_t* argp) {
    /* Delete whatever is specified in the door payload */
}
```

The server procedure itself will need to perform some kind of
test on the door payload to determine which handler should be
invoked. Often this is as simple as checking a (user-supplied)
field in the door payload:

```c
int flag = door_payload->flag;
(void*) handler = NULL;

/* the final entry in the switching table is 0, which causes
this loop to halt */
for (i = 0; switching_tbl[i].flag != 0; i++) {
    if (switching_tbl[i].flag == flag) {
         handler = switching_tbl[i].cmd;
    }
}

if (handler == NULL) {
    /* Invalid handler specified by user. Do cleanup and exit */
}

handler(door_payload);
```

But who is responsible for calling `door_return`? Sometimes the
handler is responsible, and sometimes the server procedure
itself is responsible. You have some more flexibility if you
make it the handler's problem, but you get better consistency if
you ensure that the server procedure always calls `door_return`
itself.
