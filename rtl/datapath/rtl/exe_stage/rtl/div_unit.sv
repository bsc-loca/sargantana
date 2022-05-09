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
    input  logic                 clk_i,          // Clock signal
    input  logic                 rstn_i,         // Negative reset  
    input  logic                 flush_div_i,     // Kill on fly instructions
    input  logic                 div_unit_sel_i, // Select divider module
    input  rr_exe_arith_instr_t  instruction_i,  // New incoming instruction
    output exe_wb_scalar_instr_t instruction_o   // Output instruction
);

// Declarations
bus64_t data_src1, data_src2;
exe_wb_scalar_instr_t instruction_d[1:0];
exe_wb_scalar_instr_t instruction_q[1:0];
logic div_zero_d[1:0];
logic div_zero_q[1:0];
logic same_sign_d[1:0];
logic same_sign_q[1:0];
logic signed_op_q[1:0];
logic signed_op_d[1:0];
logic op_32_d[1:0];
logic op_32_q[1:0];

bus64_t remanent_out[1:0];
bus64_t dividend_quotient_out[1:0];
bus64_t divisor_out[1:0];
bus64_t remanent_q[1:0];
bus64_t dividend_quotient_q[1:0];
bus64_t divisor_q[1:0];
bus64_t dividend_d;
bus64_t divisor_d;
    
bus64_t dividend_quotient_32;
bus64_t dividend_quotient_64;
bus64_t remanent_32;
bus64_t remanent_64;

bus64_t quo0;
bus64_t rmd0;
bus64_t quo1;
bus64_t rmd1;

logic [5:0] cycles_counter[1:0];

assign data_src1 = instruction_i.data_rs1;
assign data_src2 = instruction_i.data_rs2;

//--------------------------------------------------------------------------------------------------
//----- FIRST INSTRUCTION  -------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

    always_comb begin
        for (int i = 1; i >= 0; i--) begin
            instruction_d[i] = instruction_q[i];
            div_zero_d[i]    = div_zero_q[i];
            same_sign_d[i]   = same_sign_q[i];
            op_32_d[i]       = op_32_q[i];
            signed_op_d[i]   = signed_op_q[i]; 
        end
        if (instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_DIV)) begin
            instruction_d[div_unit_sel_i].ex              = '0; // Divisions can not generate exceptions
            instruction_d[div_unit_sel_i].valid           = instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_DIV);
            instruction_d[div_unit_sel_i].pc              = instruction_i.instr.pc;
            instruction_d[div_unit_sel_i].bpred           = instruction_i.instr.bpred;
            instruction_d[div_unit_sel_i].rs1             = instruction_i.instr.rs1;
            instruction_d[div_unit_sel_i].rd              = instruction_i.instr.rd;
            instruction_d[div_unit_sel_i].change_pc_ena   = instruction_i.instr.change_pc_ena;
            instruction_d[div_unit_sel_i].regfile_we      = instruction_i.instr.regfile_we;
            instruction_d[div_unit_sel_i].instr_type      = instruction_i.instr.instr_type;
            instruction_d[div_unit_sel_i].stall_csr_fence = instruction_i.instr.stall_csr_fence;
            instruction_d[div_unit_sel_i].csr_addr        = instruction_i.instr.imm[CSR_ADDR_SIZE-1:0];
            instruction_d[div_unit_sel_i].prd             = instruction_i.prd;
            instruction_d[div_unit_sel_i].checkpoint_done = instruction_i.checkpoint_done;
            instruction_d[div_unit_sel_i].chkp            = instruction_i.chkp;
            instruction_d[div_unit_sel_i].gl_index        = instruction_i.gl_index;
            instruction_d[div_unit_sel_i].branch_taken    = 1'b0;
            instruction_d[div_unit_sel_i].result_pc       = data_src1;                 // Store dividend in result_pc
            instruction_d[div_unit_sel_i].mem_type        = instruction_i.instr.mem_type;
            `ifdef VERILATOR
            instruction_d[div_unit_sel_i].id              = instruction_i.instr.id;
            `endif

            div_zero_d[div_unit_sel_i]     = (~(|data_src2) || (instruction_i.instr.op_32 && ~(|data_src2[31:0])));
            same_sign_d[div_unit_sel_i]    = (instruction_i.instr.op_32) ? ~(data_src2[31] ^ data_src1[31]) 
            : ~(data_src2[63] ^ data_src1[63]);
        end 
    end



    assign dividend_d     = ((data_src1[63] & instruction_i.instr.signed_op & !instruction_i.instr.op_32) |
                             (data_src1[31] & instruction_i.instr.signed_op &  instruction_i.instr.op_32)) ? ~data_src1 + 64'b1 : data_src1;

    assign divisor_d      = ((data_src2[63] & instruction_i.instr.signed_op & !instruction_i.instr.op_32) |
                             (data_src2[31] & instruction_i.instr.signed_op &  instruction_i.instr.op_32)) ? ~data_src2 + 64'b1 : data_src2;


