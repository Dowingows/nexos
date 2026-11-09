# Memory and services

The NES has 2 KiB of internal CPU RAM. The linker separates kernel globals,
program arguments, a small heap, the loaded user program, C stacks, and the
6502 hardware stack. These regions are not interchangeable just because one
has unused bytes.

Run `make memory` to report the current configuration. At the time this
document was written, the report was:

| Region | Current allocation |
| --- | ---: |
| DATA + BSS at `$0200-$04FF` | 723 / 768 bytes |
| NEX1 arguments at `$0500-$051F` | 32 bytes |
| Heap at `$0520-$053F` | 32 bytes |
| NEX1 program and BSS at `$0540-$05FF` | up to 192 bytes |
| C stacks at `$0600-$07FF` | 480 / 512 bytes |

The process configuration currently reserves five process slots. Each slot
has a 96-byte C stack (including its guard byte), a 64-byte copy of the active
6502 hardware-stack region, and 32 bytes of saved zero page. The remaining
32 bytes of C-stack space and 45 bytes of DATA+BSS are a small margin, not a
large pool for new services. Use the report from the current build as the
source of truth if code changes alter the totals.

## Stack and process safety

There is no universally safe C-function size. Stack use depends on compiler
output, local variables, nested calls, and the path taken before a yield.
Prefer short functions and small fixed buffers. Avoid deep recursion and large
local arrays. Check `create_process()` results; zero means no slot was free.

The context switch checks the hardware stack pointer, cc65 software stack
pointer, and a guard byte before switching. These checks are diagnostic aids,
not memory protection. Corruption can happen before a context switch or may
not be visible in the final stack pointer.

Scheduling is cooperative. Processes need to yield or wait for an event;
there is no timer-driven preemption. A program that never yields can starve
other work.

## Current services

### Video

The video path uses a small circular command queue instead of a RAM
framebuffer. C tasks enqueue tile updates; the NMI writes a bounded number of
commands to the PPU during VBlank. The current budget is eight commands per
frame. Keep the NMI short and do not call ordinary C or the scheduler from it:
those routines share CPU and cc65 state with the interrupted process.

### Input

The Family BASIC keyboard driver scans a matrix once per frame and publishes
characters through a fixed-size queue. The shell reads the queue without
blocking. A future input service could publish current button state and
pressed/released events; it does not need a separate process if a short
per-frame update is enough.

### Memory and filesystem

The USTAR filesystem is read-only and embedded in the ROM. The current loader
supports one small NEX1 executable at a time. The `kmalloc` implementation is
a simple bounded allocator; it is not virtual memory or paging.

## Hardware limits and future expansion

The current cartridge header uses mapper 0 (NROM), with no bank switching.
The NES has no MMU, virtual-memory page faults, or hardware-enforced process
isolation. Software can organize resources into blocks, but that is not the
same as memory paging. More RAM requires a cartridge/mapper with PRG-RAM and
matching linker, startup, and emulator support; changing linker addresses
alone does not add physical memory.

If the project later adds a sprite service, reserve the NES OAM DMA page at
`$0200` deliberately and move kernel RAM elsewhere. Do not place an OAM buffer
there while DATA+BSS still occupies that address. For a larger design, consider
fewer process slots with larger stacks, or services implemented as short
per-frame functions with explicit persistent state.

The most useful next experiments are bounded allocation and failure reporting,
process lifecycle and exit behavior, and coordination between terminal output
and independent services. Each experiment should include a memory-budget
update and a test that exercises its failure case.
