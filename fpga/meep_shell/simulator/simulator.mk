VERILATOR = verilator
MEEP_SIM_DIR = $(PROJECT_DIR)/fpga/meep_shell/simulator

MEEP_SIMULATOR = $(PROJECT_DIR)/sim-meep

FLAGS ?=

MEEP_VERI_FLAGS = \
	$(foreach flag, $(FLAGS), -D$(flag)) \
	-DVERILATOR_GCC \
	+define+VERILATOR_TORTURE_TESTS \
	+incdir+$(PROJECT_DIR)/rtl \
	+incdir+$(PROJECT_DIR)/fpga/common/rtl/common_cells/include \
	+incdir+$(PROJECT_DIR)/fpga/common/rtl/axi/include \
	+incdir+$(PROJECT_DIR)/fpga/meep_shell/src \
	--top-module $(TOP_MODULE) \
	--unroll-count 256 \
	-Wno-lint -Wno-style -Wno-STMTDLY -Wno-fatal \
	-CFLAGS "-std=c++11 -I$(SIM_DIR)/riscv-isa-sim/" \
	-LDFLAGS "-pthread -L$(SIM_DIR)/riscv-isa-sim/build/ -l:libriscv.a -l:libdisasm.a -ldl" \
	--exe \
	--trace-fst \
	--trace-max-array 512 \
	--trace-max-width 256 \
	--trace-structs \
	--trace-params \
	--trace-underscore \
	--assert \
	--Mdir $(MEEP_SIM_DIR)/build \
	--savable

MEEP_VERI_OPTI_FLAGS = -O2 -CFLAGS "-O2"

MEEP_SIM_CPP_SRCS = $(SIM_CPP_SRCS) $(wildcard $(MEEP_SIM_DIR)/models/cxx/*.cpp)
MEEP_SIM_VERILOG_SRCS = $(SIM_VERILOG_SRCS) $(shell cat $(PROJECT_DIR)/fpga/common/filelist.f) $(wildcard $(PROJECT_DIR)/fpga/meep_shell/src/*) $(wildcard $(MEEP_SIM_DIR)/models/hdl/*.sv)
 
$(MEEP_SIMULATOR): $(MEEP_SIM_VERILOG_SRCS) $(MEEP_SIM_CPP_SRCS) bootrom.hex $(SPIKE_DIR)/build/libriscv.so $(MEEP_SIM_DIR)/veri_top.sv
		$(VERILATOR) --cc $(MEEP_VERI_FLAGS) $(VERI_OPTI_FLAGS) $(MEEP_SIM_VERILOG_SRCS) $(MEEP_SIM_CPP_SRCS) $(MEEP_SIM_DIR)/veri_top.sv -o $(SIMULATOR)
		$(MAKE) -C $(MEEP_SIM_DIR)/build -f V$(TOP_MODULE).mk $(MEEP_SIMULATOR)

clean-meep-simulator:
		rm -rf $(MEEP_SIM_DIR)/build $(MEEP_SIMULATOR)

clean:: clean-meep-simulator