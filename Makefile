
BUILD_DIR := build
EMULATOR := ./tools/bin/nes-emulator
C_HEADERS := $(wildcard kernel/*.h kernel/proc/*.h kernel/memory/*.h kernel/exception/*.h kernel/drivers/*.h kernel/terminal/*.h kernel/shell/*.h kernel/debug/*.h)
FS_FILES = $(shell find filesystem -type f | sort)
FS_PATHS = $(patsubst filesystem/%,%,$(FS_FILES))
PROGRAMS := $(patsubst programs/%.c,%,$(wildcard programs/*.c))
PROGRAM_NEX := $(addprefix $(BUILD_DIR)/,$(addsuffix .nex,$(PROGRAMS)))
PROGRAM_HEADERS := $(wildcard programs/*.h)

.PHONY: all clean run

all: $(BUILD_DIR)/nexos.nes

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Limites compartilhados: nao editar o arquivo gerado.
$(BUILD_DIR)/process_config.inc: kernel/proc/config.h | $(BUILD_DIR)
	awk '/^#define (PROCS_MAX|PROC_C_STACK_SIZE|PROC_CPU_STACK_SIZE|PROC_ZP_SIZE) / {print $$2 " = " $$3}' $< > $@

$(BUILD_DIR)/video_config.inc: kernel/drivers/video.h | $(BUILD_DIR)
	awk '/^#define (GFX_QUEUE_SIZE|GFX_COMMAND_SIZE|GFX_NMI_BUDGET) / {print $$2 " = " $$3}' $< > $@

# Recompilar C quando um cabecalho mudar.
$(BUILD_DIR)/kernel.s $(BUILD_DIR)/common.s $(BUILD_DIR)/exception.s $(BUILD_DIR)/kmalloc.s $(BUILD_DIR)/process.s $(BUILD_DIR)/scheduler.s $(BUILD_DIR)/video.s $(BUILD_DIR)/os.s: $(C_HEADERS)

# ==========================================
# BOOT / RESET
# ==========================================
$(BUILD_DIR)/font.chr: tools/build_font.py | $(BUILD_DIR)
	python3 $< $@

$(BUILD_DIR)/reset.o: kernel/boot/reset.asm $(BUILD_DIR)/video_config.inc $(BUILD_DIR)/font.chr | $(BUILD_DIR)
	ca65 -I $(BUILD_DIR) --bin-include-dir $(BUILD_DIR) $< -o $@

# Sistema de arquivos TAR somente leitura, empacotado dentro da ROM.
$(BUILD_DIR)/rootfs.tar: $(FS_FILES) $(PROGRAM_NEX) | $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)/rootfs/bin
	for program in $(PROGRAMS); do cp $(BUILD_DIR)/$$program.nex $(BUILD_DIR)/rootfs/bin/$$program.nex; done
	tar --format ustar -b 1 -cf $@ -C filesystem $(FS_PATHS) -C $(abspath $(BUILD_DIR)/rootfs) bin

# Programas C compilados separadamente; o entry point fica primeiro em CODE.
$(BUILD_DIR)/%.program.s: programs/%.c $(PROGRAM_HEADERS) | $(BUILD_DIR)
	cc65 -t none -Oirs -I programs $< -o $@

$(BUILD_DIR)/%.program.o: $(BUILD_DIR)/%.program.s
	ca65 $< -o $@

$(BUILD_DIR)/%.raw: $(BUILD_DIR)/%.program.o linker/program.cfg | $(BUILD_DIR)
	ld65 -C linker/program.cfg $< none.lib -o $@ -Ln $(BUILD_DIR)/$*.lbl

$(BUILD_DIR)/%.nex: $(BUILD_DIR)/%.raw tools/pack_nex.py | $(BUILD_DIR)
	python3 tools/pack_nex.py $< $(BUILD_DIR)/$*.lbl $@

# ==========================================
# COMPILACAO C -> ASSEMBLY
# ==========================================
$(BUILD_DIR)/kernel.s: kernel/kernel.c | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/os.s: kernel/os.c $(C_HEADERS) | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/common.s: kernel/common.c | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/exception.s: kernel/exception/exception.c | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/kmalloc.s: kernel/memory/kmalloc.c | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/process.s: kernel/proc/process.c | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/scheduler.s: kernel/proc/scheduler.c | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/video.s: kernel/drivers/video.c | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/keyboard.s: kernel/drivers/keyboard.c $(C_HEADERS) | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/terminal.s: kernel/terminal/terminal.c $(C_HEADERS) | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/shell.s: kernel/shell/shell.c $(C_HEADERS) | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/syscall.s: kernel/syscall.c $(C_HEADERS) | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/fs.s: kernel/fs.c $(C_HEADERS) | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/user_api.s: kernel/user_api.c $(C_HEADERS) | $(BUILD_DIR)
	cc65 -t none $< -o $@

$(BUILD_DIR)/terminal.o: $(BUILD_DIR)/terminal.s
	ca65 $< -o $@

$(BUILD_DIR)/shell.o: $(BUILD_DIR)/shell.s
	ca65 $< -o $@

$(BUILD_DIR)/syscall.o: $(BUILD_DIR)/syscall.s
	ca65 $< -o $@

$(BUILD_DIR)/fs.o: $(BUILD_DIR)/fs.s
	ca65 $< -o $@

$(BUILD_DIR)/user_api.o: $(BUILD_DIR)/user_api.s
	ca65 $< -o $@

$(BUILD_DIR)/fs_data.o: kernel/fs_data.asm $(BUILD_DIR)/rootfs.tar | $(BUILD_DIR)
	ca65 -I $(BUILD_DIR) --bin-include-dir $(BUILD_DIR) $< -o $@

# ==========================================
# ASSEMBLY -> OBJETOS
# ==========================================
$(BUILD_DIR)/main.o: $(BUILD_DIR)/kernel.s
	ca65 $< -o $@

$(BUILD_DIR)/os.o: $(BUILD_DIR)/os.s
	ca65 $< -o $@

$(BUILD_DIR)/common.o: $(BUILD_DIR)/common.s
	ca65 $< -o $@

$(BUILD_DIR)/process.o: $(BUILD_DIR)/process.s
	ca65 $< -o $@

$(BUILD_DIR)/scheduler.o: $(BUILD_DIR)/scheduler.s
	ca65 $< -o $@

$(BUILD_DIR)/debug.o: kernel/debug/debug.asm | $(BUILD_DIR)
	ca65 $< -o $@

$(BUILD_DIR)/user_gate.o: kernel/user_gate.asm | $(BUILD_DIR)
	ca65 $< -o $@

$(BUILD_DIR)/kmalloc.o: $(BUILD_DIR)/kmalloc.s
	ca65 $< -o $@

$(BUILD_DIR)/exception_c.o: $(BUILD_DIR)/exception.s
	ca65 $< -o $@

$(BUILD_DIR)/exception_asm.o: kernel/exception/exception.asm | $(BUILD_DIR)
	ca65 $< -o $@

$(BUILD_DIR)/switch.o: kernel/proc/switch.asm $(BUILD_DIR)/process_config.inc | $(BUILD_DIR)
	ca65 -I $(BUILD_DIR) --bin-include-dir $(BUILD_DIR) $< -o $@

$(BUILD_DIR)/ppu.o: kernel/drivers/ppu.asm | $(BUILD_DIR)
	ca65 $< -o $@

$(BUILD_DIR)/video.o: $(BUILD_DIR)/video.s | $(BUILD_DIR)
	ca65 $< -o $@

$(BUILD_DIR)/keyboard.o: $(BUILD_DIR)/keyboard.s
	ca65 $< -o $@

# ==========================================
# LINKER
# ==========================================
COMMON_OBJECTS := $(addprefix $(BUILD_DIR)/,reset.o debug.o user_gate.o user_api.o common.o exception_c.o exception_asm.o kmalloc.o process.o scheduler.o switch.o ppu.o video.o keyboard.o os.o terminal.o shell.o syscall.o fs.o fs_data.o)

$(BUILD_DIR)/nexos.nes: $(BUILD_DIR)/main.o $(COMMON_OBJECTS) linker/nes.cfg
	ld65 -C linker/nes.cfg $(COMMON_OBJECTS) $(BUILD_DIR)/main.o none.lib \
		-o $@ -m $(BUILD_DIR)/nexos.map -Ln $(BUILD_DIR)/nexos.lbl

# ==========================================
# EXECUCAO
# ==========================================
run: $(BUILD_DIR)/nexos.nes
	$(EMULATOR) $< --headless --debug

run-ui: $(BUILD_DIR)/nexos.nes
	$(EMULATOR) $< --debug

# ==========================================
# LIMPEZA
# ==========================================
clean:
	rm -rf $(BUILD_DIR)

.PHONY: memory test
memory: all
	python3 tools/memory_report.py

test: all
	python3 tools/test_processes.py
	python3 tools/test_video.py
	python3 tools/test_shell.py
