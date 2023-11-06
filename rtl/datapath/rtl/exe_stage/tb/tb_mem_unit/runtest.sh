$1
CYCLES=80

mv lib_mem_unit /tmp

BASE_DIR="../../../../../.."

vlib lib_mem_unit
vmap work $PWD/lib_mem_unit
vlog +acc=rn +incdir+ ${BASE_DIR}/includes/riscv_pkg.sv ${BASE_DIR}/includes/drac_pkg.sv ${BASE_DIR}/rtl/interface_dcache/rtl/interface_dcache.sv ../../rtl/load_store_queue.sv ../../rtl/wip_mem_unit_lsq.sv tb_mem_unit.sv colors.vh
vmake lib_mem_unit/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_mem_unit -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_mem_unit $1 -do "run $CYCLES"
fi
