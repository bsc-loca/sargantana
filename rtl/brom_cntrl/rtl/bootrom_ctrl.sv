/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : bootrom_ctrl.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Jordi Garcia
 * Email(s)       : jordi.garcia@bsc.es
  -----------------------------------------------
 */

module bootrom_ctrl (
  // Core interface
 	input	logic		        clk_i,             //   serial data clock
	input logic		        rstn_i,            //   reset
	input logic  [23:0]   req_address_i,     //   request address, for read and writes 
	input logic           req_valid_i,       //   request inputs valid state                            
	output logic          ready_o,           //   eeprom ready 
	output logic [31:0]   resp_data_o,      //   response data bus                              
	output logic          resp_valid_o,      //   response valid 
  // Memory interface
	output logic          sclk_o,            //   SPI clock - mode 0                         
	output logic          cs_n_o,            //   SPI chip select                       
	output logic          mo_o,              //   SPI master output 
	input  logic          mi_i);             //   SPI master input 


/////////////////////////////////////////////////////////////////////////
// DECLARATIONS
///////////////////////////////////////////////////////////////////////// 

  logic ready_d;
  logic ready_q;
  logic resp_valid_d;
  logic [2:0] bytecount_d;
  logic [7:0] resp_data_w;
  logic resp_valid_w;
  logic [2:0] bytecount_q;
  logic [31:0] resp_data_q;
  logic [3:0][7:0] resp_data_d;
  logic cs;
  logic [23:0] req_address_q;
	

  /* 25CSM04 EEPROM opcodes */
	`define OP_RDSR            8'b0000_0101                    // Read Status Register instruction
	`define OP_WRBP            8'b0000_1000                    // Write Ready/Busy Poll instruction
	`define OP_WREN            8'b0000_0110                    // Set Write Enable Latch instruction
	`define OP_WRDI            8'b0000_0100                    // Reset Write Enable Latch instruction
	`define OP_WRSR            8'b0000_0001                    // Write Status Register instruction
	`define OP_READ            8'b0000_0011                    // Read EEPROM Array instruction
	`define OP_WRITE           8'b0000_0010                    // Write EEPROM Array instruction
	`define OP_RDEX            8'b1000_0011                    // Read Security Register instruction
	`define OP_WREX            8'b1000_0010                    // Write Security Register instruction
	`define OP_LOCK            8'b1000_0010                    // Lock Security Register instruction
	`define OP_CHLK            8'b1000_0011                    // Check Security Register Lock Status instruction
	`define OP_RMPR            8'b0011_0001                    // Read Memory Partition Registers instruction
	`define OP_PRWE            8'b0000_0111                    // Set MPR Write Enable Latch instruction
	`define OP_PRWD            8'b0000_1010                    // Reset MPR Write Enable Latch instruction
	`define OP_WMPR            8'b0011_0010                    // Write Memory Partition Registers instruction
	`define OP_PPAB            8'b0011_0100                    // Protect Partition Address Boundaries instruction
	`define OP_FRZR            8'b0011_0111                    // Freeze Memory Protection Configuration instruction
	`define OP_SPID            8'b1001_1111                    // Read Manufacturer ID instruction
	`define OP_SRST            8'b0111_1100                    // Software Device Reset instruction



spi_eeprom_req ser (
  .clk_i          (clk_i),          //  serial data clock                              
  .rstn_i         (rstn_i),         //  reset 
  .req_opcode_i   (`OP_READ),          //  request opcode                                       
  .req_address_i  (req_address_q),  //  request address, for read and writes 
  .req_bytes_i    (9'h4),           //  request data size in bytes - max 256
  .req_data_i     (8'h0),                                                                      
  .req_valid_i    (req_valid_i),    //  request inputs valid state 
  .mo_o           (mo_o),           //  SPI master output 
  .ready_o      (ready_d),          //  eeprom ready 
  .sclk_o         (sclk_o),         //  spi clock - modei 0                   
  .sclk_en_o      (cs),             //  spi clock enable
  .resp_data_o    (resp_data_w),    //  response data bus                         
  .resp_valid_o   (resp_valid_w),   //  response valid                                  
  .mi_i           (mi_i));          //  SPI master input                     

/////////////////////////////////////////////////////////////////////////
// CORE LOGIC
///////////////////////////////////////////////////////////////////////// 


  always_comb begin
    if (~rstn_i) begin
      resp_data_d = resp_data_q;
    end
    else begin
      resp_data_d[bytecount_q] = resp_data_w;
    end
  end

  always_ff @(posedge req_valid_i) req_address_q <= req_address_i;

  always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
      ready_o <= 1;
    else begin
      if (req_valid_i)
        ready_o <= 0;
      else if (resp_valid_o)
        ready_o <= 1;
    end
  end

  always_ff @(posedge resp_valid_w, posedge req_valid_i) begin
    if (req_valid_i)
      bytecount_q = 0;
    else 
      bytecount_q = bytecount_d;
  end
  logic resp_val_set;
  always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
      resp_data_q = 0; 
      resp_valid_o = 0;
      resp_val_set = 0;
    end else begin
      resp_data_q = resp_data_d;
      if (resp_val_set) begin
        resp_valid_o = 0;
        if (req_valid_i)
          resp_val_set = 0;
      end else if (bytecount_q == 4) begin
        resp_valid_o = 1;
        resp_val_set = 1;
      end
    end
  end


  assign bytecount_d = bytecount_q + 1;
  assign resp_data_o = resp_data_q;
  assign cs_n_o = ~cs;
	
endmodule
