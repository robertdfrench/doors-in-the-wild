# Static File Descriptor
Applications which have one (1) canonical door to share amongst
all threads sometimes choose to make that door's file descriptor
available as a global static variable, often initialized to `-1`
(an illegal value) at launch time.

This can be used to check whether or not the application has yet
entered a phase where door services are being offered -- an
important distinction for tools which have bootup or other
preparatory work to do before acting as a door server.

This is as simple as the following line of code in a translation
unit:

```c
int doorfd = -1;
```

This also allows for door termination to be idempotent, which is
useful if multiple server threads attempt to shut down the door
server at once (e.g. if multiple clients send a 'stop' command):

```c
void
nwamd_door_fini(void)
{
	if (doorfd != -1) {
		nlog(LOG_DEBUG, "nwamd_door_fini: closing door");
		(void) door_revoke(doorfd);
		doorfd = -1;
	}
	(void) unlink(NWAM_DOOR);
}
```
