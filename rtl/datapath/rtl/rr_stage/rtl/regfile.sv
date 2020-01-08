/* -----------------------------------------------
* Project Name   : DRAC
* File           : regfile.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
*                  Victor Soria Pardos
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
*  0.2        | Victor.SP  |        | Add phisical 
*                                     registers.
* -----------------------------------------------
*/

//`default_nettype none
import drac_pkg::*;
import riscv_pkg::*;


module regfile (
    input   logic                   clk_i,
    // write port input
    input   logic                   write_enable_1_i,
    input   phreg_t                 write_addr_1_i,
    input   bus64_t                 write_data_1_i,

    input   logic                   write_enable_2_i,
    input   phreg_t                 write_addr_2_i,
    input   bus64_t                 write_data_2_i,

    // read ports input
    input   phreg_t                 read_addr1_i,
    input   phreg_t                 read_addr2_i,
    // read port output
    output  bus64_t                 read_data1_o,
    output  bus64_t                 read_data2_o

); 
// reg 0 should be 0 why waste 1 register for this...
reg64_t registers [1:NUM_PHISICAL_REGISTERS-1];

// these assigns select data of register at position x 
// if x = 0 then return 0
assign read_data1_o = (read_addr1_i == 0) ? 64'b0 : (write_addr_1_i == read_addr1_i && write_enable_1_i) ? write_data_1_i :
                      (write_addr_2_i == read_addr1_i && write_enable_2_i) ? write_data_2_i :registers[read_addr1_i];

assign read_data2_o = (read_addr2_i == 0) ? 64'b0 : (write_addr_1_i == read_addr2_i && write_enable_1_i) ? write_data_1_i : 
                      (write_addr_2_i == read_addr2_i && write_enable_2_i) ? write_data_2_i : registers[read_addr2_i];
//assign read_data2_o = (write_addr_i == read_addr2_i && write_enable_i) ? write_data_i : (read_addr2_i > 0) ? registers[read_addr2_i] : 64'b0; 

always_ff @(posedge clk_i)  begin
    if (write_enable_1_i && (write_addr_1_i > 0)) begin
        registers[write_addr_1_i] <= write_data_1_i;
    end
    if (write_enable_2_i && (write_addr_2_i > 0)) begin
        registers[write_addr_2_i] <= write_data_2_i;
    end
end

endmodule
