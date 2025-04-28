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
 import drac_pkg::*;
 import riscv_pkg::*;
 
 module score_board_simd (
     input logic                    clk_i,
     input logic                    rstn_i,
     input logic                    flush_i,
 
     // INPUTS
     input  logic                         ready_i,            // Instruction valid and ready to be issued to SIMD unit
     input  rr_exe_simd_instr_t            instr_entry_i,      // Instruction entry
     //input  instr_entry_t           instr_entry_i,      
     input  sew_t                          sew_i,              // SEW: 00 for 8 bits, 01 for 16 bits, 10 for 32 bits, 11 for 64 bits
     input  logic [VMAXELEM_LOG:0]  vl_i,           // Vector Lenght
 
     // OUTPUTS
     output logic [5:0]             simd_exe_stages_o, 
     output logic                   stall_simd_o        // Stall pipeline
 );

localparam int MAX_STAGES = $clog2(VLEN/8) + 2;  // Number of stages based on the minimum SEW
localparam int DIV_STAGES = 32;                 // number of clocks a DIV/REM instruction takes


typedef struct packed {
    logic valid;
    `ifdef VERILATOR
    instr_type_t simd_instr_type;
    `endif
} instr_pipe_t;

instr_pipe_t simd_pipe_d [MAX_STAGES:2][MAX_STAGES-2:0];
instr_pipe_t simd_pipe_q [MAX_STAGES:2][MAX_STAGES-2:0];

// This pipeline is taking care of in-flight DIV/REM instructions
// it's seperated from other instructions as DIV/REM is way more time consuming
// than other instructions.
// The behaviour and managment of this pipeline is alike the simd_pipe
// the differences are explained
instr_pipe_t division_pipe_d [DIV_STAGES - 2:0];
instr_pipe_t division_pipe_q [DIV_STAGES - 2:0];


logic [5:0] simd_exe_stages;
logic is_vmul;
logic is_vred;
logic is_vmadd_vsmul;
logic is_vdiv;

logic stall_simd;

// here we save the content of the previous Div/Rem and in case a Rem is happening after a Div with the same operands
// we can set the result in the next clock since it has been already computed.

bus64_t previous_div_rs1_q;                 // Register Source 1  of previous div/rem
bus64_t previous_div_rs1_d;                 // Register Source 1  of previous div/rem

bus_simd_t previous_div_vs1_q;                // VRegister Source 1 of previous div/rem
bus_simd_t previous_div_vs1_d;                // VRegister Source 1 of previous div/rem

bus_simd_t previous_div_vs2_q;                // VRegister Source 2 of previous div/rem
bus_simd_t previous_div_vs2_d;                // VRegister Source 2 of previous div/rem

logic  previous_div_is_opvx_q;            // Instruction uses rs1 instead of vs1 of previous div/rem
logic  previous_div_is_opvx_d;            // Instruction uses rs1 instead of vs1 of previous div/rem

instr_type_t previous_div_instr_type_q;   // Type of instruction of previous div/rem
instr_type_t previous_div_instr_type_d;   // Type of instruction of previous div/rem

// Truncate functions
function [5:0] trunc_stages(input [31:0] val_in);
    trunc_stages = val_in[5:0];
endfunction

function [4:0] trunc_5_bit(input [31:0] val_in);
    trunc_5_bit = val_in[4:0];
endfunction

function [3:0] trunc_33_to_4bits(input [32:0] val_in);
    trunc_33_to_4bits = val_in[3:0];
endfunction

assign is_vmadd_vsmul = ((instr_entry_i.instr.instr_type == VMADD)  ||
                         (instr_entry_i.instr.instr_type == VNMSUB) ||
                         (instr_entry_i.instr.instr_type == VMACC)  ||
                         (instr_entry_i.instr.instr_type == VNMSAC) ||
                         (instr_entry_i.instr.instr_type == VWMACC)  ||
                         (instr_entry_i.instr.instr_type == VWMACCU)  ||
                         (instr_entry_i.instr.instr_type == VWMACCUS)  ||
                         (instr_entry_i.instr.instr_type == VWMACCSU)||
                         (instr_entry_i.instr.instr_type == VSMUL)) ? 1'b1 : 1'b0;

