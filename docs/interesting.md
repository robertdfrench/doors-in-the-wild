# Interesting or Curious

* [`usr/src/cmd/audio/samples/au/Makefile`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/audio/samples/au/Makefile)
There are audiofiles (or were) for the desktop environment, and
one if them is a "doorbell".

* [`usr/src/cmd/bhyve/common/pci_nvme.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/bhyve/common/pci_nvme.c)
bhyve doorbells are a notification mechanism for VM guests, and
they are unrelated to illumos doors. These doorbells also exist
in the FreeBSD implementation of bhyve.

* [`usr/src/cmd/bhyve/common/pci_xhci.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/bhyve/common/pci_xhci.c)
Same as above.

* [`usr/src/cmd/bnu/Devices`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/bnu/Devices)
`bnu` devices mention something called a "garage/door" but this
seems to be in the context of serial modems.

* [`usr/src/cmd/file/file.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/file/file.c)
The `file(1)` command uses `door_info` to print information
about the cookie and associated door server, if possible. If the
call to `door_info` fails, it just says "door".
