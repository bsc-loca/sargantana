/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : simd_unit.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gerard.candon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Gerard C. | 
 *  0.2        | Xavier C. | Adding vmul and vred 
 * -----------------------------------------------
 */


module simd_unit_mc
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input wire                    clk_i,                  // Clock
    input wire                    rstn_i,                 // Reset
    input rr_exe_simd_instr_t     instruction_i,          // In instruction 
    output exe_wb_scalar_instr_t  instruction_scalar_o,   // Out instruction
    output exe_wb_simd_instr_t    instruction_simd_o      // Out instruction
);

localparam MAX_STAGES = $clog2(VLEN/8); // The vector reduction tree module will have the maximum stages

bus64_t [drac_pkg::VELEMENTS-1:0] vs1_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] vs2_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] vd_elements;
bus_simd_t rs1_replicated;
bus_simd_t fu_data_vd;
bus64_t data_rd; //Optimisation: Use just lower bits of fu_data_vd

rr_exe_simd_instr_t instr_to_out; // Output instruction
rr_exe_simd_instr_t sel_fu_out;   // Which instruction output should return the FUs

logic [3:0] simd_exe_stages;

function logic is_vred(rr_exe_simd_instr_t instr);
    is_vred = (instr.instr.instr_type == VREDSUM   ||
               instr.instr.instr_type == VREDAND   ||
               instr.instr.instr_type == VREDOR    ||
               instr.instr.instr_type == VREDXOR) ? 1'b1 : 1'b0;
endfunction

function logic is_vmul(rr_exe_simd_instr_t instr);
    is_vmul = (instr.instr.instr_type == VMUL   ||
               instr.instr.instr_type == VMULH  ||
               instr.instr.instr_type == VMULHU ||
               instr.instr.instr_type == VMULHSU) ? 1'b1 : 1'b0;
endfunction

function logic is_vw(rr_exe_simd_instr_t instr);
    is_vw = (instr.instr.instr_type == VWADD    ||
             instr.instr.instr_type == VWADDU   ||
             instr.instr.instr_type == VWSUB    ||
             instr.instr.instr_type == VWSUBU   ||
             instr.instr.instr_type == VWADDW   ||
             instr.instr.instr_type == VWADDUW  ||
             instr.instr.instr_type == VWSUBW   ||
             instr.instr.instr_type == VWSUBUW) ? 1'b1 : 1'b0;
endfunction

function logic is_vn(rr_exe_simd_instr_t instr);
    is_vn = (instr.instr.instr_type == VNSRL    ||
             instr.instr.instr_type == VNSRA) ? 1'b1 : 1'b0;
endfunction

function logic is_vww(rr_exe_simd_instr_t instr);
    is_vww = (instr.instr.instr_type == VWADDW   ||
             instr.instr.instr_type == VWADDUW  ||
             instr.instr.instr_type == VWSUBW   ||
             instr.instr.instr_type == VWSUBUW) ? 1'b1 : 1'b0;
endfunction

function logic is_vm(rr_exe_simd_instr_t instr);
    is_vm = (instr.instr.instr_type == VMSEQ || 
             instr.instr.instr_type == VMSLTU ||
             instr.instr.instr_type == VMSLT || 
             instr.instr.instr_type == VMSLEU ||
             instr.instr.instr_type == VMSLE) ? 1'b1 : 1'b0;
endfunction

typedef struct packed {
    logic valid;
    rr_exe_simd_instr_t simd_instr;
} instr_pipe_t;

genvar i_pipe;
generate
    for (i_pipe = 2; i_pipe <= MAX_STAGES; i_pipe++) begin : simd_pipe
        instr_pipe_t slot [0:i_pipe-1];
    end
endgenerate

