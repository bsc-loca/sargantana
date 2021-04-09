/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vcomp.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gerard.candon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Gerard C. | 
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

module vcomp (
    input instr_type_t          instr_type_i,
    input sew_t                 sew_i,
    input bus64_t               data_vs1_i,
    input bus64_t               data_vs2_i,
    output bus64_t              data_vd_o
);

logic is_signed;
logic is_max;
logic is_min;
logic is_seq;
logic [7:0] is_greater;
logic [7:0] is_equal;
bus64_t data_a, data_b;

assign is_signed = instr_type_i == VMAX || instr_type_i == VMIN ? 1'b1 : 1'b0;
assign is_max = instr_type_i == VMAX || instr_type_i == VMAXU ? 1'b1 : 1'b0;
assign is_min = instr_type_i == VMIN || instr_type_i == VMINU ? 1'b1 : 1'b0;
assign is_seq = instr_type_i == VMSEQ || instr_type_i == VCNT ? 1'b1 : 1'b0;

always_comb begin
    for (int i = 0; i<8; ++i) begin
        is_greater[i] = $signed({is_signed & data_vs1_i[(i*8)+7], data_vs1_i[(i*8)+:8]}) >
                        $signed({is_signed & data_vs2_i[(i*8)+7], data_vs2_i[(i*8)+:8]});
        is_equal[i] = data_vs1_i[(i*8)+:8] == data_vs2_i[(i*8)+:8];
    end

    if (is_max) begin
        data_a = data_vs1_i;
        data_b = data_vs2_i;
    end else begin
        data_a = data_vs2_i;
        data_b = data_vs1_i;
    end

    case (sew_i)
        SEW_8: begin
            for (int i = 0; i<8; ++i) begin
                if (is_seq) begin
                    data_vd_o[(i*8)+:8] = {7'b0, is_equal[i]};
                end else if (is_greater[i]) begin
                    data_vd_o[(i*8)+:8] = data_a[(i*8)+:8];
                end else begin
                    data_vd_o[(i*8)+:8] = data_b[(i*8)+:8];
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i<4; ++i) begin
                if (is_seq) begin
                    data_vd_o[(i*16)+:16] = {15'b0, &(is_equal[(2*i)+:2])};
                end else if (is_greater[(2*i)+1] |
                            (is_equal[(2*i)+1] & is_greater[2*i])) begin
                    data_vd_o[(i*16)+:16] = data_a[(i*16)+:16];
                end else begin
                    data_vd_o[(i*16)+:16] = data_b[(i*16)+:16];
                end
            end
        end
        SEW_32: begin
            for (int i = 0; i<2; ++i) begin
                if (is_seq) begin
                    data_vd_o[(i*32)+:32] = {31'b0, &(is_equal[(4*i)+:4])};
                end else if (is_greater[(4*i)+3] |
                            (is_equal[(4*i)+3] & (is_greater[(4*i)+2] |
                            (is_equal[(4*i)+2] & (is_greater[(4*i)+1] |
                            (is_equal[(4*i)+1] & (is_greater[4*i]))))))) begin
                    data_vd_o[(i*32)+:32] = data_a[(i*32)+:32];
                end else begin
                    data_vd_o[(i*32)+:32] = data_b[(i*32)+:32];
                end
            end
        end
        SEW_64: begin
            if (is_seq) begin
               data_vd_o = {63'b0, &(is_equal)};
            end else if (is_greater[7] |
               (is_equal[7] & (is_greater[6] |
               (is_equal[6] & (is_greater[5] |
               (is_equal[5] & (is_greater[4] |
               (is_equal[4] & (is_greater[3] |
               (is_equal[3] & (is_greater[2] |
               (is_equal[2] & (is_greater[1] |
               (is_equal[1] & (is_greater[0]))))))))))))))) begin
                data_vd_o = data_a;
            end else begin
                data_vd_o = data_b;
            end
        end 
    endcase
end
endmodule
