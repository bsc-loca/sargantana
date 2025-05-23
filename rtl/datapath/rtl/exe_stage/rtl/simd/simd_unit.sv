/*
 * Copyright 2025 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */


 module simd_unit
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input wire                    clk_i,                  // Clock
    input wire                    rstn_i,                 // Reset
    input logic                   flush_i,                // Flush 
    input vxrm_t                  vxrm_i,                 // Vector Fixed-Point Rounding Mode
    input rr_exe_simd_instr_t     instruction_i,          // In instruction 
    output exe_wb_scalar_instr_t  instruction_scalar_o,   // Out instruction
    output exe_wb_simd_instr_t    instruction_simd_o      // Out instruction
);

localparam MAX_STAGES = $clog2(VLEN/8) + 2; // The vector reduction tree module will have the maximum stages
localparam int DIV_STAGES = 32;             // number of clocks a DIV/REM instruction takes


bus64_t [drac_pkg::VELEMENTS-1:0] vs1_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] vs2_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] data_vm;
bus64_t [drac_pkg::VELEMENTS-1:0] vd_elements;
bus_simd_t rs1_replicated;
bus_simd_t fu_data_vd;
bus64_t data_rd; //Optimisation: Use just lower bits of fu_data_vd

rr_exe_simd_instr_t instr_to_out; // Output instruction
logic [VMAXELEM_LOG:0] vl_to_out;

function [3:0] trunc_4bits(input [31:0] val_in);
    trunc_4bits = val_in[3:0];
endfunction

function [3:0] trunc_33_to_4bits(input [32:0] val_in);
    trunc_33_to_4bits = val_in[3:0];
endfunction

function [4:0] trunc_64_to_5_bits(input [63:0] val_in);
    trunc_64_to_5_bits = val_in[4:0];
endfunction

// these variabls hold data related to the previous
// DIV/REM inst in order for us to be able to indicate
// if the current DIV/REM can be skipped

bus64_t         previous_div_rs1_q;                 // Register Source 1  of previous div/rem
bus64_t         previous_div_rs1_d;                 // Register Source 1  of previous div/rem

bus_simd_t      previous_div_vs1_q;                 // VRegister Source 1 of previous div/rem
bus_simd_t      previous_div_vs1_d;                 // VRegister Source 1 of previous div/rem

bus_simd_t      previous_div_vs2_q;                 // VRegister Source 2 of previous div/rem
bus_simd_t      previous_div_vs2_d;                 // VRegister Source 2 of previous div/rem

logic           previous_div_is_opvx_q;             // Instruction uses rs1 instead of vs1 of previous div/rem
logic           previous_div_is_opvx_d;             // Instruction uses rs1 instead of vs1 of previous div/rem

instr_type_t    previous_div_instr_type_q;          // Type of instruction of previous div/rem
instr_type_t    previous_div_instr_type_d;          // Type of instruction of previous div/rem          

function [5:0] trunc_6bits(input [31:0] val_in);
    trunc_6bits = val_in[5:0];
endfunction

function [$clog2(VLEN/8) - 1 :0] trunc_vl_i_sew8(input [VMAXELEM_LOG + 1:0] val_in);
    trunc_vl_i_sew8 = val_in[$clog2(VLEN/8) - 1 : 0];
endfunction

function [$clog2(VLEN/16) - 1 : 0] trunc_vl_i_sew16(input [VMAXELEM_LOG + 1:0] val_in);
    trunc_vl_i_sew16 = val_in[$clog2(VLEN/16) - 1 : 0];
endfunction

function [$clog2(VLEN/32) - 1 : 0] trunc_vl_i_sew32(input [VMAXELEM_LOG + 1:0] val_in);
    trunc_vl_i_sew32 = val_in[$clog2(VLEN/32) - 1 : 0];
endfunction

function [$clog2(VLEN/64) - 1 : 0] trunc_vl_i_sew64(input [VMAXELEM_LOG + 1:0] val_in);
    trunc_vl_i_sew64 = val_in[$clog2(VLEN/64) - 1 : 0];
endfunction


logic [5:0] simd_exe_stages;

function logic not_masked_output(input rr_exe_simd_instr_t instr);
    not_masked_output = ((instr.instr.instr_type == VADC) ||
                         (instr.instr.instr_type == VSBC) ||
                         (instr.instr.instr_type == VMADC) ||
                         (instr.instr.instr_type == VMSBC) ||
                         (instr.instr.instr_type == VFIRST)) ? 1'b1 : 1'b0;
endfunction
function logic is_vred(input rr_exe_simd_instr_t instr);
    is_vred = ((instr.instr.instr_type == VREDSUM)   ||
               (instr.instr.instr_type == VREDAND)   ||
               (instr.instr.instr_type == VREDOR)    ||
               (instr.instr.instr_type == VREDXOR)   ||
               (instr.instr.instr_type == VREDMAXU)  ||
               (instr.instr.instr_type == VREDMAX)   ||
               (instr.instr.instr_type == VREDMINU)  ||
               (instr.instr.instr_type == VREDMIN)   ||
               (instr.instr.instr_type == VWREDSUM)  ||
               (instr.instr.instr_type == VWREDSUMU)) ? 1'b1 : 1'b0;
endfunction

function logic is_vdiv(input rr_exe_simd_instr_t instr);
    is_vdiv = ((instr.instr.instr_type == VDIV)    ||
               (instr.instr.instr_type == VDIVU)   ||
               (instr.instr.instr_type == VREM)    ||
               (instr.instr.instr_type == VREMU)) ? 1'b1 : 1'b0;
    
endfunction

function logic is_vmul(input rr_exe_simd_instr_t instr);
    is_vmul = ((instr.instr.instr_type == VWMUL)  ||
               (instr.instr.instr_type == VWMULU) ||
               (instr.instr.instr_type == VWMULSU)||
               (instr.instr.instr_type == VMUL)   ||
               (instr.instr.instr_type == VMULH)  ||
               (instr.instr.instr_type == VMULHU) ||
               (instr.instr.instr_type == VMULHSU)) ? 1'b1 : 1'b0;
endfunction

function logic is_vmadd_vsmul(input rr_exe_simd_instr_t instr);
    is_vmadd_vsmul = ((instr.instr.instr_type == VMADD)  ||
                      (instr.instr.instr_type == VNMSUB) ||
                      (instr.instr.instr_type == VMACC)  ||
                      (instr.instr.instr_type == VNMSAC) ||
                      (instr.instr.instr_type == VWMACC) ||
                      (instr.instr.instr_type == VWMACCU) ||
                      (instr.instr.instr_type == VWMACCUS) ||
                      (instr.instr.instr_type == VWMACCSU)||
                      (instr.instr.instr_type == VSMUL)) ? 1'b1 : 1'b0;
endfunction

function logic is_vw(input rr_exe_simd_instr_t instr);
    is_vw = ((instr.instr.instr_type == VWADD)    ||
             (instr.instr.instr_type == VWADDU)   ||
             (instr.instr.instr_type == VWSUB)    ||
             (instr.instr.instr_type == VWSUBU)   ||
             (instr.instr.instr_type == VWADDW)   ||
             (instr.instr.instr_type == VWADDUW)  ||
             (instr.instr.instr_type == VWSUBW)   ||
             (instr.instr.instr_type == VWSUBUW)  ||
             (instr.instr.instr_type == VWREDSUM) ||
             (instr.instr.instr_type == VWREDSUMU)||
             (instr.instr.instr_type == VWMUL)    ||
             (instr.instr.instr_type == VWMULU)   ||
             (instr.instr.instr_type == VWMULSU)  ||
             (instr.instr.instr_type == VWMACC)   ||
             (instr.instr.instr_type == VWMACCU)  ||
             (instr.instr.instr_type == VWMACCSU) ||
             (instr.instr.instr_type == VWMACCUS)) ? 1'b1 : 1'b0;
endfunction

function logic is_vn(input rr_exe_simd_instr_t instr);
    is_vn = ((instr.instr.instr_type == VNCLIPU)  ||
             (instr.instr.instr_type == VNCLIP)  ||
             (instr.instr.instr_type == VNSRL)    ||
             (instr.instr.instr_type == VNSRA)) ? 1'b1 : 1'b0;
endfunction

function logic is_vww(input rr_exe_simd_instr_t instr);
    is_vww = ((instr.instr.instr_type == VWADDW) ||
             (instr.instr.instr_type == VWADDUW) ||
             (instr.instr.instr_type == VWSUBW)  ||
             (instr.instr.instr_type == VWSUBUW)) ? 1'b1 : 1'b0;
endfunction

