"""Mostra o orcamento do mapa atual; executar depois de make."""
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
print(f'Processos: {count}')
print(f'Zero page em uso: {segments.get("ZEROPAGE", 0)} / {config["PROC_ZP_SIZE"]} bytes salvos por processo')
print(f'DATA + BSS ($0200-$04FF): {ram} / 768 bytes; livres: {768-ram}')
print('Argumentos NEX1 ($0500-$051F): 32 bytes; heap ($0520-$053F): 32 bytes')
print('Programa NEX1 ($0540-$05FF): 192 bytes; código + BSS: até 192 bytes')
print(f'Pilhas C ($0600-$07FF): {cstacks} / 512 bytes; livres: {512-cstacks}')
print(f'Por processo: pilha C {config["PROC_C_STACK_SIZE"]} bytes (1 sentinela), '
      f'pilha CPU {config["PROC_CPU_STACK_SIZE"]} bytes, ZP {config["PROC_ZP_SIZE"]} bytes')
print('Limites de RAM e CSTACK correspondem a linker/nes.cfg; revisar ao alterar o mapa.')
