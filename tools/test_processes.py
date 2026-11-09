"""Emulator integration tests for scheduling, capacity, and stack diagnostics."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent


def command(args):
    return subprocess.run(args, cwd=root, check=True, capture_output=True, text=True)


def output():
    try:
        result = subprocess.run(
            ['./tools/bin/nes-emulator', 'build/nexos.nes', '--headless', '--debug'],
            cwd=root, capture_output=True, timeout=1)
        assert result.returncode == 0, result.stderr
        return result.stdout.decode()
    except subprocess.TimeoutExpired as error:
        return (error.stdout or b'').decode()


source = (root / 'kernel/kernel.c').read_text()
# Synthetic tasks exist only in the temporary test ROM.
def variant(prefix='', extra='', single=False, release=''):
    tasks = 'volatile nes_uint8_t test_flag = 1;\n'
    for name in 'abcde':
        injection = prefix if name == 'a' else release if name == 'b' else ''
        tasks += 'void test_' + name + '(void) { nes_uint8_t i;\n' + injection
        tasks += "for (i=1; i<=10; i++) { debug_putchar('" + name.upper() + "'); "
        tasks += "if (i == 10) debug_putchar('1'); debug_putchar('0' + i % 10); "
        tasks += "debug_putchar('\\n'); yield(); } for (;;) yield(); }\n"
    text = source.replace('"proc/process.h"', '"process.h"')
    text = text.replace('void kernel_main(void)', tasks + '\nvoid kernel_main(void)')
    names = 'a' if single else 'abcde'
    registration = ''.join('    create_process((nes_uint16_t)test_' + name + ');\n' for name in names)
    text = text.replace('    create_process((nes_uint16_t)application);', registration + extra)
    path = root / 'build/test-kernel.c'
    path.write_text(text)
    command(['cc65', '-t', 'none', '-I', 'kernel/proc', '-I', 'kernel',
             'build/test-kernel.c', '-o', 'build/test-kernel.s'])
    command(['ca65', 'build/test-kernel.s', '-o', 'build/main.o'])
    (root / 'build/nexos.nes').unlink(missing_ok=True)
    command(['make', 'all'])
    return output()


try:
    command(['make', '-B', 'all'])
    assert output() == '', 'Idle must run without error messages'
    text = variant()
    expected = [letter + str(i) for i in range(1, 11) for letter in 'ABCDE']
    assert text.splitlines() == expected, text
    print('OK: five contexts preserve counters and circular scheduling')

    # The sixth creation must fail without publishing a process without a context.
    text = variant(extra='''    if (create_process((nes_uint16_t)test_a) == 0) {
        debug_putchar('L'); debug_putchar('\\n');
    }''')
    assert text.splitlines() == ['L'] + expected, text
    print('OK: sixth process creation is rejected; existing processes continue')

    # Reuse registers and the C stack in a variadic function.
    text = variant(prefix='    debug_printf("numero=%u texto=%s\\n", 1234u, "ok");\n')
    assert text.splitlines() == ['numero=1234 texto=ok'] + expected, text
    print('OK: debug_printf uses the syscall and preserves arguments and context')

    text = variant(prefix='    *((volatile unsigned char *)(0x0800 - PROC_C_STACK_SIZE)) = 0;\n')
    assert 'STACK OVERFLOW' in text and 'B1' not in text, text
    print('OK: C stack guard detects corruption')

    text = variant(prefix='    __asm__("ldx #$b0");\n    __asm__("txs");\n')
    assert 'STACK OVERFLOW' in text and 'B1' not in text, text
    print('OK: CPU stack pointer outside its window is detected')
    text = variant(single=True)
    assert text.splitlines() == ['A' + str(i) for i in range(1, 11)], text
    print('OK: a single process resumes after each yield')

    text = variant(single=True, prefix='    *((volatile unsigned char *)(0x0800 - PROC_C_STACK_SIZE)) = 0;\n')
    assert 'STACK OVERFLOW (C)' in text and 'A2' not in text, text
    print('OK: a single process detects C stack corruption')

    text = variant(single=True, prefix='    __asm__("ldx #$b0");\n    __asm__("txs");\n')
    assert 'STACK OVERFLOW (CPU)' in text and 'A2' not in text, text
    print('OK: a single process detects an invalid hardware stack pointer')

    text = variant(prefix='    debug_puts("WAIT\\n"); process_wait(&test_flag); debug_puts("RESUME\\n");\n',
                   release='    debug_puts("RELEASE\\n"); test_flag = 0;\n')
    assert text.splitlines() == ['WAIT', 'RELEASE', 'B1', 'C1', 'D1', 'E1', 'RESUME', 'A1'] + [
        letter + str(i) for i in range(2, 11) for letter in 'BCDEA'], text
    print('OK: a blocked process yields the CPU and resumes after its event')

    text = variant(single=True, prefix='    test_flag = 0; process_wait(&test_flag);\n')
    assert text.splitlines() == ['A' + str(i) for i in range(1, 11)], text
    print('OK: an event completed before blocking is not missed')

    config_path = root / 'build/process_config.inc'
    original_config = config_path.read_text()
    for old, new, message in [
        ('PROCS_MAX = 5', 'PROCS_MAX = 10', 'Pilhas dos processos excedem CSTACK'),
        ('PROC_ZP_SIZE = 32', 'PROC_ZP_SIZE = 16', 'Aumente PROC_ZP_SIZE'),
    ]:
        config_path.write_text(original_config.replace(old, new))
        command(['ca65', '-I', 'build', 'kernel/proc/switch.asm', '-o', 'build/switch.o'])
        result = subprocess.run(['make', 'all'], cwd=root, capture_output=True, text=True)
        assert result.returncode != 0 and message in result.stderr, result.stderr
    print('OK: linker rejects oversized stacks and incomplete zero-page contexts')
finally:
    # Do not leave a test ROM in place of the user ROM.
    command(['make', '-B', 'all'])
