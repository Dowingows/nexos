"""Report the current memory map budget; run after make."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
config = dict((name, int(value)) for name, value in re.findall(
    r'^#define (PROCS_MAX|PROC_\w+) (\d+)$',
    (root / 'kernel/proc/config.h').read_text(), re.M))
segments = {}
for name, start, end, size in re.findall(
        r'^(\w+)\s+([0-9A-F]{6})\s+([0-9A-F]{6})\s+([0-9A-F]{6})\s+[0-9A-F]+\s*$',
        (root / 'build/nexos.map').read_text(), re.M):
    segments[name] = int(size, 16)
ram = segments.get('DATA', 0) + segments.get('BSS', 0)
count = config['PROCS_MAX']
cstacks = count * config['PROC_C_STACK_SIZE']
print(f'Processes: {count}')
print(f'Zero page used: {segments.get("ZEROPAGE", 0)} / {config["PROC_ZP_SIZE"]} bytes saved per process')
print(f'DATA + BSS ($0200-$04FF): {ram} / 768 bytes; free: {768-ram}')
print('NEX1 arguments ($0500-$051F): 32 bytes; heap ($0520-$053F): 32 bytes')
print('NEX1 program ($0540-$05FF): 192 bytes; code + BSS limit: 192 bytes')
print(f'C stacks ($0600-$07FF): {cstacks} / 512 bytes; free: {512-cstacks}')
print(f'Per process: C stack {config["PROC_C_STACK_SIZE"]} bytes (one guard byte), '
      f'CPU stack {config["PROC_CPU_STACK_SIZE"]} bytes, zero page {config["PROC_ZP_SIZE"]} bytes')
print('RAM and CSTACK limits are defined in linker/nes.cfg; update this report when the map changes.')
