/* -----------------------------------------------
* Project Name   : DRAC
* File           : vredtree.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Xavier Carril
* Email(s)       : xavier.carril@bsc.es
* -----------------------------------------------
* Revision History
*  Revision   | Author    | Description
* -----------------------------------------------
*/

import drac_pkg::*;
import riscv_pkg::*;

module vredtree (
    input  logic clk_i,                         // Clock signal
    input  logic rstn_i,                        // Reset signal
    input  instr_type_t instr_type_i,           // Instruction type
    input  sew_t sew_i,                         // SEW: 00 for 8 bits, 01 for 16 bits, 10 for 32 bits, 11 for 64 bits
    input  logic [VMAXELEM_LOG:0] vl_i,         // Current vector lenght in elements
    input  bus_simd_t data_vs1_i,               // 128-bit from vs1
    input  bus_simd_t data_vs2_i,               // 128-bit source operand 
    input  bus_simd_t data_old_vd,              // Backup of previous vector destination value
    input  bus_mask_t data_vm_i,                // Vector mask of VLEN/8 size
    input  instr_type_t instr_to_out_i,         // Instruction to output
    input  logic [VMAXELEM_LOG:0] vl_to_out_i,  // Vector Lenght to output
    input  sew_t sew_to_out_i,                  // SEW indication for output 
    output bus_simd_t red_data_vd_o             // 128-bit result (only cares last element)
);

localparam int NUM_STAGES = $clog2(VLEN / 8) + 1;      // Number of stages based on the minimum SEW

function sew_t increase_sew_size(sew_t sew);
    case (sew)
        SEW_8: return SEW_16;
        SEW_16: return SEW_32;
        SEW_32: return SEW_64;
        default: return SEW_16;
    endcase
endfunction

function logic is_vw(input instr_type_t instr);
    is_vw = (instr inside {VWREDSUM, VWREDSUMU}) ? 1'b1 : 1'b0;
endfunction

function [7:0] trunc_8bits(input [8:0] val_in);
    trunc_8bits = val_in[7:0];
endfunction

function [15:0] trunc_16bits(input [16:0] val_in);
    trunc_16bits = val_in[15:0];
endfunction

function [31:0] trunc_32bits(input [32:0] val_in);
    trunc_32bits = val_in[31:0];
endfunction

function [63:0] trunc_64bits(input [64:0] val_in);
    trunc_64bits = val_in[63:0];
endfunction

// Intermediate vector declaration with a generate block
typedef struct packed {
    sew_t sew;
    bus_mask_t mask;
    instr_type_t instr_type;
    bus_simd_t data_vs1;
    logic [VMAXELEM_LOG:0] vl;
    logic [VLEN-1:0] intermediate;
} node_t;

node_t gen_intermediate_d [NUM_STAGES-1:0];
node_t gen_intermediate_q [NUM_STAGES-1:0];

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        for (int i = 0; i < NUM_STAGES; i++) begin 
            gen_intermediate_q[i] <= '0;
        end
    end else begin
        for (int i = 0; i < NUM_STAGES; i++) begin
            gen_intermediate_q[i] <= gen_intermediate_d[i];
        end
    end
end

// Vector Mask Managment for LMUL<1 cases
bus_mask_t data_vm;
always_comb begin
    for (int i = 0; i < $size(data_vm); i++) begin
        if (i < vl_i) begin
            data_vm[i] = data_vm_i[i];
        end else begin
            data_vm[i] = 1'b0;
        end
    end
end

