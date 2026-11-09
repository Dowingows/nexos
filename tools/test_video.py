"""Integra C/NMI/PPU: FIFO, wrap-around, lotacao e limite por VBlank."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent


def command(args):
    result = subprocess.run(args, cwd=root, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result


try:
    command(['make', '-B', 'all'])
    source = (root / 'kernel/kernel.c').read_text()
    start = source.index('static void application(void)')
    end = source.index('void kernel_main(void)', start)
    source = source[:start] + '''static unsigned char worker_done;
static void worker_a(void)
{
    unsigned char i;
    for (i = 0; i < 8; i++) os_draw_tile(i, 10, 1);
    worker_done++;
    for (;;) yield();
}
static void worker_b(void)
{
    unsigned char i;
    for (i = 16; i < 24; i++) os_draw_tile(i, 20, 1);
    worker_done++;
    for (;;) yield();
}
static void application(void)
{
    unsigned char i;
    if (os_draw_tile(32, 0, 1)) debug_puts("ERROR x\\n");
    if (os_draw_tile(0, 30, 1)) debug_puts("ERROR y\\n");
    for (i = 0; i < 20; i++) {
        if (!os_draw_tile(i, (i * 3u) % 30u, i & 1)) debug_puts("ERROR draw\\n");
    }
    while (worker_done != 2) yield();
    while (gfx_head != gfx_tail) {
        gfx_waiting = 1;
        if (gfx_head != gfx_tail) process_wait(&gfx_waiting);
    }
    debug_puts("QUEUE OK\\n");
    for (;;) yield();
}

''' + source[end:]
    source = source.replace('    create_process((nes_uint16_t)application);', '    create_process((nes_uint16_t)application);\n    create_process((nes_uint16_t)worker_a);\n    create_process((nes_uint16_t)worker_b);')
    source = source.replace('    video_enable();', '''    {
        unsigned char fill_index;
        for (fill_index = 0; fill_index < GFX_QUEUE_SIZE - 1; fill_index++) {
            if (!gfx_enqueue_tile(fill_index, 29, 1)) debug_puts("ERROR fill\\n");
        }
    }
    if (gfx_enqueue_tile(15, 29, 1)) debug_puts("ERROR full\\n");
    gfx_head = 0;
    gfx_tail = 0;
    gfx_waiting = 0;
    if (!gfx_enqueue_tile(1, 0, 1)) debug_puts("ERROR first\\n");
    if (!gfx_enqueue_tile(2, 0, 0)) debug_puts("ERROR second\\n");
    if (!gfx_enqueue_tile(3, 0, 1)) debug_puts("ERROR third\\n");
    if (gfx_enqueue_tile(32, 0, 1)) debug_puts("ERROR bounds\\n");
    video_enable();''')
    (root / 'build/video-test.c').write_text(source)
    command(['cc65', '-t', 'none', '-I', 'kernel', 'build/video-test.c', '-o', 'build/video-test.s'])
    command(['ca65', 'build/video-test.s', '-o', 'build/main.o'])

    reset = (root / 'kernel/boot/reset.asm').read_text()
    reset = reset.replace('    inc nmi_count', '    inc nmi_count\n    lda #$FD\n    sta $5FF0')
    # Instrumentacao somente na ROM de teste. Preserva X e Y do consumidor.
    reset = reset.replace('    ; Libera a vaga apenas depois da escrita completa na PPU.', '''    lda #$FE
    sta $5FF0
    lda _gfx_queue,x
    sta $5FF0
    lda _gfx_queue+1,x
    sta $5FF0
    lda _gfx_queue+2,x
    sta $5FF0

    ; Le novamente o tile na PPU: a primeira leitura e o buffer atrasado.
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
    ; Libera a vaga apenas depois da escrita completa na PPU.''')
    reset = reset.replace('    beq @done', '    bne :+\n    jmp @done\n:')
    reset = reset.replace('    bne @command', '    beq :+\n    jmp @command\n:')
    (root / 'build/video-reset.asm').write_text(reset)
    command(['ca65', '-I', 'build', '--bin-include-dir', 'build', 'build/video-reset.asm', '-o', 'build/reset.o'])
    (root / 'build/nexos.nes').unlink(missing_ok=True)
    command(['make', 'all'])
    try:
        result = subprocess.run(['./tools/bin/nes-emulator', 'build/nexos.nes', '--headless', '--debug'],
                                cwd=root, capture_output=True, timeout=2)
        output = result.stdout
        assert result.returncode == 0, result.stderr
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b''
    commands, frames, text = [], [], bytearray()
    index = 0
    while index < len(output):
        value = output[index]
        index += 1
        if value == 0xFD:
            frames.append(0)
        elif value == 0xFE:
            commands.append(tuple(output[index:index+3]))
            index += 3
            assert frames, output
            frames[-1] += 1
        else:
            text.append(value)
    assert commands[:3] == [(1, 0, 1), (2, 0, 0), (3, 0, 1)], commands
    assert len(commands) == 39, commands
    remaining = commands[3:]
    # A ordem relativa de cada produtor deve ser mantida; a intercalacao
    # entre produtores depende de quando a NMI acontece.
    expected_app = [(i, (i*3) % 30, i & 1) for i in range(20)]
    expected_a = [(i, 10, 1) for i in range(8)]
    expected_b = [(i, 20, 1) for i in range(16, 24)]
    assert [c for c in remaining if c[1] not in (10, 20)] == expected_app, remaining
    assert [c for c in remaining if c[1] == 10] == expected_a, remaining
    assert [c for c in remaining if c[1] == 20] == expected_b, remaining
    assert bytes(text) == b'QUEUE OK\n', text
    assert max(frames) <= 8, frames
    print('OK: 39 comandos de tres produtores, sem perdas, com wrap-around e leitura da VRAM')
    print('OK: fila cheia e coordenadas invalidas recusadas; produtores bloqueiam e retomam')
    print('OK: NMI processa no maximo 8 comandos por VBlank')
finally:
    command(['make', '-B', 'all'])
