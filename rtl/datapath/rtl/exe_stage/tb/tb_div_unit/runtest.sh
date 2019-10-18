$1
CYCLES=10000

mv lib_div_unit /tmp

vlib lib_div_unit
vmap work $PWD/lib_div_unit
vlog +acc=rn +incdir+ ../definitions.v ../div_unit.v tb_div_unit.sv colors.vh
vmake lib_div_unit/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_div_unit -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_div_unit $1 -do "run $CYCLES"
fi
