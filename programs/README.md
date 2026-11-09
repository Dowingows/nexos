# NexOS user programs

Add a C source file under `programs/` with this entry point:

```c
void program_entry(const char *arguments);
```

The Makefile discovers `programs/*.c`, compiles each one into a `.nex`
executable, and packages it under `/bin` in the embedded USTAR filesystem.
For example, `programs/hello.c` becomes `/bin/hello.nex` and can be started by
typing `hello` in the shell.

Include `nexos.h` to use the fixed ROM API:

- `nexos_write(text)` writes to the terminal through the kernel API.
- `nexos_yield()` cooperatively gives the CPU to another process.
- `nexos_cat(path)` prints a file from the read-only filesystem.
- `nexos_ls()` lists files from the read-only filesystem.

The current NEX1 loader reserves 32 bytes for arguments and allows up to
192 bytes for the program image plus BSS. Only one user executable can run at a
time because there is one load region. The scheduler is cooperative, so a
program that does not call `nexos_yield()` can monopolize the CPU.

The examples `hello.c`, `ls.c`, and `cat.c` demonstrate the API. Run `make` to
rebuild the ROM and filesystem; no Makefile edit is needed for a new C program.
