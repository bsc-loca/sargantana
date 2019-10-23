$1
CYCLES=80
BASE_DIR="../../../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
ICACHE_INTERF="${BASE_DIR}/rtl/interface_icache/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
INCLUDES="${BASE_DIR}/includes"

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv $ICACHE_INTERF/icache_interface.sv \
 tb_icache_interface.sv colors.vh
vmake lib_module/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_icache_interface -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_icache_interface $1 -do "run $CYCLES"
fi
