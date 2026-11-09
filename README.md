# NexOS

NexOS is a small educational operating-system experiment for the Nintendo
Entertainment System (NES). Its goal is to explore operating-system ideas on
realistically constrained hardware: a 6502 CPU and only 2 KiB of internal RAM.
It is a learning project, not a general-purpose operating system.

The project was inspired by [1000OS by Seiya](https://1000os.seiya.me/).
Thank you for sharing a project that helped make this experiment possible.

AI tools assisted with selected parts of the code, debugging, and documentation.
The project's overall idea is to demonstrate that a small, hands-on OS
experiment can be built for hardware such as the NES, while making the many
constraints and engineering challenges visible to learners.

## What is here

- A small 6502 kernel written in C and Assembly.
- Cooperative processes, context switching, event waits, and system-call-like
  APIs for output, filesystem access, and yielding the CPU.
- A 32 by 30 tile terminal and a shell with `help`, `ver`, `clear`, `echo`,
  `ls`, `cat`, `chars`, and executable launch by name.
- A circular graphics queue shared between C and the Assembly PPU/NMI path.
- A read-only USTAR filesystem embedded in the ROM.
- Small C programs compiled into NexOS `.nex` executables and packaged under
  `/bin` in the filesystem.
- Tests for process scheduling, graphics queue behavior, terminal output, and
  shell commands.

## Build and test

The build expects `make`, Python 3, `cc65` (`cc65`, `ca65`, and `ld65`), and a
`tar` implementation with USTAR support.

```sh
make            # Build build/nexos.nes
make test       # Run process, video, and shell tests
make memory     # Print the current RAM and stack budget
make run        # Run the bundled emulator in headless/debug mode
make run-ui     # Open the bundled emulator with its UI
```

To use Mesen, first run `make`, then open `build/nexos.nes` in Mesen. The shell
reads a Family BASIC keyboard matrix, so configure the NES expansion port as a
Family BASIC Keyboard and make sure Mesen has focus. The exact menu labels can
vary by Mesen release. See the [Mesen project](https://www.mesen.ca/) and its
[configuration guide](https://github.com/SourMesen/Mesen/blob/master/Docs/content/gettingstarted/_index.md).

The keyboard driver currently implements the key matrix in
`kernel/drivers/keyboard.c`; it does not turn an ordinary computer keyboard
into NES controller buttons. Use an emulator that supports the Family BASIC
Keyboard device, such as Mesen, or another compatible emulator.

## Try the shell

After boot, enter commands using the configured keyboard:

```text
nexos> help
nexos> ls
nexos> cat HELLO.TXT
nexos> hello
nexos> clear
```

The built-in shell is intentionally small. Programs are separate C sources in
`programs/`; the Makefile discovers them, builds `.nex` files, and adds them
to the embedded TAR filesystem. See [`programs/README.md`](programs/README.md)
and [`docs/shell.md`](docs/shell.md).

## Important constraints

The current ROM uses mapper 0 (NROM), so it has no bank switching. The 6502
does not provide an MMU, virtual memory, or hardware-enforced process
protection. Scheduling is cooperative: a process must yield or wait for an
event so other processes can run. Only one user executable can be loaded at a
time, and the program plus its BSS is limited to 192 bytes. These constraints
are part of the experiment, not abstractions hidden by the project.

The current measured internal-RAM report is available with `make memory`.
Keep new kernel state, queues, and stacks within that budget. For design notes,
see [`docs/memory-and-services.md`](docs/memory-and-services.md).

## A learning project

NexOS is meant to be read, modified, and used for experiments. It demonstrates
small versions of scheduling, system calls, drivers, event synchronization,
filesystems, program loading, and memory budgeting. Some interfaces are
deliberately simplified and should not be confused with protected or
preemptive facilities found in desktop operating systems.
