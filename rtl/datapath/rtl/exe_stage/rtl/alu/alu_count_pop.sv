
/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : alu_count_pop.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Raúl Gilabert Gámez
 * Email(s)       : raul.gilabert@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

module alu_count_pop
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input bus64_t data_rs1_i,
    output bus64_t result_o
);

logic[1:0] data_sum_0[31:0];
logic[2:0] data_sum_1[15:0];
logic[3:0] data_sum_2[7:0];
logic[4:0] data_sum_3[3:0];
logic[5:0] data_sum_4[1:0];

always_comb begin
    for (int i = 0; i < 32; ++i) begin
        data_sum_0[i] = data_rs1_i[2*i] + data_rs1_i[2*i + 1];
    end

    for (int i = 0; i < 16; ++i) begin
        data_sum_1[i] = data_sum_0[2*i] + data_sum_0[2*i + 1];
    end

    for (int i = 0; i < 8; ++i) begin
        data_sum_2[i] = data_sum_1[2*i] + data_sum_1[2*i + 1];
    end

    for (int i = 0; i < 4; ++i) begin
        data_sum_3[i] = data_sum_2[2*i] + data_sum_2[2*i + 1];
    end

    for (int i = 0; i < 2; ++i) begin
        data_sum_4[i] = data_sum_3[2*i] + data_sum_3[2*i + 1];
    end

    result_o = data_sum_4[0] + data_sum_4[1];
end

endmodule