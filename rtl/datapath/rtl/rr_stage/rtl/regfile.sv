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

module regfile 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   logic                                 clk_i,
    input   logic                                 rstn_i,
    // write port input
    input   logic   [NUM_SCALAR_WB-1:0] write_enable_i,
    input   phreg_t [NUM_SCALAR_WB-1:0] write_addr_i,
    input   bus64_t [NUM_SCALAR_WB-1:0] write_data_i,

    // read ports input
    input   phreg_t                               read_addr1_i,
    input   phreg_t                               read_addr2_i,
    // read port output
    output  bus64_t                               read_data1_o,
    output  bus64_t                               read_data2_o

); 
// reg 0 should be 0 why waste 1 register for this...
reg64_t registers [NUM_PHISICAL_REGISTERS-1:1];
bus64_t bypass_data1;
bus64_t bypass_data2;
logic   bypass1;
logic   bypass2;

// these assigns select data of register at position x 
// if x = 0 then return 0

always_comb begin
    bypass_data1 = 64'b0;
    bypass_data2 = 64'b0;
    bypass1 = 1'b0;
    bypass2 = 1'b0;

    for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
        if ((write_addr_i[i] == read_addr1_i) && write_enable_i[i]) begin
            bypass_data1 |= write_data_i[i];
            bypass1      |= 1'b1;
        end

        if ((write_addr_i[i] == read_addr2_i) && write_enable_i[i]) begin
            bypass_data2 |= write_data_i[i];
            bypass2      |= 1'b1;
        end
    end

    if (read_addr1_i == 0) begin
        read_data1_o = 64'b0;
    end else if (bypass1) begin
        read_data1_o = bypass_data1;
    end else begin
        read_data1_o = registers[read_addr1_i];
    end

    if (read_addr2_i == 0) begin
        read_data2_o = 64'b0;
    end else if (bypass2) begin
        read_data2_o = bypass_data2;
    end else begin
        read_data2_o = registers[read_addr2_i];
    end
end

always_ff @(posedge clk_i)  begin
    if (~rstn_i) begin
        for (int i = 0; i<NUM_PHISICAL_REGISTERS-1 ; ++i) begin
            registers[i] <= '0;
        end
    end else begin
        for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
            if (write_enable_i[i] && (write_addr_i[i] > 0)) begin
                registers[write_addr_i[i]] <= write_data_i[i];
            end
        end
    end
end

endmodule
