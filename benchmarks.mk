RISCV_TESTS_DIR = $(PROJECT_DIR)/drac-bench

RISCV_GCC_OPTS = -march=rv64g -DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -fno-tree-loop-distribute-patterns

# *** riscv-tests benchmark compilation ***

$(PROJECT_DIR)/benchmarks/Makefile: 
		mkdir -p $(PROJECT_DIR)/benchmarks/
		cd $(PROJECT_DIR)/benchmarks/ && $(RISCV_TESTS_DIR)/configure

.PHONY: build-benchmarks
build-benchmarks: $(PROJECT_DIR)/benchmarks/Makefile
		$(MAKE) -C $(PROJECT_DIR)/benchmarks RISCV_GCC_OPTS="$(RISCV_GCC_OPTS)" benchmarks

# *** riscv-tests benchmark simulation ***

run-benchmarks: build-benchmarks $(SIMULATOR)
		$(PROJECT_DIR)/run-benchmarks.sh
		
# *** Cleaning ***

clean-benchmarks:
		rm -rf $(PROJECT_DIR)/benchmarks

clean:: clean-benchmarks