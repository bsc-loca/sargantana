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
    import fpnew_pkg::*;
(
    input wire                    clk_i,                  // Clock
    input wire                    rstn_i,                 // Reset
    input logic                   flush_i,                // Flush 
    input vxrm_t                  vxrm_i,                 // Vector Fixed-Point Rounding Mode
    input rr_exe_simd_instr_t     instruction_i,          // In instruction 
    output exe_wb_scalar_instr_t  instruction_scalar_o,   // Out instruction
    output exe_wb_simd_instr_t    instruction_simd_o,     // Out instruction
    output logic                  stall_prev_o,
    output logic                  stall_post_o,
    output exe_wb_fp_instr_t      instruction_fp_o        // Out instruction
);

// The vector datapath supports VLEN up to 512: VMAXELEM is 7 bits, vagu counts
// elements in 7 bits and mask operations use the low 64 bits of a register.
if (riscv_pkg::VLEN > 512) begin : g_vlen_check
    $error("VLEN=%0d is not supported (maximum 512)", riscv_pkg::VLEN);
end

// MAX_STAGES has been defined as parameter in drac_pkg
// to avoid duplicity with score_board_simd ex-localparams
localparam int DIV_STAGES = 32;             // number of clocks a DIV/REM instruction takes


bus64_t [drac_pkg::VELEMENTS-1:0] vs1_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] vs2_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] data_vm;
bus64_t [drac_pkg::VELEMENTS-1:0] vd_elements;
bus_simd_t rs1_replicated;
bus_simd_t fu_data_vd;
bus64_t data_rd; //Optimisation: Use just lower bits of fu_data_vd

rr_exe_simd_instr_t instr_to_out; // Output instruction
rr_exe_simd_instr_t instr_to_out_integer;

// floating point variables' declaration
bus_simd_t          fpnew_result;
fpnew_pkg::status_t fpnew_status;
rr_exe_simd_instr_t fpnew_out_instruction;

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
    is_vw = ((instr.instr.instr_type == VWADD)      ||
             (instr.instr.instr_type == VWADDU)     ||
             (instr.instr.instr_type == VWSUB)      ||
             (instr.instr.instr_type == VWSUBU)     ||
             (instr.instr.instr_type == VWADDW)     ||
             (instr.instr.instr_type == VWADDUW)    ||
             (instr.instr.instr_type == VWSUBW)     ||
             (instr.instr.instr_type == VWSUBUW)    ||
             (instr.instr.instr_type == VWREDSUM)   ||
             (instr.instr.instr_type == VWREDSUMU)  ||
             (instr.instr.instr_type == VWMUL)      ||
             (instr.instr.instr_type == VWMULU)     ||
             (instr.instr.instr_type == VWMULSU)    ||
             (instr.instr.instr_type == VWMACC)     ||
             (instr.instr.instr_type == VWMACCU)    ||
             (instr.instr.instr_type == VWMACCSU)   ||
             (instr.instr.instr_type == VWMACCUS)   ||
             (instr.instr.instr_type == VFWADD)     ||
             (instr.instr.instr_type == VFWSUB)     ||
             (instr.instr.instr_type == VFWMUL)     ||
             (instr.instr.instr_type == VFWMACC)    ||
             (instr.instr.instr_type == VFWNMACC)   ||
             (instr.instr.instr_type == VFWMSAC)    ||
             (instr.instr.instr_type == VFWNMSAC)   ||
             (instr.instr.instr_type == VFWADDW)    ||
             (instr.instr.instr_type == VFWSUBW)          ||
             (instr.instr.instr_type == VFWREDUSUM)      ||
             (instr.instr.instr_type == VFWREDOSUM)      ||
             (instr.instr.instr_type == VFWCVT_XU_F)     ||
             (instr.instr.instr_type == VFWCVT_X_F)      ||
             (instr.instr.instr_type == VFWCVT_RTZ_XU_F) ||
             (instr.instr.instr_type == VFWCVT_RTZ_X_F)  ||
             (instr.instr.instr_type == VFWCVT_F_XU)     ||
             (instr.instr.instr_type == VFWCVT_F_X)      ||
             (instr.instr.instr_type == VFWCVT_F_F)      ||
             (instr.instr.instr_type == VWSLL)) ? 1'b1 : 1'b0;
endfunction

function logic is_vn(input rr_exe_simd_instr_t instr);
    is_vn = ((instr.instr.instr_type == VNCLIPU)  ||
             (instr.instr.instr_type == VNCLIP)  ||
             (instr.instr.instr_type == VNSRL)    ||
             (instr.instr.instr_type == VNSRA) ||
             (instr.instr.instr_type == VFNCVT_XU_F) ||
             (instr.instr.instr_type == VFNCVT_X_F) ||
             (instr.instr.instr_type == VFNCVT_RTZ_XU_F) ||
             (instr.instr.instr_type == VFNCVT_RTZ_X_F) ||
             (instr.instr.instr_type == VFNCVT_F_XU) ||
             (instr.instr.instr_type == VFNCVT_F_X) ||
             (instr.instr.instr_type == VFNCVT_F_F) ||
             (instr.instr.instr_type == VFNCVT_ROD_F_F)) ? 1'b1 : 1'b0;
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
             (instr.instr.instr_type == VMSBC)  ||
             (instr.instr.instr_type == VMFNE)  ||
             (instr.instr.instr_type == VMFLT)  ||
             (instr.instr.instr_type == VMFEQ)  ||
             (instr.instr.instr_type == VMFLE)  ||
             (instr.instr.instr_type == VMFGT)  ||
             (instr.instr.instr_type == VMFGE)) ? 1'b1 : 1'b0;
