SPIKE_DIR = $(SIM_DIR)/riscv-isa-sim

# *** Spike Compilation ***

$(SPIKE_DIR)/build/Makefile: 
		mkdir -p $(SPIKE_DIR)/build/
		cd $(SPIKE_DIR)/build/ && ../configure

.PHONY: build-spike
build-spike: $(SPIKE_DIR)/build/Makefile
		$(MAKE) -C $(SPIKE_DIR)/build

$(SPIKE_DIR)/build/libriscv.so: build-spike
$(SPIKE_DIR)/build/spike: build-spike

# *** Cleaning ***

clean-spike:
		rm -rf $(SPIKE_DIR)/build

clean:: clean-spike