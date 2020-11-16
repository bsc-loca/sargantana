VLOG_FLAGS=-svinputport=compat 
CYCLES=-all
BASE_DIR="../../../../../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
WB_STAGE="${BASE_DIR}/rtl/datapath/rtl/wb_stage/rtl"

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module
vlog $VLOG_FLAGS +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv $WB_STAGE/graduation_list.sv tb_graduation_list.sv colors.vh
vmake lib_module/ > Makefile

if [ -z "$1" ]
then
      vsim work.tb_graduation_list -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_graduation_list $1 -do "run $CYCLES"
fi
