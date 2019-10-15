$1
CYCLES=80

mv lib_mul_unit /tmp

vlib lib_mul_unit
vmap work $PWD/lib_mul_unit
vlog +acc=rn +incdir+ ../definitions.v ../mul_unit.v tb_mul_unit.sv colors.vh
vmake lib_mul_unit/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_mul_unit -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_mul_unit $1 -do "run $CYCLES"
fi
