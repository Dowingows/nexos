"""Package a 6502 binary in the minimal NEX1 executable format."""
import sys
import re
from pathlib import Path

source = Path(sys.argv[1]).read_bytes()
labels = Path(sys.argv[2]).read_text()
match = re.search(r'^al ([0-9A-Fa-f]+) \.__BSS_SIZE__$', labels, re.M)
if match is None:
    raise SystemExit("Não encontrei __BSS_SIZE__ nos símbolos do programa")
bss_size = int(match.group(1), 16)
entry = re.search(r'^al ([0-9A-Fa-f]+) \._program_entry$', labels, re.M)
if entry is None or int(entry.group(1), 16) != 0x0540:
    raise SystemExit("O programa precisa exportar program_entry em $0540")

if not source or len(source) + bss_size > 192:
    raise SystemExit("NEX1 aceita até 192 bytes somando programa e BSS")

Path(sys.argv[3]).write_bytes(
    b"NEX1" + len(source).to_bytes(2, "little") +
    bss_size.to_bytes(2, "little") + source
)
