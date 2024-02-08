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
    input  logic clk_i,                   // Clock signal
    input  logic rstn_i,                // Reset signal
    input  instr_type_t instr_type_i,   // Instruction type
    input  sew_t sew_i,                 // SEW: 00 for 8 bits, 01 for 16 bits, 10 for 32 bits, 11 for 64 bits
    input  bus64_t data_fu_i,          // Result of vs1[0] and vs2[0] in data_fu[0]
    input  bus_simd_t data_vs2_i,       // 128-bit source operand 
    input  bus_mask_t data_vm_i,        // Vector mask of VLEN/8 size
    input  sew_t sew_to_out_i,          // SEW indication for output 
    output bus_simd_t red_data_vd_o     // 128-bit result (only cares last element)
);

localparam int NUM_STAGES = $clog2(VLEN / 8);      // Number of stages based on the minimum SEW
integer i;

function int get_sew_size(sew_t sew);
    case (sew)
        SEW_8: return 8;
        SEW_16: return 16;
        SEW_32: return 32;
        SEW_64: return 64;
    endcase
endfunction

// Intermediate vector declaration with a generate block
genvar gv_stage;
generate
    for (gv_stage = 0; gv_stage < NUM_STAGES; gv_stage++) begin : gen_intermediate
        sew_t sew;
        bus_mask_t mask;
        instr_type_t instr_type;
        bus64_t data_vs1;
        logic [VLEN-1:0] intermediate;
    end
endgenerate

always_comb begin
    gen_intermediate[0].sew = sew_i;
    gen_intermediate[0].mask = data_vm_i;
    gen_intermediate[0].instr_type = instr_type_i;
    gen_intermediate[0].intermediate = data_vs2_i;
    gen_intermediate[0].data_vs1 = data_fu_i;
end