function logic is_vm(input rr_exe_simd_instr_t instr);
    is_vm = ((instr.instr.instr_type == VMSEQ)  ||
             (instr.instr.instr_type == VMSNE)  || 
             (instr.instr.instr_type == VMSLTU) ||
             (instr.instr.instr_type == VMSLT)  || 
             (instr.instr.instr_type == VMSLEU) || 
             (instr.instr.instr_type == VMSLE)  ||
             (instr.instr.instr_type == VMSGTU) ||             
             (instr.instr.instr_type == VMSGT)  ||
             (instr.instr.instr_type == VMAND)  ||
             (instr.instr.instr_type == VMNAND)  ||
             (instr.instr.instr_type == VMANDN)  ||
             (instr.instr.instr_type == VMXOR)  ||
             (instr.instr.instr_type == VMOR)  ||
             (instr.instr.instr_type == VMNOR)  ||
             (instr.instr.instr_type == VMORN)  ||
             (instr.instr.instr_type == VMXNOR) ||
             (instr.instr.instr_type == VMSBF)  ||
             (instr.instr.instr_type == VMSIF)  ||
             (instr.instr.instr_type == VMSOF)  ||
             (instr.instr.instr_type == VMADC)  ||             
             (instr.instr.instr_type == VMSBC)) ? 1'b1 : 1'b0;
endfunction

function bus64_t min_unsigned (input bus64_t a, b);
    min_unsigned = (a < b) ? a : b ;
endfunction

// This fucntion indicates wether the current DIV/REM can be done in 1 clock cycle
// this happens when the opearands and type matched the previous DIV/REM and the result
// is ready
function logic is_div_1_clock(input bus_simd_t vs1, input bus_simd_t vs2, input bus64_t rs1,
                            input logic is_opvx, input instr_type_t instr_type, input rr_exe_simd_instr_t instr_entry_i);

    is_div_1_clock = (is_opvx != instr_entry_i.instr.is_opvx) ? 1'b0 :    (((instr_type == instr_entry_i.instr.instr_type)                ||
                                                                    ((instr_type == VDIV) && (instr_entry_i.instr.instr_type == VREM))    ||
                                                                    ((instr_type == VREM) && (instr_entry_i.instr.instr_type == VDIV))    ||
                                                                    ((instr_type == VDIVU) && (instr_entry_i.instr.instr_type == VREMU))  ||
                                                                    ((instr_type == VREMU) && (instr_entry_i.instr.instr_type == VDIVU))      ) ? (is_opvx ?  ((vs2 == instr_entry_i.data_vs2) && (rs1 == instr_entry_i.data_rs1)) :
                                                                                                                                                        ((vs2 == instr_entry_i.data_vs2) && (vs1 == instr_entry_i.data_vs1))) : 1'b0); 
    
endfunction



typedef struct packed {
    logic valid;
    rr_exe_simd_instr_t simd_instr;
} instr_pipe_t;
instr_pipe_t simd_pipe_d [MAX_STAGES:2] [MAX_STAGES-1:0] ;
instr_pipe_t simd_pipe_q [MAX_STAGES:2] [MAX_STAGES-1:0] ;


// This pipeline is taking care of in-flight DIV/REM instructions
// it's seperated from other instructions as DIV/REM is way more time consuming
// than other instructions.
// The behaviour and managment of this pipeline is alike the simd_pipe
// the differences are explained
// Note that there can't be more than 1 in flight DIV/REM at a time, should another
// DIV/REM instruction be dispatched while the previous one is being processed, the
// pipline is stalled. The stalling mechanism can be seen in sargantana/rtl/datapath/rtl/exe_stage/rtl/score_board_simd.sv
logic division_pipe_d [DIV_STAGES - 2:0];
logic division_pipe_q [DIV_STAGES - 2:0];

// in order to reduce the area and not use a redundant array of rr_exe_simd_instr_t
// a global instruction is stored, since there can't be more than 1 in-flight div/rems 
rr_exe_simd_instr_t division_instruction_d;
rr_exe_simd_instr_t division_instruction_q;

// Cycle instruction management for those instructions that takes more than 1 cycle
/*
 * 2 cycle -> |0|1|
 * 3 cycle -> |0|1|2|
 * 4 cycle -> |0|1|2|3|
 ...
*/

always_comb begin
    previous_div_rs1_d = previous_div_rs1_q;               
    previous_div_vs1_d = previous_div_vs1_q;                
    previous_div_vs2_d = previous_div_vs2_q;                
    previous_div_is_opvx_d = previous_div_is_opvx_q;            
    previous_div_instr_type_d = previous_div_instr_type_q; 

    if (is_vmul(instruction_i)) begin
        simd_exe_stages = (instruction_i.instr.sew == SEW_64) ? 6'd3 : 6'd2;
    end
    else if (is_vmadd_vsmul(instruction_i)) begin
        simd_exe_stages = (instruction_i.instr.sew == SEW_64) ? 6'd4 : 6'd3;
    end
    else if (is_vred(instruction_i)) begin
        case (instruction_i.instr.sew)
            SEW_8  : simd_exe_stages = trunc_6bits($clog2(VLEN >> 3) + 2);
            SEW_16 : simd_exe_stages = trunc_6bits($clog2(VLEN >> 3) + 1);
            SEW_32 : simd_exe_stages = trunc_6bits($clog2(VLEN >> 3));
            SEW_64 : simd_exe_stages = trunc_6bits($clog2(VLEN >> 3) - 1);
            default : simd_exe_stages = trunc_6bits($clog2(VLEN >> 3));
        endcase
    end else if (is_vdiv(instruction_i)) begin
        
        // Deciding on how many cycles to do the DIV/REM
        if(is_div_1_clock(  .vs1(previous_div_vs1_q), .vs2(previous_div_vs2_q), .rs1(previous_div_rs1_q), .is_opvx(previous_div_is_opvx_q),
        .instr_type(previous_div_instr_type_q), .instr_entry_i(instruction_i)) && instruction_i.instr.valid) begin

            simd_exe_stages = 6'd1; 

        end else begin

            simd_exe_stages = 6'd32; 

        end

        // when a new DIV/REM is issued, it's operands are saved
        // for comparision with future DIV/REM
        if(instruction_i.instr.valid) begin
            previous_div_rs1_d          = instruction_i.data_rs1;                 
            previous_div_vs1_d          = instruction_i.data_vs1;                
            previous_div_vs2_d          = instruction_i.data_vs2;                
            previous_div_is_opvx_d      = instruction_i.instr.is_opvx;            
            previous_div_instr_type_d   = instruction_i.instr.instr_type;
        end
        else begin
            previous_div_rs1_d          = previous_div_rs1_q;               
            previous_div_vs1_d          = previous_div_vs1_q;                
            previous_div_vs2_d          = previous_div_vs2_q;                
            previous_div_is_opvx_d      = previous_div_is_opvx_q;            
            previous_div_instr_type_d   = previous_div_instr_type_q;  
        end                    
    end 
    
    else begin
        simd_exe_stages = 6'd1;
    end
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        for (int i = 2; i <= MAX_STAGES; i++) begin
            for (int j = 0; j < MAX_STAGES; j++) begin
                simd_pipe_q[i][j] <= '0;
            end
        end
        for (int i = 0; i < (DIV_STAGES - 1); i++) begin
            division_pipe_q[i]      <= '0;
            division_instruction_q  <= '0;
        end
        
        previous_div_rs1_q          <= '0;                
        previous_div_vs1_q          <= '0;               
        previous_div_vs2_q          <= '0;              
        previous_div_is_opvx_q      <= '0;          
        previous_div_instr_type_q   <= ADD;


    end else begin
        for (int i = 2; i <= MAX_STAGES; i++) begin
            for (int j = 0; j < MAX_STAGES; j++) begin
                simd_pipe_q[i][j] <= simd_pipe_d[i][j];
            end
        end
        
        for (int i = 0; i < (DIV_STAGES - 1); i++) begin
            division_pipe_q[i]      <= division_pipe_d[i];
        end
        division_instruction_q      <= division_instruction_d;

        previous_div_rs1_q          <= previous_div_rs1_d;                
        previous_div_vs1_q          <= previous_div_vs1_d;               
        previous_div_vs2_q          <= previous_div_vs2_d;              
        previous_div_is_opvx_q      <= previous_div_is_opvx_d;          
        previous_div_instr_type_q   <= previous_div_instr_type_d;
    end
end