// Cycle instruction management for those instructions that takes more than 1 cycle
/*
 * 2 cycle -> |0|1|
 * 3 cycle -> |0|1|2|
 * 4 cycle -> |0|1|2|3|
 ...
*/
always_comb begin
    if (is_vmul(instruction_i)) begin
        simd_exe_stages = (instruction_i.sew == SEW_64) ? 4'd3 : 4'd2;
    end 
    else if (is_vred(instruction_i)) begin
        case (instruction_i.sew)
            SEW_8, SEW_16 : simd_exe_stages = 4'($clog2(VLEN >> 3));
            SEW_32 : simd_exe_stages = 4'($clog2(VLEN >> 3) - 1);
            SEW_64 : simd_exe_stages = 4'($clog2(VLEN >> 3) - 2);
            default : simd_exe_stages = 4'($clog2(VLEN >> 3));
        endcase
    end else begin
        simd_exe_stages = 4'd1;
    end
end

for (genvar i=2; i <= MAX_STAGES; i++) begin
    always_comb begin
        if (simd_exe_stages == i) begin
            simd_pipe[i].slot[0].valid = instruction_i.instr.valid;
            simd_pipe[i].slot[0].simd_instr = instruction_i;
        end else begin
            simd_pipe[i].slot[0].valid = 1'b0;
            simd_pipe[i].slot[0].simd_instr = '{default: '0, sew: SEW_8};
        end
    end
end

// Each cycle, each instruction go forward 1 slot
for (genvar i = 2; i <= MAX_STAGES; i++) begin
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            for (int j = 1; j < $size(simd_pipe[i].slot); j++) begin
                simd_pipe[i].slot[j].valid <= 1'b0;
                simd_pipe[i].slot[j].simd_instr <= '{default: '0, sew: SEW_8};
            end
        end else begin
            for (int j = 1; j < $size(simd_pipe[i].slot); j++) begin
                simd_pipe[i].slot[j].valid <= simd_pipe[i].slot[j-1].valid;
                simd_pipe[i].slot[j].simd_instr <= simd_pipe[i].slot[j-1].simd_instr;
            end
        end
    end
end

//Select the instruction that completes its correspondent pipeline
logic mc_commit_output;
logic [MAX_STAGES:0] or_reduction;
assign or_reduction[1:0] = 2'b0; 
for (genvar i = 2; i <= MAX_STAGES; i++) begin
    always_comb begin
        or_reduction[i] = simd_pipe[i].slot[i-1].valid;
    end
end
assign mc_commit_output = |or_reduction;

rr_exe_simd_instr_t valid_instructions[MAX_STAGES:2];
generate
    for (genvar i = 2; i <= MAX_STAGES; i++) begin : gen_valid_instr
        assign valid_instructions[i] = (or_reduction[i]) ? simd_pipe[i].slot[i-1].simd_instr : '0;
    end
endgenerate

rr_exe_simd_instr_t instr_score_board;
always_comb begin
    instr_score_board = '0;
    for (int i = 2; i <= MAX_STAGES; i++) begin
        if (or_reduction[i]) begin
            instr_score_board = valid_instructions[i];
            break;
        end
    end
end


always_comb begin
    if (mc_commit_output) begin
        instr_to_out = instr_score_board;
    end else if (instruction_i.exe_stages == 1) begin
        instr_to_out = instruction_i;
    end else begin
        instr_to_out = '0;
    end 
end

//We replicate rs1 or imm taking the sew into account
always_comb begin
    case (instruction_i.sew)
        SEW_8: begin
            for (int i=0; i<VLEN/8; ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*8)+:8] = instruction_i.data_rs1[7:0];
                else rs1_replicated[(i*8)+:8] = instruction_i.instr.imm[7:0];
            end
        end
        SEW_16: begin
            for (int i=0; i<VLEN/16; ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*16)+:16] = instruction_i.data_rs1[15:0];
                else rs1_replicated[(i*16)+:16] = instruction_i.instr.imm[15:0];
            end
        end
        SEW_32: begin
            for (int i=0; i<VLEN/32; ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*32)+:32] = instruction_i.data_rs1[31:0];
                else rs1_replicated[(i*32)+:32] = instruction_i.instr.imm[31:0];
            end
        end
        SEW_64: begin
            for (int i=0; i<VLEN/64; ++i) begin
                if (instruction_i.instr.is_opvx) rs1_replicated[(i*64)+:64] = instruction_i.data_rs1[63:0];
                else rs1_replicated[(i*64)+:64] = instruction_i.instr.imm[63:0];
            end
        end
    endcase
