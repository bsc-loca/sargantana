/* -------------------------------------------------------------------------------
 * Project        : BootROM
 * File           : bootrom.vh
 * Description    :
 * Organization   : BSC
 * Author(s)      : 
 * Email(s)       : 
 * References     :
 * -------------------------------------------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 * -----------------------------------------------------------------------------*/

  `ifndef _BOOTROM_H_
  `define _BOOTROM_H_

  /* 25CSM04 EEPROM opcodes */
		// STATUS Register instructions
  `define _25CSM04_RDSR_    8'h05
  `define _25CSM04_WRBP_    8'h08
  `define _25CSM04_WREN_		8'h06
  `define _25CSM04_WRDI_    8'h04
  `define _25CSM04_WRSR_    8'h01

		// EEPROM and Security Register Instructions
  `define _25CSM04_READ_    8'h03
  `define _25CSM04_WRITE_   8'h02
  `define _25CSM04_RDEX_    8'h83
  `define _25CSM04_WREX_    8'h82
  `define _25CSM04_LOCK_    8'h82
  `define _25CSM04_CHLK_    8'h83

		// Memory Partition Register Instructions
  `define _25CSM04_RMPR_    8'h31
  `define _25CSM04_PRWE_    8'h07
  `define _25CSM04_PRWD_    8'h0A
  `define _25CSM04_WMPR_    8'h32
  `define _25CSM04_PPAB_    8'h34
  `define _25CSM04_FRZR_    8'h37

		// Identification Register Instructions
  `define _25CSM04_SPID_    8'h9F

		// Device Reset Instruction
  `define _25CSM04_SRST_    8'h7C


	/* model specific parameters */
	`define _25CSM04_ADDR_SZ_ 24
	`define _25CSM04_OPCODE_SZ_ 8



  /* axi spi parameters */
  `define _DATA_WIDTH_SPI_  8
  `define _SPI_RATIO_GRADE_ 3


  `endif
