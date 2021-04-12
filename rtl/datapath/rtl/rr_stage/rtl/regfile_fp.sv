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
*  0.3        | Guillem.LP |        | Add one extra port 
* -----------------------------------------------
*/

//`default_nettype none
import drac_pkg::*;
import riscv_pkg::*;


module regfile_fp (
    input   logic                                 clk_i,
    input   logic                                 rstn_i,
    // write port input
    input   logic   [drac_pkg::NUM_FP_WB-1:0]     write_enable_i,
    input   phreg_t [drac_pkg::NUM_FP_WB-1:0]     write_addr_i,
    input   bus64_t [drac_pkg::NUM_FP_WB-1:0]     write_data_i,

    // read ports input
    input   phreg_t                               read_addr1_i,
    input   phreg_t                               read_addr2_i,
    input   phreg_t                               read_addr3_i,
    // read port output
    output  bus64_t                               read_data1_o,
    output  bus64_t                               read_data2_o,
    output  bus64_t                               read_data3_o

); 
// reg 0 should be 0 why waste 1 register for this...
reg64_t registers [0:NUM_FP_PHISICAL_REGISTERS-1];
bus64_t bypass_data1;
bus64_t bypass_data2;
bus64_t bypass_data3;
logic   [drac_pkg::NUM_FP_WB-1:0] bypass1;
logic   [drac_pkg::NUM_FP_WB-1:0] bypass2;
logic   [drac_pkg::NUM_FP_WB-1:0] bypass3;

// these assigns select data of register at position x 
// if x = 0 then return 0

always_comb begin
    bypass_data1 = 64'b0;
    bypass_data2 = 64'b0;
    bypass_data3 = 64'b0;

    for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
        if (write_addr_i[i] == read_addr1_i && write_enable_i[i]) begin
            bypass_data1 |= write_data_i[i];
            bypass1[i]    = 1'b1;
        end else begin
            bypass_data1 |= 64'b0;
            bypass1[i]    = 1'b0;
        end

        if (write_addr_i[i] == read_addr2_i && write_enable_i[i]) begin
            bypass_data2 |= write_data_i[i];
            bypass2[i]    = 1'b1;
        end else begin
            bypass_data2 |= 64'b0;
            bypass2[i]    = 1'b0;
        end

        if (write_addr_i[i] == read_addr3_i && write_enable_i[i]) begin
            bypass_data3 |= write_data_i[i];
            bypass3[i]    = 1'b1;
        end else begin
            bypass_data3 |= 64'b0;
            bypass3[i]    = 1'b0;
        end
    end

    if (|bypass1) begin
        read_data1_o = bypass_data1;
    end else begin
        read_data1_o = registers[read_addr1_i];
    end

    if (|bypass2) begin
        read_data2_o = bypass_data2;
    end else begin
        read_data2_o = registers[read_addr2_i];
    end

    if (|bypass3) begin
        read_data3_o = bypass_data3;
    end else begin
        read_data3_o = registers[read_addr3_i];
    end
end

always_ff @(posedge clk_i)  begin
    if (~rstn_i) begin
        registers[0] <= 64'h00;
        registers[1] <= 64'h01;
        registers[2] <= 64'h02;
    end else begin
        for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
            if (write_enable_i[i]) begin
                registers[write_addr_i[i]] <= write_data_i[i];
            end
        end
    end
end

endmodule
