SIM_DIR = $(PROJECT_DIR)/simulator

include $(SIM_DIR)/bootrom/bootrom.mk
include $(SIM_DIR)/reference/spike.mk
include $(SIM_DIR)/verilator/verilator.mk