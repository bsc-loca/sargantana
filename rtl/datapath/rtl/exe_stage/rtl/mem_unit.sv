/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : mem_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 *  0.1        | Victor.SP  |  
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

module mem_unit (
    input  wire             clk_i,                  // Clock signal
    input  wire             rstn_i,                 // Reset signal
    input logic             kill_i,                 // Exception detected at Commit
    input logic             flush_i,                // Delete all load_store_queue entries
    input addr_t            io_base_addr_i,         // Input_output_address

    input rr_exe_instr_t    instruction_i,          // Interface to add new instuction
    input bus64_t           data_rs1_i,             // Data operand 1
    input bus64_t           data_rs2_i,             // Data operand 2
    input resp_dcache_cpu_t resp_dcache_cpu_i,      // Response from dcache
    input wire              commit_store_or_amo_i,  // Signal from commit enables writes.


    output req_cpu_dcache_t req_cpu_dcache_o,       // Request to dcache
    output exe_wb_instr_t   instruction_o,          // Output instruction     
    output exception_t      exception_mem_commit_o, // Exception of the commit instruction
    output logic            mem_commit_stall_o,     // Stall commit stage
    output gl_index_t       mem_gl_index_o,         // GL Index of the memory instruction
    output logic            lock_o,                 // Mem unit is able to accept more petitions
    output logic            empty_o                 // Mem unit has no pending Ops
);

logic is_STORE_or_AMO_s0_d;
logic is_STORE_or_AMO_s0_q;
logic is_STORE_or_AMO_s1_d;
logic is_STORE_or_AMO_s1_q;
logic is_STORE_or_AMO_s2_q;

logic full_lsq;
logic empty_lsq;
logic flush_to_lsq;
logic read_head_lsq;
rr_exe_instr_t instruction_to_lsq;
rr_exe_instr_t instruction_to_dcache;
rr_exe_instr_t stored_instr_to_dcache;
rr_exe_instr_t instruction_s1_d;
rr_exe_instr_t instruction_s1_q;
rr_exe_instr_t instruction_s2_q;
bus64_t data_rs1_to_dcache;
bus64_t data_rs2_to_dcache;
bus64_t stored_data_rs1;
bus64_t stored_data_rs2;
bus64_t data_rs2_s1_d;
bus64_t data_rs2_s1_q;

logic reset_head_lsq;
logic advance_head_lsq;
logic mem_commit_stall_s0, mem_commit_stall_s1, mem_commit_stall_s2;
logic kill_miss;

logic io_s1_q;
logic io_s2_q;
logic wait_for_response;

logic xcpt;
logic xcpt_s1_q;
logic xcpt_s2_q;
logic xcpt_ma_st_s2_q; 
logic xcpt_ma_ld_s2_q;
logic xcpt_pf_st_s2_q;
logic xcpt_pf_ld_s2_q;
bus64_t xcpt_addr_s1_q;
bus64_t xcpt_addr_s2_q;



// State machine variables

logic [1:0] state;
logic [1:0] next_state;

// Possible states of the control automata
parameter ResetState  = 2'b00,
          ReadHead = 2'b01,
          WaitReady = 2'b10,
          WaitCommit = 2'b11;

///////////////////////////////////////////////////////////////////////////////
///// LOAD STORE QUEUE
///////////////////////////////////////////////////////////////////////////////

assign flush_to_lsq = kill_i | flush_i;

assign  instruction_to_lsq = (instruction_i.instr.unit == UNIT_MEM) ? instruction_i : 'h0 ;

load_store_queue load_store_queue_inst (
    .clk_i              (clk_i),               
    .rstn_i             (rstn_i),
    .instruction_i      (instruction_to_lsq),
    .data_rs1_i         (data_rs1_i),
    .data_rs2_i         (data_rs2_i),                  
    .flush_i            (flush_to_lsq),
    .read_next_i        (read_head_lsq),
    .reset_next_i       (reset_head_lsq),
    .advance_head_i     (advance_head_lsq), 
    .instruction_o      (instruction_to_dcache),
    .data_rs1_o         (data_rs1_to_dcache),
    .data_rs2_o         (data_rs2_to_dcache),                 
    .ls_queue_entry_o   (),        
    .full_o             (full_lsq),
    .empty_o            (empty_lsq)
);

///////////////////////////////////////////////////////////////////////////////
///// State machine Stage 1
///////////////////////////////////////////////////////////////////////////////


