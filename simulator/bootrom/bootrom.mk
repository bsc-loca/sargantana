BOOTROM_DIR = $(SIM_DIR)/bootrom

RISCV_GCC ?= riscv64-unknown-elf-gcc
RISCV_OBJCOPY ?= riscv64-unknown-elf-objcopy

$(BOOTROM_DIR)/build:
	mkdir -p $@

$(BOOTROM_DIR)/build/%.dtb: $(BOOTROM_DIR)/%.dts
	dtc -I dts $< -O dtb -o $@

$(BOOTROM_DIR)/build/bootrom.o: $(BOOTROM_DIR)/bootrom.S $(BOOTROM_DIR)/build/ariane.dtb $(BOOTROM_DIR)/build
	$(RISCV_GCC) -T$(BOOTROM_DIR)/linker.ld $(BOOTROM_DIR)/bootrom.S -I$(BOOTROM_DIR)/build -nostdlib -nostartfiles -nodefaultlibs -static -Wl,--no-gc-sections -march=rv64imafd -o $@
	
#$(BOOTROM_DIR)/build/bootrom.bin: $(BOOTROM_DIR)/build/bootrom.o $(BOOTROM_DIR)/build
#	$(RISCV_OBJCOPY) -O binary $< $@

# This is wrong, but it's how it was originally done. Might break at some point...
bootrom.hex: $(BOOTROM_DIR)/build/bootrom.o
	$(BOOTROM_DIR)/bin2hex.py -w 128 $< $@

clean-bootrom:
	rm -rf $(BOOTROM_DIR)/build bootrom.hex

clean:: clean-bootrom