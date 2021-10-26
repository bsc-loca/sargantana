`timescale 1 ns/1 ps
`include "testconsts.vh"
module tb_spi_eeprom_req;

	reg		         clk;          // serial data clock                                      
	reg            reset;        // reset
	reg		[7:0]    req_opcode;   // request opcode 
	reg   [23:0]   req_address;  // request address, for read and writes 
	reg   [7:0]    req_data;     // request data 
	reg   [8:0]    req_bytes;    // request data size in bytes - max 256
	reg           req_valid;    // request inputs valid state                            
	wire					spi_clk_en;
	reg						cs_n;
	wire           mo;           // SPI master output 
	wire           ready;        // eeprom ready 
	wire           spi_clk;      // spi clock - mode 0                         
	wire  [7:0]    resp_data;    // response data bus                              
	wire           resp_valid;   // response valid 
	wire            mi;           // SPI master input 

  reg  [07:00]         test_mem [0:524287];         // EEPROM data memory array (524288x8)
  logic [15:0] tcount;
	
  /* 25CSM04 EEPROM opcodes */
	`define RDSR            8'b0000_0101                    // Read Status Register instruction
	`define WRBP            8'b0000_1000                    // Write Ready/Busy Poll instruction
	`define WREN            8'b0000_0110                    // Set Write Enable Latch instruction
	`define WRDI            8'b0000_0100                    // Reset Write Enable Latch instruction
	`define WRSR            8'b0000_0001                    // Write Status Register instruction
	`define READ            8'b0000_0011                    // Read EEPROM Array instruction
	`define WRITE           8'b0000_0010                    // Write EEPROM Array instruction
	`define RDEX            8'b1000_0011                    // Read Security Register instruction
	`define WREX            8'b1000_0010                    // Write Security Register instruction
	`define LOCK            8'b1000_0010                    // Lock Security Register instruction
	`define CHLK            8'b1000_0011                    // Check Security Register Lock Status instruction
	`define RMPR            8'b0011_0001                    // Read Memory Partition Registers instruction
	`define PRWE            8'b0000_0111                    // Set MPR Write Enable Latch instruction
	`define PRWD            8'b0000_1010                    // Reset MPR Write Enable Latch instruction
	`define WMPR            8'b0011_0010                    // Write Memory Partition Registers instruction
	`define PPAB            8'b0011_0100                    // Protect Partition Address Boundaries instruction
	`define FRZR            8'b0011_0111                    // Freeze Memory Protection Configuration instruction
	`define SPID            8'b1001_1111                    // Read Manufacturer ID instruction
	`define SRST            8'b0111_1100                    // Software Device Reset instruction

	spi_eeprom_req ser0 (.clk_i (clk), .rstn_i (~reset), .req_opcode_i (req_opcode), .req_address_i (req_address), .req_data_i (req_data), .req_bytes_i (req_bytes), .req_valid_i (req_valid), .mo_o (mo), .ready_o (ready), .sclk_o (spi_clk), .sclk_en_o (spi_clk_en), .resp_data_o (resp_data), .resp_valid_o (resp_valid), .mi_i (mi));

	M25CSM04 mem0 (.CS_N (cs_n), .SO (mi), .WP_N (1'h1), .SI (mo), .SCK (spi_clk), .HOLD_N (1'h1), .RESET(reset));

	always #20 clk = ~clk;

	initial begin
    $display("TEST CONFIGURATION: (you can change this in testconsts.vh file)");
    $display("Number of random tests: %d",`N_TESTS);
    $display("Minimum addr range: %d",`ADDR_MIN);
    $display("Maximum addr range: %d",`ADDR_MAX);
    $display("\n\n");
    tcount = 0;
		clk = 1;
		reset = 1;
		//cs_n = 1;
		req_valid = 0;
		req_opcode = `WREN;
		req_address = 24'h0;
    req_data = 8'h0;
    req_bytes = 9'h0;
    $readmemh("bootrom_content.hex", test_mem);
		$dumpfile("eeprom_req_tb.vcd");
		$dumpvars(0, tb_spi_eeprom_req);
    #120
    reset = 0;
	end

  task check_read;
    input [24:0] addr;
    begin
      wait(resp_valid);
      if(resp_data === test_mem[addr]) begin
        $display("TEST[%d] addr %d: OK", tcount, addr);
      end else begin
        $display("TEST[%d] addr %d: FAIL\nread: %h, expected: %h", tcount, addr, resp_data, test_mem[addr]);
        $stop;
      end
    end
  endtask
  
  task do_read;
    input [23:0] addr;
    begin
      req_opcode = `READ;
      req_address = addr;
      req_bytes = 9'h1;
      wait(ready)
      req_valid = 1;
      wait(~ready);
      req_valid = 0;
      check_read(addr);
    end
  endtask



	always @(posedge clk)
	begin
    tcount = tcount + 1;
    do_read($urandom_range(`ADDR_MIN, `ADDR_MAX));
    if (tcount == `N_TESTS) begin
      $display("All tests successfully passed! (max tests: %d)",`N_TESTS);
      $finish;
    end  
	end
	
	assign cs_n = ~spi_clk_en;
endmodule