// Update State
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        state <= ResetState;
    end else if (kill_miss) begin
        state <= ReadHead;
    end else begin
        state <= next_state;
    end
end

// Update State
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        stored_instr_to_dcache.instr.valid <= 1'b0;
        stored_instr_to_dcache.instr.instr_type <= ADD;
    end 
    else if (kill_miss) begin
        stored_instr_to_dcache.instr.valid <= 1'b0;
        stored_instr_to_dcache.instr.instr_type <= ADD;
    end
    else if (read_head_lsq & instruction_to_dcache.instr.valid) begin
        stored_instr_to_dcache <= instruction_to_dcache;
        stored_data_rs1 <= data_rs1_to_dcache;
        stored_data_rs2 <= data_rs2_to_dcache;
    end
end


// Mealy Output and Nexy State
always_comb begin
    case(state)
        // Reset state
        ResetState: begin
            req_cpu_dcache_o.valid      = 1'b0;              // Invalid instruction
            req_cpu_dcache_o.data_rs1   = 64'h0;
            req_cpu_dcache_o.instr_type = ADD;
            req_cpu_dcache_o.mem_size   = 3'h0;
            req_cpu_dcache_o.rd         = 5'h0;
            next_state                  = ReadHead;        // Next state Read Head
            read_head_lsq               = 1'b0;          // Read head of LSQ
            mem_commit_stall_s0         = 1'b0;
            instruction_s1_d            = 'h0;
        end
        // Read head of LSQ
        ReadHead: begin
            if (kill_i | empty_lsq) begin
                req_cpu_dcache_o.valid      = 1'b0;              // Invalid instruction
                req_cpu_dcache_o.instr_type = ADD;
                next_state                  = ReadHead;        // Next state Read Head
                read_head_lsq               = 1'b1;          // Read head of LSQ  
                mem_commit_stall_s0         = 1'b0;
                instruction_s1_d            = 'h0;
            end else begin
                req_cpu_dcache_o.valid      = (instruction_to_dcache.instr.valid & resp_dcache_cpu_i.ready) & 
                                              (~is_STORE_or_AMO_s0_d | commit_store_or_amo_i) &
                                              ~wait_for_response;
                req_cpu_dcache_o.data_rs1   = data_rs1_to_dcache;
                data_rs2_s1_d               = data_rs2_to_dcache;
                req_cpu_dcache_o.instr_type = instruction_to_dcache.instr.instr_type;
                req_cpu_dcache_o.mem_size   = instruction_to_dcache.instr.mem_size;
                req_cpu_dcache_o.rd         = instruction_to_dcache.instr.rd;
                req_cpu_dcache_o.imm        = instruction_to_dcache.instr.result;
                next_state = (instruction_to_dcache.instr.valid & resp_dcache_cpu_i.ready & ~wait_for_response) ?
                                (is_STORE_or_AMO_s0_d & !commit_store_or_amo_i) ? WaitCommit : ReadHead :
                                WaitReady; 
                read_head_lsq               = 1'b1;
                mem_commit_stall_s0         = instruction_to_dcache.instr.valid & is_STORE_or_AMO_s0_d & commit_store_or_amo_i;
                if (instruction_to_dcache.instr.valid & ~resp_dcache_cpu_i.ready) begin
                    instruction_s1_d        = 'h0;
                    is_STORE_or_AMO_s1_d    = 1'b0;
                end else if (is_STORE_or_AMO_s0_d & !commit_store_or_amo_i) begin
                    instruction_s1_d        = 'h0;
                    is_STORE_or_AMO_s1_d    = 1'b0;
                end else begin
                    instruction_s1_d        = instruction_to_dcache;
                    is_STORE_or_AMO_s1_d    = is_STORE_or_AMO_s0_d;
                end
            end
        end
        WaitReady: begin
            if (kill_i) begin
                req_cpu_dcache_o.valid      = 1'b0;              // Invalid instruction
                req_cpu_dcache_o.instr_type = ADD;
                next_state                  = ReadHead;        // Next state Read Head
                read_head_lsq               = 1'b1;          // Read head of LSQ  
                mem_commit_stall_s0         = 1'b0;
                instruction_s1_d            = 'h0;
            end else begin
                req_cpu_dcache_o.valid      = (stored_instr_to_dcache.instr.valid & resp_dcache_cpu_i.ready & 
                                              (commit_store_or_amo_i | ~is_STORE_or_AMO_s0_q) & ~wait_for_response);
                req_cpu_dcache_o.data_rs1   = stored_data_rs1;
                data_rs2_s1_d               = stored_data_rs2;
                req_cpu_dcache_o.instr_type = stored_instr_to_dcache.instr.instr_type;
                req_cpu_dcache_o.mem_size   = stored_instr_to_dcache.instr.mem_size;
                req_cpu_dcache_o.rd         = stored_instr_to_dcache.instr.rd;
                req_cpu_dcache_o.imm        = stored_instr_to_dcache.instr.result;
                next_state = (stored_instr_to_dcache.instr.valid & resp_dcache_cpu_i.ready & ~wait_for_response) ?
                                (is_STORE_or_AMO_s0_q & !commit_store_or_amo_i) ? WaitCommit : ReadHead :
                                WaitReady; 
                read_head_lsq               = 1'b0;
                mem_commit_stall_s0         = stored_instr_to_dcache.instr.valid & is_STORE_or_AMO_s0_q & commit_store_or_amo_i;
                if (stored_instr_to_dcache.instr.valid & ~resp_dcache_cpu_i.ready) begin
                    instruction_s1_d        = 'h0;
                    is_STORE_or_AMO_s1_d    = 1'b0;
                end else if (is_STORE_or_AMO_s0_q & !commit_store_or_amo_i) begin
                    instruction_s1_d        = 'h0;
                    is_STORE_or_AMO_s1_d    = 1'b0;
                end else begin
                    instruction_s1_d        = stored_instr_to_dcache;
                    is_STORE_or_AMO_s1_d    = is_STORE_or_AMO_s0_q;
                end
            end
        end
        WaitCommit: begin
            if (kill_i) begin
                req_cpu_dcache_o.valid = 1'b0;              // Invalid instruction
                req_cpu_dcache_o.instr_type = ADD;
                req_cpu_dcache_o.mem_size = 3'h0;
                req_cpu_dcache_o.rd = 5'h0;
                next_state = ReadHead;        // Next state Read Head
                read_head_lsq = 1'b1;          // Read head of LSQ
                mem_commit_stall_s0 = 1'b0;
                instruction_s1_d = 'h0;
            end else begin
                req_cpu_dcache_o.valid      = commit_store_or_amo_i & ~wait_for_response;
                req_cpu_dcache_o.data_rs1   = stored_data_rs1;
                data_rs2_s1_d               = stored_data_rs2;
                req_cpu_dcache_o.instr_type = stored_instr_to_dcache.instr.instr_type;
                req_cpu_dcache_o.mem_size   = stored_instr_to_dcache.instr.mem_size;
                req_cpu_dcache_o.rd         = stored_instr_to_dcache.instr.rd;
                req_cpu_dcache_o.imm        = stored_instr_to_dcache.instr.result;
                read_head_lsq               = 1'b0;
                mem_commit_stall_s0         = commit_store_or_amo_i;
                next_state = (commit_store_or_amo_i) ? ReadHead : WaitCommit;
                if (commit_store_or_amo_i) begin
                    instruction_s1_d = stored_instr_to_dcache;
                    is_STORE_or_AMO_s1_d = 1'b1;
                end else begin
                    instruction_s1_d = 'h0;
                    is_STORE_or_AMO_s1_d = 1'b0;
                end
            end
        end
    endcase
