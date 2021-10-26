`timescale 1 ns/1 ps
`include "testconsts.vh"
module tb_bootrom_ctrl;

	logic           clk;          // serial data clock                                      
	logic           reset;        // reset
	logic  [23:0]   req_address;  // request address, for read and writes 
	logic  [31:0]   req_data;     // request data 
	logic           req_valid;    // request inputs valid state                            
	logic					  cs_n;
	logic           mo;           // SPI master output 
	logic           ready;        // eeprom ready 
	logic           spi_clk;      // spi clock - mode 0                         
	logic  [31:0]   resp_data;    // response data bus        
	logic           resp_valid;   // response valid 
	logic           mi;           // SPI master input 

  reg  [07:00]    memory [0:524287];         // EEPROM data memory array (524288x8)
	logic  [31:0]   expected;   
  logic [15:0] tcount;
  logic vcount;
	
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

	bootrom_ctrl bd0 (.clk_i (clk),
                      .rstn_i (~reset),
                      .req_address_i (req_address),
                      .req_valid_i (req_valid),
                      .mo_o (mo), 
                      .ready_o (ready), 
                      .sclk_o (spi_clk), 
                      .cs_n_o (cs_n), 
                      .resp_data_o (resp_data), 
                      .resp_valid_o (resp_valid), 
                      .mi_i (mi));

	M25CSM04 mem0 (.CS_N (cs_n), .SO (mi), .WP_N (1'h1), .SI (mo), .SCK (spi_clk), .HOLD_N (1'h1), .RESET(reset));

	always #200 clk = ~clk;

  initial begin
    $display("TEST CONFIGURATION: (you can change this in testconsts.vh file)");
    $readmemh("bootrom_content.hex", memory);
    $display("Number of random tests: %d",N_TESTS);
    $display("Minimum addr range: %h",ADDR_MIN);
    $display("Maximum addr range: %h",ADDR_MAX);
    $display("\n\n");
		$dumpfile("dump.vcd");
		$dumpvars(0, tb_bootrom_ctrl);
    tcount = 0;
  end

	initial begin
		clk = 1;
		reset = 1;
		req_valid = 0;
		req_address = 24'b0;
		#600;
		reset = 0;
	end


  task do_check;
    begin
      wait(resp_valid);
      if (resp_data === expected) begin
        $display("TEST[%d] addr %h: OK", tcount, req_address);
       end else begin
         $display("TEST[%d] addr %h: FAIL\nread: %h, expected: %h", tcount, req_address, resp_data, expected);
        $stop;
      end
    end
  endtask

  task do_fetch;
    begin
      logic [23:0] tmp_addr;
      wait(ready);
      tmp_addr = $urandom_range(ADDR_MIN, ADDR_MAX);
      req_address = {tmp_addr[23:2], 2'h0};
      req_valid = 1;
      wait(~ready);
      req_valid = 0;
      do_check();
    end
  endtask


	always @(posedge clk, posedge reset)
	begin
    if (reset) begin
      tcount = 0;
    end else begin
      tcount = tcount + 1;
      do_fetch();
      if (tcount == N_TESTS) begin
        $display("All tests successfully passed! (max tests: %d)",N_TESTS);
        $finish;
      end  
    end
	end

	always @(posedge clk, posedge reset)
	begin
    if (reset | req_valid) begin
      vcount = 'b0;
    end else if (resp_valid) begin
      if (vcount) begin  
        $display("TEST[%d] addr %h: FAIL\nmultiple cycles valid", tcount, req_address);
        $stop;
      end else begin
        vcount = 'b1;
      end
    end
	end

  assign expected = {memory[req_address+3],memory[req_address+2],memory[req_address+1],memory[req_address]};
	
endmodule
