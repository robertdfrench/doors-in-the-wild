# Linting
Because server procedures are never invoked as functions (*well, not as such*),
static analyzers will claim that they are unused, or dead code, leading to a lot
of noise.

In the illumos source tree, nearly every server procedure is decorated with
`ARGSUSED`, which promises the linter that we are indeed using these functions:

```c
/* ARGSUSED */
static void
event_handler(void *cookie, char *argp, size_t asize,
    door_desc_t *dp, uint_t n_desc)
{
	(void) door_return(NULL, 0, NULL, 0);
}
```