end

assign is_STORE_or_AMO_s0_d = (instruction_to_dcache.instr.instr_type == SD)          || 
                              (instruction_to_dcache.instr.instr_type == SW)          ||
                              (instruction_to_dcache.instr.instr_type == SH)          ||
                              (instruction_to_dcache.instr.instr_type == SB)          ||
                              (instruction_to_dcache.instr.instr_type == AMO_MAXWU)   ||
                              (instruction_to_dcache.instr.instr_type == AMO_MAXDU)   ||
                              (instruction_to_dcache.instr.instr_type == AMO_MINWU)   ||
                              (instruction_to_dcache.instr.instr_type == AMO_MINDU)   ||
                              (instruction_to_dcache.instr.instr_type == AMO_MAXW)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_MAXD)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_MINW)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_MIND)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_ORW)     ||
                              (instruction_to_dcache.instr.instr_type == AMO_ORD)     ||
                              (instruction_to_dcache.instr.instr_type == AMO_ANDW)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_ANDD)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_XORW)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_XORD)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_ADDW)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_ADDD)    ||
                              (instruction_to_dcache.instr.instr_type == AMO_SWAPW)   ||
                              (instruction_to_dcache.instr.instr_type == AMO_SWAPD)   ||
                              (instruction_to_dcache.instr.instr_type == AMO_SCW)     ||
                              (instruction_to_dcache.instr.instr_type == AMO_SCD)     ||
                              (instruction_to_dcache.instr.instr_type == AMO_LRW)     ||
                              (instruction_to_dcache.instr.instr_type == AMO_LRD)     ;
                              
