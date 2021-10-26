#$1
VLOG_FLAGS=-svinputport=compat 
CYCLES=-all
ROOT=$(git rev-parse --show-cdup)
RTL="../../rtl/"

rm -rf lib_bootrom_unit

vlib lib_bootrom_unit
vmap work $PWD/lib_bootrom_unit
vlog $VLOG_FLAGS +acc=rn +incdir+  ${RTL}bootrom_ctrl.sv ${RTL}spi_eeprom_req.sv ${ROOT}tb/models/25CSM04.v tb_bootrom_ctrl.sv 
#vmake lib_bootrom_unit > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_bootrom_ctrl -fsmdebug  -do "view wave" -do "do wave.do" -do "run $CYCLES"
else
      vsim  work.tb_bootrom_ctrl -c -do "run -all"
fi

