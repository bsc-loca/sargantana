/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : mul_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 *                  Victor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

module mul_unit (
    input  logic            clk_i,          // Clock Signal
    input  logic            rstn_i,         // Negative reset signal
    input  logic            kill_mul_i,     // Kill on fly instructions signal
    input  rr_exe_instr_t   instruction_i,  // New instruction
    input  bus64_t          data_src1_i,    // Source register 1
    input  bus64_t          data_src2_i,    // Source register 1
    output exe_wb_instr_t   instruction_o   // Output instruction
);

// Declarations
logic same_sign;
logic int_32_0_d, int_32_0_q, int_32_1_q;
logic neg_def_0_d, neg_def_0_q, neg_def_1_q;
logic [2:0] type_0_d; 
logic [2:0] type_0_q;
logic [2:0] type_1_q;
bus64_t src1_def_q, src1_def_d;
bus64_t src2_def_q, src2_def_d;
logic [95:0] result_low_d;
logic [95:0] result_high_d;
logic [95:0] result_low_q;
logic [95:0] result_high_q;
bus128_t result_128;
bus128_t result_128_def;
bus64_t result_32_aux;
bus64_t result_32;
bus64_t result_64;
exe_wb_instr_t instruction_0_d;
exe_wb_instr_t instruction_0_q;
exe_wb_instr_t instruction_1_q;
exe_wb_instr_t instruction_s1;
exe_wb_instr_t instruction_s2;
 

assign same_sign = instruction_i.instr.op_32 ? ~(data_src2_i[31] ^ data_src1_i[31]) : ~(data_src2_i[63] ^ data_src1_i[63]);

assign type_0_d = instruction_i.instr.mem_size;

assign int_32_0_d = instruction_i.instr.op_32;

// Source Operands, convert if source is negative and operation is signed
always_comb begin
    case (type_0_d)
        3'b000: begin  // Multiply word, Low part, Signed - MUL , MULW
            src1_def_d   = ((data_src1_i[63] & !int_32_0_d) | (data_src1_i[31]  & int_32_0_d)) ?
                             ~data_src1_i + 64'b1 : data_src1_i;
            src2_def_d   = ((data_src2_i[63] & !int_32_0_d) | (data_src2_i[31]  & int_32_0_d)) ?
                             ~data_src2_i + 64'b1 : data_src2_i;
            neg_def_0_d  = !same_sign;
        end
        3'b001: begin  // Multiply word, High part, Signed - MULH
            src1_def_d   = (data_src1_i[63]) ? ~data_src1_i + 64'b1 : data_src1_i;
            src2_def_d   = (data_src2_i[63]) ? ~data_src2_i + 64'b1 : data_src2_i;
            neg_def_0_d  = !same_sign;
        end
        3'b010: begin  // Multiply word, High part, SignedxUnsigned - MULHSU
            src1_def_d   = (data_src1_i[63]) ? ~data_src1_i + 64'b1 : data_src1_i;
            src2_def_d   = data_src2_i;
            neg_def_0_d  = data_src1_i[63];
        end
        3'b011: begin  //  Multiply word, High part, Unsigned Unsigned MULHU
            src1_def_d   = data_src1_i;
            src2_def_d   = data_src2_i;
            neg_def_0_d  = 1'b0;
        end
        default: begin
            src1_def_d   = 64'b0;
            src2_def_d   = 64'b0;
            neg_def_0_d  = 1'b0;
        end
    endcase
end

assign result_low_d  = src1_def_q * src2_def_q[31:0];
assign result_high_d = src1_def_q * src2_def_q[63:32];

// 32-bit multiplication MULW, operation finished
assign result_32_aux = neg_def_0_q ? ~result_low_d[63:0] + 64'b1 : result_low_d[63:0];
assign result_32 = {{32{result_32_aux[31]}},result_32_aux[31:0]};

assign instruction_0_d.valid         = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_MUL);
assign instruction_0_d.pc            = instruction_i.instr.pc;
assign instruction_0_d.ex            = instruction_i.instr.ex;
assign instruction_0_d.bpred         = instruction_i.instr.bpred;
assign instruction_0_d.rs1           = instruction_i.instr.rs1;
assign instruction_0_d.rd            = instruction_i.instr.rd;
assign instruction_0_d.change_pc_ena = instruction_i.instr.change_pc_ena;
assign instruction_0_d.regfile_we    = instruction_i.instr.regfile_we;
assign instruction_0_d.instr_type    = instruction_i.instr.instr_type;
assign instruction_0_d.stall_csr_fence = instruction_i.instr.stall_csr_fence;
assign instruction_0_d.csr_addr      = instruction_i.instr.result[CSR_ADDR_SIZE-1:0];
assign instruction_0_d.prd           = instruction_i.prd;
assign instruction_0_d.checkpoint_done = instruction_i.checkpoint_done;
assign instruction_0_d.chkp          = instruction_i.chkp;
assign instruction_0_d.gl_index      = instruction_i.gl_index;
assign instruction_0_d.branch_taken  = 1'b0;
assign instruction_0_d.result_pc     = 0;
assign instruction_0_d.result        = instruction_i.instr.result;

