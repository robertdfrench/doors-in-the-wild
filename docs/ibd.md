# [`IBD(4D)`](https://man.omnios.org/man4d/ibd.4d)
*Infiniband IPoIB device driver*

* [`usr/src/cmd/ibd_upgrade/ibd_delete_link.c`](https://github.com/illumos/illumos-gate/blob/master/usr/src/cmd/ibd_upgrade/ibd_delete_link.c)

Calls into a door for dladm. Links against something that provides a
`dladm_door_fd` call which returns a door fd for dladm. Probably libdladm.
