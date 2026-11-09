# Terminal and shell

The terminal is 32 columns by 30 rows. It draws ASCII characters as tiles in
the PPU nametable and keeps only a two-byte cursor in RAM; it has no full-screen
framebuffer. The font generator creates printable ASCII glyphs in CHR-ROM.
General UTF-8 and accented characters are not supported yet.

## Input

The keyboard process scans a Family BASIC keyboard matrix through `$4016` and
`$4017`, queues characters, then waits for the next frame event. The shell
consumes that queue without busy-waiting. For interactive use, open the ROM in
an emulator with Family BASIC Keyboard support and configure that device on the
NES expansion port. Mesen supports the device; its input configuration may
change between releases.

The current mapping is defined in `kernel/drivers/keyboard.c`. The keyboard
driver handles key repeat suppression and a small fixed-size queue. The shell
supports printable ASCII, Enter, and Backspace; it currently has no line
editing, history, or cursor movement.

## Commands

- `help` lists the basic commands.
- `ver` prints the NexOS version.
- `clear` clears the terminal.
- `echo TEXT` prints text.
- `ls` and `cat FILE` are separate programs loaded from `/bin`.
- `chars` prints the printable ASCII range.
- A program name or path launches its `.nex` executable; for example `hello`.

The shell can also call `shell_execute()` directly from a kernel process. For
normal text output, use `os_write()` or `printf()`. They reach the terminal
through `SYS_WRITE`. Diagnostic output uses the separate debug syscall and is
sent to the emulator debug port.

## Graphics queue

Each tile update is a three-byte `(x, y, tile)` command. C producers write to
a circular queue; the NMI consumes at most eight commands per VBlank and
updates the PPU. The queue has sixteen slots, fifteen of which are usable.
When full, a producer waits cooperatively for the NMI to free a slot.

The terminal clears the page when output reaches row 30; scrolling is not
implemented. The clear is gradual because it enqueues tile updates. Output
from multiple applications is not yet serialized around independent terminal
sessions; the shell owns the cursor in this version.

`make test` exercises the initial screen, ASCII font, commands, terminal
controls, page clearing, and graphics queue behavior.
