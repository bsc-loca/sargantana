/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : div_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Victor Soria Pardos 
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */

import drac_pkg::*;

import riscv_pkg::*;

module div_unit (
    input  logic          clk_i,          // Clock signal
    input  logic          rstn_i,         // Negative reset  
    input  logic          kill_div_i,     // Kill on fly instructions
    input  rr_exe_instr_t instruction_i,  // New incoming instruction
    input  bus64_t        data_src1_i,    // Dividend
    input  bus64_t        data_src2_i,    // Divisor
    output exe_wb_instr_t instruction_o   // Output instruction
);

    // Declarations
    exe_wb_instr_t instruction_d[16:0];
    exe_wb_instr_t instruction_q[16:0];
    logic div_zero_d[16:0];
    logic div_zero_q[16:0];
    logic same_sign_d[16:0];
    logic same_sign_q[16:0];
    logic signed_op_q[16:0];
    logic signed_op_d[16:0];
    logic op_32_d[16:0];
    logic op_32_q[16:0];

    bus64_t remanent_out[16:0];
    bus64_t dividend_quotient_out[16:0];
    bus64_t divisor_out[16:0];
    bus64_t remanent_q[16:0];
    bus64_t dividend_quotient_q[16:0];
    bus64_t divisor_q[16:0];
    bus64_t dividend_d;
    bus64_t divisor_d;
    
    bus64_t dividend_quotient_32;
    bus64_t dividend_quotient_64;
    bus64_t remanent_32;
    bus64_t remanent_64;

    bus64_t quo_32;
    bus64_t quo_64;
    bus64_t rmd_32;
    bus64_t rmd_64;


//--------------------------------------------------------------------------------------------------
//----- FIRST INSTRUCTION  -------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

    always_comb begin
        instruction_d[16].ex.cause  = INSTR_ADDR_MISALIGNED;
        instruction_d[16].ex.origin = 0;
        instruction_d[16].ex.valid  = 0;

        if(instruction_i.instr.ex.valid) begin // Propagate exception from previous stages
            instruction_d[16].ex = instruction_i.instr.ex;
        end

        instruction_d[16].valid         = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_DIV);
        instruction_d[16].pc            = instruction_i.instr.pc;
        instruction_d[16].bpred         = instruction_i.instr.bpred;
        instruction_d[16].rs1           = instruction_i.instr.rs1;
        instruction_d[16].rd            = instruction_i.instr.rd;
        instruction_d[16].change_pc_ena = instruction_i.instr.change_pc_ena;
        instruction_d[16].regfile_we    = instruction_i.instr.regfile_we;
        instruction_d[16].instr_type    = instruction_i.instr.instr_type;
        instruction_d[16].stall_csr_fence = instruction_i.instr.stall_csr_fence;
        instruction_d[16].csr_addr      = instruction_i.instr.result[CSR_ADDR_SIZE-1:0];
        instruction_d[16].prd           = instruction_i.prd;
        instruction_d[16].checkpoint_done = instruction_i.checkpoint_done;
        instruction_d[16].chkp          = instruction_i.chkp;
        instruction_d[16].gl_index      = instruction_i.gl_index;
        instruction_d[16].branch_taken  = 1'b0;
        instruction_d[16].result_pc     = data_src1_i;                 // Store dividend in result_pc


        for (int i = 15; i >= 0; i--) begin
            instruction_d[i] = instruction_q[i + 1];
            div_zero_d[i] = div_zero_q[i + 1];
            same_sign_d[i] = same_sign_q[i + 1];
            op_32_d[i] = op_32_q[i + 1];
            signed_op_d[i] = signed_op_q[i + 1]; 
        end

        div_zero_d[16]     = ~(|data_src2_i);
        same_sign_d[16]    = (instruction_i.instr.op_32) ? ~(data_src2_i[31] ^ data_src1_i[31]) : ~(data_src2_i[63] ^ data_src1_i[63]);
    end



    assign dividend_d     = ((data_src1_i[63] & instruction_i.instr.signed_op & !instruction_i.instr.op_32) |
                             (data_src1_i[31] & instruction_i.instr.signed_op &  instruction_i.instr.op_32)) ? ~data_src1_i + 64'b1 : data_src1_i;

    assign divisor_d      = ((data_src2_i[63] & instruction_i.instr.signed_op & !instruction_i.instr.op_32) |
                             (data_src2_i[31] & instruction_i.instr.signed_op &  instruction_i.instr.op_32)) ? ~data_src2_i + 64'b1 : data_src2_i;


