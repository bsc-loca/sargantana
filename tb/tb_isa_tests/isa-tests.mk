TB_ISA_TEST_DIR = $(PROJECT_DIR)/tb/tb_isa_tests

RISCV_TESTS_DIR = $(PROJECT_DIR)/drac-bench

# *** ISA Test Compilation ***

$(TB_ISA_TEST_DIR)/build/Makefile: 
		mkdir -p $(TB_ISA_TEST_DIR)/build/
		cd $(TB_ISA_TEST_DIR)/build/ && $(RISCV_TESTS_DIR)/configure

.PHONY: build-isa-tests
build-isa-tests: $(TB_ISA_TEST_DIR)/build/Makefile
		$(MAKE) -C $(TB_ISA_TEST_DIR)/build isa

# *** ISA Test Simulation ***

run-isa-tests: build-isa-tests $(SIMULATOR)
		$(TB_ISA_TEST_DIR)/run-tests.py $(SIMULATOR) $(TB_ISA_TEST_DIR)/build/isa

# *** Cleaning ***

clean-isa-tests:
		rm -rf $(TB_ISA_TEST_DIR)/build

clean:: clean-isa-tests