end

assign sel_fu_out = (is_vred(instruction_i)) ? instruction_i : instr_to_out;

//The source operands are separated into an array of 64-bit wide elements, each of which
//go into the Functional Units
localparam int unsigned HALF_SIZE = DATA_SIZE >> 1;
genvar i;
generate
    for (i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
        always_comb begin
            if (is_vw(instruction_i) || is_vn(instruction_i)) begin
                vs1_elements[i] = (instruction_i.instr.is_opvx | instruction_i.instr.is_opvi) ? 
                                        {{HALF_SIZE{1'b0}}, rs1_replicated[i*(HALF_SIZE) +: (HALF_SIZE)]} : 
                                        {{HALF_SIZE{1'b0}}, instruction_i.data_vs1[i*(HALF_SIZE) +: (HALF_SIZE)]};
                vs2_elements[i] = (is_vww(instruction_i) || is_vn(instruction_i)) ? 
                                        instruction_i.data_vs2[(i*DATA_SIZE) +: DATA_SIZE] :
                                        {{HALF_SIZE{1'b0}}, instruction_i.data_vs2[i*(HALF_SIZE) +: (HALF_SIZE)]};
            end else begin
                //vs1 is either the data_vs1, or the replicated rs1/imm
                vs1_elements[i] = (instruction_i.instr.is_opvx | instruction_i.instr.is_opvi) ? 
                                        rs1_replicated[(i*DATA_SIZE) +: DATA_SIZE] : 
                                        instruction_i.data_vs1[(i*DATA_SIZE) +: DATA_SIZE];
                vs2_elements[i] = instruction_i.data_vs2[(i*DATA_SIZE) +: DATA_SIZE];
            end
        end
        
        functional_unit_mc functional_unit_mc_inst(
            .clk_i           (clk_i),
            .rstn_i          (rstn_i),
            .fu_id_i         (i),
            .instruction_i   (instruction_i),
            .sel_out_instr_i (sel_fu_out),
            .data_vs1_i      (vs1_elements[i]),
            .data_vs2_i      (vs2_elements[i]),
            .data_vd_o       (vd_elements[i])
        );
    end
endgenerate

//The result of the FUs are concatenated into the result data
always_comb begin
    fu_data_vd = sel_fu_out.data_old_vd; // By Default
    for (int i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
        if (is_vn(sel_fu_out)) begin
            fu_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = vd_elements[i][HALF_SIZE-1:0];
        end else begin
            fu_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = vd_elements[i];
        end
    end
end

bus64_t ext_element;

//Compute the result of operations that don't operate on vector element
//granularity, and produce a scalar result
always_comb begin
    ext_element = 'h0;
    data_rd = 'h0;
    if (instr_to_out.instr.instr_type == VMV_X_S) begin
        //Extract element 0
        case (instr_to_out.sew)
            SEW_8: begin
                data_rd = {{56{vs2_elements[0][7]}}, vs2_elements[0]};
            end
            SEW_16: begin
                data_rd = {{48{vs2_elements[0][15]}}, vs2_elements[0]};
            end
            SEW_32: begin
                data_rd = {{32{vs2_elements[0][31]}}, vs2_elements[0]};
            end
            SEW_64: begin
                data_rd = vs2_elements[0];
            end
        endcase
    end else if (instr_to_out.instr.instr_type == VEXT) begin
        //Extract element specified by rs1
        case (instr_to_out.sew)
            SEW_8: begin
                if (instr_to_out.data_rs1 >= VELEMENTS*8) begin
                    ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    ext_element = vs2_elements[(instr_to_out.data_rs1[$clog2(VELEMENTS*8)-1:0]/8)];
                end
                case(instr_to_out.data_rs1[$clog2(VELEMENTS*8)-1:0]%8)
                    4'b000: data_rd = {56'h0,ext_element[7:0]};
                    4'b001: data_rd = {56'h0,ext_element[15:8]};
                    4'b010: data_rd = {56'h0,ext_element[23:16]};
                    4'b011: data_rd = {56'h0,ext_element[31:24]};
                    4'b100: data_rd = {56'h0,ext_element[39:32]};
                    4'b101: data_rd = {56'h0,ext_element[47:40]};
                    4'b110: data_rd = {56'h0,ext_element[55:48]};
                    4'b111: data_rd = {56'h0,ext_element[63:56]};
                endcase
            end
            SEW_16: begin
                if (instr_to_out.data_rs1 >= VELEMENTS*4) begin
                    ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    ext_element = vs2_elements[(instr_to_out.data_rs1[$clog2(VELEMENTS*4)-1:0]/4)];
                end
                case(instr_to_out.data_rs1[$clog2(VELEMENTS*4)-1:0]%4)
                    2'b00: data_rd = {48'h0,ext_element[15:0]};
                    2'b01: data_rd = {48'h0,ext_element[31:16]};
                    2'b10: data_rd = {48'h0,ext_element[47:32]};
                    2'b11: data_rd = {48'h0,ext_element[63:48]};
                endcase
            end
            SEW_32: begin
                if (instr_to_out.data_rs1 >= VELEMENTS*2) begin
                    ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    ext_element = vs2_elements[(instr_to_out.data_rs1[$clog2(VELEMENTS*2)-1:0]/2)];
                end
                case(instr_to_out.data_rs1[$clog2(VELEMENTS*2)-1:0]%2)
                    1'b0: data_rd = {32'h0,ext_element[31:0]};
                    1'b1: data_rd = {32'h0,ext_element[63:32]};
                endcase
            end
            SEW_64: begin
                if (instr_to_out.data_rs1 >= VELEMENTS) begin
                    data_rd = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    data_rd = vs2_elements[instr_to_out.data_rs1[$clog2(VELEMENTS)-1:0]];
                end
            end
        endcase
    end else if (instr_to_out.instr.instr_type == VCNT) begin
        //Vector count equals
        //Uses the result of the FUs, which performed a vseq, and counts
        //consecutive '1's
        data_rd = 0;
        case (instr_to_out.sew)
            SEW_8: begin
                for (int i = 0; i<VLEN/8; ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
            SEW_16: begin
                for (int i = 0; i<VLEN/16; ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
            SEW_32: begin
                for (int i = 0; i<VLEN/32; ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
            SEW_64: begin
                for (int i = 0; i<VLEN/64; ++i) begin
                    if (!fu_data_vd[i]) break;
                    data_rd = i+1;
                end
            end
        endcase
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
    .sew_i         (instruction_i.sew),
    .data_fu_i     (vd_elements[0]),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_vm_i     (instruction_i.data_vm),
    .sew_to_out_i  (instr_to_out.sew),
    .red_data_vd_o (red_data_vd)
);

bus_simd_t result_data_vd;
always_comb begin
    if (is_vred(instr_to_out)) begin
        result_data_vd = red_data_vd;
    end else if (instr_to_out.instr.instr_type == VMV_S_X) begin
        case (instr_to_out.sew)
            SEW_8: begin
                result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):8], instruction_i.data_rs1[7:0]};
            end
            SEW_16: begin
                result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):16], instruction_i.data_rs1[15:0]};
            end
            SEW_32: begin
                result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):32], instruction_i.data_rs1[31:0]};
            end
            SEW_64: begin
                result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):64], instruction_i.data_rs1[63:0]};
            end
        endcase  
    `ifdef VBPM_ENABLE
    end else if (instr_to_out.instr.instr_type == VBPM) begin
        result_data_vd = data_vbpm;
    end else if (instr_to_out.instr.instr_type == VPIG) begin
        result_data_vd = {instr_to_out.data_vs2[(VLEN-1) -: 2], instr_to_out.data_vs1[(VLEN-3):0]};
    `endif
    end else if (instr_to_out.instr.instr_type == VMAND || instr_to_out.instr.instr_type == VMOR || instr_to_out.instr.instr_type == VMXOR) begin
        result_data_vd = '1;
        result_data_vd[63:0] = fu_data_vd[63:0]; // Works with VLEN up to 512, higher than that requires concatenation of results from FU
    end else if (instr_to_out.instr.instr_type == VMSEQ || instr_to_out.instr.instr_type == VMSLTU ||
                 instr_to_out.instr.instr_type == VMSLT || instr_to_out.instr.instr_type == VMSLEU ||
                 instr_to_out.instr.instr_type == VMSLE) begin
        result_data_vd = '1;
        case (instr_to_out.sew)
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
                    result_data_vd[i] = fu_data_vd[0];
                end
            end
        endcase
    end else begin
        result_data_vd = fu_data_vd;
    end
