VERILATOR = verilator
SIM_DIR = $(PROJECT_DIR)/simulator

include $(SIM_DIR)/bootrom/bootrom.mk
include $(SIM_DIR)/spike.mk

TOP_MODULE = veri_top

SIMULATOR = $(PROJECT_DIR)/sim

FLAGS ?=

VERI_FLAGS = \
	$(foreach flag, $(FLAGS), -D$(flag)) \
	-DVERILATOR_GCC \
	+define+VERILATOR_TORTURE_TESTS \
	+incdir+$(PROJECT_DIR)/rtl \
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
	--Mdir $(SIM_DIR)/build \
	--savable

VERI_OPTI_FLAGS = -O2 -CFLAGS "-O2"

SIM_CPP_SRCS = $(wildcard $(SIM_DIR)/models/cxx/*.cpp)
SIM_VERILOG_SRCS = $(shell cat $(FILELIST)) $(wildcard $(SIM_DIR)/models/hdl/*.sv)
 
$(SIMULATOR): $(SIM_VERILOG_SRCS) $(SIM_CPP_SRCS) bootrom.hex $(SPIKE_DIR)/build/libriscv.so $(SIM_DIR)/veri_top.sv
		$(VERILATOR) --cc $(VERI_FLAGS) $(VERI_OPTI_FLAGS) $(SIM_VERILOG_SRCS) $(SIM_CPP_SRCS) $(SIM_DIR)/veri_top.sv -o $(SIMULATOR)
		$(MAKE) -C $(SIM_DIR)/build -f V$(TOP_MODULE).mk $(SIMULATOR)

clean-simulator:
		rm -rf $(SIM_DIR)/build $(SIMULATOR)

clean:: clean-simulator