//--------------------------------------------------------------------------------------------------
//----- PIPELINE -----------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

    div_4bits div_4bits_int0 (
        .remanent_i(remanent_q[0]),
        .dividend_quotient_i(dividend_quotient_q[0]),
        .divisor_i(divisor_q[0]),
        .remanent_o(remanent_out[0]),
        .dividend_quotient_o(dividend_quotient_out[0]),
        .divisor_o(divisor_out[0])
    );
    
    div_4bits div_4bits_int1 (
        .remanent_i(remanent_q[1]),
        .dividend_quotient_i(dividend_quotient_q[1]),
        .divisor_i(divisor_q[1]),
        .remanent_o(remanent_out[1]),
        .dividend_quotient_o(dividend_quotient_out[1]),
        .divisor_o(divisor_out[1])
    );


    // Registers
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            for (int i = 0; i <= 1; i++) begin
                instruction_q[i]        <= 'h0;
                div_zero_q[i]           <= 1'b0;
                same_sign_q[i]          <= 1'b0;
                op_32_q[i]              <= 1'b0;
                signed_op_q[i]          <= 1'b0;
                remanent_q[i]           <= 'h0;
                dividend_quotient_q[i]  <= 'h0;
                divisor_q[i]            <= 'h0;
                cycles_counter[i]       <= 6'd0;
            end
        end else if (flush_div_i) begin
            for (int i = 0; i <= 1; i++) begin
                instruction_q[i].valid  <= 1'b0;
                div_zero_q[i]           <= 1'b0;
                same_sign_q[i]          <= 1'b0;
                op_32_q[i]              <= 1'b0;
                signed_op_q[i]          <= 1'b0;
                remanent_q[i]           <= 'h0;
                dividend_quotient_q[i]  <= 'h0;
                divisor_q[i]            <= 'h0;
                cycles_counter[i]       <= 6'd0;
            end       
        end else if (instruction_i.instr.valid & (instruction_i.instr.unit == UNIT_DIV)) begin
            instruction_q[div_unit_sel_i]        <= instruction_d[div_unit_sel_i];
            div_zero_q[div_unit_sel_i]           <= div_zero_d[div_unit_sel_i];
            same_sign_q[div_unit_sel_i]          <= same_sign_d[div_unit_sel_i];
            op_32_q[div_unit_sel_i]              <= instruction_i.instr.op_32;
            signed_op_q[div_unit_sel_i]          <= instruction_i.instr.signed_op;

            remanent_q[div_unit_sel_i]           <= 'h0;
            dividend_quotient_q[div_unit_sel_i]  <= (instruction_i.instr.op_32) ? {dividend_d[31:0],32'b0} : dividend_d;
            divisor_q[div_unit_sel_i]            <= (instruction_i.instr.op_32) ? {32'b0, divisor_d[31:0]} : divisor_d;
            
            cycles_counter[div_unit_sel_i]        <= (instruction_i.instr.op_32) ? 6'd17 : 6'd33;
            
            instruction_q[~div_unit_sel_i]        <= instruction_d[~div_unit_sel_i];
            div_zero_q[~div_unit_sel_i]           <= div_zero_d[~div_unit_sel_i];
            same_sign_q[~div_unit_sel_i]          <= same_sign_d[~div_unit_sel_i];
            op_32_q[~div_unit_sel_i]              <= op_32_d[~div_unit_sel_i];
            signed_op_q[~div_unit_sel_i]          <= signed_op_d[~div_unit_sel_i]; 

            remanent_q[~div_unit_sel_i]           <= remanent_out[~div_unit_sel_i];
            dividend_quotient_q[~div_unit_sel_i]  <= dividend_quotient_out[~div_unit_sel_i];
            divisor_q[~div_unit_sel_i]            <= divisor_out[~div_unit_sel_i];
            
            if (cycles_counter[~div_unit_sel_i] != 6'd0) begin
                cycles_counter[~div_unit_sel_i]   <= cycles_counter[~div_unit_sel_i] - 6'd1;
            end
        end else begin
            for (int i = 1; i >= 0; i--) begin
                instruction_q[i]        <= instruction_d[i];
                div_zero_q[i]           <= div_zero_d[i];
                same_sign_q[i]          <= same_sign_d[i];
                op_32_q[i]              <= op_32_d[i];
                signed_op_q[i]          <= signed_op_d[i]; 

                remanent_q[i]           <= remanent_out[i];
                dividend_quotient_q[i]  <= dividend_quotient_out[i];
                divisor_q[i]            <= divisor_out[i];
                
                if (cycles_counter[i] != 6'd0) begin
                    cycles_counter[i]   <= cycles_counter[i] - 6'd1;
                end
            end
        end
    end


//--------------------------------------------------------------------------------------------------
//----- OUTPUT INSTRUCTION -------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------
                    
        assign quo0 = (div_zero_q[0]) ? 64'hFFFFFFFFFFFFFFFF :
                        (signed_op_q[0] ? (same_sign_q[0] ? dividend_quotient_q[0] : ~dividend_quotient_q[0] + 64'b1) : dividend_quotient_q[0]);
                        
        assign quo1 = (div_zero_q[1]) ? 64'hFFFFFFFFFFFFFFFF :
                        (signed_op_q[1] ? (same_sign_q[1] ? dividend_quotient_q[1] : ~dividend_quotient_q[1] + 64'b1) : dividend_quotient_q[1]);
                    
        assign rmd0 = (div_zero_q[0]) ? instruction_q[0].result_pc : (signed_op_q[0] ?
                    (((instruction_q[0].result_pc[63] &  !op_32_q[0]) | (instruction_q[0].result_pc[31] & op_32_q[0])) ?
                    ~remanent_q[0] + 64'b1 : remanent_q[0]) : remanent_q[0]);
                
        assign rmd1 = (div_zero_q[1]) ? instruction_q[1].result_pc : (signed_op_q[1] ?
                    (((instruction_q[1].result_pc[63] &  !op_32_q[1]) | (instruction_q[1].result_pc[31] & op_32_q[1])) ?
                    ~remanent_q[1] + 64'b1 : remanent_q[1]) : remanent_q[1]);

    always_comb begin
        instruction_o.valid           = 'h0;
        instruction_o.pc              = 'h0;
        instruction_o.bpred           = 'h0;
        instruction_o.rs1             = 'h0;
        instruction_o.rd              = 'h0;
        instruction_o.change_pc_ena   = 'h0;
        instruction_o.regfile_we      = 'h0;
        instruction_o.instr_type      = ADD;
        instruction_o.stall_csr_fence = 'h0;
        instruction_o.csr_addr        = 'h0;
        instruction_o.prd             = 'h0;
        instruction_o.checkpoint_done = 'h0;
        instruction_o.chkp            = 'h0;
        instruction_o.gl_index        = 'h0;
        instruction_o.mem_type        = NOT_MEM;
        `ifdef VERILATOR
        instruction_o.id              = 'h0;
        `endif
        instruction_o.branch_taken    = 'h0;
        instruction_o.result_pc       = 'h0;
        instruction_o.ex              = 'h0;
        instruction_o.result          = 'h0;
        instruction_o.fp_status       = 'h0;
        if (cycles_counter[0] == 6'd1) begin
            instruction_o.valid           = instruction_q[0].valid;
            instruction_o.pc              = instruction_q[0].pc;
            instruction_o.bpred           = instruction_q[0].bpred;
            instruction_o.rs1             = instruction_q[0].rs1;
            instruction_o.rd              = instruction_q[0].rd;
            instruction_o.change_pc_ena   = instruction_q[0].change_pc_ena;
            instruction_o.regfile_we      = instruction_q[0].regfile_we;
            instruction_o.instr_type      = instruction_q[0].instr_type;
            instruction_o.stall_csr_fence = instruction_q[0].stall_csr_fence;
            instruction_o.csr_addr        = instruction_q[0].csr_addr;
            instruction_o.prd             = instruction_q[0].prd;
            instruction_o.checkpoint_done = instruction_q[0].checkpoint_done;
            instruction_o.chkp            = instruction_q[0].chkp;
            instruction_o.gl_index        = instruction_q[0].gl_index;
            instruction_o.mem_type        = instruction_q[0].mem_type;
            `ifdef VERILATOR
            instruction_o.id              = instruction_q[0].id;
            `endif
            instruction_o.branch_taken    = 1'b0;
            instruction_o.result_pc       = 0;
            instruction_o.fp_status       = 'h0;
            instruction_o.ex              = instruction_q[0].ex;
            case(instruction_q[0].instr_type)
                DIV,DIVU,DIVW,DIVUW: begin
                    if (op_32_q[0]) begin
                        instruction_o.result = {{32{quo0[31]}},quo0[31:0]};
                    end else begin
                        instruction_o.result = quo0;
                    end
                end
                REM,REMU,REMW,REMUW: begin
                    if (op_32_q[0]) begin
                        instruction_o.result = {{32{rmd0[31]}},rmd0[31:0]};
                    end else begin
                        instruction_o.result = rmd0;
                    end
                end
            endcase
        end 
        else if (cycles_counter[1] == 6'd1) begin
            instruction_o.valid           = instruction_q[1].valid;
            instruction_o.pc              = instruction_q[1].pc;
            instruction_o.bpred           = instruction_q[1].bpred;
            instruction_o.rs1             = instruction_q[1].rs1;
            instruction_o.rd              = instruction_q[1].rd;
            instruction_o.change_pc_ena   = instruction_q[1].change_pc_ena;
            instruction_o.regfile_we      = instruction_q[1].regfile_we;
            instruction_o.instr_type      = instruction_q[1].instr_type;
            instruction_o.stall_csr_fence = instruction_q[1].stall_csr_fence;
            instruction_o.csr_addr        = instruction_q[1].csr_addr;
            instruction_o.prd             = instruction_q[1].prd;
            instruction_o.checkpoint_done = instruction_q[1].checkpoint_done;
            instruction_o.chkp            = instruction_q[1].chkp;
            instruction_o.gl_index        = instruction_q[1].gl_index;
            instruction_o.mem_type        = instruction_q[1].mem_type;
            `ifdef VERILATOR
            instruction_o.id              = instruction_q[1].id;
            `endif
            instruction_o.fp_status       = 'h0;
            instruction_o.branch_taken    = 1'b0;
            instruction_o.result_pc       = 0;
            instruction_o.ex              = instruction_q[1].ex;
            case(instruction_q[1].instr_type)
                DIV,DIVU,DIVW,DIVUW: begin
                    if (op_32_q[1]) begin
                        instruction_o.result = {{32{quo1[31]}},quo1[31:0]};
                    end else begin
                        instruction_o.result = quo1;
                    end
                end
                REM,REMU,REMW,REMUW: begin
                    if (op_32_q[1]) begin
                        instruction_o.result = {{32{rmd1[31]}},rmd1[31:0]};
                    end else begin
                        instruction_o.result = rmd1;
                    end
                end
            endcase
        end else begin
            instruction_o.valid = 0;
        end
    end

endmodule // divider

