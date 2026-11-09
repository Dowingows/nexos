.setcpu "6502"

.export _start_tasks, _switch_context, _current_task, _next_task
.export _process_context_init, _process_contexts_ready
.import _process_entry
.importzp sp
.import __CSTACK_START__, __CSTACK_SIZE__, __ZEROPAGE_SIZE__

.include "process_config.inc"
TASK_COUNT = PROCS_MAX
STACK_SIZE = PROC_CPU_STACK_SIZE
STACK_BASE = $0200 - STACK_SIZE
ZP_BASE = $0002
ZP_SIZE = PROC_ZP_SIZE
C_STACK_SIZE = PROC_C_STACK_SIZE
.assert TASK_COUNT > 0 .and TASK_COUNT <= 255, error, "Quantidade de processos invalida"
.assert STACK_SIZE >= 6 .and STACK_SIZE <= 255, error, "Pilha CPU invalida"
.assert ZP_SIZE >= 2 .and ZP_SIZE <= 254, error, "Contexto ZP invalido"
.assert C_STACK_SIZE >= 16, error, "Pilha C muito pequena"
.assert TASK_COUNT * C_STACK_SIZE <= __CSTACK_SIZE__, lderror, "Pilhas dos processos excedem CSTACK"
.assert __ZEROPAGE_SIZE__ <= ZP_SIZE, lderror, "Aumente PROC_ZP_SIZE para salvar toda a zero page"

.segment "BSS"
_current_task: .res 1
_next_task: .res 1
_process_contexts_ready: .res 1
cpu_stacks: .res TASK_COUNT * STACK_SIZE
cpu_sps: .res TASK_COUNT
zp_contexts: .res TASK_COUNT * ZP_SIZE
zp_template: .res ZP_SIZE

.segment "CODE"

.macro INIT_TASK_CONTEXT task
    .local copy_zp
    lda #$A5
    sta __CSTACK_START__ - (task+1)*C_STACK_SIZE
    lda #$00
    sta cpu_stacks + task * STACK_SIZE + STACK_SIZE - 6
    sta cpu_stacks + task * STACK_SIZE + STACK_SIZE - 5
    sta cpu_stacks + task * STACK_SIZE + STACK_SIZE - 4
    lda #$24
    sta cpu_stacks + task * STACK_SIZE + STACK_SIZE - 3
    lda #<(_process_entry - 1)
    sta cpu_stacks + task * STACK_SIZE + STACK_SIZE - 2
    lda #>(_process_entry - 1)
    sta cpu_stacks + task * STACK_SIZE + STACK_SIZE - 1
    lda #$F9
    sta cpu_sps + task
    ldx #$00
copy_zp:
    lda zp_template,x
    sta zp_contexts + task * ZP_SIZE,x
    inx
    cpx #ZP_SIZE
    bne copy_zp
    lda #<(__CSTACK_START__ - task * C_STACK_SIZE)
    sta zp_contexts + task * ZP_SIZE + (sp - ZP_BASE)
    lda #>(__CSTACK_START__ - task * C_STACK_SIZE)
    sta zp_contexts + task * ZP_SIZE + (sp - ZP_BASE) + 1
.endmacro

_start_tasks:
    sei
    ldx #$FF
    txs

    ; Guarda uma base limpa da zero page para reinicializar processos concluidos.
    ldx #$00
@save_template:
    lda ZP_BASE,x
    sta zp_template,x
    inx
    cpx #ZP_SIZE
    bne @save_template

    ; Cada contexto começa em process_entry com pilhas e registradores limpos.
    .repeat TASK_COUNT, task
        INIT_TASK_CONTEXT task
    .endrepeat

    lda #$01
    sta _process_contexts_ready
    lda #$00
    sta _current_task
    jmp restore_context

; Reinicializa o contexto de uma vaga reutilizada depois que o processo termina.
_process_context_init:
    .repeat TASK_COUNT, task
        cmp #task
        bne :+
        jmp .ident(.sprintf("init_task_%d", task))
        :
    .endrepeat
    rts

