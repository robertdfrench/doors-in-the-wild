# Access Control
Before a door server performs an action on behalf of a client, it will want to
make sure the action is allowed!


## Door File permissions
The Door File has a filesystem representation, and therefore can be assigned
traditional file-based access controls. For example, a door file could be
assigned to the user `jmorrison` and the group `wheel` and given the mode
`0440`. This would prevent anyone other than `jmorrison` (or a member of the
`wheel` group) from *opening* the door file.

Additionally, the door file can be placed in a zone so that only users in that
zone can open it, even if the door server process is running outside of that
zone.

This is a helpful step, but as we shall see it is neither sufficient nor
entirely necessary.

For one thing, this does nothing to prevent the file descriptor from being
passed around *after* an appropriate user has opened the door file. Any process
in position of a valid file descriptor is permitted to share it with any other
process. A user process that is not sufficiently carefuly with this descriptor
could share it with a user who would not normally be able to open the door file.

Consider door file permissions to be instructive rather than authoritative.


## Client Credentials
The [`door_ucred(3C)`](https://illumos.org/man/3C/door_ucred) function can be
called in a server procedure to get the (real, effective, or set) user id of the
process which issued the `door_call`. This can be used to verify that, no matter
how the calling process obtained the file descriptor, they are who we expect
them to be.

The [`ucred_get(3C)`](https://illumos.org/man/3C/ucred_get) family of functions
can also be used to get the zone id of the calling process, so that we can
return an error (and log an alert!) if the call originates from outside an
intended zone.


## Authorizations and Privileges
Further, the [`ucred(3C)`](https://illumos.org/man/3C/ucred) struct returned by
[`door_ucred(3C)`](https://illumos.org/man/3C/door_ucred) can be used to look up
the calling user's [Privileges](https://illumos.org/man/7/privileges) or (via
[`chkauthattr(3SECDB)`](https://www.illumos.org/man/3SECDB/chkauthattr)) their [RBAC](https://www.illumos.org/man/7/rbac)
authorizations.