endfunction

function logic is_vsetvl(input rr_exe_simd_instr_t instr);
    is_vsetvl = ((instr.instr.instr_type == VSETVL)   ||
                (instr.instr.instr_type == VSETVLI)   || 
                (instr.instr.instr_type == VSETIVLI)) ? 1'b1 : 1'b0;
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



// Tracking of the instructions that take more than 1 cycle
//
// An instruction with simd_exe_stages == i (2 <= i <= MAX_STAGES) sets
// simd_pipe_valid_q[i][0] when it is received and leaves the unit i-1 cycles
// later, when its valid bit reaches simd_pipe_valid_q[i][i-2]. When several
// instructions finish in the same cycle the lowest latency class wins.
//
// The valid bits advance every cycle and are cleared on flush, so a valid bit
// in simd_pipe_valid_q[i][j] always belongs to the instruction received j+1
// cycles ago. The instruction itself is therefore kept once, in delay lines
// shared by all the latency classes (slot j holds the instruction received
// j+1 cycles ago), and only with the fields read once it leaves the pipe:
//  - simd_pipe_instr_q: fields shown at the write-back outputs, plus vta and
//    old vd (tail and inactive elements), for every class
//  - simd_pipe_mask_q:  use_mask and vm, used to mask the VMUL/VMADD/VDIV
//    family results (classes 2 to 4 and DIV_STAGES)
//  - simd_pipe_vs2_q:   vs2, used by the functional units for VMADD/VNMSUB
//    (classes 3 and 4)
// The remaining fields of a finishing instruction are zero, they are only
// read for instruction types that always take 1 cycle (checked under
// ASSERTIONS). The delay lines are neither reset nor cleared on flush, they
// are only read together with a valid bit.
localparam int PIPE_SLOTS      = drac_pkg::MAX_STAGES - 1;
localparam bit DIV_IN_PIPE     = (drac_pkg::MAX_STAGES >= DIV_STAGES);
localparam int PIPE_MASK_SLOTS = DIV_IN_PIPE ? (DIV_STAGES - 1) : 3;
localparam int PIPE_VS2_SLOTS  = 3;

typedef struct packed {
    addrPC_t                    pc;
    branch_pred_t               bpred;
    reg_t                       rs1;
    reg_t                       rd;
    vreg_t                      vd;
    sew_t                       sew;
    logic [2:0]                 lmul;
    logic [VMAXELEM_LOG:0]      vl;
    logic                       vta;
    logic [CSR_ADDR_SIZE-1:0]   csr_addr;           // imm[CSR_ADDR_SIZE-1:0]
    functional_unit_t           unit;
    logic                       regfile_we;
    logic                       vregfile_we;
    logic                       fregfile_we;
    instr_type_t                instr_type;
    logic                       stall_csr_fence;
    `ifdef SIM_KONATA_DUMP
    bus64_t                     id;
    `endif
    bus_simd_t                  data_old_vd;
    phreg_t                     prd;
    phvreg_t                    pvd;
    phreg_t                     fprd;
    logic                       checkpoint_done;
    checkpoint_ptr              chkp;
    gl_index_t                  gl_index;
} simd_pipe_instr_t;

typedef struct packed {
    logic                       use_mask;
    bus_mask_t                  data_vm;
} simd_pipe_mask_t;

// Only the fields kept in the delay lines are taken from the instruction
/* verilator lint_off UNUSEDSIGNAL */
function automatic simd_pipe_instr_t pack_pipe_instr(input rr_exe_simd_instr_t instr);
    simd_pipe_instr_t pipe_instr;
    pipe_instr.pc               = instr.instr.pc;
    pipe_instr.bpred            = instr.instr.bpred;
    pipe_instr.rs1              = instr.instr.rs1;
    pipe_instr.rd               = instr.instr.rd;
    pipe_instr.vd               = instr.instr.vd;
    pipe_instr.sew              = instr.instr.sew;
    pipe_instr.lmul             = instr.instr.lmul;
    pipe_instr.vl               = instr.instr.vl;
    pipe_instr.vta              = instr.instr.vta;
    pipe_instr.csr_addr         = instr.instr.imm[CSR_ADDR_SIZE-1:0];
    pipe_instr.unit             = instr.instr.unit;
    pipe_instr.regfile_we       = instr.instr.regfile_we;
    pipe_instr.vregfile_we      = instr.instr.vregfile_we;
    pipe_instr.fregfile_we      = instr.instr.fregfile_we;
    pipe_instr.instr_type       = instr.instr.instr_type;
    pipe_instr.stall_csr_fence  = instr.instr.stall_csr_fence;
    `ifdef SIM_KONATA_DUMP
    pipe_instr.id               = instr.instr.id;
    `endif
    pipe_instr.data_old_vd      = instr.data_old_vd;
    pipe_instr.prd              = instr.prd;
    pipe_instr.pvd              = instr.pvd;
    pipe_instr.fprd             = instr.fprd;
    pipe_instr.checkpoint_done  = instr.checkpoint_done;
    pipe_instr.chkp             = instr.chkp;
    pipe_instr.gl_index         = instr.gl_index;
    return pipe_instr;
endfunction