always_comb begin
    for (int i = 0; i < NUM_STAGES; i++) begin 
        if (i == 0) begin
            gen_intermediate_d[0].sew = (is_vw(instr_type_i)) ? increase_sew_size(sew_i) : sew_i;
            gen_intermediate_d[0].mask = data_vm;
            gen_intermediate_d[0].instr_type = instr_type_i;
            gen_intermediate_d[0].intermediate = data_vs2_i;
            gen_intermediate_d[0].data_vs1 = data_vs1_i;
            gen_intermediate_d[0].vl = vl_i;
        end else begin
            gen_intermediate_d[i].mask = '0;
            gen_intermediate_d[i].intermediate = '0;
            for (int j = 0; j < (VLEN/16); j++) begin
                case (gen_intermediate_q[i-1].sew) 
                    SEW_8: begin
                        if (j < (gen_intermediate_q[i-1].vl >> i)) begin
                            if (!gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b0;
                                gen_intermediate_d[i].intermediate[(j*8) +: 8] = '0;
                            end else if (gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*8) +: 8] = gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8];
                            end else if (!gen_intermediate_q[i-1].mask[(j*2)] && gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*8) +: 8] = gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8];
                            end else begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                case (gen_intermediate_q[i-1].instr_type)
                                    VREDSUM: gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            trunc_8bits(gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8] + gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8]);
                                    VREDAND: gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            (gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8] & gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8]);
                                    VREDOR:  gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            (gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8] | gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8]);
                                    VREDXOR: gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            (gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8] ^ gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8]);
                                    VREDMAX: gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8] : gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8];
                                    VREDMAXU: gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8] : gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8];
                                    VREDMIN: gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8] : gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8];
                                    VREDMINU: gen_intermediate_d[i].intermediate[(j*8) +: 8] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8] : gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8];
                                    default: gen_intermediate_d[i].intermediate = '0;
                                endcase
                            end
                        end
                    end
                    SEW_16: begin
                        //if (((j*16) < (VLEN >> i)) || ((i==1) && (is_vw(gen_intermediate_q[i-1].instr_type)) && ((j*8) < (VLEN >> i)))) begin
                        if (j < (gen_intermediate_q[i-1].vl >> i)) begin
                            if (!gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b0;
                                gen_intermediate_d[i].intermediate[(j*16) +: 16] = '0;
                            end else if (gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*16) +: 16] = gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16];
                            end else if (!gen_intermediate_q[i-1].mask[(j*2)] && gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*16) +: 16] = gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16];
                            end else begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                case (gen_intermediate_q[i-1].instr_type)
                                    VREDSUM: gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                             trunc_16bits(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] + gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                    VREDAND: gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                            (gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] & gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                    VREDOR:  gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                            (gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] | gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                    VREDXOR: gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                            (gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] ^ gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                    VREDMAX: gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16] : gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16];
                                    VREDMAXU: gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16] : gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16];
                                    VREDMIN: gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] : gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16];
                                    VREDMINU: gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] : gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16];
                                    VWREDSUM: begin
                                        if (i == 1) begin
                                            gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                                $signed(gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8]) + $signed(gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8]);
                                        end else begin
                                            gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                                trunc_16bits(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] + gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                        end
                                    end
                                    VWREDSUMU: begin
                                        if (i == 1) begin
                                            gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                                $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*8) +: 8]) + $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*8) + 8 +: 8]);
                                        end else begin
                                            gen_intermediate_d[i].intermediate[(j*16) +: 16] = 
                                                trunc_16bits(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16] + gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                        end
                                    end
                                    default: gen_intermediate_d[i].intermediate = '0;
                                endcase
                            end
                        end
                    end
                    SEW_32: begin
                        if (j < (gen_intermediate_q[i-1].vl >> i)) begin
                            if (!gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b0;
                                gen_intermediate_d[i].intermediate[(j*32) +: 32] = '0;
                            end else if (gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*32) +: 32] = gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32];
                            end else if (!gen_intermediate_q[i-1].mask[(j*2)] && gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*32) +: 32] = gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32];
                            end else begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                case (gen_intermediate_q[i-1].instr_type)
                                    VREDSUM: gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                trunc_32bits(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] + gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                    VREDAND: gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                (gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] & gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                    VREDOR:  gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                (gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] | gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                    VREDXOR: gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                (gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] ^ gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                    VREDMAX: gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32] : gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32];
                                    VREDMAXU: gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32] : gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32];
                                    VREDMIN: gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] : gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32];
                                    VREDMINU: gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] : gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32];
                                    VWREDSUM: begin
                                        if (i == 1) begin
                                            gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                $signed(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16]) + $signed(gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                        end else begin
                                            gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                trunc_32bits(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] + gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                        end
                                    end
                                    VWREDSUMU: begin
                                        if (i == 1) begin
                                            gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*16) +: 16]) + $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*16) + 16 +: 16]);
                                        end else begin
                                            gen_intermediate_d[i].intermediate[(j*32) +: 32] = 
                                                trunc_32bits(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32] + gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                        end
                                    end
                                    default: gen_intermediate_d[i].intermediate = '0;
                                endcase
                            end
                        end
                    end
                    SEW_64: begin
                        if (j < (gen_intermediate_q[i-1].vl >> i)) begin
                            if (!gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b0;
                                gen_intermediate_d[i].intermediate[(j*64) +: 64] = '0;
                            end else if (gen_intermediate_q[i-1].mask[(j*2)] && !gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*64) +: 64] = gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64];
                            end else if (!gen_intermediate_q[i-1].mask[(j*2)] && gen_intermediate_q[i-1].mask[(j*2)+1]) begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                gen_intermediate_d[i].intermediate[(j*64) +: 64] = gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64];
                            end else begin
                                gen_intermediate_d[i].mask[((j*2) >> 1)] = 1'b1;
                                case (gen_intermediate_q[i-1].instr_type)
                                    VREDSUM: gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                trunc_64bits(gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] + gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64]);
                                    VREDAND: gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                (gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] & gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64]);
                                    VREDOR:  gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                (gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] | gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64]);
                                    VREDXOR: gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                (gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] ^ gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64]);
                                    VREDMAX: gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64] : gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64];
                                    VREDMAXU: gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64] : gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64];
                                    VREDMIN: gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                            ($signed(gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64]) < $signed(gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] : gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64];
                                    VREDMINU: gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                            ($unsigned(gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64]) < $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64])) ?
                                            gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] : gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64];
                                    VWREDSUM: begin
                                        if (i == 1) begin
                                            gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                $signed(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32]) + $signed(gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                        end else begin
                                            gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                trunc_64bits(gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] + gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64]);
                                        end
                                    end
                                    VWREDSUMU: begin
                                        if (i == 1) begin
                                            gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*32) +: 32]) + $unsigned(gen_intermediate_q[i-1].intermediate[2*(j*32) + 32 +: 32]);
                                        end else begin
                                            gen_intermediate_d[i].intermediate[(j*64) +: 64] = 
                                                trunc_64bits(gen_intermediate_q[i-1].intermediate[2*(j*64) +: 64] + gen_intermediate_q[i-1].intermediate[2*(j*64) + 64 +: 64]);
                                        end
                                    end
                                    default: gen_intermediate_d[i].intermediate = '0;
                                endcase
                            end
                        end
                    end
                endcase
            end
            gen_intermediate_d[i].sew = gen_intermediate_q[i-1].sew;
            gen_intermediate_d[i].instr_type = gen_intermediate_q[i-1].instr_type;
            gen_intermediate_d[i].data_vs1 = gen_intermediate_q[i-1].data_vs1;
            gen_intermediate_d[i].vl = gen_intermediate_q[i-1].vl;
        end
    end
