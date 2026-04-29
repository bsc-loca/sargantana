
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../../../../../../rtl/datapath/rtl/exe_stage/rtl/fpu/src/fpnew_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../../../../includes/drac_pkg.sv
VERILOG_SOURCES += $(PWD)/../../../../../../includes/riscv_pkg.sv
VERILOG_SOURCES += $(PWD)/../../rtl/realigner.sv

COCOTB_TOPLEVEL = realigner
COCOTB_TEST_MODULES = test_realigner

EXTRA_ARGS += --trace --trace-fst --trace-structs --trace-params --trace-underscore -Wno-lint -Wno-style -Wno-STMTDLY -Wno-BLKANDNBLK -Wno-fatal 

include $(shell cocotb-config --makefiles)/Makefile.sim
