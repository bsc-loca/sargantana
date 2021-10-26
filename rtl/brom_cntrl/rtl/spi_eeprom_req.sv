/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : spi_eeprom_req.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Jordi Garcia
 * Email(s)       : jordi.garcia@bsc.es
  -----------------------------------------------
 */

module spi_eeprom_req (
 	input	logic		        clk_i,             //   serial data clock
	input logic		        rstn_i,            //   reset
	input	logic	 [7:0]    req_opcode_i,      //   request opcode 
	input logic  [23:0]   req_address_i,     //   request address, for read and writes 
	input logic  [7:0]    req_data_i,        //   request data 
	input logic  [8:0]    req_bytes_i,       //   request data size in bytes - max 256
	input logic           req_valid_i,       //   request inputs valid state                            
	output logic          mo_o,              //   SPI master output 
	output logic          ready_o,           //   eeprom ready 
	output logic          sclk_o,            //   spi clock - mode 0                         
	output logic          sclk_en_o,         //   spi clock - mode 0                         
	output logic [7:0]    resp_data_o,       //   response data bus                              
	output logic          resp_valid_o,      //   response valid 
	input  logic          mi_i);             //   SPI master input 
	

/////////////////////////////////////////////////////////////////////////
// DECLARATIONS
///////////////////////////////////////////////////////////////////////// 
	
//	localparam STATE_IDLE = 0;
//	localparam STATE_T_OP = 1;
//	localparam STATE_T_AREAD = 2;
//	localparam STATE_R_DREAD = 3;
//	localparam STATE_T_AWRITE = 4;
//	localparam STATE_T_DWRITE = 5;
  localparam CLK_DIV_FACTOR = 16;

  typedef enum logic [2:0] {STATE_IDLE, STATE_T_OP, STATE_T_AREAD, STATE_R_DREAD, STATE_T_AWRITE, STATE_T_DWRITE} e_state;
	
  e_state state;// = STATE_IDLE;
  e_state next_state;// = STATE_IDLE;
	logic [8:0] cnt_tbyte;          // bytes to transmit (write op - max 256)
	logic [8:0] cnt_rbyte;          // bytes expected to read
	logic [8:0] cnt_abyte;          // adress bytes
	logic [7:0] req_opcode_q;
	logic [23:0] req_address_q;
	logic [8:0] req_bytes_q;
	logic [7:0] req_data_q;
	logic [1:0] clk_phs;
	logic [2:0] bitcount_q; 
	logic [2:0] bitcount_d; 
	logic [8:0] bytecount_q; 
	logic [8:0] bytecount_d; 
	logic       resp_valid_d;
	logic       resp_valid_q;
	logic [7:0] resp_data_d; 
	logic [7:0] resp_data_q; 
  logic [7:0] clk_div_cnt;
  logic clk;

	logic rx_finish;                // end of recieve
	logic tx_finish;                // end of data transmition
	logic tx_addr_finish;           // end of address transmition


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


