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
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

module simd_unit (
    input rr_exe_simd_instr_t     instruction_i,          // In instruction 
    output exe_wb_scalar_instr_t  instruction_scalar_o,   // Out instruction
    output exe_wb_simd_instr_t    instruction_simd_o      // Out instruction
);

bus64_t [drac_pkg::VELEMENTS-1:0] vs1_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] vs2_elements;
bus64_t [drac_pkg::VELEMENTS-1:0] vd_elements;
bus_simd_t rs1_replicated;
bus_simd_t data_vd;
bus64_t data_rd; //Optimisation: Use just lower bits of data_vd

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

//The source operands are separated into an array of 64-bit wide elements, each of which
//go into the Functional Units
genvar i;
generate
    for (i=0; i<drac_pkg::VELEMENTS; i=i+1) begin
        //vs1 is either the data_vs1, or the replicated rs1/imm
        assign vs1_elements[i] = instruction_i.instr.is_opvx | instruction_i.instr.is_opvi ? 
                                 rs1_replicated[((i+1)*DATA_SIZE)-1:(i*DATA_SIZE)] : 
                                 instruction_i.data_vs1[((i+1)*DATA_SIZE)-1:(i*DATA_SIZE)];
        assign vs2_elements[i] = instruction_i.data_vs2[((i+1)*DATA_SIZE)-1:(i*DATA_SIZE)];

        functional_unit functional_unit_inst(
            .fu_id_i       (i),
            .instruction_i (instruction_i),
            .data_vs1_i    (vs1_elements[i]),
            .data_vs2_i    (vs2_elements[i]),
            .data_vd_o     (vd_elements[i])
        );

        //The result of the FUs are concatenated into the result data
        assign data_vd[((i+1)*drac_pkg::DATA_SIZE)-1:(i*drac_pkg::DATA_SIZE)] = vd_elements[i];
    end
endgenerate

bus64_t ext_element;

//Compute the result of operations that don't operate on vector element
//granularity, and produce a scalar result
always_comb begin
    ext_element = 'h0;
    data_rd = 'h0;
    if (instruction_i.instr.instr_type == VMV_X_S) begin
        //Extract element 0
        case (instruction_i.sew)
            SEW_8: begin
                data_rd = {55'h0, vs2_elements[0]};
            end
            SEW_16: begin
                data_rd = {48'h0, vs2_elements[0]};
            end
            SEW_32: begin
                data_rd = {32'h0, vs2_elements[0]};
            end
            SEW_64: begin
                data_rd = vs2_elements[0];
            end
        endcase
    end else if (instruction_i.instr.instr_type == VEXT) begin
        //Extract element specified by rs1
        case (instruction_i.sew)
            SEW_8: begin
                if (instruction_i.data_rs1 >= VELEMENTS*8) begin
                    ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    ext_element = vs2_elements[(instruction_i.data_rs1[$clog2(VELEMENTS*8)-1:0]/8)];
                end
                case(instruction_i.data_rs1[$clog2(VELEMENTS*8)-1:0]%8)
                    4'b000: data_rd = {55'h0,ext_element[7:0]};
                    4'b001: data_rd = {55'h0,ext_element[15:8]};
                    4'b010: data_rd = {55'h0,ext_element[23:16]};
                    4'b011: data_rd = {55'h0,ext_element[31:24]};
                    4'b100: data_rd = {55'h0,ext_element[39:32]};
                    4'b101: data_rd = {55'h0,ext_element[47:40]};
                    4'b110: data_rd = {55'h0,ext_element[55:48]};
                    4'b111: data_rd = {55'h0,ext_element[63:56]};
                endcase
            end
            SEW_16: begin
                if (instruction_i.data_rs1 >= VELEMENTS*4) begin
                    ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    ext_element = vs2_elements[(instruction_i.data_rs1[$clog2(VELEMENTS*4)-1:0]/4)];
                end
                case(instruction_i.data_rs1[$clog2(VELEMENTS*4)-1:0]%4)
                    2'b00: data_rd = {48'h0,ext_element[15:0]};
                    2'b01: data_rd = {48'h0,ext_element[31:16]};
                    2'b10: data_rd = {48'h0,ext_element[47:32]};
                    2'b11: data_rd = {48'h0,ext_element[63:48]};
                endcase
            end
            SEW_32: begin
                if (instruction_i.data_rs1 >= VELEMENTS*2) begin
                    ext_element = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    ext_element = vs2_elements[(instruction_i.data_rs1[$clog2(VELEMENTS*2)-1:0]/2)];
                end
                case(instruction_i.data_rs1[$clog2(VELEMENTS*2)-1:0]%2)
                    1'b0: data_rd = {32'h0,ext_element[31:0]};
                    1'b1: data_rd = {32'h0,ext_element[63:32]};
                endcase
            end
            SEW_64: begin
                if (instruction_i.data_rs1 >= VELEMENTS) begin
                    data_rd = 'h0; //If the element to extract is bigger than the number of elements, extract 0
                end else begin
                    data_rd = vs2_elements[instruction_i.data_rs1[$clog2(VELEMENTS)-1:0]];
                end
            end
        endcase
    end else if (instruction_i.instr.instr_type == VCNT) begin
        //Vector count equals
        //Uses the result of the FUs, which performed a vseq, and counts
        //consecutive '1's
        data_rd = 0;
        case (instruction_i.sew)
            SEW_8: begin
                for (int i = 0; i<VLEN/8; ++i) begin
                    if (!data_vd[i*8]) break;
                    data_rd = i+1;
                end
            end
            SEW_16: begin
                for (int i = 0; i<VLEN/16; ++i) begin
                    if (!data_vd[i*16]) break;
                    data_rd = i+1;
                end
            end
            SEW_32: begin
                for (int i = 0; i<VLEN/32; ++i) begin
                    if (!data_vd[i*32]) break;
                    data_rd = i+1;
                end
            end
            SEW_64: begin
                for (int i = 0; i<VLEN/64; ++i) begin
                    if (!data_vd[i*64]) break;
                    data_rd = i+1;
                end
            end
        endcase
    end else begin
        data_rd = 64'b0;
    end