assign is_STORE_or_AMO_s0_q = (stored_instr_to_dcache.instr.instr_type == SD)          || 
                              (stored_instr_to_dcache.instr.instr_type == SW)          ||
                              (stored_instr_to_dcache.instr.instr_type == SH)          ||
                              (stored_instr_to_dcache.instr.instr_type == SB)          ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MAXWU)   ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MAXDU)   ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MINWU)   ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MINDU)   ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MAXW)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MAXD)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MINW)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_MIND)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_ORW)     ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_ORD)     ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_ANDW)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_ANDD)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_XORW)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_XORD)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_ADDW)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_ADDD)    ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_SWAPW)   ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_SWAPD)   ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_SCW)     ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_SCD)     ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_LRW)     ||
                              (stored_instr_to_dcache.instr.instr_type == AMO_LRD)     ;

assign mem_gl_index_o = instruction_to_dcache.gl_index;


always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        instruction_s1_q     <= 'h0;
        instruction_s2_q     <= 'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        data_rs2_s1_q        <= 'h0;
        xcpt_ma_st_s2_q      <= 1'b0;
        xcpt_ma_ld_s2_q      <= 1'b0;
        xcpt_pf_st_s2_q      <= 1'b0;
        xcpt_pf_ld_s2_q      <= 1'b0;
        xcpt_addr_s2_q       <= 'h0;
        io_s1_q              <= 1'b0;
    end
    if (kill_miss) begin
        instruction_s1_q     <= 'h0;
        instruction_s2_q     <= 'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        data_rs2_s1_q        <= 'h0;
        io_s1_q              <= 1'b0;
    end
    else if (~wait_for_response) begin
        instruction_s1_q     <= instruction_s1_d;
        is_STORE_or_AMO_s1_q <= is_STORE_or_AMO_s1_d;
        data_rs2_s1_q        <= data_rs2_s1_d;
        xcpt_addr_s1_q       <= resp_dcache_cpu_i.addr;
        io_s1_q              <= resp_dcache_cpu_i.io_address_space;
                
        instruction_s2_q     <= instruction_s1_q;
        is_STORE_or_AMO_s2_q <= is_STORE_or_AMO_s1_q;
        xcpt_ma_st_s2_q      <= resp_dcache_cpu_i.xcpt_ma_st;
        xcpt_ma_ld_s2_q      <= resp_dcache_cpu_i.xcpt_ma_ld;
        xcpt_pf_st_s2_q      <= resp_dcache_cpu_i.xcpt_pf_st;
        xcpt_pf_ld_s2_q      <= resp_dcache_cpu_i.xcpt_pf_ld;
        xcpt_addr_s2_q       <= xcpt_addr_s1_q;
        io_s2_q              <= io_s1_q;
    end
end

assign req_cpu_dcache_o.data_rs2 = data_rs2_s1_q;

assign xcpt_s1_q = instruction_s1_q.instr.valid & 
                 (resp_dcache_cpu_i.xcpt_ma_st | resp_dcache_cpu_i.xcpt_ma_ld |
                  resp_dcache_cpu_i.xcpt_pf_st |  resp_dcache_cpu_i.xcpt_pf_ld);
assign mem_commit_stall_s1 = instruction_s1_q.instr.valid & is_STORE_or_AMO_s1_q;