for (genvar i = 1; i < NUM_STAGES; i++) begin
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            gen_intermediate[i].sew <= SEW_8;
            gen_intermediate[i].mask <= '0;
            gen_intermediate[i].instr_type <= ADD;
            gen_intermediate[i].intermediate <= '0;
            gen_intermediate[i].data_vs1 <= '0;
        end else begin
            int half_size = VLEN >> i;
            int idx;
            int idx_mask;
            gen_intermediate[i].mask <= '0;
            for (int j = 0; j < VLEN/16; j++) begin
                idx_mask = j*2;
                case (gen_intermediate[i-1].sew) 
                    SEW_8: begin
                        idx = j*8;
                        if (idx < half_size) begin
                            if (!gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 8] <= '0;
                            end else if (gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 8] <= gen_intermediate[i-1].intermediate[2*idx +: 8];
                            end else if (!gen_intermediate[i-1].mask[idx_mask] && gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 8] <= gen_intermediate[i-1].intermediate[2*idx + 8 +: 8];
                            end else begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                case (gen_intermediate[i-1].instr_type)
                                    VREDSUM: gen_intermediate[i].intermediate[idx +: 8] <= 
                                            gen_intermediate[i-1].intermediate[2*idx +: 8] + gen_intermediate[i-1].intermediate[2*idx + 8 +: 8];
                                    VREDAND: gen_intermediate[i].intermediate[idx +: 8] <= 
                                            gen_intermediate[i-1].intermediate[2*idx +: 8] & gen_intermediate[i-1].intermediate[2*idx + 8 +: 8];
                                    VREDOR:  gen_intermediate[i].intermediate[idx +: 8] <= 
                                            gen_intermediate[i-1].intermediate[2*idx +: 8] | gen_intermediate[i-1].intermediate[2*idx + 8 +: 8];
                                    VREDXOR: gen_intermediate[i].intermediate[idx +: 8] <= 
                                            gen_intermediate[i-1].intermediate[2*idx +: 8] ^ gen_intermediate[i-1].intermediate[2*idx + 8 +: 8];
                                    default: gen_intermediate[i].intermediate <= '0;
                                endcase
                            end
                        end else begin
                            if (idx < VLEN) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 8] <= 8'd0;
                            end
                        end
                    end
                    SEW_16: begin
                        idx = j*16;
                        if (idx < half_size) begin
                            if (!gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 16] <= '0;
                            end else if (gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 16] <= gen_intermediate[i-1].intermediate[2*idx +: 16];
                            end else if (!gen_intermediate[i-1].mask[idx_mask] && gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 16] <= gen_intermediate[i-1].intermediate[2*idx + 16 +: 16];
                            end else begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                case (gen_intermediate[i-1].instr_type)
                                    VREDSUM: gen_intermediate[i].intermediate[idx +: 16] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 16] + gen_intermediate[i-1].intermediate[2*idx + 16 +: 16];
                                    VREDAND: gen_intermediate[i].intermediate[idx +: 16] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 16] & gen_intermediate[i-1].intermediate[2*idx + 16 +: 16];
                                    VREDOR:  gen_intermediate[i].intermediate[idx +: 16] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 16] | gen_intermediate[i-1].intermediate[2*idx + 16 +: 16];
                                    VREDXOR: gen_intermediate[i].intermediate[idx +: 16] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 16] ^ gen_intermediate[i-1].intermediate[2*idx + 16 +: 16];
                                    default: gen_intermediate[i].intermediate <= '0;
                                endcase
                            end
                        end else begin
                            if (idx < VLEN) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 16] <= 16'd0;
                            end
                        end
                    end
                    SEW_32: begin
                        idx = j*32;
                        if (idx < half_size) begin
                            if (!gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 32] <= '0;
                            end else if (gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 32] <= gen_intermediate[i-1].intermediate[2*idx +: 32];
                            end else if (!gen_intermediate[i-1].mask[idx_mask] && gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 32] <= gen_intermediate[i-1].intermediate[2*idx + 32 +: 32];
                            end else begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                case (gen_intermediate[i-1].instr_type)
                                    VREDSUM: gen_intermediate[i].intermediate[idx +: 32] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 32] + gen_intermediate[i-1].intermediate[2*idx + 32 +: 32];
                                    VREDAND: gen_intermediate[i].intermediate[idx +: 32] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 32] & gen_intermediate[i-1].intermediate[2*idx + 32 +: 32];
                                    VREDOR:  gen_intermediate[i].intermediate[idx +: 32] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 32] | gen_intermediate[i-1].intermediate[2*idx + 32 +: 32];
                                    VREDXOR: gen_intermediate[i].intermediate[idx +: 32] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 32] ^ gen_intermediate[i-1].intermediate[2*idx + 32 +: 32];
                                    default: gen_intermediate[i].intermediate <= '0;
                                endcase
                            end
                        end else begin
                            if (idx < VLEN) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 32] <= 32'd0;
                            end
                        end
                    end
                    SEW_64: begin
                        idx = j*64;
                        if (idx < half_size) begin
                            if (!gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 64] <= '0;
                            end else if (gen_intermediate[i-1].mask[idx_mask] && !gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 64] <= gen_intermediate[i-1].intermediate[2*idx +: 64];
                            end else if (!gen_intermediate[i-1].mask[idx_mask] && gen_intermediate[i-1].mask[idx_mask+1]) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                gen_intermediate[i].intermediate[idx +: 64] <= gen_intermediate[i-1].intermediate[2*idx + 64 +: 64];
                            end else begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b1;
                                case (gen_intermediate[i-1].instr_type)
                                    VREDSUM: gen_intermediate[i].intermediate[idx +: 64] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 64] + gen_intermediate[i-1].intermediate[2*idx + 64 +: 64];
                                    VREDAND: gen_intermediate[i].intermediate[idx +: 64] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 64] & gen_intermediate[i-1].intermediate[2*idx + 64 +: 64];
                                    VREDOR:  gen_intermediate[i].intermediate[idx +: 64] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 64] | gen_intermediate[i-1].intermediate[2*idx + 64 +: 64];
                                    VREDXOR: gen_intermediate[i].intermediate[idx +: 64] <= 
                                                gen_intermediate[i-1].intermediate[2*idx +: 64] ^ gen_intermediate[i-1].intermediate[2*idx + 64 +: 64];
                                    default: gen_intermediate[i].intermediate <= '0;
                                endcase
                            end
                        end else begin
                            if (idx < VLEN) begin
                                gen_intermediate[i].mask[(idx_mask >> 1)] <= 1'b0;
                                gen_intermediate[i].intermediate[idx +: 64] <= 64'd0;
                            end
                        end
                    end
                endcase
            end
            gen_intermediate[i].sew <= gen_intermediate[i-1].sew;
            gen_intermediate[i].instr_type <= gen_intermediate[i-1].instr_type;
            gen_intermediate[i].data_vs1 <= gen_intermediate[i-1].data_vs1;
        end
    end
