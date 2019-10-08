`include "LAGARTO_CONFIG.v"

module INT_REGISTER_FILE(
input  						CLK,
input 						lock,

input 						write_enable1,
input  			[4:0]		write_addr1,
input  			`WORD_DATA	write_data1,

input  			[4:0] 		read_addr1,
input  			[4:0] 		read_addr2,

output 	 	   `WORD_DATA	read_data1,
output 	 	   `WORD_DATA	read_data2

); 

BANK BANK_1(
.CLK            (CLK),
.lock           (lock),

.write_enable   (write_enable1),
.write_addr     (write_addr1),
.write_data     (write_data1),

.read_addr      (read_addr1),
.read_data      (read_data1)
); 

BANK BANK_2(
.CLK            (CLK),
.lock           (lock),

.write_enable   (write_enable1),
.write_addr     (write_addr1),
.write_data     (write_data1),

.read_addr      (read_addr2),
.read_data      (read_data2)
); 

endmodule


module BANK(
input  						CLK,
input 						lock,

input 						write_enable,
input  			[4:0]		write_addr,
input  			`WORD_DATA	write_data,

input  			[4:0] 		read_addr,
output `WORD_DATA read_data
); 


// Lógica de Bypass
wire `WORD_DATA aux_read_data;
reg `WORD_DATA aux_data;
wire [4:0] aux_read_addr;
reg addr_0;
reg same_address, same_address_aux;

always @(*) begin
  if ((write_addr == read_addr) && write_enable) begin
    same_address = 1'b1;
  end
  else
    same_address = 1'b0;
end

always @(posedge CLK) begin
  addr_0 <= (read_addr == 5'b0);
  same_address_aux <= same_address;
end

always @(posedge CLK) begin
  if (same_address)
     aux_data <= write_data;
end

assign aux_read_addr = same_address ? 5'h0 : read_addr;


`ifndef SRAM_MEMORIES
integer i;
//$readmemh ("REGISTER_INT.mem", BANK);
reg `WORD_DATA BANK[0:31];

`ifndef SYNTHESIS
initial
begin
for( i=0; i<32 ; i=i+1)
BANK[i] = 64'h0;
end
`endif

reg `WORD_DATA read_data_int;
always @(posedge CLK)
begin
	read_data_int <= BANK[aux_read_addr];
end

assign aux_read_data = read_data_int;

always@(posedge CLK) 
begin
if(write_enable)
    BANK[write_addr] <= write_data;
end
`else

// Port A: Write; Port B: Read
  TS6N65LPLLA32X64M2F RFArray (
    .AA  (write_addr) ,
    .D  (write_data) ,
    .BWEB  (64'b0) ,
    .WEB  (!write_enable) ,
    .CLKW  (CLK) ,
    .AB  (aux_read_addr) ,
    .REB  (1'b0) ,
    .CLKR  (CLK) ,
    .Q  (aux_read_data) 
    ); // QA output left unconnected
`endif

assign read_data =(addr_0) ? 64'b0 : (same_address_aux) ? aux_data : aux_read_data;

endmodule