always_comb begin
    instruction_o.valid = 1'b0;
    reset_head_lsq      = 1'b0;
    advance_head_lsq    = 1'b0;
    mem_commit_stall_s2 = 1'b0;
    kill_miss           = 1'b0;
    wait_for_response   = 1'b0;
    if(instruction_s2_q.instr.valid & xcpt_s2_q) begin
        instruction_o.valid         = instruction_s2_q.instr.valid;
        instruction_o.pc            = instruction_s2_q.instr.pc;
        instruction_o.bpred         = instruction_s2_q.instr.bpred;
        instruction_o.rs1           = instruction_s2_q.instr.rs1;
        instruction_o.rd            = instruction_s2_q.instr.rd;
        instruction_o.change_pc_ena = instruction_s2_q.instr.change_pc_ena;
        instruction_o.regfile_we    = instruction_s2_q.instr.regfile_we;
        instruction_o.instr_type    = instruction_s2_q.instr.instr_type;
        instruction_o.stall_csr_fence = instruction_s2_q.instr.stall_csr_fence;
        instruction_o.csr_addr      = instruction_s2_q.instr.result[CSR_ADDR_SIZE-1:0];
        instruction_o.prd           = instruction_s2_q.prd;
        instruction_o.checkpoint_done = instruction_s2_q.checkpoint_done;
        instruction_o.chkp          = instruction_s2_q.chkp;
        instruction_o.gl_index      = instruction_s2_q.gl_index;
        instruction_o.branch_taken  = 1'b0;
        instruction_o.result_pc     = 0;
        instruction_o.result        = resp_dcache_cpu_i.data;
        mem_commit_stall_s2         = 1'b0;
        advance_head_lsq            = 1'b1;
    end
    else if (instruction_s2_q.instr.valid & io_s2_q & ~resp_dcache_cpu_i.nack & is_STORE_or_AMO_s2_q) begin
        instruction_o.valid         = instruction_s2_q.instr.valid;
        instruction_o.pc            = instruction_s2_q.instr.pc;
        instruction_o.bpred         = instruction_s2_q.instr.bpred;
        instruction_o.rs1           = instruction_s2_q.instr.rs1;
        instruction_o.rd            = instruction_s2_q.instr.rd;
        instruction_o.change_pc_ena = instruction_s2_q.instr.change_pc_ena;
        instruction_o.regfile_we    = instruction_s2_q.instr.regfile_we;
        instruction_o.instr_type    = instruction_s2_q.instr.instr_type;
        instruction_o.stall_csr_fence = instruction_s2_q.instr.stall_csr_fence;
        instruction_o.csr_addr      = instruction_s2_q.instr.result[CSR_ADDR_SIZE-1:0];
        instruction_o.prd           = instruction_s2_q.prd;
        instruction_o.checkpoint_done = instruction_s2_q.checkpoint_done;
        instruction_o.chkp          = instruction_s2_q.chkp;
        instruction_o.gl_index      = instruction_s2_q.gl_index;
        instruction_o.branch_taken  = 1'b0;
        instruction_o.result_pc     = 0;
        instruction_o.result        = resp_dcache_cpu_i.data;
        mem_commit_stall_s2         = 1'b0;
        advance_head_lsq            = 1'b1;
    end
    else if(instruction_s2_q.instr.valid & io_s2_q & ~is_STORE_or_AMO_s2_q & ~resp_dcache_cpu_i.nack & ~resp_dcache_cpu_i.valid) begin
        instruction_o.valid         = 1'b0;
        mem_commit_stall_s2         = 1'b0;
        advance_head_lsq            = 1'b0;
        wait_for_response           = 1'b1;
    end
    else if(instruction_s2_q.instr.valid & resp_dcache_cpu_i.valid) begin
        instruction_o.valid         = instruction_s2_q.instr.valid;
        instruction_o.pc            = instruction_s2_q.instr.pc;
        instruction_o.bpred         = instruction_s2_q.instr.bpred;
        instruction_o.rs1           = instruction_s2_q.instr.rs1;
        instruction_o.rd            = instruction_s2_q.instr.rd;
        instruction_o.change_pc_ena = instruction_s2_q.instr.change_pc_ena;
        instruction_o.regfile_we    = instruction_s2_q.instr.regfile_we;
        instruction_o.instr_type    = instruction_s2_q.instr.instr_type;
        instruction_o.stall_csr_fence = instruction_s2_q.instr.stall_csr_fence;
        instruction_o.csr_addr      = instruction_s2_q.instr.result[CSR_ADDR_SIZE-1:0];
        instruction_o.prd           = instruction_s2_q.prd;
        instruction_o.checkpoint_done = instruction_s2_q.checkpoint_done;
        instruction_o.chkp          = instruction_s2_q.chkp;
        instruction_o.gl_index      = instruction_s2_q.gl_index;
        instruction_o.branch_taken  = 1'b0;
        instruction_o.result_pc     = 0;
        instruction_o.result        = resp_dcache_cpu_i.data;
        mem_commit_stall_s2         = 1'b0;
        advance_head_lsq            = 1'b1;
   end else if (instruction_s2_q.instr.valid) begin 
        instruction_o.valid         = 1'b0;
        reset_head_lsq              = 1'b1;
        mem_commit_stall_s2         = instruction_s2_q.instr.valid & is_STORE_or_AMO_s2_q;
        kill_miss                   = 1'b1;
   end
