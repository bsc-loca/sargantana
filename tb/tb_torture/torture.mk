TB_TORTURE_DIR = $(PROJECT_DIR)/tb/tb_torture

# Folders

RISCV_TORTURE      = $(TB_TORTURE_DIR)/riscv-torture
TORTURE_OUTPUT     = $(TB_TORTURE_DIR)/riscv-torture/output
TORTURE_CONFIG     = $(TB_TORTURE_DIR)/config
TORTURE_ENV        = $(PROJECT_DIR)/drac-bench/env
TORTURE_SIGNATURES = $(TB_TORTURE_DIR)/signatures

# Configs, sources, binaries, signatures...

TORTURE_CONFIGS          = $(wildcard $(TORTURE_CONFIG)/*.config)
TORTURE_SOURCES          = $(patsubst $(TORTURE_CONFIG)/%.config,$(TORTURE_OUTPUT)/test_%.S,$(TORTURE_CONFIGS))
TORTURE_BINARIES         = $(patsubst $(TORTURE_OUTPUT)/%.S,$(TORTURE_OUTPUT)/%.riscv,$(TORTURE_SOURCES))
TORTURE_SIM_SIGNATURES   = $(patsubst $(TORTURE_CONFIG)/%.config,$(TORTURE_SIGNATURES)/%_sim.txt,$(TORTURE_CONFIGS))
TORTURE_SPIKE_SIGNATURES = $(patsubst $(TORTURE_CONFIG)/%.config,$(TORTURE_SIGNATURES)/%_spike.txt,$(TORTURE_CONFIGS))
TORTURE_DIFFS			 = $(patsubst $(TORTURE_CONFIG)/%.config,$(TORTURE_SIGNATURES)/%.diff,$(TORTURE_CONFIGS))

# Compilation settings

ENTROPY = -DENTROPY=$(shell echo $$$$)
RISCV_GCC_VMEM_OPTS = $(ENTROPY) -static -mcmodel=medany -fvisibility=hidden \
	-nostdlib -nostartfiles -lm -lgcc -march=rv64g -mabi=lp64 -std=gnu99 -O2 \
	-DUSE_VMEM=1 -I$(TORTURE_ENV)/v -T$(TORTURE_ENV)/v/link.ld \
	$(TORTURE_ENV)/v/entry.S $(TORTURE_ENV)/v/vm.c $(TORTURE_ENV)/v/string.c 

RISCV_GCC_PMEM_OPTS = $(ENTROPY) -static -mcmodel=medany -fvisibility=hidden \
	-nostdlib -nostartfiles -lm -lgcc -march=rv64g -mabi=lp64 -std=gnu99 -O2 \
	-I$(TORTURE_ENV)/p -T$(TORTURE_ENV)/p/link.ld

TORTURE_RISCV_GCC_OPTS = $(RISCV_GCC_VMEM_OPTS)

define get_config
$(patsubst test_%,%,$(firstword $(subst -, ,$(basename $(notdir $(1))))))
endef

# Spike settings

SPIKE = ./simulator/riscv-isa-sim/build/spike
SPIKE_OPTS = -l --log-commits --isa=rv64g --mmu-dirty

# Diff script

SIGDIFF = $(TB_TORTURE_DIR)/sigdiff.sh

# *** Convinience targets ***

.PHONY: build-torture run-torture

run-torture: $(TORTURE_DIFFS)

build-torture: $(TORTURE_BINARIES)

# *** Test generation & compilation ***

$(TORTURE_OUTPUT)/%.S: 
		$(MAKE) -C $(RISCV_TORTURE) gen OPTIONS="-C ../config/$(call get_config, $@).config -o test_$(call get_config, $@)"

$(TORTURE_OUTPUT)/%.riscv: $(TORTURE_OUTPUT)/%.S
		$(RISCV_GCC) $(TORTURE_RISCV_GCC_OPTS) $< -o $@

$(TORTURE_SIGNATURES):
		mkdir -p $@

# *** Simulation & signature generation ***

# Do not remove signature files
.PRECIOUS: $(TORTURE_SPIKE_SIGNATURES) $(TORTURE_SIM_SIGNATURES) 

$(TORTURE_SIGNATURES)/%_sim.txt: $(TORTURE_OUTPUT)/test_%.riscv $(TORTURE_SIGNATURES) $(SIMULATOR)
		$(SIMULATOR) +load=$< +torture_dump_ON +torture_dump=$@

$(TORTURE_SIGNATURES)/%_spike.txt: $(TORTURE_OUTPUT)/test_%.riscv $(TORTURE_SIGNATURES) $(SIMULATOR)
		$(SPIKE) $(SPIKE_OPTS) --log=$@ $<

$(TORTURE_SIGNATURES)/%.diff: $(TORTURE_SIGNATURES)/%_sim.txt $(TORTURE_SIGNATURES)/%_spike.txt
		$(SIGDIFF) $^ $(TORTURE_OUTPUT)/test_$*.riscv > $@

# *** Cleaning ***

clean-torture:
		rm -rf $(TORTURE_SIGNATURES) $(TORTURE_OUTPUT)/test*

clean:: clean-torture