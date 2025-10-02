# Preventing Thread Cancellation
By default, if a door client thread is cancelled, the corresponding server
procedure thread will be cancelled as well. This can lead to surprises if the
server procedure is not set up for
[cancellation(7)](https://illumos.org/man/7/cancellation).

Unless your server procedure is designed with cancellation in mind as a
first-class feature, you should probably use `DOOR_NO_CANCEL` when calling
[`door_create(3C)`](https://illumos.org/man/3C/door_create). This will prevent
an errant or malicious client from being able to interrupt server logic in
unrecoverable ways.