end



///////////////////////////////////////////////////////////////////////////////
///// Outputs
///////////////////////////////////////////////////////////////////////////////

assign xcpt_s2_q = instruction_s2_q.instr.valid & (xcpt_ma_st_s2_q | xcpt_ma_ld_s2_q | xcpt_pf_st_s2_q | xcpt_pf_ld_s2_q | instruction_s2_q.instr.ex.valid);

always_comb begin
    instruction_o.ex.cause  = INSTR_ADDR_MISALIGNED;
    instruction_o.ex.origin = 0;
    instruction_o.ex.valid  = 0;
    exception_mem_commit_o.cause  = ST_AMO_ADDR_MISALIGNED;
    exception_mem_commit_o.origin = 0;
    exception_mem_commit_o.valid  = 0;
    if(instruction_s2_q.instr.ex.valid) begin // Propagate exception from previous stages
        instruction_o.ex = instruction_s2_q.instr.ex;
    end else if(xcpt_ma_st_s2_q & instruction_s2_q.instr.valid) begin // Misaligned store
        exception_mem_commit_o.cause    = ST_AMO_ADDR_MISALIGNED;
        exception_mem_commit_o.origin   = xcpt_addr_s2_q;
        exception_mem_commit_o.valid    = 1;
    end else if (xcpt_ma_ld_s2_q & instruction_s2_q.instr.valid) begin // Misaligned load
        instruction_o.ex.cause          = LD_ADDR_MISALIGNED;
        instruction_o.ex.origin         = xcpt_addr_s2_q;
        instruction_o.ex.valid          = 1;
    end else if (xcpt_pf_st_s2_q & instruction_s2_q.instr.valid) begin // Page fault store
        exception_mem_commit_o.cause    = ST_AMO_PAGE_FAULT;
        exception_mem_commit_o.origin   = xcpt_addr_s2_q;
        exception_mem_commit_o.valid    = 1;
    end else if (xcpt_pf_ld_s2_q & instruction_s2_q.instr.valid) begin // Page fault load
        instruction_o.ex.cause          = LD_PAGE_FAULT;
        instruction_o.ex.origin         = xcpt_addr_s2_q;
        instruction_o.ex.valid          = 1;
    end else if (((|resp_dcache_cpu_i.addr[63:40] != 0 && !resp_dcache_cpu_i.addr[39]) ||
                   ( !(&resp_dcache_cpu_i.addr[63:40]) && resp_dcache_cpu_i.addr[39] )) &&
                   instruction_s2_q.instr.valid) begin // invalid address
        case(instruction_s2_q.instr.instr_type)
            SD, SW, SH, SB, AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
            AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW,
            AMO_MAXWU, AMO_MINW, AMO_MINWU, AMO_SWAPD, AMO_ADDD,
            AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU: begin
                exception_mem_commit_o.cause  = ST_AMO_ACCESS_FAULT;
                exception_mem_commit_o.origin = resp_dcache_cpu_i.addr;
                exception_mem_commit_o.valid  = 1;
            end
            LD,LW,LWU,LH,LHU,LB,LBU: begin
                instruction_o.ex.cause  = LD_ACCESS_FAULT;
                instruction_o.ex.origin = resp_dcache_cpu_i.addr;
                instruction_o.ex.valid  = 1;
            end
            default: begin
                `ifdef ASSERTIONS
                    assert (1 == 0);
                `endif
                instruction_o.ex.valid = 0;
            end
        endcase
    end 
end

assign mem_commit_stall_o = mem_commit_stall_s0 | mem_commit_stall_s1 | mem_commit_stall_s2;

assign req_cpu_dcache_o.kill = kill_i | xcpt_s1_q;
assign req_cpu_dcache_o.io_base_addr = io_base_addr_i;


assign lock_o   = full_lsq;
assign empty_o  = empty_lsq & ~req_cpu_dcache_o.valid;

endmodule
