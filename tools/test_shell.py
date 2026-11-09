"""Valida syscalls, terminal e executor sem teclado, na PPU do emulador."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(root / 'tools'))
from build_font import build, patterns


def command(args):
    result = subprocess.run(args, cwd=root, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)


def capture(body, timeout=3, expected_debug=b'DONE\n'):
    source = (root / 'kernel/kernel.c').read_text()
    start = source.index('static void application(void)')
    end = source.index('void kernel_main(void)', start)
    source = source[:start] + '''static void test_drain_graphics(void)
{
    while (gfx_head != gfx_tail) yield();
}

static void application(void)
{
''' + body + '''
    test_drain_graphics();
    debug_puts("DONE\\n");
    for (;;) yield();
}

''' + source[end:]
    source = '#include "syscall.h"\n' + source
    (root / 'build/shell-test.c').write_text(source)
    command(['cc65', '-t', 'none', '-I', 'kernel', 'build/shell-test.c', '-o', 'build/shell-test.s'])
    command(['ca65', 'build/shell-test.s', '-o', 'build/main.o'])
    (root / 'build/nexos.nes').unlink(missing_ok=True)
    command(['make', 'all'])
    try:
        result = subprocess.run(['./tools/bin/nes-emulator', 'build/nexos.nes', '--headless', '--debug'],
                                cwd=root, capture_output=True, timeout=timeout)
        output = result.stdout
        assert result.returncode == 0, result.stderr
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b''
    screen = [[0]*32 for _ in range(30)]
    text = bytearray()
    writes = []
    index = 0
    while index < len(output):
        value = output[index]
        index += 1
        if value == 0xFE:
            x, y, tile = output[index:index+3]
            index += 3
            assert x < 32 and y < 30, (x, y)
            screen[y][x] = tile
            writes.append((x, y, tile))
        else:
            text.append(value)
    assert text == expected_debug, text
    return screen, writes


def lines(screen):
    return [''.join(' ' if value in (0, 32) else '\u00d7' if value == 127 else chr(value)
                    for value in row).rstrip() for row in screen]


def preview(screen, filename):
    # Rebuild the verified VRAM contents using the CHR-ROM tiles.
    # This visualizes the nametable; it is not a screenshot of the emulator window.
    import struct
    import zlib
    font = (root / 'build/font.chr').read_bytes()
    rows = []
    for y in range(240):
        row = bytearray()
        for x in range(256):
            tile = screen[y // 8][x // 8]
            on = font[tile*16 + y % 8] & (0x80 >> (x % 8))
            row.extend((bytes((236, 238, 236)) if on else bytes(3)) * 3)
        rows.extend([b'\x00' + row] * 3)
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', 768, 720, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b''.join(rows))) + chunk(b'IEND', b'')
    (root / 'build' / filename).write_bytes(png)



try:
    command(['make', '-B', 'all'])
    assert len(patterns) == 95
    assert (root / 'build/font.chr').read_bytes() == build()
    assert all(any(build()[code*16:code*16+8]) for code in range(33, 127))
    reset = (root / 'kernel/boot/reset.asm').read_text()
    reset = reset.replace('    ; Free the slot only after the complete PPU write.', '''    lda #$FE
    sta $5FF0
    lda _gfx_queue,x
    sta $5FF0
    lda _gfx_queue+1,x
    sta $5FF0
    lda _gfx_queue+2,x
    sta $5FF0

    bit $2002
    lda _gfx_queue+1,x
    lsr a
    lsr a
    lsr a
    ora #$20
    sta $2006
    lda _gfx_queue+1,x
    asl a
    asl a
    asl a
    asl a
    asl a
    ora _gfx_queue,x
    sta $2006
    lda $2007
    lda $2007
    cmp _gfx_queue+2,x
    beq :+
    lda #'E'
    sta $5FF0
:
    ; Free the slot only after the complete PPU write.''')
    reset = reset.replace('    beq @done', '    bne :+\n    jmp @done\n:')
    reset = reset.replace('    bne @command', '    beq :+\n    jmp @command\n:')
    (root / 'build/shell-reset.asm').write_text(reset)
    command(['ca65', '-I', 'build', '--bin-include-dir', 'build', 'build/shell-reset.asm', '-o', 'build/reset.o'])

    screen, writes = capture('    shell_init();')
    expected = ['32 \u00d7 30', 'NexOS v0.1', '', 'Initializing kernel...', '', 'Ready.', '', 'nexos>']
    assert lines(screen)[:8] == expected, lines(screen)
    preview(screen, 'shell-preview.png')
    print('OK: tela inicial e simbolo de multiplicacao conferidos na VRAM', flush=True)

    screen, writes = capture('    shell_execute("chars");')
    assert [tile for _, _, tile in writes[:95]] == list(range(32, 127)), writes
    preview(screen, 'font-preview.png')
    print('OK: os 95 caracteres imprimiveis ASCII renderizados', flush=True)

    screen, _ = capture('    shell_execute("help");')
    assert 'Commands:' in '\n'.join(lines(screen)) and 'help ver clear' in '\n'.join(lines(screen)), lines(screen)
    screen, _ = capture('    shell_execute("ver");')
    assert 'NexOS v0.1' in '\n'.join(lines(screen)), lines(screen)
    screen, _ = capture('    shell_execute("echo hello NES");')
    assert 'hello NES' in '\n'.join(lines(screen)), lines(screen)
    screen, _ = capture('    shell_execute("missing");')
    text = '\n'.join(lines(screen))
    assert 'Unknown command or program unava' in text and 'ilable: missing' in text, text
    screen, _ = capture('''    if (system_call(255, "bad")) debug_puts("ERROR syscall\\n");
    if (system_call(SYS_WRITE, 0)) debug_puts("ERROR null\\n");''')
    assert lines(screen) == ['']*30, lines(screen)
    print('OK: comandos internos, desconhecidos e syscalls invalidas', flush=True)

    screen, writes = capture('''    system_call(SYS_DEBUG_PUTCHAR, "D");
    debug_putchar('!'); debug_putchar('\\n');
    debug_printf("%s %u %x\\n", "dbg", 42u, 0xAu);
    if (system_call(SYS_DEBUG_PUTCHAR, 0)) debug_puts("ERROR null debug\\n");''',
        expected_debug=b'D!\ndbg 42 000a\nDONE\n')
    assert not writes, writes
    print('OK: syscall de debug valida argumentos e nao escreve na tela', flush=True)

    screen, _ = capture('    printf("%s %d %u %x %%\\n", "ok", -12, 123u, 0xABCDu);')
    assert lines(screen)[0] == 'ok -12 123 abcd %', lines(screen)
    print('OK: printf escreve formatacao na tela e nao no canal debug', flush=True)

    screen, _ = capture('    os_write("ABCDEFGHIJKLMNOP"); os_write("QRSTUVWXYZ012345"); os_write("B\\rC\\nD\\bE\\x01");')
    assert lines(screen)[:3] == ['ABCDEFGHIJKLMNOPQRSTUVWXYZ012345', 'C', 'E?'], lines(screen)
    print('OK: 32 colunas, quebra de linha, retorno, backspace e substituicao', flush=True)

    screen, _ = capture('    os_write("erase me"); shell_execute("clear");', timeout=10)
    assert lines(screen) == ['nexos>'] + ['']*29, lines(screen)
    print('OK: clear apaga as 30 linhas sem framebuffer na RAM', flush=True)

    screen, _ = capture('    os_write("' + '\\n'*29 + 'A'*32 + '"); os_write("new page");', timeout=10)
    assert lines(screen) == ['new page'] + ['']*29, lines(screen)
    print('OK: limite de 30 linhas abre uma pagina nova com pilhas validas', flush=True)
finally:
    command(['make', '-B', 'all'])