function automatic simd_pipe_mask_t pack_pipe_mask(input rr_exe_simd_instr_t instr);
    simd_pipe_mask_t pipe_mask;
    pipe_mask.use_mask          = instr.instr.use_mask;
    pipe_mask.data_vm           = instr.data_vm;
    return pipe_mask;
endfunction
/* verilator lint_on UNUSEDSIGNAL */

function automatic rr_exe_simd_instr_t unpack_pipe_instr(input simd_pipe_instr_t pipe_instr,
                                                          input simd_pipe_mask_t  pipe_mask,
                                                          input bus_simd_t        pipe_vs2);
    rr_exe_simd_instr_t instr;
    instr                               = '0;
    instr.instr.valid                   = 1'b1; // only valid instructions enter the pipes
    instr.instr.pc                      = pipe_instr.pc;
    instr.instr.bpred                   = pipe_instr.bpred;
    instr.instr.rs1                     = pipe_instr.rs1;
    instr.instr.rd                      = pipe_instr.rd;
    instr.instr.vd                      = pipe_instr.vd;
    instr.instr.sew                     = pipe_instr.sew;
    instr.instr.lmul                    = pipe_instr.lmul;
    instr.instr.vl                      = pipe_instr.vl;
    instr.instr.vta                     = pipe_instr.vta;
    instr.instr.imm[CSR_ADDR_SIZE-1:0]  = pipe_instr.csr_addr;
    instr.instr.unit                    = pipe_instr.unit;
    instr.instr.regfile_we              = pipe_instr.regfile_we;
    instr.instr.vregfile_we             = pipe_instr.vregfile_we;
    instr.instr.fregfile_we             = pipe_instr.fregfile_we;
    instr.instr.use_mask                = pipe_mask.use_mask;
    instr.instr.instr_type              = pipe_instr.instr_type;
    instr.instr.stall_csr_fence         = pipe_instr.stall_csr_fence;
    `ifdef SIM_KONATA_DUMP
    instr.instr.id                      = pipe_instr.id;
    `endif
    instr.data_vs2                      = pipe_vs2;
    instr.data_old_vd                   = pipe_instr.data_old_vd;
    instr.data_vm                       = pipe_mask.data_vm;
    instr.prd                           = pipe_instr.prd;
    instr.pvd                           = pipe_instr.pvd;
    instr.fprd                          = pipe_instr.fprd;
    instr.checkpoint_done               = pipe_instr.checkpoint_done;
    instr.chkp                          = pipe_instr.chkp;
    instr.gl_index                      = pipe_instr.gl_index;
    return instr;
endfunction

logic [drac_pkg::MAX_STAGES-2:0] simd_pipe_valid_d [drac_pkg::MAX_STAGES:2];
logic [drac_pkg::MAX_STAGES-2:0] simd_pipe_valid_q [drac_pkg::MAX_STAGES:2];
simd_pipe_instr_t                simd_pipe_instr_q [PIPE_SLOTS-1:0];
simd_pipe_mask_t                 simd_pipe_mask_q  [PIPE_MASK_SLOTS-1:0];
bus_simd_t                       simd_pipe_vs2_q   [PIPE_VS2_SLOTS-1:0];
rr_exe_simd_instr_t              simd_pipe_out     [drac_pkg::MAX_STAGES:2]; // Instruction finishing in each class


// This pipeline is taking care of in-flight DIV/REM instructions
// it's seperated from other instructions as DIV/REM is way more time consuming
// than other instructions.
// Note that there can't be more than 1 in flight DIV/REM at a time, should another
// DIV/REM instruction be dispatched while the previous one is being processed, the
// pipline is stalled. The stalling mechanism can be seen in sargantana/rtl/datapath/rtl/exe_stage/rtl/score_board_simd.sv
logic               division_out_valid;     // A 32-cycle DIV/REM finishes
rr_exe_simd_instr_t division_out_instr;     // Last 32-cycle DIV/REM received

logic is_fpnew_turn;

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

    if (is_vsetvl(instruction_i)) begin
        previous_div_instr_type_d = instruction_i.instr.instr_type;
        simd_exe_stages = 6'd1;
    end else if (is_vmul(instruction_i)) begin
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
    else if (is_vf_redu(instruction_i.instr.instr_type)) begin
        if (is_vw(instruction_i)) begin
            simd_exe_stages = STAGES_TREE64_W;
        end else begin
            case(instruction_i.instr.sew)
                SEW_32  : simd_exe_stages = STAGES_TREE32;
                SEW_64  : simd_exe_stages = STAGES_TREE64;
                default : simd_exe_stages = $clog2(VLEN >> 5);          // default case for completion
            endcase
        end
    end
    else if (is_vf_redo(instruction_i.instr.instr_type)) begin
        if (is_vw(instruction_i)) begin
            simd_exe_stages = STAGES_VFREDO64_W;
        end else begin
            case(instruction_i.instr.sew)
                SEW_32  : simd_exe_stages = STAGES_VFREDO32;
                SEW_64  : simd_exe_stages = STAGES_VFREDO64;
                default : simd_exe_stages = STAGES_VFREDO32;
            endcase
        end
    end
    else begin
        simd_exe_stages = 6'd1;
    end
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        previous_div_rs1_q          <= '0;                
        previous_div_vs1_q          <= '0;               
        previous_div_vs2_q          <= '0;              
        previous_div_is_opvx_q      <= '0;          
        previous_div_instr_type_q   <= drac_pkg::ADD;
    end else begin
        previous_div_rs1_q          <= previous_div_rs1_d;                
        previous_div_vs1_q          <= previous_div_vs1_d;               
        previous_div_vs2_q          <= previous_div_vs2_d;              
        previous_div_is_opvx_q      <= previous_div_is_opvx_d;          
        previous_div_instr_type_q   <= previous_div_instr_type_d;
    end