//--------------------------------------------------------------------------------------------------
//----- PIPELINE -----------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

    genvar index;
    generate
    for (index = 16; index >= 1; index= index - 1)
        begin: gen_code_label
            div_4bits div_4bits_ints (
                .remanent_i(remanent_q[index]),
                .dividend_quotient_i(dividend_quotient_q[index]),
                .divisor_i(divisor_q[index]),
                .remanent_o(remanent_out[index]),
                .dividend_quotient_o(dividend_quotient_out[index]),
                .divisor_o(divisor_out[index])
            );
        end
    endgenerate


    // Registers
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            for (int i = 0; i < 17; i++) begin
                instruction_q[i].valid = 0;
            end
        end else if (kill_div_i) begin
            for (int i = 0; i < 17; i++) begin
                instruction_q[i].valid = 0;
            end       
        end else begin
            instruction_q[16]        = instruction_d[16];
            div_zero_q[16]           = div_zero_d[16];
            same_sign_q[16]          = same_sign_d[16];
            op_32_q[16]              = instruction_i.instr.op_32;
            signed_op_q[16]          = instruction_i.instr.signed_op;

            remanent_q[16]           = 'h0;
            dividend_quotient_q[16]  = (instruction_i.instr.op_32) ? {dividend_d[31:0],32'b0} : dividend_d;
            divisor_q[16]            = (instruction_i.instr.op_32) ? {32'b0, divisor_d[31:0]} : divisor_d;

            for (int i = 15; i >= 0; i--) begin
                instruction_q[i]        = instruction_d[i];
                div_zero_q[i]           = div_zero_d[i];
                same_sign_q[i]          = same_sign_d[i];
                op_32_q[i]              = op_32_d[i];
                signed_op_q[i]          = signed_op_d[i]; 

                remanent_q[i]           = remanent_out[i + 1];
                dividend_quotient_q[i]  = dividend_quotient_out[i + 1];
                divisor_q[i]            = divisor_out[i + 1];
            end
        end
    end


//--------------------------------------------------------------------------------------------------
//----- OUTPUT INSTRUCTION -------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------


    assign quo_32 = (div_zero_q[8]) ? 64'hFFFFFFFFFFFFFFFF :
                    (signed_op_q[8] ? (same_sign_q[8] ? dividend_quotient_32 : ~dividend_quotient_32 + 64'b1) : dividend_quotient_32);

    assign quo_64 = (div_zero_q[0]) ? 64'hFFFFFFFFFFFFFFFF :
                    (signed_op_q[0] ? (same_sign_q[0] ? dividend_quotient_64 : ~dividend_quotient_64 + 64'b1) : dividend_quotient_64);

    assign rmd_32 = (div_zero_q[8]) ? instruction_q[8].result_pc : (signed_op_q[5] ?
                (((instruction_q[8].result_pc[63] &  !op_32_q[8]) | (instruction_q[5].result_pc[31] & op_32_q[5])) ?
                ~remanent_32 + 64'b1 : remanent_32) : remanent_32);

    assign rmd_64 = (div_zero_q[0]) ? instruction_q[0].result_pc : (signed_op_q[0] ?
                (((instruction_q[0].result_pc[63] &  !op_32_q[0]) | (instruction_q[0].result_pc[31] & op_32_q[0])) ?
                ~remanent_64 + 64'b1 : remanent_64) : remanent_64);

    always_comb begin
        if (instruction_q[8].valid & op_32_q[8]) begin
            instruction_o.valid         = instruction_q[8].valid;
            instruction_o.pc            = instruction_q[8].pc;
            instruction_o.bpred         = instruction_q[8].bpred;
            instruction_o.rs1           = instruction_q[8].rs1;
            instruction_o.rd            = instruction_q[8].rd;
            instruction_o.change_pc_ena = instruction_q[8].change_pc_ena;
            instruction_o.regfile_we    = instruction_q[8].regfile_we;
            instruction_o.instr_type    = instruction_q[8].instr_type;
            instruction_o.stall_csr_fence = instruction_q[8].stall_csr_fence;
            instruction_o.csr_addr      = instruction_q[8].csr_addr;
            instruction_o.prd           = instruction_q[8].prd;
            instruction_o.checkpoint_done = instruction_q[8].checkpoint_done;
            instruction_o.chkp          = instruction_q[8].chkp;
            instruction_o.gl_index      = instruction_q[8].gl_index;
            instruction_o.branch_taken  = 1'b0;
            instruction_o.result_pc     = 0;
            instruction_o.ex            = instruction_q[8].ex;
            case(instruction_q[8].instr_type)
                DIV,DIVU,DIVW,DIVUW: begin
                    instruction_o.result = {{32{quo_32[31]}},quo_32[31:0]};
                end
                REM,REMU,REMW,REMUW: begin
                    instruction_o.result = {{32{rmd_32[31]}},rmd_32[31:0]};
                end
            endcase
        end 
        else if (instruction_q[0].valid & (~op_32_q[0]) ) begin
            instruction_o.valid         = instruction_q[0].valid;
            instruction_o.pc            = instruction_q[0].pc;
            instruction_o.bpred         = instruction_q[0].bpred;
            instruction_o.rs1           = instruction_q[0].rs1;
            instruction_o.rd            = instruction_q[0].rd;
            instruction_o.change_pc_ena = instruction_q[0].change_pc_ena;
            instruction_o.regfile_we    = instruction_q[0].regfile_we;
            instruction_o.instr_type    = instruction_q[0].instr_type;
            instruction_o.stall_csr_fence = instruction_q[0].stall_csr_fence;
            instruction_o.csr_addr      = instruction_q[0].csr_addr;
            instruction_o.prd           = instruction_q[0].prd;
            instruction_o.checkpoint_done = instruction_q[0].checkpoint_done;
            instruction_o.chkp          = instruction_q[0].chkp;
            instruction_o.gl_index      = instruction_q[0].gl_index;
            instruction_o.branch_taken  = 1'b0;
            instruction_o.result_pc     = 0;
            instruction_o.ex            = instruction_q[0].ex;
            case(instruction_q[0].instr_type)
                DIV,DIVU,DIVW,DIVUW: begin
                    instruction_o.result = quo_64;
                end
                REM,REMU,REMW,REMUW: begin
                    instruction_o.result = rmd_64;
                end
            endcase
        end else begin
            instruction_o.valid = 0;
        end
    end

endmodule // divider

