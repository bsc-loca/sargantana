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


 module simd_unit
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input wire                    clk_i,                  // Clock
    input wire                    rstn_i,                 // Reset
    input logic [VMAXELEM_LOG:0]  vl_i,                   // Current vector lenght in elements
    input rr_exe_simd_instr_t     instruction_i,          // In instruction 
    output exe_wb_scalar_instr_t  instruction_scalar_o,   // Out instruction
    output exe_wb_simd_instr_t    instruction_simd_o      // Out instruction
);

localparam MAX_STAGES = $clog2(VLEN/8) + 1; // The vector reduction tree module will have the maximum stages

bus64_t [drac_pkg::VELEMENTS-1:0] vs1_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] vs2_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] data_vm;
bus64_t [drac_pkg::VELEMENTS-1:0] vd_elements;
bus_simd_t rs1_replicated;
bus_simd_t fu_data_vd;
bus64_t data_rd; //Optimisation: Use just lower bits of fu_data_vd

rr_exe_simd_instr_t instr_to_out; // Output instruction
rr_exe_simd_instr_t sel_fu_out;   // Which instruction output should return the FUs

function [3:0] trunc_4bits(input [31:0] val_in);
    trunc_4bits = val_in[3:0];
endfunction

logic [3:0] simd_exe_stages;

function logic not_masked_output(input rr_exe_simd_instr_t instr);
    not_masked_output = ((instr.instr.instr_type == VADC) ||
                         (instr.instr.instr_type == VSBC) ||
                         (instr.instr.instr_type == VMADC) ||
                         (instr.instr.instr_type == VMSBC)) ? 1'b1 : 1'b0;
endfunction
function logic is_vred(input rr_exe_simd_instr_t instr);
    is_vred = ((instr.instr.instr_type == VREDSUM)   ||
               (instr.instr.instr_type == VREDAND)   ||
               (instr.instr.instr_type == VREDOR)    ||
               (instr.instr.instr_type == VREDXOR)) ? 1'b1 : 1'b0;
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

function logic is_vmadd(input rr_exe_simd_instr_t instr);
    is_vmadd = ((instr.instr.instr_type == VMADD)  ||
               (instr.instr.instr_type == VNMSUB) ||
               (instr.instr.instr_type == VMACC)  ||
               (instr.instr.instr_type == VNMSAC)) ? 1'b1 : 1'b0;
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
             (instr.instr.instr_type == VWMUL)    ||
             (instr.instr.instr_type == VWMULU)   ||
             (instr.instr.instr_type == VWMULSU)) ? 1'b1 : 1'b0;
endfunction

function logic is_vn(input rr_exe_simd_instr_t instr);
    is_vn = ((instr.instr.instr_type == VNSRL)    ||
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
             (instr.instr.instr_type == VMSGT)) ? 1'b1 : 1'b0;
endfunction

typedef struct packed {
    logic valid;
    rr_exe_simd_instr_t simd_instr;
} instr_pipe_t;

instr_pipe_t simd_pipe_d [MAX_STAGES:2] [MAX_STAGES-1:0] ;
instr_pipe_t simd_pipe_q [MAX_STAGES:2] [MAX_STAGES-1:0] ;

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
    else if (is_vmadd(instruction_i)) begin
        simd_exe_stages = (instruction_i.sew == SEW_64) ? 4'd4 : 4'd3;
    end
    else if (is_vred(instruction_i)) begin
        case (instruction_i.sew)
            SEW_8, SEW_16 : simd_exe_stages = trunc_4bits($clog2(VLEN >> 3) + 1);
            SEW_32 : simd_exe_stages = trunc_4bits($clog2(VLEN >> 3));
            SEW_64 : simd_exe_stages = trunc_4bits($clog2(VLEN >> 3) - 1);
            default : simd_exe_stages = trunc_4bits($clog2(VLEN >> 3));
        endcase
    end else begin
        simd_exe_stages = 4'd1;
    end
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        for (int i = 2; i <= MAX_STAGES; i++) begin
            for (int j = 0; j < MAX_STAGES; j++) begin
                simd_pipe_q[i][j] <= '0;
            end
        end
    end else begin
        for (int i = 2; i <= MAX_STAGES; i++) begin
            for (int j = 0; j < MAX_STAGES; j++) begin
                simd_pipe_q[i][j] <= simd_pipe_d[i][j];
            end
        end
    end
end

// Each cycle, each instruction go forward 1 slot
always_comb begin
    for (int i = 2; i <= MAX_STAGES; i++) begin
        for (int j = 0; j < MAX_STAGES; j++) begin
            if (j==0) begin
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
end