// Each cycle, each instruction go forward 1 slot
always_comb begin
    for (int i = 2; i <= MAX_STAGES; i++) begin
        for (int j = 0; j < MAX_STAGES; j++) begin
            simd_pipe_d[i][j].valid = 1'b0;
            simd_pipe_d[i][j].simd_instr = '0; // Implicitly sets SEW_8
            if (flush_i) begin
                simd_pipe_d[i][j].valid = 1'b0;
                simd_pipe_d[i][j].simd_instr = '0; // Implicitly sets SEW_8
            end else if (j==0) begin
                if (simd_exe_stages == i) begin
                    simd_pipe_d[i][0].valid = instruction_i.instr.valid;
                    simd_pipe_d[i][0].simd_instr = instruction_i;
                end else begin
                    simd_pipe_d[i][0].valid = 1'b0;
                    simd_pipe_d[i][0].simd_instr = '0; // Implicitly sets SEW_8
                end
            end else begin
                if (j < i) begin
                    simd_pipe_d[i][j].valid = simd_pipe_q[i][j-1].valid;
                    simd_pipe_d[i][j].simd_instr = simd_pipe_q[i][j-1].simd_instr;
                end else begin
                    simd_pipe_d[i][j].valid = 1'b0;
                    simd_pipe_d[i][j].simd_instr = '0;
                end
            end
        end
    end


    // division_instruction_d = division_instruction_q;
    for (int j = 0; j < (DIV_STAGES - 1); j++) begin
        if (j==0) begin

            if(is_vdiv(instruction_i) && (simd_exe_stages == 6'd32) && instruction_i.instr.valid) begin
                division_pipe_d[0]      = instruction_i.instr.valid;
                division_instruction_d  = instruction_i;
                // division_pipe_d[0].simd_instr = instruction_i;
            end
            else begin
                division_pipe_d[0]      = 1'b0;
                division_instruction_d  = division_instruction_q;
                // division_pipe_d[0].simd_instr = '0;
            end
        end else begin
            division_pipe_d[j]          = division_pipe_q[j-1];
            // division_instruction_d = division_instruction_q;
            // division_pipe_d[j].simd_instr = division_pipe_q[j-1].simd_instr;
                 
        end
    end
    
end

//Select the instruction that completes its correspondent pipeline
rr_exe_simd_instr_t instr_score_board;
logic valid_found;
always_comb begin
    instr_score_board = '0;
    valid_found = 1'b0;
    for (int i = 2; (i <= MAX_STAGES) && (!valid_found); i++) begin
        if (simd_pipe_q[i][i-2].valid) begin
            instr_score_board = simd_pipe_q[i][i-2].simd_instr;
            valid_found = 1'b1;
        end
    end
    // like the normal pipeline in Division pipeline we check to see if we have
    // a finalized instruction
    if((!valid_found) && (division_pipe_q[DIV_STAGES - 2])) begin
        // instr_score_board = division_pipe_q[DIV_STAGES - 2].simd_instr;
        instr_score_board = division_instruction_q;
        valid_found = 1'b1;
    end
end

always_comb begin
    if (valid_found && (instr_score_board.instr.vl != 'h0)) begin
        instr_to_out = instr_score_board;
    end else if (instruction_i.exe_stages == 1) begin
        instr_to_out = instruction_i;
    end else begin
        instr_to_out = '0;
    end 
end

//We replicate rs1 or imm taking the sew into account
always_comb begin
    case (instruction_i.instr.sew)
        SEW_8: begin
            for (int i=0; i<(VLEN/8); ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*8)+:8] = instruction_i.data_rs1[7:0];
                else rs1_replicated[(i*8)+:8] = instruction_i.instr.imm[7:0];
            end
        end
        SEW_16: begin
            for (int i=0; i<(VLEN/16); ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*16)+:16] = instruction_i.data_rs1[15:0];
                else rs1_replicated[(i*16)+:16] = instruction_i.instr.imm[15:0];
            end
        end
        SEW_32: begin
            for (int i=0; i<(VLEN/32); ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*32)+:32] = instruction_i.data_rs1[31:0];
                else rs1_replicated[(i*32)+:32] = instruction_i.instr.imm[31:0];
            end
        end
        SEW_64: begin
            for (int i=0; i<(VLEN/64); ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*64)+:64] = instruction_i.data_rs1[63:0];
                else rs1_replicated[(i*64)+:64] = instruction_i.instr.imm[63:0];
            end
        end
    endcase
end

//The source operands are separated into an array of 64-bit wide elements, each of which
//go into the Functional Units

fu_id_t fu_id[drac_pkg::VELEMENTS-1:0];
always_comb begin
    for (int i = 0; i < drac_pkg::VELEMENTS; i++) begin
        fu_id[i] = fu_id_t'(i);
    end
end

// For setting vxsat when overflow on vector saturation
logic [ drac_pkg::VELEMENTS-1:0 ] v_sat_ovf;