end

sew_t sew_to_out;
logic [VMAXELEM_LOG-1:0] stage_to_out;

assign sew_to_out = (is_vw(instr_to_out_i)) ? increase_sew_size(sew_to_out_i) : sew_to_out_i;
assign stage_to_out = $clog2(vl_to_out_i);

always_comb begin
    red_data_vd_o = '0;
    case (sew_to_out)
        SEW_8: begin
            if (!gen_intermediate_q[stage_to_out].mask[0]) begin
                red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            end else begin
                case (gen_intermediate_q[stage_to_out].instr_type)
                    VREDSUM, VWREDSUM, VWREDSUMU:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 8] + gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
                    VREDAND:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 8] & gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
                    VREDOR:   red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 8] | gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
                    VREDXOR:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 8] ^ gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
                    VREDMAX:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 8])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[0 +: 8])};
                    VREDMAXU: red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 8]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[0 +: 8])};
                    VREDMIN:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 8])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 8] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
                    VREDMINU: red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 8]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 8] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
                    default: red_data_vd_o = '0;
                endcase
            end
        end
        SEW_16: begin
            if (!gen_intermediate_q[stage_to_out].mask[0]) begin
                red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])};
            end else begin
                case (gen_intermediate_q[stage_to_out].instr_type)
                    VREDSUM, VWREDSUM, VWREDSUMU:  red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 16] + gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])};
                    VREDAND:  red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 16] & gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])};
                    VREDOR:   red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 16] | gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])};
                    VREDXOR:  red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 16] ^ gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])};
                    VREDMAX:  red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 16])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 16] : gen_intermediate_q[stage_to_out].intermediate[0 +: 16])};
                    VREDMAXU: red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 16]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 16] : gen_intermediate_q[stage_to_out].intermediate[0 +: 16])};
                    VREDMIN:  red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 16])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 16] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])};
                    VREDMINU: red_data_vd_o = {{data_old_vd[VLEN-1:16]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 16]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 16] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 16])};
                    default: red_data_vd_o = '0;
                endcase
            end
        end
        SEW_32: begin
            if (!gen_intermediate_q[stage_to_out].mask[0]) begin
                red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])};
            end else begin
                case (gen_intermediate_q[stage_to_out].instr_type)
                    VREDSUM, VWREDSUM, VWREDSUMU: red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 32] + gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])};
                    VREDAND:  red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 32] & gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])};
                    VREDOR:   red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 32] | gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])};
                    VREDXOR:  red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 32] ^ gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])};
                    VREDMAX:  red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 32])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 32] : gen_intermediate_q[stage_to_out].intermediate[0 +: 32])};
                    VREDMAXU: red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 32]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 32] : gen_intermediate_q[stage_to_out].intermediate[0 +: 32])};
                    VREDMIN:  red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 32])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 32] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])};
                    VREDMINU: red_data_vd_o = {{data_old_vd[VLEN-1:32]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 32]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 32] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 32])};
                    default: red_data_vd_o = '0;
                endcase
            end
        end
        SEW_64: begin
            if (!gen_intermediate_q[stage_to_out].mask[0]) begin
                red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])};
            end else begin
                case (gen_intermediate_q[stage_to_out].instr_type)
                    VREDSUM, VWREDSUM, VWREDSUMU: red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 64] + gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])};
                    VREDAND:  red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 64] & gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])};
                    VREDOR:   red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 64] | gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])};
                    VREDXOR:  red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (gen_intermediate_q[stage_to_out].intermediate[0 +: 64] ^ gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])};
                    VREDMAX:  red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 64])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 64] : gen_intermediate_q[stage_to_out].intermediate[0 +: 64])};
                    VREDMAXU: red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 64]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 64] : gen_intermediate_q[stage_to_out].intermediate[0 +: 64])};
                    VREDMIN:  red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[0 +: 64])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 64] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])};
                    VREDMINU: red_data_vd_o = {{data_old_vd[VLEN-1:64]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[0 +: 64]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])) ? gen_intermediate_q[stage_to_out].intermediate[0 +: 64] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 64])};
                    default: red_data_vd_o = '0;
                endcase
            end
        end
    endcase