end

bus_simd_t masked_data_vd;
sew_t masked_sew;
//Apply the mask to the vector result
//Unaffected elements are filled with the old vd data
always_comb begin
    if (is_vw(instr_to_out) && (instr_to_out.sew != SEW_64)) begin
        bit [1:0] sew_inc = instr_to_out.sew + 1;
        masked_sew = sew_t'(sew_inc);
    end else begin
        masked_sew = instr_to_out.sew;
    end

    if (is_vred(instr_to_out) || ~instr_to_out.instr.use_mask) begin
        masked_data_vd = result_data_vd;
    end else if (is_vm(instr_to_out)) begin
        masked_data_vd = '1;
        case (masked_sew)
            SEW_8: begin
                for (int i = 0; i<VLEN/8; ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
            SEW_16: begin
                for (int i = 0; i<VLEN/16; ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
            SEW_32: begin
                for (int i = 0; i<VLEN/32; ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
            SEW_64: begin
                for (int i = 0; i<VLEN/64; ++i) begin
                    masked_data_vd[i] = (instr_to_out.data_vm[i]) ? result_data_vd[i]: instr_to_out.data_old_vd[i];
                end
            end
        endcase
    end else begin
        masked_data_vd = (instr_to_out.instr.instr_type == VMERGE) ? instr_to_out.data_vs2 : instr_to_out.data_old_vd;
        case (masked_sew)
            SEW_8: begin
                for (int i = 0; i<VLEN/8; ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(8*i)+:8] = result_data_vd[(8*i)+:8];
                    end
                end
            end
            SEW_16: begin
                for (int i = 0; i<VLEN/16; ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(16*i)+:16] = result_data_vd[(16*i)+:16];
                    end
                end
            end
            SEW_32: begin
                for (int i = 0; i<VLEN/32; ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(32*i)+:32] = result_data_vd[(32*i)+:32];
                    end
                end
            end
            SEW_64: begin
                for (int i = 0; i<VLEN/64; ++i) begin
                    if (instr_to_out.data_vm[i]) begin
                        masked_data_vd[(64*i)+:64] = result_data_vd[(64*i)+:64];
                    end
                end
            end
        endcase
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
assign instruction_scalar_o.change_pc_ena = instr_to_out.instr.change_pc_ena;
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
assign instruction_simd_o.vresult = masked_data_vd;
assign instruction_simd_o.change_pc_ena = instr_to_out.instr.change_pc_ena;
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
