ROOT_DIR = $(shell git rev-parse --show-cdup)
top_module = tb_bootrom_ctrl

RTL_DIR = ${ROOT_DIR}rtl
INCLUDE_DIR = ${ROOT_DIR}includes
MODEL_DIR = ${ROOT_DIR}tb/models
SIM_DIR = ${ROOT_DIR}tb/${top_module}

veri_vsrcs = \
	${ROOT_DIR}tb/${top_module}/${top_module}.v \
	${RTL_DIR}/spi_eeprom_req.sv \
	${RTL_DIR}/bootrom_ctrl.sv \
	${MODEL_DIR}/25CSM04.v

veri_flags = \
	--top-module $(top_module) \
	--exe \
	--trace \
	--trace-max-array 256 \
	--trace-max-width 256 \
	-Wno-lint -Wno-style -Wno-STMTDLY -Wno-fatal \
	-Wno-lint -Wno-style -Wno-STMTDLY -Wno-fatal \
	-CFLAGS "-std=c++11 -g" \
	+incdir+${RTL_DIR} \
	--assert \
	--Mdir ${SIM_DIR}/verilator


sim: ${SIM_DIR}/bootrom_content.hex
	${SIM_DIR}/runtest.sh nogui

sim-gui: ${SIM_DIR}/bootrom_content.hex
	${SIM_DIR}/runtest.sh 

${SIM_DIR}/bootrom_content.hex: 
	tail -c 1000000 /dev/random | xxd -ps | tr -d "\n" | fold -w 2 | tail -n 524288 > $@

clean:
	cd ${SIM_DIR} && rm -rf lib_bootrom_unit transcript vsim.wlf modelsim.ini *.vcd bootrom_content.hex