assign is_vdiv =  ((instr_entry_i.instr.instr_type == VDIV )  ||
                   (instr_entry_i.instr.instr_type == VDIVU ) ||
                   (instr_entry_i.instr.instr_type == VREM )  ||
                   (instr_entry_i.instr.instr_type == VREMU)) ? 1'b1 : 1'b0;

assign is_vmul = ((instr_entry_i.instr.instr_type == VWMUL)   ||
                (instr_entry_i.instr.instr_type == VWMULU)   ||
                (instr_entry_i.instr.instr_type == VWMULSU)   ||
                (instr_entry_i.instr.instr_type == VMUL)   ||
                (instr_entry_i.instr.instr_type == VMULH)  ||
                (instr_entry_i.instr.instr_type == VMULHU) ||
                (instr_entry_i.instr.instr_type == VMULHSU)) ? 1'b1 : 1'b0;

assign is_vred = ((instr_entry_i.instr.instr_type == VREDSUM) ||
                (instr_entry_i.instr.instr_type == VREDAND)   ||
                (instr_entry_i.instr.instr_type == VREDOR)    ||
                (instr_entry_i.instr.instr_type == VREDXOR)   ||
                (instr_entry_i.instr.instr_type == VREDMAXU)  ||
                (instr_entry_i.instr.instr_type == VREDMAX)   ||
                (instr_entry_i.instr.instr_type == VREDMINU)  ||
                (instr_entry_i.instr.instr_type == VREDMIN)   ||
                (instr_entry_i.instr.instr_type == VWREDSUM)  ||
                (instr_entry_i.instr.instr_type == VWREDSUMU)) ? 1'b1 : 1'b0;

// This fucntion indicates wehter the current DIV/REM can be done in 1 clock cycle
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



always_comb begin

    previous_div_rs1_d          = previous_div_rs1_q;               
    previous_div_vs1_d          = previous_div_vs1_q;                
    previous_div_vs2_d          = previous_div_vs2_q;                
    previous_div_is_opvx_d      = previous_div_is_opvx_q;            
    previous_div_instr_type_d   = previous_div_instr_type_q;

    if (is_vmul) begin
        simd_exe_stages = (sew_i == SEW_64) ? 6'd3 : 6'd2;
    end 
    else if (is_vmadd_vsmul) begin
        simd_exe_stages = (sew_i == SEW_64) ? 6'd4 : 6'd3;
    end 
    else if (is_vred) begin
        case (sew_i)
            SEW_8 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3) + 2);
            SEW_16 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3) + 1);
            SEW_32 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3));
            SEW_64 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3) - 1);
            default : simd_exe_stages = trunc_stages($clog2(VLEN >> 3));
        endcase
    end else if(is_vdiv) begin

        // Deciding on how many cycles to do the DIV/REM
        if(is_div_1_clock(  .vs1(previous_div_vs1_q), .vs2(previous_div_vs2_q), .rs1(previous_div_rs1_q), .is_opvx(previous_div_is_opvx_q),
        .instr_type(previous_div_instr_type_q), .instr_entry_i(instr_entry_i)) && ready_i) begin

            simd_exe_stages = 6'd1; 
        end
        
        else begin

           simd_exe_stages = 6'd32;                     
        end
        
        // when a new DIV/REM is issued, it's operands are saved
        // for comparision with future DIV/REM
        if((~stall_simd) && ready_i) begin
            previous_div_rs1_d          = instr_entry_i.data_rs1;                 
            previous_div_vs1_d          = instr_entry_i.data_vs1;                
            previous_div_vs2_d          = instr_entry_i.data_vs2;                
            previous_div_is_opvx_d      = instr_entry_i.instr.is_opvx;            
            previous_div_instr_type_d   = instr_entry_i.instr.instr_type;   
    
        end
        else begin
            previous_div_rs1_d          = previous_div_rs1_q;               
            previous_div_vs1_d          = previous_div_vs1_q;                
            previous_div_vs2_d          = previous_div_vs2_q;                
            previous_div_is_opvx_d      = previous_div_is_opvx_q;            
            previous_div_instr_type_d   = previous_div_instr_type_q;   
        end                     
    end else begin
        simd_exe_stages = 6'd1;
    end
end