localparam int unsigned HALF_SIZE = DATA_SIZE >> 1;
genvar gv_fu;
generate
    for (gv_fu=0; gv_fu<drac_pkg::VELEMENTS; gv_fu=gv_fu+1) begin
        always_comb begin
            if (is_vw(instruction_i) || is_vn(instruction_i)) begin
                vs1_elements[gv_fu] = (instruction_i.instr.is_opvx | instruction_i.instr.is_opvi) ? 
                                        {{HALF_SIZE{1'b0}}, rs1_replicated[gv_fu*(HALF_SIZE) +: (HALF_SIZE)]} : 
                                        {{HALF_SIZE{1'b0}}, instruction_i.data_vs1[gv_fu*(HALF_SIZE) +: (HALF_SIZE)]};
                vs2_elements[gv_fu] = (is_vww(instruction_i) || is_vn(instruction_i)) ? 
                                        instruction_i.data_vs2[(gv_fu*DATA_SIZE) +: DATA_SIZE] :
                                        {{HALF_SIZE{1'b0}}, instruction_i.data_vs2[gv_fu*(HALF_SIZE) +: (HALF_SIZE)]};
                 data_vm[gv_fu] = {64{1'b0}};                                        
            end else begin
                //vs1 is either the data_vs1, or the replicated rs1/imm
                vs1_elements[gv_fu] = (instruction_i.instr.is_opvx | instruction_i.instr.is_opvi) ? 
                                        rs1_replicated[(gv_fu*DATA_SIZE) +: DATA_SIZE] : 
                                        instruction_i.data_vs1[(gv_fu*DATA_SIZE) +: DATA_SIZE];
                vs2_elements[gv_fu] = instruction_i.data_vs2[(gv_fu*DATA_SIZE) +: DATA_SIZE];
                case (instruction_i.instr.sew)
                    SEW_8: begin
                        data_vm[gv_fu] = {{56{1'b0}}, instruction_i.data_vm[(gv_fu*(DATA_SIZE/8)) +: 8]};
                    end
                    SEW_16: begin
                        data_vm[gv_fu] = {{60{1'b0}}, instruction_i.data_vm[(gv_fu*(DATA_SIZE/16)) +: 4]};
                    end
                    SEW_32: begin
                         data_vm[gv_fu] = {{62{1'b0}}, instruction_i.data_vm[(gv_fu*(DATA_SIZE/32)) +: 2]};
                    end
                    SEW_64: begin
                        data_vm[gv_fu] =  {{48{1'b0}}, instruction_i.data_vm[(gv_fu*(DATA_SIZE/64)) +: 1]};
                    end
                    default: begin
                        data_vm[gv_fu] = {64{1'b0}};
                    end

                endcase 
            end
        end

        functional_unit functional_unit_inst(
            .clk_i           (clk_i),
            .rstn_i          (rstn_i),
            .fu_id_i         (fu_id[gv_fu]),
            .instruction_i   (instruction_i),
            .sel_out_instr_i (instr_to_out),
            .vxrm_i          (vxrm_i),
            .data_vs1_i      (vs1_elements[gv_fu]),
            .data_vs2_i      (vs2_elements[gv_fu]),
            .data_vm         (data_vm[gv_fu]),
            .data_vd_o       (vd_elements[gv_fu]),
            .sat_ovf_o       (v_sat_ovf[gv_fu])
        );
    end
endgenerate

//The result of the FUs are concatenated into the result data
always_comb begin
    fu_data_vd = (instr_to_out.instr.vta) ? '1 : instr_to_out.data_old_vd;
    for (int i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
        if (is_vn(instr_to_out)) begin
            fu_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = vd_elements[i][HALF_SIZE-1:0];
        end else if ((instr_to_out.instr.instr_type == VMADC) || (instr_to_out.instr.instr_type == VMSBC)) begin
            case (instr_to_out.instr.sew)
                SEW_8: begin
                    for (int j = 0; j<(DATA_SIZE/8); ++j) begin
                        fu_data_vd[(i*(DATA_SIZE/8)+j)] = vd_elements[i][j];
                    end
                end
                SEW_16: begin
                    for (int j = 0; j<(DATA_SIZE/16); ++j) begin
                        fu_data_vd[(i*(DATA_SIZE/16)+j)] = vd_elements[i][j];
                    end
                end
                SEW_32: begin
                    for (int j = 0; j<(DATA_SIZE/32); ++j) begin
                        fu_data_vd[(i*(DATA_SIZE/32)+j)] = vd_elements[i][j];
                    end
                end
                SEW_64: begin
                    for (int j = 0; j<(DATA_SIZE/64); ++j) begin
                        fu_data_vd[i*(DATA_SIZE/64)+j] = vd_elements[i][j];
                    end
                end
            endcase    
        end else begin
            fu_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = vd_elements[i];
        end
    end
end

// vpopc module
bus64_t data_vpopc_rd;
vpopc vpopc_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_vm_i     (instruction_i.data_vm),
    .use_mask_i    (instruction_i.instr.use_mask),
    .vl_i          (instruction_i.instr.vl),
    .data_vd_o     (data_vpopc_rd)
);

bus64_t result_vfirst;
vfirst vfirst_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_vm       (instruction_i.data_vm),
    .use_mask      (instruction_i.instr.use_mask),
    .vl_i          (instruction_i.instr.vl),
    .data_rd_o     (result_vfirst)
);

bus64_t ext_element;
//Compute the result of operations that don't operate on vector element
//granularity, and produce a scalar result
always_comb begin
    ext_element = 'h0;
    data_rd = 'h0;
    if (instr_to_out.instr.instr_type == VMV_X_S) begin
        //Extract element 0
        case (instr_to_out.instr.sew)
            SEW_8: begin
                data_rd = {{56{vs2_elements[0][7]}}, vs2_elements[0][7:0]};
            end
            SEW_16: begin
                data_rd = {{48{vs2_elements[0][15]}}, vs2_elements[0][15:0]};
            end
            SEW_32: begin
                data_rd = {{32{vs2_elements[0][31]}}, vs2_elements[0][31:0]};
            end
            SEW_64: begin
                data_rd = vs2_elements[0];
            end
        endcase
    end 

    
    // else if (instr_to_out.instr.instr_type == VEXT) begin
    //     //Extract element specified by rs1
    //     case (instr_to_out.sew)
    //         SEW_8: begin
    //             if (instr_to_out.data_rs1 >= (VELEMENTS*8)) begin
    //                 ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
    //             end else begin
    //                 ext_element = vs2_elements[(instr_to_out.data_rs1[$clog2(VELEMENTS*8)-1:0]/8)];
    //             end
    //             case(instr_to_out.data_rs1[$clog2(VELEMENTS*8)-1:0]%8)
    //                 3'b000: data_rd = {56'h0,ext_element[7:0]};
    //                 3'b001: data_rd = {56'h0,ext_element[15:8]};
    //                 3'b010: data_rd = {56'h0,ext_element[23:16]};
    //                 3'b011: data_rd = {56'h0,ext_element[31:24]};
    //                 3'b100: data_rd = {56'h0,ext_element[39:32]};
    //                 3'b101: data_rd = {56'h0,ext_element[47:40]};
    //                 3'b110: data_rd = {56'h0,ext_element[55:48]};
    //                 3'b111: data_rd = {56'h0,ext_element[63:56]};
    //             endcase
    //         end
    //         SEW_16: begin
    //             if (instr_to_out.data_rs1 >= (VELEMENTS*4)) begin
    //                 ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
    //             end else begin
    //                 ext_element = vs2_elements[(instr_to_out.data_rs1[$clog2(VELEMENTS*4)-1:0]/4)];
    //             end
    //             case(instr_to_out.data_rs1[$clog2(VELEMENTS*4)-1:0]%4)
    //                 2'b00: data_rd = {48'h0,ext_element[15:0]};
    //                 2'b01: data_rd = {48'h0,ext_element[31:16]};
    //                 2'b10: data_rd = {48'h0,ext_element[47:32]};
    //                 2'b11: data_rd = {48'h0,ext_element[63:48]};
    //             endcase
    //         end
    //         SEW_32: begin
    //             if (instr_to_out.data_rs1 >= (VELEMENTS*2)) begin
    //                 ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
    //             end else begin
    //                 ext_element = vs2_elements[(instr_to_out.data_rs1[$clog2(VELEMENTS*2)-1:0]/2)];
    //             end
    //             case(instr_to_out.data_rs1[$clog2(VELEMENTS*2)-1:0]%2)
    //                 1'b0: data_rd = {32'h0,ext_element[31:0]};
    //                 1'b1: data_rd = {32'h0,ext_element[63:32]};
    //             endcase
    //         end
    //         SEW_64: begin
    //             if (instr_to_out.data_rs1 >= VELEMENTS) begin
    //                 data_rd = 'h0; //If the element to extract is bigger than the number of elements, extract 0
    //             end else begin
    //                 data_rd = vs2_elements[instr_to_out.data_rs1[$clog2(VELEMENTS)-1:0]];
    //             end
    //         end
    //     endcase
    // end 
    else if (instr_to_out.instr.instr_type == VCNT) begin
        //Vector count equals
        //Uses the result of the FUs, which performed a vseq, and counts
        //consecutive '1's
        data_rd = 0;
        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i = 0; i<(VLEN/8); ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
            SEW_16: begin
                for (int i = 0; i<(VLEN/16); ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
            SEW_32: begin
                for (int i = 0; i<(VLEN/32); ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
            SEW_64: begin
                for (int i = 0; i<(VLEN/64); ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
        endcase
    end else if (instr_to_out.instr.instr_type == VPOPC) begin
        if((instruction_i.instr.vl == 0)) begin
            data_rd = '0;
        end else begin
            data_rd = data_vpopc_rd;
        end
    end else if (instr_to_out.instr.instr_type == VFIRST) begin
        // VFIRST directly returns a scalar value
        data_rd = result_vfirst;
    end else begin
        data_rd = 64'b0;
    end
end

`ifdef VBPM_ENABLE
bus_simd_t data_vbpm;
// VBPM
vbpm vbpm_inst (
    .data_vs1_i    (instruction_i.data_vs1),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_vd_o     (data_vbpm)
);
`endif

// Vector Reduction Module
bus_simd_t red_data_vd;

vredtree vredtree_inst(
    .clk_i         (clk_i),
    .rstn_i        (rstn_i),
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .vl_i          (instruction_i.instr.vl),
    .data_vs1_i    (instruction_i.data_vs1),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_old_vd   (instruction_i.data_old_vd),
    .data_vm_i     (instruction_i.data_vm),
    .instr_to_out_i(instr_to_out.instr.instr_type),
    .vl_to_out_i   (instr_to_out.instr.vl),
    .sew_to_out_i  (instr_to_out.instr.sew),
    .red_data_vd_o (red_data_vd)
);

bus_simd_t data_viota_vd;
viota viota_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_old_vd   (instruction_i.data_old_vd),
    .data_vm_i     (instruction_i.data_vm),
    .use_mask_i    (instruction_i.instr.use_mask),
    .data_vd_o     (data_viota_vd)
);
bus64_t result_vmsbf;
vmsb_i_o_f vmsbf_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_vm       (instruction_i.data_vm),
    .use_mask      (instruction_i.instr.use_mask),
    .data_vd_o     (result_vmsbf)
);


bus_simd_t result_data_vd;
bus64_t shift_amount_in_vslide;
bus64_t gather_index;
always_comb begin
    shift_amount_in_vslide = 'h0;
    gather_index = 'h0;
    if (is_vred(instr_to_out)) begin
        result_data_vd = red_data_vd;
    end else if (instr_to_out.instr.instr_type == VIOTA) begin
        result_data_vd = data_viota_vd;        
    end else if (instr_to_out.instr.instr_type == VMV_S_X) begin
        case (instr_to_out.instr.sew)
            SEW_8: begin
                if (instr_to_out.instr.vta) begin
                    result_data_vd = {{(VLEN-8){1'b1}}, instruction_i.data_rs1[7:0]};
                end else begin
                    result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):8], instruction_i.data_rs1[7:0]};
                end
            end
            SEW_16: begin
                if (instr_to_out.instr.vta) begin
                    result_data_vd = {{(VLEN-16){1'b1}}, instruction_i.data_rs1[15:0]};
                end else begin
                    result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):16], instruction_i.data_rs1[15:0]};
                end
            end
            SEW_32: begin
                if (instr_to_out.instr.vta) begin
                    result_data_vd = {{(VLEN-32){1'b1}}, instruction_i.data_rs1[31:0]};
                end else begin
                    result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):32], instruction_i.data_rs1[31:0]};
                end
            end
            SEW_64: begin
                if (instr_to_out.instr.vta) begin
                    result_data_vd = {{(VLEN-64){1'b1}}, instruction_i.data_rs1[63:0]};
                end else begin
                    result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):64], instruction_i.data_rs1[63:0]};
                end
            end
            default: begin
                result_data_vd = '0; 
            end
        endcase  
    `ifdef VBPM_ENABLE
    end else if (instr_to_out.instr.instr_type == VBPM) begin
        result_data_vd = data_vbpm;
    end else if (instr_to_out.instr.instr_type == VPIG) begin
        result_data_vd = {instr_to_out.data_vs2[(VLEN-1) -: 2], instr_to_out.data_vs1[(VLEN-3):0]};
    `endif
    end else if ((instr_to_out.instr.instr_type == VMORN) || (instr_to_out.instr.instr_type == VMNOR) ||
                 (instr_to_out.instr.instr_type == VMANDN) || (instr_to_out.instr.instr_type == VMNAND) ||
                 (instr_to_out.instr.instr_type == VMAND) || (instr_to_out.instr.instr_type == VMOR) ||
                 (instr_to_out.instr.instr_type == VMXOR) || (instr_to_out.instr.instr_type == VMXNOR)) begin
        result_data_vd = '1;
        result_data_vd[63:0] = fu_data_vd[63:0]; // Works with VLEN up to 512, higher than that requires concatenation of results from FU
    end else if ((instr_to_out.instr.instr_type == VMSBF) || (instr_to_out.instr.instr_type == VMSIF) ||
                 (instr_to_out.instr.instr_type == VMSOF)) begin
        result_data_vd = '1;
        result_data_vd[63:0] = result_vmsbf[63:0];   
    end else if ((instr_to_out.instr.instr_type == VMSEQ)  || (instr_to_out.instr.instr_type == VMSNE) ||
                 (instr_to_out.instr.instr_type == VMSLTU) || (instr_to_out.instr.instr_type == VMSLT) || 
                 (instr_to_out.instr.instr_type == VMSLEU) || (instr_to_out.instr.instr_type == VMSLE) ||
                 (instr_to_out.instr.instr_type == VMSGTU) || (instr_to_out.instr.instr_type == VMSGT)) begin
        result_data_vd = '1;
        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
                    result_data_vd[i*8 +: 8] = fu_data_vd[i*DATA_SIZE +: 8];
                end
            end
            SEW_16: begin
                for (int i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
                    result_data_vd[i*4 +: 4] = fu_data_vd[i*DATA_SIZE +: 4];
                end
            end
            SEW_32: begin
                for (int i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
                    result_data_vd[i*2 +: 2] = fu_data_vd[i*DATA_SIZE +: 2];
                end
            end
            SEW_64: begin
                for (int i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
                    result_data_vd[i] = fu_data_vd[i*DATA_SIZE];
                end
            end
            default: begin
                result_data_vd = '0;
            end
        endcase
    end else if ((instr_to_out.instr.instr_type == VZEXT_VF2) || (instr_to_out.instr.instr_type == VZEXT_VF4) || (instr_to_out.instr.instr_type == VZEXT_VF8) ||
                (instr_to_out.instr.instr_type == VSEXT_VF2) || (instr_to_out.instr.instr_type == VSEXT_VF4) || (instr_to_out.instr.instr_type == VSEXT_VF8)) begin
        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i = 0; i<(VLEN/8); ++i) begin
                    if ((instr_to_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*8) +: 8] = {{{4{fu_data_vd[((8*(i+1))/2)-1]}}, fu_data_vd[(i*4)+:4]}};
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*8) +: 8] = {{{4{1'b0}}, fu_data_vd[(i*4)+:4]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*8) +: 8] = {{{6{fu_data_vd[((8*(i+1))/4)-1]}}, fu_data_vd[(i*2)+:2]}};
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*8) +: 8] = {{{6{1'b0}}, fu_data_vd[(i*2)+:2]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*8) +: 8] = {{{7{fu_data_vd[((16*(i+1))/8)-1]}}, fu_data_vd[(i*1)+:1]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*8) +: 8] = {{{7{1'b0}}}, fu_data_vd[(i*1)+:1]};
                    end
                end
            end
            SEW_16: begin
                for (int i = 0; i<(VLEN/16); ++i) begin
                    if ((instr_to_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*16) +: 16] = {{{8{fu_data_vd[((16*(i+1))/2)-1]}}, fu_data_vd[(i*8)+:8]}};
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*16) +: 16] = {{{8{1'b0}}, fu_data_vd[(i*8)+:8]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*16) +: 16] = {{{12{fu_data_vd[((16*(i+1))/4)-1]}}, fu_data_vd[(i*4)+:4]}};
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*16) +: 16] = {{{12{1'b0}}, fu_data_vd[(i*4)+:4]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*16) +: 16] = {{{14{fu_data_vd[((16*(i+1))/8)-1]}}, fu_data_vd[(i*2)+:2]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*16) +: 16] = {{{14{1'b0}}}, fu_data_vd[(i*2)+:2]};
                    end
                end
            end
            SEW_32: begin
                for (int i = 0; i<(VLEN/32); ++i) begin
                    if ((instr_to_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{16{fu_data_vd[((32*(i+1))/2)-1]}}, fu_data_vd[(i*16)+:16]}};
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{16{1'b0}}, fu_data_vd[(i*16)+:16]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{24{fu_data_vd[((32*(i+1))/4)-1]}}, fu_data_vd[(i*8)+:8]}};
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{24{1'b0}}, fu_data_vd[(i*8)+:8]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{28{fu_data_vd[((32*(i+1))/8)-1]}}, fu_data_vd[(i*4)+:4]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{28{1'b0}}}, fu_data_vd[(i*4)+:4]};
                    end
                end
            end
            SEW_64: begin
                for (int i = 0; i<(VLEN/64); ++i) begin
                    if ((instr_to_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{32{fu_data_vd[((64*(i+1))/2)-1]}}, fu_data_vd[(i*32)+:32]}};                                     
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{32{1'b0}}, fu_data_vd[(i*32)+:32]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{48{fu_data_vd[((64*(i+1))/4)-1]}}, fu_data_vd[(i*16)+:16]}};                                 
                    end else if((instr_to_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{48{1'b0}}, fu_data_vd[(i*16)+:16]}};
                    end else if ((instr_to_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{56{fu_data_vd[((64*(i+1))/8)-1]}}, fu_data_vd[(i*8)+:8]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{56{1'b0}}}, fu_data_vd[(i*8)+:8]};
                    end
                end
            end    
            default: begin
                result_data_vd = '0;
            end
        endcase
    end 
    else if (instr_to_out.instr.instr_type == VSLIDEUP) begin
        result_data_vd = instr_to_out.data_old_vd;
        shift_amount_in_vslide = 0;
        if(instr_to_out.instr.is_opvi) begin
            shift_amount_in_vslide = instruction_i.instr.imm[4:0];
        end
        else if(instr_to_out.instr.is_opvx) begin
            shift_amount_in_vslide = instruction_i.data_rs1;
        end
        else begin // To avoid creating a latch
            shift_amount_in_vslide = '0;
        end


        case (instr_to_out.instr.sew)
            SEW_8: begin
                if(shift_amount_in_vslide < (VLEN/8)) begin
                    for (int i = 0; i < (VLEN/8) ; ++i) begin
                        if((i + shift_amount_in_vslide) < (VLEN/8)  ) begin
                            result_data_vd[(i + shift_amount_in_vslide) * 8 +: 8] = instruction_i.data_vs2[i * 8 +: 8];
                        end

                    end
                end
            end
            SEW_16: begin
                if(shift_amount_in_vslide < (VLEN/16)) begin
                    for (int i = 0; i < (VLEN/16) ; ++i) begin
                            if((i + shift_amount_in_vslide) < (VLEN/16)  ) begin
                                result_data_vd[(i + shift_amount_in_vslide) * 16 +: 16] = instruction_i.data_vs2[i * 16 +: 16];
                            end

                    end
                end
            end
            SEW_32: begin
                if(shift_amount_in_vslide < (VLEN/32)) begin
                    for (int i = 0; i < (VLEN/32) ; ++i) begin
                            if((i + shift_amount_in_vslide) < (VLEN/32)  ) begin
                                result_data_vd[(i + shift_amount_in_vslide) * 32 +: 32] = instruction_i.data_vs2[i * 32 +: 32];
                            end

                    end
                end
            end
            SEW_64: begin
                if(shift_amount_in_vslide < (VLEN/64)) begin
                    for (int i = 0; i < (VLEN/64) ; ++i) begin
                            if((i + shift_amount_in_vslide) < (VLEN/64)  ) begin
                                result_data_vd[(i + shift_amount_in_vslide) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                            end

                    end
                end
            end

            default: begin
                if(shift_amount_in_vslide < (VLEN/64)) begin
                    for (int i = 0; i < (VLEN/64) ; ++i) begin
                            if((i + shift_amount_in_vslide) < (VLEN/64)  ) begin
                                result_data_vd[(i + shift_amount_in_vslide) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                            end

                    end
                end
            end
        endcase
    end else if (instr_to_out.instr.instr_type == VSLIDEDOWN) begin
        result_data_vd = 0;
        shift_amount_in_vslide = 0;

        if(instr_to_out.instr.is_opvi) begin
            shift_amount_in_vslide = instruction_i.instr.imm[4:0];
        end
        else if(instr_to_out.instr.is_opvx) begin
            shift_amount_in_vslide = instruction_i.data_rs1;
        end
        else begin // To avoid an unwanted latch
            shift_amount_in_vslide = '0;
        end
        case (instr_to_out.instr.sew)
            SEW_8: begin
                if(shift_amount_in_vslide < (VLEN/8)) begin

                    for (int i = 0; i < (VLEN/8) ; ++i) begin
                        if(((i - shift_amount_in_vslide[31:0]) < (instr_to_out.instr.vl)) && ((i - shift_amount_in_vslide[31:0]) >= (0))) begin
                            result_data_vd[(i - shift_amount_in_vslide) * 8 +: 8] = instruction_i.data_vs2[i * 8 +: 8];
                        end

                    end


                end
            end
            SEW_16: begin
                if(shift_amount_in_vslide < (VLEN/16)) begin

                    for (int i = 0; i < (VLEN/16) ; ++i) begin
                        if(((i - shift_amount_in_vslide[31:0]) < (instr_to_out.instr.vl)) && ((i - shift_amount_in_vslide[31:0]) >= (0))) begin
                            result_data_vd[(i - shift_amount_in_vslide) * 16 +: 16] = instruction_i.data_vs2[i * 16 +: 16];
                        end

                    end


                end
            end
            SEW_32: begin
                if(shift_amount_in_vslide < (VLEN/32)) begin

                    for (int i = 0; i < (VLEN/32) ; ++i) begin
                        if(((i - shift_amount_in_vslide[31:0]) < (instr_to_out.instr.vl)) && ((i - shift_amount_in_vslide[31:0]) >= (0))) begin
                            result_data_vd[(i - shift_amount_in_vslide) * 32 +: 32] = instruction_i.data_vs2[i * 32 +: 32];
                        end

                    end


                end
            end
            SEW_64: begin
                if(shift_amount_in_vslide < (VLEN/64)) begin

                    for (int i = 0; i < (VLEN/64) ; ++i) begin
                        if(((i - shift_amount_in_vslide[31:0]) < (instr_to_out.instr.vl)) && ((i - shift_amount_in_vslide[31:0]) >= (0))) begin
                            result_data_vd[(i - shift_amount_in_vslide) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                        end

                    end


                end
            end

            default: begin
                if(shift_amount_in_vslide < (VLEN/64)) begin

                    for (int i = 0; i < (VLEN/64) ; ++i) begin
                        if(((i - shift_amount_in_vslide[31:0]) < (instr_to_out.instr.vl)) && ((i - shift_amount_in_vslide[31:0]) >= (0))) begin
                            result_data_vd[(i - shift_amount_in_vslide) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                        end

                    end


                end
            end

        endcase
    end 
    else if (instr_to_out.instr.instr_type == VSLIDE1UP) begin
        //Forood: This instruction can easily be fused with VLSIDE1DOWN
        // I coded them seperatly in order to keep things clean and understandable in case
        result_data_vd = '0;
        
        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i = 0 ; i < ((VLEN/8) - 1) ; ++i) begin
                   if(i < (instr_to_out.instr.vl - 1)) begin    
                        result_data_vd[(i + 1) * 8 +: 8] = instruction_i.data_vs2[i * 8 +: 8];
                    end 
                end
                result_data_vd[0 +: 8] = instruction_i.data_rs1[7:0];
            end
            SEW_16: begin
                for (int i = 0 ; i < ((VLEN/16) - 1) ; ++i) begin
                    if(i < (instr_to_out.instr.vl - 1)) begin
                        result_data_vd[(i + 1) * 16 +: 16] = instruction_i.data_vs2[i * 16 +: 16];
                    end
                end
                result_data_vd[0 +: 16] = instruction_i.data_rs1[15:0];
            end
            SEW_32: begin
                for (int i = 0 ; i < ((VLEN/32) - 1) ; ++i) begin
                    if(i < (instr_to_out.instr.vl - 1)) begin
                        result_data_vd[(i + 1) * 32 +: 32] = instruction_i.data_vs2[i * 32 +: 32];
                    end
                end
                result_data_vd[0 +: 32] = instruction_i.data_rs1[31:0];
            end
            SEW_64: begin
                for (int i = 0 ; i < ((VLEN/64) - 1) ; ++i) begin
                    if(i < (instr_to_out.instr.vl - 1)) begin    
                        result_data_vd[(i + 1) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                    end
                end
                result_data_vd[0 +: 64] = instruction_i.data_rs1[63:0];
            end
            default: begin
                for (int i = 0 ; i < ((VLEN/64) - 1) ; ++i) begin
                    if(i < (instr_to_out.instr.vl - 1)) begin    
                        result_data_vd[(i + 1) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                    end
                end
                result_data_vd[0 +: 64] = instruction_i.data_rs1[63:0];
            end
        endcase
    end 
    else if (instr_to_out.instr.instr_type == VSLIDE1DOWN) begin
        //Forood: This instruction can easily be fused with VLSIDE1DUP
        // I coded them seperatly in order to keep things clean and understandable in case
        // future debugging is needed.
        result_data_vd = '0;
        case (instr_to_out.instr.sew)
            SEW_8: begin                 
                    for (int i = 1 ; i < (VLEN/8)  ; ++i) begin
                        if (i < instr_to_out.instr.vl) begin
                            result_data_vd[(i - 1) * 8 +: 8] = instruction_i.data_vs2[i * 8 +: 8];
                        end
                    end
                    result_data_vd[trunc_vl_i_sew8(instr_to_out.instr.vl - 1) * 8 +: 8] = instruction_i.data_rs1[7:0];
                    

            end
            SEW_16: begin
                for (int i = 1 ; i < (VLEN/16)  ; ++i) begin
                        if (i < instr_to_out.instr.vl) begin
                            result_data_vd[(i - 1) * 16 +: 16] = instruction_i.data_vs2[i * 16 +: 16];
                        end
                    end
                    result_data_vd[trunc_vl_i_sew16(instr_to_out.instr.vl - 1) * 16 +: 16] = instruction_i.data_rs1[15:0];
                    
            end
            SEW_32: begin
                for (int i = 1 ; i < (VLEN/32)  ; ++i) begin
                        if (i < instr_to_out.instr.vl) begin
                            result_data_vd[(i - 1) * 32 +: 32] = instruction_i.data_vs2[i * 32 +: 32];
                        end
                    end
                    result_data_vd[trunc_vl_i_sew32(instr_to_out.instr.vl - 1) * 32 +: 32] = instruction_i.data_rs1[31:0];
            end
            SEW_64: begin
                for (int i = 1 ; i < (VLEN/64)  ; ++i) begin
                        if (i < instr_to_out.instr.vl) begin
                            result_data_vd[(i - 1) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                        end
                    end
                    result_data_vd[trunc_vl_i_sew64(instr_to_out.instr.vl - 1) * 64 +: 64] = instruction_i.data_rs1[63:0];
            end

            default: begin
                for (int i = 1 ; i < (VLEN/64)  ; ++i) begin
                        if (i < instr_to_out.instr.vl) begin
                            result_data_vd[(i - 1) * 64 +: 64] = instruction_i.data_vs2[i * 64 +: 64];
                        end
                    end
                    result_data_vd[trunc_vl_i_sew64(instr_to_out.instr.vl - 1) * 64 +: 64] = instruction_i.data_rs1[63:0];
                
            end
        endcase
    end 
    else if ((instr_to_out.instr.instr_type == VRGATHER) && (~instr_to_out.instr.is_opvx) && (~instr_to_out.instr.is_opvi)) begin
        result_data_vd = '0;
        
        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i = 0 ; i < (VLEN/8)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 8) +: 8]) < instruction_i.instr.vlmax) begin
                        //Forood : this line and lines like this that can be seen in the VRGATHER and VRGATHER16 has a problem that needs to be sloved
                        // because the $clog2(VLEN/8) can become greater than 8 bits if the VLEN goes beyond 2048 and a min function must be used
                        result_data_vd[(i * 8) +: 8] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 8) +: min_unsigned($clog2(VLEN/8), 8)]) * 8 +: 8];
                    end
                    else begin
                        result_data_vd[(i * 8) +: 8] = 0;
                    end
                end
                
            end
            SEW_16: begin
                for (int i = 0 ; i < (VLEN/16)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 16) +: 16]) < instruction_i.instr.vlmax) begin
                        result_data_vd[(i * 16) +: 16] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 16) +: min_unsigned($clog2(VLEN/16), 16)]) * 16 +: 16];
                    end
                    else begin
                        result_data_vd[(i * 16) +: 16] = 0;
                    end
                end
            end
            SEW_32: begin
                for (int i = 0 ; i < (VLEN/32)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 32) +: 32]) < instruction_i.instr.vlmax) begin
                        result_data_vd[(i * 32) +: 32] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 32) +: min_unsigned($clog2(VLEN/32), 32)]) * 32 +: 32];
                    end
                    else begin
                        result_data_vd[(i * 32) +: 32] = 0;
                    end
                end
            end
            SEW_64: begin
                for (int i = 0 ; i < (VLEN/64)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 64) +: 64]) < instruction_i.instr.vlmax) begin
                        result_data_vd[(i * 64) +: 64] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 64) +: min_unsigned($clog2(VLEN/64), 64)]) * 64 +: 64];
                    end
                    else begin
                        result_data_vd[(i * 64) +: 64] = 0;
                    end
                end
            end
        endcase
    end 
    else if (instr_to_out.instr.instr_type == VRGATHEREI16) begin
        result_data_vd = 0;
        //Forood: don't know what to do when the SEW < 16 because there are more elements than indexes, at the moment they are left
        // untouched but they may be forced to set to 0
        // also when sew > 16 there are more indexes than elements, so at the moment only (VLEN/SEW) first elements are checked 


        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i = 0 ; i < (VLEN/16)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 16) +: 16]) < (VLEN/8)) begin
                        result_data_vd[(i * 8) +: 8] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 16) +: min_unsigned($clog2(VLEN/8), 16)]) * 8 +: 8];
                    end
                    else begin
                        result_data_vd[(i * 8) +: 8] = 0;
                    end
                end
                
            end
            SEW_16: begin
                for (int i = 0 ; i < (VLEN/16)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 16) +: 16]) < (VLEN/16)) begin
                        result_data_vd[(i * 16) +: 16] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 16) +: min_unsigned($clog2(VLEN/16), 16)]) * 16 +: 16];
                    end
                    else begin
                        result_data_vd[(i * 16) +: 16] = 0;
                    end
                end
            end
            SEW_32: begin
                for (int i = 0 ; i < (VLEN/32)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 16) +: 16]) < (VLEN/32)) begin
                        result_data_vd[(i * 32) +: 32] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 16) +: min_unsigned($clog2(VLEN/32), 16)]) * 32 +: 32];
                    end
                    else begin
                        result_data_vd[(i * 32) +: 32] = 0;
                    end
                end
            end
            SEW_64: begin
                for (int i = 0 ; i < (VLEN/64)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 16) +: 16]) < (VLEN/64)) begin
                        result_data_vd[(i * 64) +: 64] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 16) +: min_unsigned($clog2(VLEN/64), 16)]) * 64 +: 64];
                    end
                    else begin
                        result_data_vd[(i * 64) +: 64] = 0;
                    end
                end
            end
            default: begin
                for (int i = 0 ; i < (VLEN/64)  ; ++i) begin
                    if((instruction_i.data_vs1[(i * 16) +: 16]) < (VLEN/64)) begin
                        result_data_vd[(i * 64) +: 64] = instruction_i.data_vs2[(instruction_i.data_vs1[(i * 16) +: min_unsigned($clog2(VLEN/64), 16)]) * 64 +: 64];
                    end
                    else begin
                        result_data_vd[(i * 64) +: 64] = 0;
                    end
                end
            end
        endcase
    end

    else if ((instr_to_out.instr.instr_type == VRGATHER) && ((instr_to_out.instr.is_opvx) || (instr_to_out.instr.is_opvi))) begin
        result_data_vd = 0;

        gather_index = 0;
        if(instr_to_out.instr.is_opvi) begin
            gather_index = instruction_i.instr.imm[4:0];
        end
        if(instr_to_out.instr.is_opvx) begin
            gather_index = instruction_i.data_rs1;
        end

        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i = 0 ; i < (VLEN/8)  ; ++i) begin
                    if((gather_index) < (VLEN/8)) begin
                        result_data_vd[(i * 8) +: 8] = instruction_i.data_vs2[(gather_index) * 8 +: 8];
                    end
                    else begin
                        result_data_vd[(i * 8) +: 8] = 0;
                    end
                end     
            end
            SEW_16: begin
                for (int i = 0 ; i < (VLEN/16)  ; ++i) begin
                    if((gather_index) < (VLEN/16)) begin
                        result_data_vd[(i * 16) +: 16] = instruction_i.data_vs2[(gather_index) * 16 +: 16];
                    end
                    else begin
                        result_data_vd[(i * 16) +: 16] = 0;
                    end
                end    
            end
            SEW_32: begin
                for (int i = 0 ; i < (VLEN/32)  ; ++i) begin
                    if((gather_index) < (VLEN/32)) begin
                        result_data_vd[(i * 32) +: 32] = instruction_i.data_vs2[(gather_index) * 32 +: 32];
                    end
                    else begin
                        result_data_vd[(i * 32) +: 32] = 0;
                    end
                end    
            end
            SEW_64: begin
                for (int i = 0 ; i < (VLEN/64)  ; ++i) begin
                    if((gather_index) < (VLEN/64)) begin
                        result_data_vd[(i * 64) +: 64] = instruction_i.data_vs2[(gather_index) * 64 +: 64];
                    end
                    else begin
                        result_data_vd[(i * 64) +: 64] = 0;
                    end
                end    
            end
            default: begin
                for (int i = 0 ; i < (VLEN/64)  ; ++i) begin
                    if((gather_index) < (VLEN/64)) begin
                        result_data_vd[(i * 64) +: 64] = instruction_i.data_vs2[(gather_index) * 64 +: 64];
                    end
                    else begin
                        result_data_vd[(i * 64) +: 64] = 0;
                    end
                end    
            end
        endcase
    end
    else if ((instr_to_out.instr.instr_type == VCOMPRESS)) begin
        result_data_vd = (instr_to_out.instr.vta) ? '1 : instr_to_out.data_old_vd;


        //this variable is used to track the last occupied element of vd
        gather_index = 0;

        case (instr_to_out.instr.sew)
            SEW_8: begin
                for (int i = 0 ; i < (VLEN/8)  ; ++i) begin
                    if((instruction_i.data_vs1[i] == 1'b1) && (i < instr_to_out.instr.vl) ) begin
                        result_data_vd[(gather_index * 8) +: 8] = instruction_i.data_vs2[(i) * 8 +: 8];
                        gather_index = gather_index[62:0] + 1'b1;
                    end
                end     
            end
            SEW_16: begin
                for (int i = 0 ; i < (VLEN/16)  ; ++i) begin
                    if((instruction_i.data_vs1[i] == 1'b1) && (i < instr_to_out.instr.vl) ) begin
                        result_data_vd[(gather_index * 16) +: 16] = instruction_i.data_vs2[(i) * 16 +: 16];
                        gather_index = gather_index[62:0] + 1'b1;
                    end
                end    
            end
            SEW_32: begin
                for (int i = 0 ; i < (VLEN/32)  ; ++i) begin
                    if((instruction_i.data_vs1[i] == 1'b1) && (i < instr_to_out.instr.vl) ) begin
                        result_data_vd[(gather_index * 32) +: 32] = instruction_i.data_vs2[(i) * 32 +: 32];
                        gather_index = gather_index[62:0] + 1'b1;
                    end
                end    
            end
            SEW_64: begin
                for (int i = 0 ; i < (VLEN/64)  ; ++i) begin
                    if((instruction_i.data_vs1[i] == 1'b1) && (i < instr_to_out.instr.vl) ) begin
                        result_data_vd[(gather_index * 64) +: 64] = instruction_i.data_vs2[(i) * 64 +: 64];
                        gather_index = gather_index[62:0] + 1'b1;
                    end
                end   
            end
            default: begin
                for (int i = 0 ; i < (VLEN/64)  ; ++i) begin
                    if((instruction_i.data_vs1[i] == 1'b1) && (i < instr_to_out.instr.vl) ) begin
                        result_data_vd[(gather_index * 64) +: 64] = instruction_i.data_vs2[(i) * 64 +: 64];
                        gather_index = gather_index[62:0] + 1'b1;
                    end
                end   
            end
            
        endcase
    end

    else begin
        result_data_vd = fu_data_vd;
    end
end

bus_simd_t masked_data_vd;
sew_t masked_sew;
//Apply the mask to the vector result
//Unaffected elements are filled with the old vd data
always_comb begin
    if (is_vw(instr_to_out) && (instr_to_out.instr.sew != SEW_64)) begin
        case (instr_to_out.instr.sew)
            SEW_8: masked_sew = SEW_16;
            SEW_16: masked_sew = SEW_32;
            SEW_32: masked_sew = SEW_64;
            default: masked_sew = SEW_64;
        endcase
    end else begin
        masked_sew = instr_to_out.instr.sew;
    end

    if (is_vred(instr_to_out) || not_masked_output(instr_to_out)|| ~instr_to_out.instr.use_mask) begin
        masked_data_vd = result_data_vd;
    end else if (is_vm(instr_to_out)) begin
        //masked_data_vd = '1;
        masked_data_vd = (instr_to_out.instr.vma) ? '1 : instr_to_out.data_old_vd;
        case (masked_sew)
            SEW_8: begin
                for (int i = 0; i<(VLEN/8); ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
            SEW_16: begin
                for (int i = 0; i<(VLEN/16); ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
            SEW_32: begin
                for (int i = 0; i<(VLEN/32); ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
            SEW_64: begin
                for (int i = 0; i<(VLEN/64); ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
        endcase
    end else begin
        masked_data_vd = (instr_to_out.instr.instr_type == VMERGE) ? instr_to_out.data_vs2 : instr_to_out.data_old_vd;
        case (masked_sew)
            SEW_8: begin
                for (int i = 0; i<(VLEN/8); ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(8*i)+:8] = result_data_vd[(8*i)+:8];
                    end
                end
            end
            SEW_16: begin
                for (int i = 0; i<(VLEN/16); ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(16*i)+:16] = result_data_vd[(16*i)+:16];
                    end
                end
            end
            SEW_32: begin
                for (int i = 0; i<(VLEN/32); ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(32*i)+:32] = result_data_vd[(32*i)+:32];
                    end
                end
            end
            SEW_64: begin
                for (int i = 0; i<(VLEN/64); ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(64*i)+:64] = result_data_vd[(64*i)+:64];
                    end
                end
            end
        endcase
    end
end

bus_simd_t tail_data_vd;
always_comb begin
    tail_data_vd = (instr_to_out.instr.vta || is_vm(instr_to_out)) ? '1 : instr_to_out.data_old_vd;
    case(masked_sew)
        SEW_8: begin
            for (int i = 0; i<(VLEN/8); ++i) begin
                if ((i < instr_to_out.instr.vl) || (instr_to_out.instr.instr_type == VMV1R)) begin
                    if (is_vm(instr_to_out)) begin
                        tail_data_vd[i] = masked_data_vd[i];
                    end else if (is_vred(instr_to_out)) begin
                        if (i == 0) begin
                            tail_data_vd[(8*i)+:8] = masked_data_vd[(8*i)+:8];
                        end
                    end else begin
                        tail_data_vd[(8*i)+:8] = masked_data_vd[(8*i)+:8];
                    end
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i<(VLEN/16); ++i) begin
                if ((i < instr_to_out.instr.vl) || (instr_to_out.instr.instr_type == VMV1R)) begin
                    if (is_vm(instr_to_out)) begin
                        tail_data_vd[i] = masked_data_vd[i];
                    end else if (is_vred(instr_to_out)) begin
                        if (i == 0) begin
                            tail_data_vd[(16*i)+:16] = masked_data_vd[(16*i)+:16];
                        end
                    end else begin
                        tail_data_vd[(16*i)+:16] = masked_data_vd[(16*i)+:16];
                    end
                end
            end
        end
        SEW_32: begin
            for (int i = 0; i<(VLEN/32); ++i) begin
                if ((i < instr_to_out.instr.vl) || (instr_to_out.instr.instr_type == VMV1R)) begin
                    if (is_vm(instr_to_out)) begin
                        tail_data_vd[i] = masked_data_vd[i];
                    end else if (is_vred(instr_to_out)) begin
                        if (i == 0) begin
                            tail_data_vd[(32*i)+:32] = masked_data_vd[(32*i)+:32];
                        end
                    end else begin
                        tail_data_vd[(32*i)+:32] = masked_data_vd[(32*i)+:32];
                    end
                end
            end
        end
        SEW_64: begin
            for (int i = 0; i<(VLEN/64); ++i) begin
                if ((i < instr_to_out.instr.vl) || (instr_to_out.instr.instr_type == VMV1R)) begin
                    if (is_vm(instr_to_out)) begin
                        tail_data_vd[i] = masked_data_vd[i];
                    end else if (is_vred(instr_to_out)) begin
                        if (i == 0) begin
                            tail_data_vd[(64*i)+:64] = masked_data_vd[(64*i)+:64];
                        end
                    end else begin
                        tail_data_vd[(64*i)+:64] = masked_data_vd[(64*i)+:64];
                    end
                end
            end
        end
    endcase
end

//Produce the scalar and vector wb structs
assign instruction_scalar_o.valid = instr_to_out.instr.valid & 
                                    (instr_to_out.instr.unit == UNIT_SIMD) & 
                                    instr_to_out.instr.regfile_we;
assign instruction_scalar_o.pc    = instr_to_out.instr.pc;
assign instruction_scalar_o.bpred = instr_to_out.instr.bpred;
assign instruction_scalar_o.rs1   = instr_to_out.instr.rs1;
assign instruction_scalar_o.rd    = instr_to_out.instr.rd;
assign instruction_scalar_o.result = data_rd;
assign instruction_scalar_o.regfile_we = instr_to_out.instr.regfile_we;
assign instruction_scalar_o.instr_type = instr_to_out.instr.instr_type;
assign instruction_scalar_o.stall_csr_fence = instr_to_out.instr.stall_csr_fence;
assign instruction_scalar_o.csr_addr = instr_to_out.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_scalar_o.prd = instr_to_out.prd;
assign instruction_scalar_o.checkpoint_done = instr_to_out.checkpoint_done;
assign instruction_scalar_o.chkp = instr_to_out.chkp;
assign instruction_scalar_o.gl_index = instr_to_out.gl_index;
assign instruction_scalar_o.branch_taken = 1'b0;
assign instruction_scalar_o.result_pc = 0;
assign instruction_scalar_o.fp_status = 0;
assign instruction_scalar_o.mem_type = NOT_MEM;
assign instruction_scalar_o.vl = instr_to_out.instr.vl;
assign instruction_scalar_o.sew = instr_to_out.instr.sew;
`ifdef SIM_KONATA_DUMP
assign instruction_scalar_o.id = instr_to_out.instr.id;
`endif

assign instruction_simd_o.valid = instr_to_out.instr.valid & 
                                  (instr_to_out.instr.unit == UNIT_SIMD) & 
                                  instr_to_out.instr.vregfile_we;
assign instruction_simd_o.pc    = instr_to_out.instr.pc;
assign instruction_simd_o.bpred = instr_to_out.instr.bpred;
assign instruction_simd_o.rs1   = instr_to_out.instr.rs1;
assign instruction_simd_o.vd    = instr_to_out.instr.vd;
assign instruction_simd_o.vresult = tail_data_vd;
assign instruction_simd_o.vregfile_we = instr_to_out.instr.vregfile_we;
assign instruction_simd_o.instr_type = instr_to_out.instr.instr_type;
assign instruction_simd_o.stall_csr_fence = instr_to_out.instr.stall_csr_fence;
assign instruction_simd_o.csr_addr = instr_to_out.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_simd_o.pvd = instr_to_out.pvd;
assign instruction_simd_o.checkpoint_done = instr_to_out.checkpoint_done;
assign instruction_simd_o.chkp = instr_to_out.chkp;
assign instruction_simd_o.gl_index = instr_to_out.gl_index;
assign instruction_simd_o.branch_taken = 1'b0;
assign instruction_simd_o.result_pc = 0;
assign instruction_simd_o.vs_ovf = v_sat_ovf != 0;
assign instruction_simd_o.vl = instr_to_out.instr.vl;
assign instruction_simd_o.sew = instr_to_out.instr.sew;
`ifdef SIM_KONATA_DUMP
assign instruction_simd_o.id = instr_to_out.instr.id;
`endif

//Exceptions
always_comb begin
    instruction_scalar_o.ex.cause = INSTR_ADDR_MISALIGNED;
    instruction_scalar_o.ex.origin = 0;
    instruction_scalar_o.ex.valid = 0;
    instruction_simd_o.ex.cause = INSTR_ADDR_MISALIGNED;
    instruction_simd_o.ex.origin = 0;
    instruction_simd_o.ex.valid = 0;
end

endmodule
