PROJECT_DIR = $(abspath .)

FILELIST = $(PROJECT_DIR)/filelist.f

# *** Verilator Simulator ***
include simulator/simulator.mk

sim: $(SIMULATOR)

# *** ISA Tests ***
include tb/tb_isa_tests/isa-tests.mk

# *** Benchmarks ***
include benchmarks.mk

# *** Torture Tests ***
include tb/tb_torture/torture.mk

# *** CI rules ***
lint:
	bash ./scripts/veri_lint.sh
	exit $?	
strict_lint:
	bash ./scripts/veri_lint_strict.sh
	exit $?	
local_spyglass:
	bash ./scripts/local_spy.sh
	exit $?	
remote_spyglass:
	bash ./scripts/spyglass_ci.sh
	exit $?	
init:
	git config core.hooksPath .githooks
	exit $?	
questa:
	rm -f /tmp/artifact_questa.log
	bash ./scripts/questa_ci.sh
	exit $?	
