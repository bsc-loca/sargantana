#$1
VLOG_FLAGS=-svinputport=compat 
CYCLES=-all
RTL="../../rtl/"
ROOT=$(git rev-parse --show-cdup)

rm -rf lib_div_unit

vlib lib_div_unit
vmap work $PWD/lib_div_unit
vlog $VLOG_FLAGS +acc=rn +incdir+ ${ROOT}includes/riscv_pkg.sv ${ROOT}includes/drac_pkg.sv ${RTL}div_4bits.sv ${RTL}div_unit.sv tb_div_unit.sv colors.vh
vmake lib_div_unit/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_div_unit -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_div_unit $1 -do "run $CYCLES"
fi