end

always_comb begin
    red_data_vd_o = '0;
    case (sew_to_out_i)
        SEW_8: begin
            case (gen_intermediate[NUM_STAGES-1].instr_type)
                VREDSUM: red_data_vd_o =  {{(VLEN-8){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[15:8] 
                                                            + gen_intermediate[NUM_STAGES-1].intermediate[7:0] 
                                                            + gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 8]};
                VREDAND: red_data_vd_o =  {{(VLEN-8){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[15:8] 
                                                            & gen_intermediate[NUM_STAGES-1].intermediate[7:0] 
                                                            & gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 8]};
                VREDOR:  red_data_vd_o =  {{(VLEN-8){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[15:8] 
                                                            | gen_intermediate[NUM_STAGES-1].intermediate[7:0] 
                                                            | gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 8]};
                VREDXOR: red_data_vd_o =  {{(VLEN-8){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[15:8] 
                                                            ^ gen_intermediate[NUM_STAGES-1].intermediate[7:0] 
                                                            ^ gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 8]};
            endcase
        end
        SEW_16: begin
            case (gen_intermediate[NUM_STAGES-1].instr_type)
                VREDSUM: red_data_vd_o = {{(VLEN-16){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[0 +: 16] + gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 16]};
                VREDAND: red_data_vd_o = {{(VLEN-16){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[0 +: 16] & gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 16]};
                VREDOR:  red_data_vd_o = {{(VLEN-16){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[0 +: 16] | gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 16]};
                VREDXOR: red_data_vd_o = {{(VLEN-16){1'b1}}, gen_intermediate[NUM_STAGES-1].intermediate[0 +: 16] ^ gen_intermediate[NUM_STAGES-1].data_vs1[0 +: 16]};
            endcase
        end
        SEW_32: begin
            case (gen_intermediate[NUM_STAGES-2].instr_type)
                VREDSUM: red_data_vd_o = {{(VLEN-32){1'b1}}, gen_intermediate[NUM_STAGES-2].intermediate[0 +: 32] + gen_intermediate[NUM_STAGES-2].data_vs1[0 +: 32]};
                VREDAND: red_data_vd_o = {{(VLEN-32){1'b1}}, gen_intermediate[NUM_STAGES-2].intermediate[0 +: 32] & gen_intermediate[NUM_STAGES-2].data_vs1[0 +: 32]};
                VREDOR:  red_data_vd_o = {{(VLEN-32){1'b1}}, gen_intermediate[NUM_STAGES-2].intermediate[0 +: 32] | gen_intermediate[NUM_STAGES-2].data_vs1[0 +: 32]};
                VREDXOR: red_data_vd_o = {{(VLEN-32){1'b1}}, gen_intermediate[NUM_STAGES-2].intermediate[0 +: 32] ^ gen_intermediate[NUM_STAGES-2].data_vs1[0 +: 32]};
            endcase
        end
        SEW_64: begin
            case (gen_intermediate[NUM_STAGES-3].instr_type)
                VREDSUM: red_data_vd_o = {{(VLEN-64){1'b1}}, gen_intermediate[NUM_STAGES-3].intermediate[0 +: 64] + gen_intermediate[NUM_STAGES-3].data_vs1[0 +: 64]};
                VREDAND: red_data_vd_o = {{(VLEN-64){1'b1}}, gen_intermediate[NUM_STAGES-3].intermediate[0 +: 64] & gen_intermediate[NUM_STAGES-3].data_vs1[0 +: 64]};
                VREDOR:  red_data_vd_o = {{(VLEN-64){1'b1}}, gen_intermediate[NUM_STAGES-3].intermediate[0 +: 64] | gen_intermediate[NUM_STAGES-3].data_vs1[0 +: 64]};
                VREDXOR: red_data_vd_o = {{(VLEN-64){1'b1}}, gen_intermediate[NUM_STAGES-3].intermediate[0 +: 64] ^ gen_intermediate[NUM_STAGES-3].data_vs1[0 +: 64]};
            endcase
        end
    endcase
end

endmodule