/////////////////////////////////////////////////////////////////////////
// STATE MACHINE LOGIC
///////////////////////////////////////////////////////////////////////// 
	
	/* next state logic */

	always_ff @(posedge clk_i, negedge rstn_i) begin
	//always @(*) begin
    if (~rstn_i) begin
      next_state = STATE_IDLE;
    end else begin
      //next_state = next_state;
			case (state)
				STATE_IDLE: begin
          if (ready_o && req_valid_i) begin
						next_state = STATE_T_OP;
          end
				end
				STATE_T_OP: begin
					if (bitcount_q == 7)   // opcode transmitted
					begin
						case (req_opcode_q)
							`OP_READ : next_state = STATE_T_AREAD;
							`OP_WRITE : next_state = STATE_T_AWRITE;
							default: next_state = STATE_IDLE;
						endcase
					end
				end
				STATE_T_AREAD: begin
					if (tx_addr_finish)
						next_state = STATE_R_DREAD;
				end
				STATE_R_DREAD: begin
					if (rx_finish)
						next_state = STATE_IDLE;
				end
				STATE_T_AWRITE: begin
					if (tx_addr_finish )
						next_state = STATE_T_DWRITE;
				end
				STATE_T_DWRITE: begin
					if (tx_finish)
						next_state = STATE_IDLE;
				end
				default : next_state = STATE_IDLE;	
			endcase
    end
	end

	
	/* state output logic */
	always @(*) begin
		case (state)
			STATE_IDLE: begin
				cnt_abyte = 0;
				cnt_rbyte = 0;
				cnt_tbyte = 0;
				sclk_en_o = 0;
				mo_o = 0;
				//ready_o = (next_state == STATE_IDLE)? 1:0;
				//resp_valid_o <= resp_valid_d;
				resp_valid_d = 0;
        resp_data_d = 0;
			end
			STATE_T_OP: begin
				//resp_valid_o <= 0;
				sclk_en_o = 1;
				mo_o = req_opcode_q[7-bitcount_q];
				//ready_o = 0;
				resp_valid_d = 0;
				resp_data_d = 0;
				case (req_opcode_q)
					`OP_WREN,
					`OP_SRST: begin
						cnt_tbyte = 0;
						cnt_abyte = 0;
						cnt_rbyte = 0;
					end
					`OP_READ: begin
						cnt_tbyte = 0;
						cnt_abyte = 3;
						cnt_rbyte = req_bytes_q;
					end
					`OP_WRITE: begin
						cnt_tbyte = req_bytes_q;
						cnt_abyte = 3;
						cnt_rbyte = 0;
					end
          default: ;
				endcase
			end
			STATE_T_AWRITE,
			STATE_T_AREAD: begin
				//ready_o = 0;
				sclk_en_o = 1;
				mo_o = req_address_q[23-({6'b0,bitcount_q} + 8*bytecount_q)];
			end
			STATE_R_DREAD: begin
				sclk_en_o = 1;
				mo_o = 1'bz;
				//ready_o = 0;
				resp_data_d[7-bitcount_q] = mi_i;
				if (bitcount_q == 7)
					resp_valid_d = 1;
				else if (bitcount_q == 0)
					resp_valid_d = 0;
			end
			STATE_T_DWRITE: begin
				sclk_en_o = 1;
				mo_o = req_data_q[7-bitcount_q];
				//ready_o = 0;
			end
      default: ;
		endcase
	end

	/* state logic */
	always_ff @(posedge clk, negedge rstn_i) begin
    if(~rstn_i) begin
      resp_valid_q <= 0;
      resp_data_q <= 0;
			state <= STATE_IDLE;
			bytecount_q <= 0;
		  bytecount_q <= 0;
			bitcount_q <= 0;	
    end
		else begin
      resp_valid_q <= resp_valid_d;
      resp_data_q <= resp_data_d;
      if (state == STATE_IDLE) begin
        req_opcode_q <= req_opcode_i;
        req_data_q <= req_data_i;
        req_address_q <= req_address_i;
        req_bytes_q <= req_bytes_i;
      end
			if (next_state != state) begin
				bytecount_q <= 0;
				bytecount_q <= 0;
				bitcount_q <= 0;	
			end
			else begin
				if (bitcount_q == 7)
					bytecount_q <= bytecount_d;
				bitcount_q <= bitcount_d;
			end
			state <= next_state;
		end
  end

/////////////////////////////////////////////////////////////////////////
// Ready logic
///////////////////////////////////////////////////////////////////////// 
  always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
      ready_o <= 1;
    else begin
      if (req_valid_i)
        ready_o <= 0;
      if (resp_valid_q)
        ready_o <= 1;
    end
  end

/////////////////////////////////////////////////////////////////////////
// Clock divider 
///////////////////////////////////////////////////////////////////////// 
  always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin 
      clk_div_cnt <= '0;
      clk <= '0;
    end else begin
      clk_div_cnt <= clk_div_cnt + 1;
      if (clk_div_cnt == 2*CLK_DIV_FACTOR-1) begin
        clk_div_cnt <= '0;
        clk <= ~clk;
      end
    end
  end
/////////////////////////////////////////////////////////////////////////
// Phased clock (180)
///////////////////////////////////////////////////////////////////////// 
logic [1:0] clk_cnt1;
logic [1:0] clk_cnt2;
	always_ff @(posedge clk, negedge rstn_i) begin
		if (~rstn_i) 
      clk_cnt1 <= 2'b0;
		else begin
			clk_cnt1 <= 2'(clk_cnt1 + 2'b1);
		end
	end
	
		always_ff @(negedge clk, negedge rstn_i) begin
		if (~rstn_i) 
      clk_cnt2 <= 2'b0;
		else begin
			clk_cnt2 <= 2'(clk_cnt2 + 2'b1);
		end
	end


  assign clk_phs = clk_cnt1 + clk_cnt2;

/////////////////////////////////////////////////////////////////////////
// Assignments
///////////////////////////////////////////////////////////////////////// 
	
	assign rx_finish = (bytecount_d == cnt_rbyte && bitcount_q == 7); 
	assign tx_finish = (bytecount_d == cnt_tbyte && bitcount_q == 7); 
	assign tx_addr_finish = (bytecount_d == cnt_abyte && bitcount_q == 7);
	assign sclk_o = (sclk_en_o)? ~clk_phs[0]: 0;
  assign resp_valid_o = resp_valid_q;
  assign resp_data_o = resp_data_q;
	assign bitcount_d = bitcount_q + 1;
	assign bytecount_d = bytecount_q + 1;

endmodule
