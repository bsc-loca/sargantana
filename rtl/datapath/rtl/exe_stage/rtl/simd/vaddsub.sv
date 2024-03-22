/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vaddsub.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gerard.candon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Gerard C. | 
 * -----------------------------------------------
 */

module vaddsub 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus64_t               data_vs1_i,     // 64-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    input logic[7:0]            data_vm,        // 64-bit mask
    input logic                 use_mask,        //
    output bus64_t              data_vd_o       // 64-bit result
);

//This module performs vector addition and subtraction. The strategy is to use
//the minimum number of adders while supporting 8, 16, 32 and 64 bit element
//widths.

logic [7:0] carry_in;
logic [7:0] carry_out;
bus64_t data_vs1;
bus64_t data_vs2;
logic [7:0][7:0] data_a;  // byte source vs2
logic [7:0][7:0] data_b;  // byte source vs1
logic [7:0][8:0] result;  // byte + carry_out partial results


logic is_sub;
logic is_rsub;
logic is_vadc;
logic is_vsbc;
logic is_subtraction;
logic is_vmadc;
logic is_vmsbc;

assign is_sub = ((instr_type_i == VSUB) || (instr_type_i == VNMSUB) || (instr_type_i == VNMSAC)) ? 1'b1 : 1'b0;
assign is_rsub = ((instr_type_i == VRSUB)) ? 1'b1 : 1'b0;
assign is_vadc = ((instr_type_i == VADC)) ? 1'b1 : 1'b0;
assign is_vsbc = ((instr_type_i == VSBC)) ? 1'b1 : 1'b0;
assign is_vmadc = ((instr_type_i == VMADC)) ? 1'b1 : 1'b0;
assign is_vmsbc = ((instr_type_i == VMSBC)) ? 1'b1 : 1'b0;

assign is_subtraction = (is_sub || is_rsub || is_vsbc || is_vmsbc);