always_comb begin
    if (valid_found && (vl_i != 'h0)) begin
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

assign sel_fu_out = (is_vred(instruction_i)) ? instruction_i : instr_to_out;

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
                case (instruction_i.sew)
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
                        //data_vm[gv_fu] = instruction_i.data_vm[63:0];
                        data_vm[gv_fu] =  {{48{1'b0}}, instruction_i.data_vm};
                        //data_vm[gv_fu] = {64{1'b0}};
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
            .sel_out_instr_i (sel_fu_out),
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
    //fu_data_vd = sel_fu_out.data_old_vd; // By Default
    fu_data_vd = {128{1'b1}}; // By Default
    for (int i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
        if (is_vn(sel_fu_out)) begin
            fu_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = vd_elements[i][HALF_SIZE-1:0];
        end else if ((sel_fu_out.instr.instr_type == VMADC) || (sel_fu_out.instr.instr_type == VMSBC)) begin
            case (sel_fu_out.sew)
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
    end else if (instr_to_out.instr.instr_type == VEXT) begin
        //Extract element specified by rs1
        case (instr_to_out.sew)
            SEW_8: begin
                if (instr_to_out.data_rs1 >= (VELEMENTS*8)) begin
                    ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    ext_element = vs2_elements[(instr_to_out.data_rs1[$clog2(VELEMENTS*8)-1:0]/8)];
                end
                case(instr_to_out.data_rs1[$clog2(VELEMENTS*8)-1:0]%8)
                    3'b000: data_rd = {56'h0,ext_element[7:0]};
                    3'b001: data_rd = {56'h0,ext_element[15:8]};
                    3'b010: data_rd = {56'h0,ext_element[23:16]};
                    3'b011: data_rd = {56'h0,ext_element[31:24]};
                    3'b100: data_rd = {56'h0,ext_element[39:32]};
                    3'b101: data_rd = {56'h0,ext_element[47:40]};
                    3'b110: data_rd = {56'h0,ext_element[55:48]};
                    3'b111: data_rd = {56'h0,ext_element[63:56]};
                endcase
            end
            SEW_16: begin
                if (instr_to_out.data_rs1 >= (VELEMENTS*4)) begin
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
                if (instr_to_out.data_rs1 >= (VELEMENTS*2)) begin
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
    .vl_i          (vl_i),
    .data_fu_i     (vd_elements[0]),
    .data_vs2_i    (instruction_i.data_vs2),
    .data_old_vd   (instruction_i.data_old_vd),
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
                //result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):8], instruction_i.data_rs1[7:0]};
                result_data_vd = {{(VLEN-8){1'b1}}, instruction_i.data_rs1[7:0]};
            end
            SEW_16: begin
                //result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):16], instruction_i.data_rs1[15:0]};
                result_data_vd = {{(VLEN-16){1'b1}}, instruction_i.data_rs1[15:0]};
            end
            SEW_32: begin
                //result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):32], instruction_i.data_rs1[31:0]};
                result_data_vd = {{(VLEN-32){1'b1}}, instruction_i.data_rs1[31:0]};
            end
            SEW_64: begin
                //result_data_vd = {instr_to_out.data_old_vd[(VLEN-1):64], instruction_i.data_rs1[63:0]};
                result_data_vd = {{(VLEN-64){1'b1}}, instruction_i.data_rs1[63:0]};
            end
        endcase  
    `ifdef VBPM_ENABLE
    end else if (instr_to_out.instr.instr_type == VBPM) begin
        result_data_vd = data_vbpm;
    end else if (instr_to_out.instr.instr_type == VPIG) begin
        result_data_vd = {instr_to_out.data_vs2[(VLEN-1) -: 2], instr_to_out.data_vs1[(VLEN-3):0]};
    `endif
    end else if ((instr_to_out.instr.instr_type == VMAND) || (instr_to_out.instr.instr_type == VMOR) || (instr_to_out.instr.instr_type == VMXOR)) begin
        result_data_vd = '1;
        result_data_vd[63:0] = fu_data_vd[63:0]; // Works with VLEN up to 512, higher than that requires concatenation of results from FU
    end else if ((instr_to_out.instr.instr_type == VMSEQ)  || (instr_to_out.instr.instr_type == VMSNE) ||
                 (instr_to_out.instr.instr_type == VMSLTU) || (instr_to_out.instr.instr_type == VMSLT) || 
                 (instr_to_out.instr.instr_type == VMSLEU) || (instr_to_out.instr.instr_type == VMSLE) ||
                 (instr_to_out.instr.instr_type == VMSGTU) || (instr_to_out.instr.instr_type == VMSGT)) begin
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
    end else if ((sel_fu_out.instr.instr_type == VZEXT_VF2) || (sel_fu_out.instr.instr_type == VZEXT_VF4) || (sel_fu_out.instr.instr_type == VZEXT_VF8) ||
                (sel_fu_out.instr.instr_type == VSEXT_VF2) || (sel_fu_out.instr.instr_type == VSEXT_VF4) || (sel_fu_out.instr.instr_type == VSEXT_VF8)) begin
        case (sel_fu_out.sew)
            SEW_8: begin
                for (int i = 0; i<(VLEN/8); ++i) begin
                    if ((sel_fu_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*8) +: 8] = {{{4{fu_data_vd[((8*(i+1))/2)-1]}}, fu_data_vd[(i*4)+:4]}};
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*8) +: 8] = {{{4{1'b0}}, fu_data_vd[(i*4)+:4]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*8) +: 8] = {{{6{fu_data_vd[((8*(i+1))/4)-1]}}, fu_data_vd[(i*2)+:2]}};
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*8) +: 8] = {{{6{1'b0}}, fu_data_vd[(i*2)+:2]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*8) +: 8] = {{{7{fu_data_vd[((16*(i+1))/8)-1]}}, fu_data_vd[(i*1)+:1]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*8) +: 8] = {{{7{1'b0}}}, fu_data_vd[(i*1)+:1]};
                    end
                end
            end
            SEW_16: begin
                for (int i = 0; i<(VLEN/16); ++i) begin
                    if ((sel_fu_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*16) +: 16] = {{{8{fu_data_vd[((16*(i+1))/2)-1]}}, fu_data_vd[(i*8)+:8]}};
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*16) +: 16] = {{{8{1'b0}}, fu_data_vd[(i*8)+:8]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*16) +: 16] = {{{12{fu_data_vd[((16*(i+1))/4)-1]}}, fu_data_vd[(i*4)+:4]}};
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*16) +: 16] = {{{12{1'b0}}, fu_data_vd[(i*4)+:4]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*16) +: 16] = {{{14{fu_data_vd[((16*(i+1))/8)-1]}}, fu_data_vd[(i*2)+:2]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*16) +: 16] = {{{14{1'b0}}}, fu_data_vd[(i*2)+:2]};
                    end
                end
            end
            SEW_32: begin
                for (int i = 0; i<(VLEN/32); ++i) begin
                    if ((sel_fu_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{16{fu_data_vd[((32*(i+1))/2)-1]}}, fu_data_vd[(i*16)+:16]}};
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{16{1'b0}}, fu_data_vd[(i*16)+:16]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{24{fu_data_vd[((32*(i+1))/4)-1]}}, fu_data_vd[(i*8)+:8]}};
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{24{1'b0}}, fu_data_vd[(i*8)+:8]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{28{fu_data_vd[((32*(i+1))/8)-1]}}, fu_data_vd[(i*4)+:4]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*HALF_SIZE) +: HALF_SIZE] = {{{28{1'b0}}}, fu_data_vd[(i*4)+:4]};
                    end
                end
            end
            SEW_64: begin
                for (int i = 0; i<(VLEN/64); ++i) begin
                    if ((sel_fu_out.instr.instr_type == VSEXT_VF2)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{32{fu_data_vd[((64*(i+1))/2)-1]}}, fu_data_vd[(i*32)+:32]}};                                     
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF2)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{32{1'b0}}, fu_data_vd[(i*32)+:32]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF4)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{48{fu_data_vd[((64*(i+1))/4)-1]}}, fu_data_vd[(i*16)+:16]}};                                 
                    end else if((sel_fu_out.instr.instr_type == VZEXT_VF4)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{48{1'b0}}, fu_data_vd[(i*16)+:16]}};
                    end else if ((sel_fu_out.instr.instr_type == VSEXT_VF8)) begin
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{56{fu_data_vd[((64*(i+1))/8)-1]}}, fu_data_vd[(i*8)+:8]}};
                    end else begin //(is_vzext8)
                        result_data_vd[(i*DATA_SIZE) +: DATA_SIZE] = {{{56{1'b0}}}, fu_data_vd[(i*8)+:8]};
                    end
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
        case (instr_to_out.sew)
            SEW_8: masked_sew = SEW_16;
            SEW_16: masked_sew = SEW_32;
            SEW_32: masked_sew = SEW_64;
            default: masked_sew = SEW_64;
        endcase
    end else begin
        masked_sew = instr_to_out.sew;
    end

    if (is_vred(instr_to_out) || not_masked_output(instr_to_out)|| ~instr_to_out.instr.use_mask) begin
        masked_data_vd = result_data_vd;
    end else if (is_vm(instr_to_out)) begin
        masked_data_vd = '1;
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
    tail_data_vd = '1;
    case(masked_sew)
        SEW_8: begin
            for (int i = 0; i<(VLEN/8); ++i) begin
                if ((i < vl_i) || (instr_to_out.instr.instr_type == VMV1R)) begin
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
                if ((i < vl_i) || (instr_to_out.instr.instr_type == VMV1R)) begin
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
                if ((i < vl_i) || (instr_to_out.instr.instr_type == VMV1R)) begin
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
                if ((i < vl_i) || (instr_to_out.instr.instr_type == VMV1R)) begin
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
assign instruction_simd_o.vresult = tail_data_vd;
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
assign instruction_simd_o.vs_ovf = v_sat_ovf != 0;
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