end
/*SEW_8: begin
    if (!gen_intermediate_q[stage_to_out].mask[1] && !gen_intermediate_q[stage_to_out].mask[0]) begin
        red_data_vd_o = {{data_old_vd[VLEN-1:8]}, gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]};
    end else if (gen_intermediate_q[stage_to_out].mask[1] && !gen_intermediate_q[stage_to_out].mask[0]) begin
        case (gen_intermediate_q[stage_to_out].instr_type)
            VREDSUM:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] + gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDAND:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] & gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDOR:   red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] | gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDXOR:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] ^ gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDMAX:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[15:8])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]))   ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[15:8])};
            VREDMAXU: red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[15:8]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[15:8])};
            VREDMIN:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[15:8])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]))   ? gen_intermediate_q[stage_to_out].intermediate[15:8] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDMINU: red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[15:8]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[15:8] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            default : red_data_vd_o = '0;
        endcase
    end else if (!gen_intermediate_q[stage_to_out].mask[1] && gen_intermediate_q[stage_to_out].mask[0]) begin
        case (gen_intermediate_q[stage_to_out].instr_type)
            VREDSUM:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[7:0] + gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDAND:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[7:0] & gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDOR:   red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[7:0] | gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDXOR:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[7:0] ^ gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDMAX:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[7:0])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]))   ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[7:0])};
            VREDMAXU: red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[7:0]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[7:0])};
            VREDMIN:  red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($signed(gen_intermediate_q[stage_to_out].intermediate[7:0])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]))   ? gen_intermediate_q[stage_to_out].intermediate[7:0] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDMINU: red_data_vd_o = {{data_old_vd[VLEN-1:8]}, (($unsigned(gen_intermediate_q[stage_to_out].intermediate[7:0]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[7:0] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            default: red_data_vd_o = '0;
        endcase
    end else begin
        case (gen_intermediate_q[stage_to_out].instr_type)
            VREDSUM:  red_data_vd_o =  {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] 
                                                        + gen_intermediate_q[stage_to_out].intermediate[7:0] 
                                                        + gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDAND:  red_data_vd_o =  {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] 
                                                        & gen_intermediate_q[stage_to_out].intermediate[7:0] 
                                                        & gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDOR:   red_data_vd_o =  {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] 
                                                        | gen_intermediate_q[stage_to_out].intermediate[7:0] 
                                                        | gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDXOR:  red_data_vd_o =  {{data_old_vd[VLEN-1:8]}, (gen_intermediate_q[stage_to_out].intermediate[15:8] 
                                                        ^ gen_intermediate_q[stage_to_out].intermediate[7:0] 
                                                        ^ gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])};
            VREDMAX:  red_data_vd_o =  {{data_old_vd[VLEN-1:8]},(($signed(gen_intermediate_q[stage_to_out].intermediate[15:8])   < $signed(gen_intermediate_q[stage_to_out].intermediate[7:0])) ? 
                                                                (($signed(gen_intermediate_q[stage_to_out].intermediate[7:0])    < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[7:0]) :
                                                                (($signed(gen_intermediate_q[stage_to_out].intermediate[15:8])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[15:8]))};
            VREDMAXU: red_data_vd_o =  {{data_old_vd[VLEN-1:8]},(($unsigned(gen_intermediate_q[stage_to_out].intermediate[15:8]) < $unsigned(gen_intermediate_q[stage_to_out].intermediate[7:0])) ? 
                                                                (($unsigned(gen_intermediate_q[stage_to_out].intermediate[7:0])  < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[7:0]) :
                                                                (($unsigned(gen_intermediate_q[stage_to_out].intermediate[15:8]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].data_vs1[0 +: 8] : gen_intermediate_q[stage_to_out].intermediate[15:8]))};
            VREDMIN:  red_data_vd_o =  {{data_old_vd[VLEN-1:8]},(($signed(gen_intermediate_q[stage_to_out].intermediate[15:8])   < $signed(gen_intermediate_q[stage_to_out].intermediate[7:0])) ? 
                                                                (($signed(gen_intermediate_q[stage_to_out].intermediate[15:8])   < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[15:8] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]) :
                                                                (($signed(gen_intermediate_q[stage_to_out].intermediate[7:0])    < $signed(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[7:0]  : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]))};
            VREDMINU: red_data_vd_o =  {{data_old_vd[VLEN-1:8]},(($unsigned(gen_intermediate_q[stage_to_out].intermediate[15:8]) < $unsigned(gen_intermediate_q[stage_to_out].intermediate[7:0])) ? 
                                                                (($unsigned(gen_intermediate_q[stage_to_out].intermediate[15:8]) < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[15:8] : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]) :
                                                                (($unsigned(gen_intermediate_q[stage_to_out].intermediate[7:0])  < $unsigned(gen_intermediate_q[stage_to_out].data_vs1[0 +: 8])) ? gen_intermediate_q[stage_to_out].intermediate[7:0]  : gen_intermediate_q[stage_to_out].data_vs1[0 +: 8]))};
            default: red_data_vd_o = '0;
        endcase
    end
end*/
endmodule
