#$1
VLOG_FLAGS=-svinputport=compat 
CYCLES=-all
ROOT=$(git rev-parse --show-cdup)
RTL="../../rtl/"

rm -rf lib_bootrom_unit

vlib lib_bootrom_unit
vmap work $PWD/lib_bootrom_unit
vlog $VLOG_FLAGS +acc=rn +incdir+  ${RTL}spi_eeprom_req.sv ${ROOT}tb/models/25CSM04.v tb_spi_eeprom_req.sv
#vmake lib_bootrom_unit

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_spi_eeprom_req -fsmdebug  -do "view wave" -do "do wave.do" -do "run $CYCLES"
else
      vsim  work.tb_spi_eeprom_req -c -do "run -all"
fi