end

// Each cycle, each valid bit goes forward 1 slot, all of them are cleared on flush
always_comb begin
    for (int i = 2; i <= drac_pkg::MAX_STAGES; i++) begin
        simd_pipe_valid_d[i] = '0;
        if (!flush_i) begin
            simd_pipe_valid_d[i][0] = (simd_exe_stages == i) && instruction_i.instr.valid &&
                                      (!drac_pkg::is_vfpnew(instruction_i.instr.instr_type) || is_zvfhmin_conv(instruction_i));
            for (int j = 1; j < (drac_pkg::MAX_STAGES - 1); j++) begin
                if (j <= (i - 2)) begin
                    simd_pipe_valid_d[i][j] = simd_pipe_valid_q[i][j-1];
                end
            end
        end
    end
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        for (int i = 2; i <= drac_pkg::MAX_STAGES; i++) begin
            simd_pipe_valid_q[i] <= '0;
        end
    end else begin
        for (int i = 2; i <= drac_pkg::MAX_STAGES; i++) begin
            simd_pipe_valid_q[i] <= simd_pipe_valid_d[i];
        end
    end
end

// Delay lines shared by all the latency classes, loaded every cycle.
// No reset: every slot is read together with a valid bit, which is reset,
// and the untapped runs of slots can be mapped to shift-register LUTs
always_ff @(posedge clk_i) begin
    simd_pipe_instr_q[0] <= pack_pipe_instr(instruction_i);
    for (int j = 1; j < PIPE_SLOTS; j++) begin
        simd_pipe_instr_q[j] <= simd_pipe_instr_q[j-1];
    end
    simd_pipe_mask_q[0] <= pack_pipe_mask(instruction_i);
    for (int j = 1; j < PIPE_MASK_SLOTS; j++) begin
        simd_pipe_mask_q[j] <= simd_pipe_mask_q[j-1];
    end
    simd_pipe_vs2_q[0] <= instruction_i.data_vs2;
    for (int j = 1; j < PIPE_VS2_SLOTS; j++) begin
        simd_pipe_vs2_q[j] <= simd_pipe_vs2_q[j-1];
    end
end

