VERILATOR = verilator
VERISIM_DIR = $(SIM_DIR)/verilator

TOP_MODULE = veri_top

SIMULATOR = $(PROJECT_DIR)/sim

FLAGS ?=

VERI_FLAGS = \
	$(foreach flag, $(FLAGS), -D$(flag)) \
	-DVERILATOR_GCC \
	+define+SIM_COMMIT_LOG \
	+define+SIM_COMMIT_LOG_DPI \
	+define+SIM_KONATA_DUMP \
	+incdir+$(PROJECT_DIR)/rtl \
	+incdir+$(PROJECT_DIR)/rtl/dcache/rtl/include \
	--top-module $(TOP_MODULE) \
	--unroll-count 256 \
	-Wno-lint -Wno-style -Wno-STMTDLY -Wno-fatal \
	-CFLAGS "-std=c++11 -I$(SPIKE_DIR)/riscv-isa-sim/" \
	-LDFLAGS "-pthread -L$(SPIKE_DIR)/build/ -Wl,-rpath=$(SPIKE_DIR)/build/ -ldisasm -ldl" \
	--exe \
	--trace-fst \
	--trace-max-array 512 \
	--trace-max-width 256 \
	--trace-structs \
	--trace-params \
	--trace-underscore \
	--assert \
	--Mdir $(VERISIM_DIR)/build \
	--savable

VERI_OPTI_FLAGS = -O2 -CFLAGS "-O2"

SIM_CPP_SRCS = $(wildcard $(SIM_DIR)/models/cxx/*.cpp) $(VERISIM_DIR)/veri_top.cpp
SIM_VERILOG_SRCS = $(shell cat $(FILELIST)) $(wildcard $(SIM_DIR)/models/hdl/*.sv)
 
$(SIMULATOR): $(SIM_VERILOG_SRCS) $(SIM_CPP_SRCS) bootrom.hex libdisasm $(VERISIM_DIR)/veri_top.sv
		$(VERILATOR) --cc $(VERI_FLAGS) $(VERI_OPTI_FLAGS) $(SIM_VERILOG_SRCS) $(SIM_CPP_SRCS) $(VERISIM_DIR)/veri_top.sv -o $(SIMULATOR)
		$(MAKE) -C $(VERISIM_DIR)/build -f V$(TOP_MODULE).mk $(SIMULATOR)

clean-simulator:
		rm -rf $(VERISIM_DIR)/build $(SIMULATOR)

clean:: clean-simulator