always_comb begin
    //If a subtraction is performed, the operand is flipped and a 1'b1 is
    //selected as carry_in (vs2 - vs1 = vs2 + (-vs1))
    if (is_sub || (is_vsbc && use_mask)) begin
        data_vs1 = ~data_vs1_i;
        data_vs2 = data_vs2_i;
        carry_in[0] = 1'b1;
    end else if ((is_vmsbc && ~use_mask)) begin //if VMSBC not use a mask then is a normal sub
        data_vs1 = data_vs1_i;
        data_vs2 = data_vs2_i;
        carry_in[0] = 1'b1; 
    end else if (is_rsub) begin
        data_vs2 = ~data_vs2_i;
        data_vs1 = data_vs1_i;
        carry_in[0] = 1'b1;
    end else if ((is_vsbc && ~use_mask) || (is_vmsbc && use_mask)) begin //if VMSBC uses a mask then priusly to flip the bit I add carry
        if (sew_i == SEW_64) begin
            data_vs1 = ~(data_vs1_i + {{63{1'b0}}, data_vm[0]});
        end else if (sew_i == SEW_32) begin
            data_vs1 = ~({data_vs1_i[63:32] + {{31{1'b0}}, data_vm[1]},
                          data_vs1_i[31:0] + {{31{1'b0}}, data_vm[0]}}
                        );
        end else if (sew_i == SEW_16) begin
            data_vs1 = ~({data_vs1_i[63:48] + {{15{1'b0}}, data_vm[3]},
                          data_vs1_i[47:32] + {{15{1'b0}}, data_vm[2]},
                          data_vs1_i[31:16] + {{15{1'b0}}, data_vm[1]},
                          data_vs1_i[15:0] +  {{15{1'b0}}, data_vm[0]}}
                          );

        end else begin //sew_8
            data_vs1 = ~({data_vs1_i[63:56] + {{7{1'b0}}, data_vm[7]},
                          data_vs1_i[55:48] + {{7{1'b0}}, data_vm[6]},
                          data_vs1_i[47:40] + {{7{1'b0}}, data_vm[5]},
                          data_vs1_i[39:32] + {{7{1'b0}}, data_vm[4]},
                          data_vs1_i[31:24] + {{7{1'b0}}, data_vm[3]},
                          data_vs1_i[23:16] + {{7{1'b0}}, data_vm[2]},
                          data_vs1_i[15:8] +  {{7{1'b0}}, data_vm[1]},
                          data_vs1_i[7:0] +   {{7{1'b0}}, data_vm[0]}}
                        );            
        end
        data_vs2 = data_vs2_i;
        carry_in[0] = 1'b1;
    end else begin
        data_vs1 = data_vs1_i;
        data_vs2 = data_vs2_i;
        if ((is_vadc && ~use_mask) || (is_vmadc && ~use_mask)) begin //if VMADC then we cake the carry of the mask
            carry_in[0] = data_vm[0];
        end else begin 
            carry_in[0] = 1'b0;
        end
    end

    //The source operands are split into byte arrays
    for (int i = 0; i<8; ++i) begin
        data_a[i] = data_vs2[(8*i)+:8];
        data_b[i] = data_vs1[(8*i)+:8];
    end
end

//Partial sums, byte-adders
assign result[0] = data_a[0] + data_b[0] + carry_in[0];
assign result[1] = data_a[1] + data_b[1] + carry_in[1];
assign result[2] = data_a[2] + data_b[2] + carry_in[2];
assign result[3] = data_a[3] + data_b[3] + carry_in[3];
assign result[4] = data_a[4] + data_b[4] + carry_in[4];
assign result[5] = data_a[5] + data_b[5] + carry_in[5];
assign result[6] = data_a[6] + data_b[6] + carry_in[6];
assign result[7] = data_a[7] + data_b[7] + carry_in[7];

//Carry out of each byte-adder
assign carry_out[0] = result[0][8];
assign carry_out[1] = result[1][8];
assign carry_out[2] = result[2][8];
assign carry_out[3] = result[3][8];
assign carry_out[4] = result[4][8];
assign carry_out[5] = result[5][8];
assign carry_out[6] = result[6][8];
assign carry_out[7] = result[7][8];

//If it is VMADC then I return the corresponding carry for the sews.
//if VMSBC then I check if the operation will generate a negative number to return the carry.
//else I return the normal value
assign data_vd_o[7:0]   = (is_vmadc)  ? (sew_i == SEW_64) ? {{7{1'b1}}, result[7][8]} : 
                                                    (sew_i == SEW_32) ? {{6{1'b1}}, result[7][8], result[3][8]} :
                                                    (sew_i == SEW_16) ? {{4{1'b1}}, result[7][8], result[5][8], result[3][8], result[1][8]} :
                                                    {result[7][8], result[6][8], result[5][8], result[4][8], result[3][8], result[2][8],
                                                     result[1][8], result[0][8]} //sew_8
                        :  (is_vmsbc) ? 
                                                    (sew_i == SEW_64) ? {{7{1'b1}}, (data_vs1 > data_vs2)} :
                                                    (sew_i == SEW_32) ? {{6{1'b1}}, (data_vs1[63:32] > data_vs2[63:32]), (data_vs1[31:0] > data_vs2[31:0])} :
                                                    (sew_i == SEW_16) ? {{4{1'b1}}, (data_vs1[63:48] > data_vs2[63:48]), (data_vs1[47:32] > data_vs2[47:32]),
                                                                                            (data_vs1[31:16] > data_vs2[31:16]), (data_vs1[15:0] > data_vs2[15:0])} :
                                                    {(data_vs1[63:56] > data_vs2[63:56]), (data_vs1[55:48] > data_vs2[55:48]), (data_vs1[47:40] > data_vs2[47:40]),
                                                    (data_vs1[39:32] > data_vs2[39:32]), (data_vs1[31:24] > data_vs2[31:24]), (data_vs1[23:16] > data_vs2[23:16]),
                                                    (data_vs1[15:8] > data_vs2[15:8]), (data_vs1[7:0] > data_vs2[7:0])} //sew_8
                                                    : result[0][7:0];
assign data_vd_o[15:8]  = (is_vmadc || is_vmsbc) ? {8{1'b1}} : result[1][7:0];
assign data_vd_o[23:16] = (is_vmadc || is_vmsbc) ? {8{1'b1}} : result[2][7:0];
assign data_vd_o[31:24] = (is_vmadc || is_vmsbc) ? {8{1'b1}} : result[3][7:0];
assign data_vd_o[39:32] = (is_vmadc || is_vmsbc) ? {8{1'b1}} : result[4][7:0];
assign data_vd_o[47:40] = (is_vmadc || is_vmsbc) ? {8{1'b1}} : result[5][7:0];
assign data_vd_o[55:48] = (is_vmadc || is_vmsbc) ? {8{1'b1}} : result[6][7:0];
assign data_vd_o[63:56] = (is_vmadc || is_vmsbc) ? {8{1'b1}} : result[7][7:0];

//64-bit wide result


//Depending on the element width, each byte-adder selects it's carry_in
// - In case the previous sum is computing the same element, the carry_out of
//   the previous sum is selected
// - Otherwise, if the operation is a sub, a 1'b1 is selected
// - Otherwise, if the operation is vadc, then data_vm[x] is selected 
// - Otherwise, 1'b0 is selected
assign carry_in[1] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[0] : (is_subtraction) ? 1'b1 : (is_vadc || (is_vmadc && ~use_mask)) ?
                        data_vm[1]: 1'b0;
assign carry_in[2] = ((sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[1] : (is_subtraction) ? 1'b1 : (is_vadc || (is_vmadc && ~use_mask)) ?
                        data_vm[2]: 1'b0;
assign carry_in[3] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[2] : (is_subtraction) ? 1'b1 : (is_vadc || (is_vmadc && ~use_mask)) ?
                        data_vm[3]: 1'b0;
assign carry_in[4] = ((sew_i == SEW_64)) ? 
                        carry_out[3] : (is_subtraction) ? 1'b1 : (is_vadc || (is_vmadc && ~use_mask)) ?
                        data_vm[4]: 1'b0;
assign carry_in[5] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ?
                        carry_out[4] : (is_subtraction) ? 1'b1 : (is_vadc || (is_vmadc && ~use_mask)) ?
                        data_vm[5]: 1'b0;
assign carry_in[6] = ((sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[5] : (is_subtraction) ? 1'b1 : (is_vadc || (is_vmadc && ~use_mask)) ?
                        data_vm[6]: 1'b0;
assign carry_in[7] = ((sew_i == SEW_16) || (sew_i == SEW_32) || (sew_i == SEW_64)) ? 
                        carry_out[6] : (is_subtraction) ? 1'b1 : (is_vadc || (is_vmadc && ~use_mask)) ?
                        data_vm[7]: 1'b0;
endmodule