// Instruction finishing in each latency class
genvar gv_pipe;
generate
    for (gv_pipe = 2; gv_pipe <= drac_pkg::MAX_STAGES; gv_pipe++) begin : g_pipe_out
        simd_pipe_mask_t out_mask;
        bus_simd_t       out_vs2;
        // VMUL family: classes 2-3, VMADD/VSMUL family: classes 3-4, 32-cycle DIV/REM: DIV_STAGES
        if (((gv_pipe >= 2) && (gv_pipe <= 4)) || (gv_pipe == DIV_STAGES)) begin : g_mask
            assign out_mask = simd_pipe_mask_q[gv_pipe-2];
        end else begin : g_no_mask
            assign out_mask = '0;
        end
        // VMADD/VNMSUB: classes 3-4
        if ((gv_pipe == 3) || (gv_pipe == 4)) begin : g_vs2
            assign out_vs2 = simd_pipe_vs2_q[gv_pipe-2];
        end else begin : g_no_vs2
            assign out_vs2 = '0;
        end
        assign simd_pipe_out[gv_pipe] = unpack_pipe_instr(simd_pipe_instr_q[gv_pipe-2], out_mask, out_vs2);
    end

    if (DIV_IN_PIPE) begin : g_div_in_pipe
        // A 32-cycle DIV/REM also enters class DIV_STAGES of simd_pipe with the
        // same valid condition, shift and flush, and that class is checked first,
        // so a separate DIV/REM tracking would never be selected
        assign division_out_valid = 1'b0;
        assign division_out_instr = '0;
    end else begin : g_div_pipe
        logic                  division_start;
        logic [DIV_STAGES-2:0] division_pipe_q;
        // in order to reduce the area and not use a redundant array of instructions
        // a global instruction is stored, since there can't be more than 1 in-flight div/rems
        simd_pipe_instr_t      division_instruction_q;
        simd_pipe_mask_t       division_mask_q;

        assign division_start = is_vdiv(instruction_i) && (simd_exe_stages == 6'd32) && instruction_i.instr.valid;

        always_ff @(posedge clk_i, negedge rstn_i) begin
            if (~rstn_i) begin
                division_pipe_q        <= '0;
                division_instruction_q <= '0;
                division_mask_q        <= '0;
            end else begin
                division_pipe_q <= (flush_i) ? '0 : {division_pipe_q[DIV_STAGES-3:0], division_start};
                // not cleared on flush, it is only read together with division_pipe_q
                if (!flush_i && division_start) begin
                    division_instruction_q <= pack_pipe_instr(instruction_i);
                    division_mask_q        <= pack_pipe_mask(instruction_i);
                end
            end
        end

        assign division_out_valid = division_pipe_q[DIV_STAGES-2];
        assign division_out_instr = unpack_pipe_instr(division_instruction_q, division_mask_q, '0);
    end
endgenerate

`ifdef ASSERTIONS
// The fields kept for each class in g_pipe_out rely on the number of cycles
// assigned to each instruction type in simd_exe_stages: only the VMUL, VMADD/VSMUL
// and DIV/REM families and the reductions take more than 1 cycle
always @(posedge clk_i) begin
    for (int i = 2; i <= drac_pkg::MAX_STAGES; i++) begin
        if (simd_pipe_valid_d[i][0]) begin
            assert ((is_vmul(instruction_i) && ((i == 2) || (i == 3)))           ||
                    (is_vmadd_vsmul(instruction_i) && ((i == 3) || (i == 4)))    ||
                    (is_vdiv(instruction_i) && (i == DIV_STAGES))                ||
                    is_vred(instruction_i)                                       ||
                    is_vf_redu(instruction_i.instr.instr_type)                   ||
                    is_vf_redo(instruction_i.instr.instr_type));
        end
    end
end
`endif

//Select the instruction that completes its correspondent pipeline
rr_exe_simd_instr_t instr_score_board;
logic valid_found;
always_comb begin
    instr_score_board = '0;
    valid_found = 1'b0;
    for (int i = 2; (i <= drac_pkg::MAX_STAGES) && (!valid_found); i++) begin
        if (simd_pipe_valid_q[i][i-2]) begin
            instr_score_board = simd_pipe_out[i];
            valid_found = 1'b1;
        end
    end
    // like the normal pipeline in Division pipeline we check to see if we have
    // a finalized instruction
    if ((!valid_found) && division_out_valid) begin
        instr_score_board = division_out_instr;
        valid_found = 1'b1;
    end
end

always_comb begin
    if (valid_found && (instr_score_board.instr.vl != 'h0)) begin
        instr_to_out_integer = instr_score_board;
    end else if ((instruction_i.exe_stages == 1) && (!drac_pkg::is_vfpnew(instruction_i.instr.instr_type) || is_zvfhmin_conv(instruction_i))) begin
        instr_to_out_integer = instruction_i;
    end else begin
        instr_to_out_integer = '0;
    end 
end

always_comb begin
    if (is_fpnew_turn) begin 
        instr_to_out = fpnew_out_instruction;
    end else begin
        instr_to_out = instr_to_out_integer;
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
                if (instruction_i.instr.is_opvx || instruction_i.instr.is_opvf) rs1_replicated[(i*16)+:16] = instruction_i.data_rs1[15:0];
                else rs1_replicated[(i*16)+:16] = instruction_i.instr.imm[15:0];
            end
        end
        SEW_32: begin
            for (int i=0; i<(VLEN/32); ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*32)+:32] = instruction_i.data_rs1[31:0];
                else if (instruction_i.instr.is_opvf) begin
                    rs1_replicated[(i*32)+:32] = (instruction_i.data_rs1[63:32] == 32'hFFFF_FFFF) ?
                                                  instruction_i.data_rs1[31:0] : FP32_QNAN;
                end
                else rs1_replicated[(i*32)+:32] = instruction_i.instr.imm[31:0];
            end
        end
        SEW_64: begin
            for (int i=0; i<(VLEN/64); ++i) begin
                if (instruction_i.instr.is_opvx || instruction_i.instr.is_opvf) rs1_replicated[(i*64)+:64] = instruction_i.data_rs1[63:0];
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
            default: begin // use default case to avoid linting issues
                data_rd = '0;
            end
        endcase
    end
    else if (instr_to_out.instr.instr_type == VFMV_F_S) begin
        // the VFMV must be treatened differently to scalar, as NaN boxing apply is compulory
        case (instr_to_out.instr.sew)
            SEW_16: begin // putting this for future support on FP16
                data_rd = {{48{1'b1}}, vs2_elements[0][15:0]};
            end
            SEW_32: begin
                data_rd = {{32{1'b1}}, vs2_elements[0][31:0]};
            end
            SEW_64: begin
                data_rd = vs2_elements[0];
            end
            default: begin // use default case to avoid linting issues
                data_rd = '0;
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

// Vectorial floating-point approximation modules
bus_simd_t data_vf7_vd;
fpnew_pkg::status_t status_vf7;

vf7_wrapper vf7_wrapper_inst (
    .clk_i,
    .rstn_i,
    .valid_i     ( is_vf_approx(instruction_i.instr.instr_type)     ),
    .sew_i       ( instruction_i.instr.sew                          ),
    .operation_i ( instruction_i.instr.instr_type == VFRSQRT7       ), // 0: VFREC7, 1: VFRSQRT7
    .src_i       ( instruction_i.data_vs2                           ),
    .vl_i        ( instruction_i.instr.vl                           ),
    .data_vm_i   ( instruction_i.data_vm                            ),
    .frm_i       ( fpnew_pkg::roundmode_e'(instruction_i.instr.frm) ),
    .res_o       ( data_vf7_vd                                      ),
    .valid_o     (                                                  ), // to be asumed it will be the same cycle, carefull when enabling VF7_MF_OUTREG
    .status_o    ( status_vf7                                       )
);

// Vectorial reduction modules (unordered vfredtree, ordered vfredoladder)
// MAXMIN operations are performed in the tree (see documentation)

bus_simd_t          fred_data_vd      ;
bus_simd_t          fredo_data_vd     ;
fpnew_pkg::status_t vfredtreeflags    ;
fpnew_pkg::status_t vfredoladderflags ;

vfredtree #(
    .DELAY_SUM_FP32( DELAY_SUM_FP32 ),
    .DELAY_SUM_FP64( DELAY_SUM_FP64 )
) vfredtree_inst  (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .instr_type_i   (instruction_i.instr.instr_type),
    .frm_i          (instruction_i.instr.frm),
    .sew_i          (instruction_i.instr.sew),
    .vl_i           (instruction_i.instr.vl),
    .data_vs1_i     (instruction_i.data_vs1),
    .data_vs2_i     (instruction_i.data_vs2),
    .data_old_vd    (instruction_i.data_old_vd),
    .data_vm_i      (instruction_i.data_vm),
    .instr_to_out_i (instr_to_out.instr.instr_type),
    .vl_to_out_i    (instr_to_out.instr.vl),
    .sew_to_out_i   (instr_to_out.instr.sew),
    .red_data_vd_o  (fred_data_vd),
    .status_o       (vfredtreeflags)
);

vfredoladder #(
    .DELAY_SUM_FP32( DELAY_SUM_FP32 ),
    .DELAY_SUM_FP64( DELAY_SUM_FP64 )
) vfredoladder_inst  (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .instr_type_i   (instruction_i.instr.instr_type),
    .frm_i          (instruction_i.instr.frm),
    .sew_i          (instruction_i.instr.sew),
    .vl_i           (instruction_i.instr.vl),
    .data_vs1_i     (instruction_i.data_vs1),
    .data_vs2_i     (instruction_i.data_vs2),
    .data_old_vd    (instruction_i.data_old_vd),
    .data_vm_i      (instruction_i.data_vm),
    .instr_to_out_i (instr_to_out.instr.instr_type),
    .vl_to_out_i    (instr_to_out.instr.vl),
    .sew_to_out_i   (instr_to_out.instr.sew),
    .red_data_vd_o  (fredo_data_vd),
    .status_o       (vfredoladderflags)
);

// Zvfhmin conversions

bus_simd_t conv_zvfhmin_vd;
fpnew_pkg::status_t conv_zvfhmin_flags;
logic is_vfncvt_f_f;

assign is_vfncvt_f_f = (instruction_i.instr.instr_type == VFNCVT_F_F) ? 1'b1 : 1'b0; 

conv_zvfhmin conv_zvfhmin_inst (
   .src_i(instruction_i.data_vs2),
   .valid_i(is_zvfhmin_conv(instruction_i)),
   .operation_i(is_vfncvt_f_f),
   .frm_i(instruction_i.instr.frm),
   .res_o(conv_zvfhmin_vd),
   .status_o(conv_zvfhmin_flags)
);

// Main vectorial FPU instantiation

logic   is_collision;
logic   fpnew_stall;
assign  is_collision = fpnew_out_instruction.instr.valid & (instr_to_out_integer.instr.valid &
                                                           (instr_to_out_integer.instr.unit == UNIT_SIMD));

assign stall_prev_o = (is_collision & (simd_exe_stages == 1'd1)) | fpnew_stall;
assign stall_post_o = is_collision | fpnew_stall;

vfpu_drac_wrapper vectorial_fpu_inst (
    .clk_i,
    .rstn_i,
    .flush_i,
    .instruction_i,
    .out_ready_i        (~is_collision), // if there's no collision let vfpu out the instruction
    .stall_o            (fpnew_stall),
    .instruction_o      (fpnew_out_instruction),
    .data_vd_o          (fpnew_result),
    .status_o           (fpnew_status)
);

// Vector permutations (vslide*, vrgather*, vcompress) in read form, see
// vperm.sv. Control from instr_to_out and operands from instruction_i, as in
// the rest of the result selection below.
bus_simd_t vperm_data_vd;

vperm vperm_inst (
    .instr_type_i       (instr_to_out.instr.instr_type),
    .sew_i              (instr_to_out.instr.sew),
    .is_opvx_i          (instr_to_out.instr.is_opvx),
    .is_opvi_i          (instr_to_out.instr.is_opvi),
    .vta_i              (instr_to_out.instr.vta),
    .vl_i               (instr_to_out.instr.vl),
    .vlmax_i            (instr_to_out.instr.vlmax),
    .data_old_vd_i      (instr_to_out.data_old_vd),
    .imm_i              (instruction_i.instr.imm[4:0]),
    .data_rs1_i         (instruction_i.data_rs1),
    .rs1_replicated_i   (rs1_replicated[31:0]),
    .vlmax_gather_i     (instruction_i.instr.vlmax),
    .data_vs1_i         (instruction_i.data_vs1),
    .data_vs2_i         (instruction_i.data_vs2),
    .data_vd_o          (vperm_data_vd)
);

bus_simd_t result_data_vd;

always_comb begin
    result_data_vd = '0;

    if (is_fpnew_turn) begin // if it's fpnew
        result_data_vd = fpnew_result;
    end else if (is_vf_redu(instr_to_out.instr.instr_type)) begin
        result_data_vd = fred_data_vd; 
    end else if (is_vf_redo(instr_to_out.instr.instr_type)) begin
        result_data_vd = fredo_data_vd; 
    end else if (is_vf_approx(instr_to_out.instr.instr_type)) begin // ready in 1c always
        result_data_vd = data_vf7_vd;
    end else if ((instr_to_out.instr.instr_type == VFMERGE) || (instr_to_out.instr.instr_type == VFMV)) begin
        result_data_vd = rs1_replicated;
    end else if (is_vred(instr_to_out)) begin
        result_data_vd = red_data_vd;
    end else if (instr_to_out.instr.instr_type == VIOTA) begin
        result_data_vd = data_viota_vd;
    end else if (is_zvfhmin_conv(instr_to_out)) begin
        result_data_vd = conv_zvfhmin_vd;
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
    else if ((instr_to_out.instr.instr_type == VSLIDEUP)    || (instr_to_out.instr.instr_type == VSLIDEDOWN)   ||
             (instr_to_out.instr.instr_type == VSLIDE1UP)   || (instr_to_out.instr.instr_type == VFSLIDE1UP)   ||
             (instr_to_out.instr.instr_type == VSLIDE1DOWN) || (instr_to_out.instr.instr_type == VFSLIDE1DOWN) ||
             (instr_to_out.instr.instr_type == VRGATHER)    || (instr_to_out.instr.instr_type == VRGATHEREI16) ||
             (instr_to_out.instr.instr_type == VCOMPRESS)) begin
        // Slides, gathers and compress, computed in read form by vperm
        result_data_vd = vperm_data_vd;
    end

    // Forood: I used direct implementation of VMV_S_X for this with minor chages
    else if (instr_to_out.instr.instr_type == VFMV_S_F) begin
        result_data_vd = '1;
        case (instr_to_out.instr.sew)
            // sew 8 is not allowed fo floating-point operations,
            // maintainign SEW_16 for future FP16 support
            SEW_16: begin
                if (instr_to_out.instr.vta) begin
                    result_data_vd = {{(VLEN-16){1'b1}}, rs1_replicated[15:0]};
                end else begin
                    // using rs1_replicated instead of rs1 to handle NaN boxing correctly
                    result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):16], rs1_replicated[15:0]};
                end
            end
            SEW_32: begin
                if (instr_to_out.instr.vta) begin
                    result_data_vd = {{(VLEN-32){1'b1}}, rs1_replicated[31:0]};
                end else begin
                    result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):32], rs1_replicated[31:0]};
                end
            end
            SEW_64: begin
                if (instr_to_out.instr.vta) begin
                    result_data_vd = {{(VLEN-64){1'b1}}, rs1_replicated[63:0]};
                end else begin
                    result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):64], rs1_replicated[63:0]};
                end
            end
            default: begin
                result_data_vd = '0; 
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

    if (is_vf_redu(instr_to_out.instr.instr_type) || is_vf_redo(instr_to_out.instr.instr_type) || is_vred(instr_to_out) || not_masked_output(instr_to_out)|| ~instr_to_out.instr.use_mask) begin
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
        masked_data_vd = ((instr_to_out.instr.instr_type == VMERGE) || (instr_to_out.instr.instr_type == VFMERGE)) ? instr_to_out.data_vs2 : instr_to_out.data_old_vd;
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
                    end else if (is_vred(instr_to_out) || is_vf_redu(instr_to_out.instr.instr_type) || is_vf_redo(instr_to_out.instr.instr_type)) begin
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
                    end else if (is_vred(instr_to_out) || is_vf_redu(instr_to_out.instr.instr_type) || is_vf_redo(instr_to_out.instr.instr_type)) begin
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
                    end else if (is_vred(instr_to_out) || is_vf_redu(instr_to_out.instr.instr_type) || is_vf_redo(instr_to_out.instr.instr_type)) begin
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
                    end else if (is_vred(instr_to_out) || is_vf_redu(instr_to_out.instr.instr_type) || is_vf_redo(instr_to_out.instr.instr_type)) begin
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

// select combinationally the output status
fpnew_pkg::status_t flags_merged;
always_comb begin
    if (is_fpnew_turn) begin
        flags_merged = fpnew_status;
    end else if (is_vf_redu(instr_to_out.instr.instr_type)) begin
        flags_merged = vfredtreeflags;
    end else if (is_vf_redo(instr_to_out.instr.instr_type)) begin
        flags_merged = vfredoladderflags;
    end else if (is_vf_approx(instr_to_out.instr.instr_type)) begin
        flags_merged = status_vf7;
    end else if (is_zvfhmin_conv(instr_to_out)) begin
        flags_merged = conv_zvfhmin_flags;
    end else begin
        flags_merged = '0;
    end
end

// give turn to fpnew output when there is no collision and
// when there is an active isntruction waiting at the output
assign is_fpnew_turn = ((~is_collision) &&
                       (fpnew_out_instruction.instr.valid) &&
                       (fpnew_out_instruction.instr.unit == UNIT_SIMD) &&
                       (fpnew_out_instruction.instr.vregfile_we));

always_comb begin
    if (is_fpnew_turn) begin
        instruction_simd_o.valid                = fpnew_out_instruction.instr.valid & 
                                                  (fpnew_out_instruction.instr.unit == UNIT_SIMD) & 
                                                  fpnew_out_instruction.instr.vregfile_we;
        instruction_simd_o.pc                   = fpnew_out_instruction.instr.pc;
        instruction_simd_o.bpred                = fpnew_out_instruction.instr.bpred;
        instruction_simd_o.rs1                  = fpnew_out_instruction.instr.rs1;
        instruction_simd_o.vd                   = fpnew_out_instruction.instr.vd;
        instruction_simd_o.vresult              = tail_data_vd;
        instruction_simd_o.vregfile_we          = fpnew_out_instruction.instr.vregfile_we;
        instruction_simd_o.instr_type           = fpnew_out_instruction.instr.instr_type;
        instruction_simd_o.stall_csr_fence      = fpnew_out_instruction.instr.stall_csr_fence;
        instruction_simd_o.csr_addr             = fpnew_out_instruction.instr.imm[CSR_ADDR_SIZE-1:0];
        instruction_simd_o.pvd                  = fpnew_out_instruction.pvd;
        instruction_simd_o.checkpoint_done      = fpnew_out_instruction.checkpoint_done;
        instruction_simd_o.chkp                 = fpnew_out_instruction.chkp;
        instruction_simd_o.gl_index             = fpnew_out_instruction.gl_index;
        instruction_simd_o.branch_taken         = 1'b0;
        instruction_simd_o.result_pc            = 0;
        instruction_simd_o.vs_ovf               = v_sat_ovf != 0;
        instruction_simd_o.vl                   = fpnew_out_instruction.instr.vl;
        instruction_simd_o.sew                  = fpnew_out_instruction.instr.sew;
        instruction_simd_o.lmul                 = fpnew_out_instruction.instr.lmul;
        `ifdef SIM_KONATA_DUMP
        instruction_simd_o.id                   = fpnew_out_instruction.instr.id;
        `endif

    end else begin
        instruction_simd_o.valid = instr_to_out.instr.valid & 
                                   (instr_to_out.instr.unit == UNIT_SIMD) & 
                                   instr_to_out.instr.vregfile_we;
        instruction_simd_o.pc    = instr_to_out.instr.pc;
        instruction_simd_o.bpred = instr_to_out.instr.bpred;
        instruction_simd_o.rs1   = instr_to_out.instr.rs1;
        instruction_simd_o.vd    = instr_to_out.instr.vd;
        instruction_simd_o.vresult = tail_data_vd;
        instruction_simd_o.vregfile_we = instr_to_out.instr.vregfile_we;
        instruction_simd_o.instr_type = instr_to_out.instr.instr_type;
        instruction_simd_o.stall_csr_fence = instr_to_out.instr.stall_csr_fence;
        instruction_simd_o.csr_addr = instr_to_out.instr.imm[CSR_ADDR_SIZE-1:0];
        instruction_simd_o.pvd = instr_to_out.pvd;
        instruction_simd_o.checkpoint_done = instr_to_out.checkpoint_done;
        instruction_simd_o.chkp = instr_to_out.chkp;
        instruction_simd_o.gl_index = instr_to_out.gl_index;
        instruction_simd_o.branch_taken = 1'b0;
        instruction_simd_o.result_pc = 0;
        instruction_simd_o.vs_ovf = v_sat_ovf != 0;
        instruction_simd_o.vl = instr_to_out.instr.vl;
        instruction_simd_o.sew = instr_to_out.instr.sew;
        instruction_simd_o.lmul = instr_to_out.instr.lmul;
        `ifdef SIM_KONATA_DUMP
        instruction_simd_o.id = instr_to_out.instr.id;
        `endif
    end
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
assign instruction_scalar_o.fp_status = flags_merged;
assign instruction_scalar_o.mem_type = NOT_MEM;
assign instruction_scalar_o.vl = instr_to_out.instr.vl;
assign instruction_scalar_o.sew = instr_to_out.instr.sew;
assign instruction_scalar_o.lmul = instr_to_out.instr.lmul;
`ifdef SIM_KONATA_DUMP
assign instruction_scalar_o.id = instr_to_out.instr.id;
`endif



assign instruction_fp_o.valid           = instr_to_out.instr.valid &
                                          (instr_to_out.instr.unit == UNIT_SIMD) & 
                                          instr_to_out.instr.fregfile_we;
assign instruction_fp_o.pc              = instr_to_out.instr.pc;
assign instruction_fp_o.bpred           = instr_to_out.instr.bpred;
assign instruction_fp_o.rs1             = instr_to_out.instr.rs1;
assign instruction_fp_o.rd              = instr_to_out.instr.rd;
assign instruction_fp_o.result          = data_rd;
assign instruction_fp_o.regfile_we      = instr_to_out.instr.fregfile_we;
assign instruction_fp_o.instr_type      = instr_to_out.instr.instr_type;
assign instruction_fp_o.stall_csr_fence = instr_to_out.instr.stall_csr_fence;
assign instruction_fp_o.csr_addr        = instr_to_out.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_fp_o.fprd            = instr_to_out.fprd;
assign instruction_fp_o.checkpoint_done = instr_to_out.checkpoint_done;
assign instruction_fp_o.chkp            = instr_to_out.chkp;
assign instruction_fp_o.gl_index        = instr_to_out.gl_index;
assign instruction_fp_o.branch_taken    = 1'b0;
assign instruction_fp_o.result_pc       = 0;
assign instruction_fp_o.fp_status       = flags_merged;
assign instruction_fp_o.ex              = '0;
`ifdef SIM_KONATA_DUMP
   assign instruction_fp_o.id           = instr_to_out.instr.id;
`endif 

//Exceptions
always_comb begin
    instruction_scalar_o.ex.cause = INSTR_ADDR_MISALIGNED;
    instruction_scalar_o.ex.origin = 0;
    instruction_scalar_o.ex.origin2 = 0;
    instruction_scalar_o.ex.tinst = 0;
    instruction_scalar_o.ex.gva = 0;
    instruction_scalar_o.ex.valid = 0;
    instruction_simd_o.ex.cause = INSTR_ADDR_MISALIGNED;
    instruction_simd_o.ex.origin = 0;
    instruction_simd_o.ex.origin2 = 0;
    instruction_simd_o.ex.tinst = 0;
    instruction_simd_o.ex.gva = 0;
    instruction_simd_o.ex.valid = 0;
end

assign instruction_simd_o.fp_status = flags_merged;

endmodule