//--------------------------------------------------------------------------------------------------
//----- FIRST STAGE  ------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        instruction_0_q          <= 'h0;
        type_0_q                 <= 3'b111;
        neg_def_0_q              <= 1'b0;
        int_32_0_q               <= 1'b0;
        src1_def_q               <= 'h0;
        src2_def_q               <= 'h0;
    end else if (kill_mul_i | (~instruction_0_d.valid)) begin
        instruction_0_q          <= 'h0;
        type_0_q                 <= 3'b111;
        neg_def_0_q              <= 1'b0;
        int_32_0_q               <= 1'b0;
        src1_def_q               <= 'h0;
        src2_def_q               <= 'h0;
    end else begin
        instruction_0_q          <= instruction_0_d;
        type_0_q                 <= type_0_d;
        int_32_0_q               <= int_32_0_d;
        neg_def_0_q              <= neg_def_0_d;
        src1_def_q               <= src1_def_d;
        src2_def_q               <= src2_def_d;
    end
end

assign instruction_s1.valid         = instruction_0_q.valid & ~(int_32_1_q);
assign instruction_s1.pc            = instruction_0_q.pc;
assign instruction_s1.bpred         = instruction_0_q.bpred;
assign instruction_s1.rs1           = instruction_0_q.rs1;
assign instruction_s1.rd            = instruction_0_q.rd;
assign instruction_s1.change_pc_ena = instruction_0_q.change_pc_ena;
assign instruction_s1.regfile_we    = instruction_0_q.regfile_we;
assign instruction_s1.instr_type    = instruction_0_q.instr_type;
assign instruction_s1.stall_csr_fence = instruction_0_q.stall_csr_fence;
assign instruction_s1.csr_addr      = instruction_0_q.result[CSR_ADDR_SIZE-1:0];
assign instruction_s1.prd           = instruction_0_q.prd;
assign instruction_s1.checkpoint_done = instruction_0_q.checkpoint_done;
assign instruction_s1.chkp          = instruction_0_q.chkp;
assign instruction_s1.gl_index      = instruction_0_q.gl_index;
assign instruction_s1.branch_taken  = 1'b0;
assign instruction_s1.result_pc     = 0;
assign instruction_s1.result        = result_32;
assign instruction_s1.ex            = instruction_0_q.ex;


//--------------------------------------------------------------------------------------------------
//----- SECOND STAGE  ------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

always_ff@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        instruction_1_q          <= 'h0;
        type_1_q                 <= 3'b111;
        int_32_1_q               <= 1'b0;
        neg_def_1_q              <= 1'b0;
        result_low_q             <= 'h0;
        result_high_q            <= 'h0;
    end else if (kill_mul_i | (~instruction_0_q.valid) | int_32_0_q) begin
        instruction_1_q          <= 'h0;
        type_1_q                 <= 3'b111;
        int_32_1_q               <= 1'b0;
        neg_def_1_q              <= 1'b0;
        result_low_q             <= 'h0;
        result_high_q            <= 'h0;
    end else begin
        instruction_1_q          <= instruction_0_q;
        type_1_q                 <= type_0_q;
        int_32_1_q               <= int_32_0_q;
        neg_def_1_q              <= neg_def_0_q;
        result_low_q             <= result_low_d;
        result_high_q            <= result_high_d;
    end
end

// 64-bit multiplication MUL
assign result_128 = {32'b0,result_low_q} + {result_high_q[95:0],32'b0};
// Convert if the result is negative
assign result_128_def = neg_def_1_q ? ~result_128 + 128'b1 : result_128;

// Select correct word
always_comb begin
    case (type_1_q)
        3'b000: begin  // Multiply word, Low part, Signed - MUL , MULW
            result_64 = result_128_def[63:0];
        end
        3'b001: begin  // Multiply word, High part, Signed - MULH
            result_64 = result_128_def[127:64];
        end
        3'b010: begin  // Multiply word, High part, SignedxUnsigned - MULHSU
            result_64 =  result_128_def[127:64];
        end
        3'b011: begin  //  Multiply word, High part, Unsigned Unsigned MULHU
            result_64 = result_128_def[127:64];
        end
        default: begin
            result_64 = 64'b0;
        end
    endcase
end

assign instruction_s2.valid         = instruction_1_q.valid & ~(int_32_1_q);
assign instruction_s2.pc            = instruction_1_q.pc;
assign instruction_s2.bpred         = instruction_1_q.bpred;
assign instruction_s2.rs1           = instruction_1_q.rs1;
assign instruction_s2.rd            = instruction_1_q.rd;
assign instruction_s2.change_pc_ena = instruction_1_q.change_pc_ena;
assign instruction_s2.regfile_we    = instruction_1_q.regfile_we;
assign instruction_s2.instr_type    = instruction_1_q.instr_type;
assign instruction_s2.stall_csr_fence = instruction_1_q.stall_csr_fence;
assign instruction_s2.csr_addr      = instruction_1_q.result[CSR_ADDR_SIZE-1:0];
assign instruction_s2.prd           = instruction_1_q.prd;
assign instruction_s2.checkpoint_done = instruction_1_q.checkpoint_done;
assign instruction_s2.chkp          = instruction_1_q.chkp;
assign instruction_s2.gl_index      = instruction_1_q.gl_index;
assign instruction_s2.branch_taken  = 1'b0;
assign instruction_s2.result_pc     = 0;
assign instruction_s2.result        = result_64;
assign instruction_s2.ex            = instruction_1_q.ex;

//--------------------------------------------------------------------------------------------------
//----- MUX SELECTS OUTPUT -------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

always_comb begin
    instruction_o = (int_32_0_q & instruction_0_q.valid ) ? instruction_s1 : instruction_s2;
end


endmodule

