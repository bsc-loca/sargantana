SPIKE_DIR = $(SIM_DIR)/reference

# *** Spike Compilation ***

$(SPIKE_DIR)/build/Makefile: 
		mkdir -p $(SPIKE_DIR)/build/
		cd $(SPIKE_DIR)/build/ && ../riscv-isa-sim/configure

$(SPIKE_DIR)/build/libdisasm.so: $(SPIKE_DIR)/build/Makefile
		$(MAKE) -C $(SPIKE_DIR)/build libdisasm.so

$(SPIKE_DIR)/build/spike: $(SPIKE_DIR)/build/Makefile
		$(MAKE) -C $(SPIKE_DIR)/build spike

.PHONY: libdisasm
libdisasm: $(SPIKE_DIR)/build/libdisasm.so

.PHONY: spike
spike: $(SPIKE_DIR)/build/spike

# *** Cleaning ***

clean-spike:
		rm -rf $(SPIKE_DIR)/build

clean:: clean-spike