end

bus_simd_t masked_data_vd;

//Apply the mask to the vector result
//Unaffected elements are filled with the old vd data
always_comb begin
    masked_data_vd = instruction_i.data_old_vd;
    case (instruction_i.sew)
        SEW_8: begin
            for (int i = 0; i<VLEN/8; ++i) begin
                if (instruction_i.data_vm[i]) begin
                    masked_data_vd[(8*i)+:8] = data_vd[(8*i)+:8];
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i<VLEN/16; ++i) begin
                if (instruction_i.data_vm[i*2]) begin
                    masked_data_vd[(16*i)+:16] = data_vd[(16*i)+:16];
                end
            end
        end
        SEW_32: begin
            for (int i = 0; i<VLEN/32; ++i) begin
                if (instruction_i.data_vm[i*4]) begin
                    masked_data_vd[(32*i)+:32] = data_vd[(32*i)+:32];
                end
            end
        end
        SEW_64: begin
            for (int i = 0; i<VLEN/64; ++i) begin
                if (instruction_i.data_vm[i*8]) begin
                    masked_data_vd[(64*i)+:64] = data_vd[(64*i)+:64];
                end
            end
        end
    endcase
end

//Produce the scalar and vector wb structs
assign instruction_scalar_o.valid = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_SIMD) & instruction_i.instr.regfile_we;
assign instruction_scalar_o.pc    = instruction_i.instr.pc;
assign instruction_scalar_o.bpred = instruction_i.instr.bpred;
assign instruction_scalar_o.rs1   = instruction_i.instr.rs1;
assign instruction_scalar_o.rd    = instruction_i.instr.rd;
assign instruction_scalar_o.result = data_rd;
assign instruction_scalar_o.change_pc_ena = instruction_i.instr.change_pc_ena;
assign instruction_scalar_o.regfile_we = instruction_i.instr.regfile_we;
assign instruction_scalar_o.instr_type = instruction_i.instr.instr_type;
assign instruction_scalar_o.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_scalar_o.csr_addr = instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_scalar_o.prd = instruction_i.prd;
assign instruction_scalar_o.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_scalar_o.chkp = instruction_i.chkp;
assign instruction_scalar_o.gl_index = instruction_i.gl_index;
assign instruction_scalar_o.branch_taken = 1'b0;
assign instruction_scalar_o.result_pc = 0;
assign instruction_scalar_o.fp_status = 0;
assign instruction_scalar_o.mem_type = NOT_MEM;
`ifdef VERILATOR
assign instruction_scalar_o.id = instruction_i.instr.id;
`endif

assign instruction_simd_o.valid = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_SIMD) & instruction_i.instr.vregfile_we;
assign instruction_simd_o.pc    = instruction_i.instr.pc;
assign instruction_simd_o.bpred = instruction_i.instr.bpred;
assign instruction_simd_o.rs1   = instruction_i.instr.rs1;
assign instruction_simd_o.vd    = instruction_i.instr.vd;
assign instruction_simd_o.vresult = masked_data_vd;
assign instruction_simd_o.change_pc_ena = instruction_i.instr.change_pc_ena;
assign instruction_simd_o.vregfile_we = instruction_i.instr.vregfile_we;
assign instruction_simd_o.instr_type = instruction_i.instr.instr_type;
assign instruction_simd_o.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_simd_o.csr_addr = instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_simd_o.pvd = instruction_i.pvd;
assign instruction_simd_o.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_simd_o.chkp = instruction_i.chkp;
assign instruction_simd_o.gl_index = instruction_i.gl_index;
assign instruction_simd_o.branch_taken = 1'b0;
assign instruction_simd_o.result_pc = 0;
`ifdef VERILATOR
assign instruction_simd_o.id = instruction_i.instr.id;
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