.repeat TASK_COUNT, task
    .ident(.sprintf("init_task_%d", task)):
        INIT_TASK_CONTEXT task
        rts
.endrepeat

; A selecao usa current_task para salvar e next_task para restaurar.
; Os blocos usam enderecos absolutos para nao consumir ponteiros
; na zero page que esta sendo copiada.
_switch_context:
    php
    pha
    txa
    pha
    tya
    pha

    .repeat TASK_COUNT, task
        lda _current_task
        cmp #task
        bne :+
        jmp .ident(.sprintf("save_%d", task))
        :
    .endrepeat
@invalid_task:
    jmp @invalid_task

; Macros mantem o mesmo formato de contexto para todas as vagas.
.macro SAVE_CONTEXT task
    .local stack, zp, overflow, check_top, check_guard, valid
    tsx
    cpx #($FF - STACK_SIZE)
    bcs :+
    jmp cpu_stack_overflow
:
    stx cpu_sps+task
    ; Verifica SP de software sem usar a pilha ou chamar C.
    lda sp+1
    cmp #>(__CSTACK_START__ - (task+1)*C_STACK_SIZE + 1)
    bcc overflow
    bne check_top
    lda sp
    cmp #<(__CSTACK_START__ - (task+1)*C_STACK_SIZE + 1)
    bcc overflow
check_top:
    lda sp+1
    cmp #>(__CSTACK_START__ - task*C_STACK_SIZE)
    bcc check_guard
    bne overflow
    lda sp
    cmp #<(__CSTACK_START__ - task*C_STACK_SIZE)
    bcc check_guard
    bne overflow
check_guard:
    lda __CSTACK_START__ - (task+1)*C_STACK_SIZE
    cmp #$A5
    beq valid
 overflow:
    jmp stack_overflow
 valid:
    ; Um unico processo continua no mesmo contexto, apos as checagens.
    lda _next_task
    cmp _current_task
    bne :+
    jmp resume
:
    ldx #0
stack:
    lda STACK_BASE,x
    sta cpu_stacks+task*STACK_SIZE,x
    inx
    cpx #STACK_SIZE
    bne stack
    ldx #0
zp:
    lda ZP_BASE,x
    sta zp_contexts+task*ZP_SIZE,x
    inx
    cpx #ZP_SIZE
    bne zp
    jmp select_next
.endmacro

.repeat TASK_COUNT, task
    .ident(.sprintf("save_%d", task)):
    SAVE_CONTEXT task
.endrepeat

select_next:
    lda _next_task
    sta _current_task
restore_context:
    .repeat TASK_COUNT, task
        lda _current_task
        cmp #task
        bne :+
        jmp .ident(.sprintf("restore_%d", task))
        :
    .endrepeat
@invalid_task:
    jmp @invalid_task

.macro RESTORE_CONTEXT task
    .local stack, zp
    ldx #0
stack:
    lda cpu_stacks+task*STACK_SIZE,x
    sta STACK_BASE,x
    inx
    cpx #STACK_SIZE
    bne stack
    ldx #0
zp:
    lda zp_contexts+task*ZP_SIZE,x
    sta ZP_BASE,x
    inx
    cpx #ZP_SIZE
    bne zp
    ldx cpu_sps+task
    txs
    jmp resume
.endmacro

.repeat TASK_COUNT, task
    .ident(.sprintf("restore_%d", task)):
    RESTORE_CONTEXT task
.endrepeat

resume:
    pla
    tay
    pla
    tax
    pla
    plp
    rts

; Diagnostico direto na porta do emulador: nao usa uma pilha corrompida.
cpu_stack_overflow:
    ldx #(cpu_stack_error - stack_error)
    jmp print_stack_error
stack_overflow:
    ldx #0
print_stack_error:
    lda stack_error,x
    beq halt_stack_error
    sta $5FF0
    inx
    bne print_stack_error
halt_stack_error:
    jmp halt_stack_error
stack_error:
    .asciiz "STACK OVERFLOW (C)"
cpu_stack_error:
    .asciiz "STACK OVERFLOW (CPU)"