// Cycle instruction management for those instructions that takes more than 1 cycle
/*
* 2 cycle -> |0|1|
* 3 cycle -> |0|1|2|
* 4 cycle -> |0|1|2|3|
...
*/

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        for (int i=2; i <= MAX_STAGES; i++) begin
            for (int j = 0; j < (MAX_STAGES-1); j++) begin
                simd_pipe_q[i][j] <= '0;
            end
        end

        for (int i = 0; i < (DIV_STAGES - 1); i++) begin
            division_pipe_q[i] <= '0;
        end

        previous_div_rs1_q          <= '0;                
        previous_div_vs1_q          <= '0;               
        previous_div_vs2_q          <= '0;              
        previous_div_is_opvx_q      <= '0;          
        previous_div_instr_type_q   <= ADD; 

    end else begin
        for (int i=2; i <= MAX_STAGES; i++) begin
            for (int j = 0; j < (MAX_STAGES-1); j++) begin
                simd_pipe_q[i][j] <= simd_pipe_d[i][j];
            end
        end
        for (int i = 0; i < (DIV_STAGES - 1); i++) begin
                division_pipe_q[i] <= division_pipe_d[i];
        end


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
        for (int j = 0; j < (MAX_STAGES-1); j++) begin
            if (flush_i) begin
                simd_pipe_d[i][j].valid = 1'b0;
                `ifdef VERILATOR
                simd_pipe_d[i][j].simd_instr_type = ADD;
                `endif
            end else if (j==0) begin
                if (simd_exe_stages == (trunc_stages(i))) begin
                    simd_pipe_d[i][0].valid = ~stall_simd & ready_i & (instr_entry_i.instr.unit == UNIT_SIMD);
                    `ifdef VERILATOR
                    simd_pipe_d[i][0].simd_instr_type = instr_entry_i.instr.instr_type;
                    `endif
                end else begin
                    simd_pipe_d[i][0].valid = 1'b0;
                    `ifdef VERILATOR
                    simd_pipe_d[i][0].simd_instr_type = ADD;
                    `endif
                end
            end else begin
                simd_pipe_d[i][j].valid = simd_pipe_q[i][j-1].valid;
                `ifdef VERILATOR
                simd_pipe_d[i][j].simd_instr_type = simd_pipe_q[i][j-1].simd_instr_type;
                `endif
            end
        end
    end


    for (int j = 0; j < (DIV_STAGES - 1); j++) begin
        if (j==0) begin
            if(is_vdiv && (simd_exe_stages == 6'd32)) begin
                division_pipe_d[0].valid = ~stall_simd & ready_i & (instr_entry_i.instr.unit == UNIT_SIMD);
                `ifdef VERILATOR
                division_pipe_d[0].simd_instr_type = instr_entry_i.instr.instr_type;
                `endif
            end
            else begin
                division_pipe_d[0].valid = 1'b0;
                `ifdef VERILATOR
                division_pipe_d[0].simd_instr_type = ADD;
                `endif
            end
        end else begin
            division_pipe_d[j].valid = division_pipe_q[j-1].valid;
            `ifdef VERILATOR
            division_pipe_d[j].simd_instr_type = division_pipe_q[j-1].simd_instr_type;
            `endif
                 
        end
    end
end

// Management to stall the instruction if necessary (we cannot write back more than 1 simd instruction)
always_comb begin
    stall_simd = 1'b0;
    for (int i = 2; (i <= MAX_STAGES) && (!stall_simd); i++) begin
        if ( ($unsigned(trunc_stages(i)) > $unsigned(simd_exe_stages)) && (simd_pipe_q[i][trunc_stages(i)-simd_exe_stages-1].valid) ) begin
            stall_simd = 1'b1;
        end
    end

    // we do the same checking for the Division pipeline to set stall if needed
    if(division_pipe_q[trunc_5_bit((DIV_STAGES - simd_exe_stages) - 1)].valid) begin
        stall_simd = 1'b1;
    end
    // Since the DIV/REM pipeline is circular and not linear (the same hardware is used in every clock) a new
    // DIV/REM instruction can not be issued while the previous one is still in flight, the check below does this.
    if (is_vdiv && (!stall_simd)) begin
        for (int i = 0; ((i < (DIV_STAGES - 1)) && (!stall_simd)); i++) begin
            if(division_pipe_q[i].valid) begin
                stall_simd = 1'b1;
            end
        end 
    end
end

// Output assignment
assign simd_exe_stages_o = simd_exe_stages;
assign stall_simd_o = stall_simd;
 
 
endmodule
 
 