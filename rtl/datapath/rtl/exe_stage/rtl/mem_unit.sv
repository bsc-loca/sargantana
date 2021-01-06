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
    output logic            lock_o,                 // Mem unit is able to accept more petitions
    output logic            empty_o                 // Mem unit has no pending Ops
);

logic is_STORE_or_AMO;

logic full_lsq;
logic empty_lsq;
logic flush_to_lsq;
logic read_head_lsq;
rr_exe_instr_t instruction_to_lsq;
rr_exe_instr_t instruction_to_dcache;
rr_exe_instr_t stored_instr_to_dcache;
bus64_t data_rs1_to_dcache;
bus64_t data_rs2_to_dcache;
bus64_t stored_data_rs1;
bus64_t stored_data_rs2;


// State machine variables

logic [1:0] state;
logic [1:0] next_state;

// Possible states of the control automata
parameter ResetState  = 2'b00,
          ReadHead = 2'b01,
          WaitResponse = 2'b10,
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
    .read_head_i        (read_head_lsq),
    .instruction_o      (instruction_to_dcache),
    .data_rs1_o         (data_rs1_to_dcache),
    .data_rs2_o         (data_rs2_to_dcache),                 
    .ls_queue_entry_o   (),        
    .full_o             (full_lsq),
    .empty_o            (empty_lsq)
);

///////////////////////////////////////////////////////////////////////////////
///// MSHR invert index
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
///// State machine
///////////////////////////////////////////////////////////////////////////////


// Update State
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
        state <= ResetState;
    else
        state <= next_state;
end

// Update State
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
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
            req_cpu_dcache_o.valid = 1'b0;              // Invalid instruction
            req_cpu_dcache_o.data_rs1 = 64'h0;
            req_cpu_dcache_o.data_rs2 = 64'h0;
            req_cpu_dcache_o.instr_type = ADD;
            req_cpu_dcache_o.mem_size = 3'h0;
            req_cpu_dcache_o.rd = 5'h0;
            next_state = ReadHead;        // Next state Read Head
            read_head_lsq = 1'b0;          // Read head of LSQ
            mem_commit_stall_o = 1'b0;
            instruction_o.valid = 0;
        end
        // Read head of LSQ
        ReadHead: begin
            if (kill_i) begin
                req_cpu_dcache_o.valid = 1'b0;              // Invalid instruction
                req_cpu_dcache_o.instr_type = ADD;
                next_state = ReadHead;        // Next state Read Head
                read_head_lsq = 1'b1;          // Read head of LSQ  
                mem_commit_stall_o = 1'b0;
                instruction_o.valid = 0;
            end else begin
                req_cpu_dcache_o.valid = instruction_to_dcache.instr.valid & ~is_STORE_or_AMO;
                req_cpu_dcache_o.data_rs1 = data_rs1_to_dcache;
                req_cpu_dcache_o.data_rs2 = data_rs2_to_dcache;
                req_cpu_dcache_o.instr_type = instruction_to_dcache.instr.instr_type;
                req_cpu_dcache_o.mem_size = instruction_to_dcache.instr.mem_size;
                req_cpu_dcache_o.rd = instruction_to_dcache.instr.rd;
                req_cpu_dcache_o.imm = instruction_to_dcache.instr.result;
                next_state = (~instruction_to_dcache.instr.valid) ? ReadHead : (is_STORE_or_AMO) ? WaitCommit : WaitResponse; 
                read_head_lsq = 1'b1;
                mem_commit_stall_o = instruction_to_dcache.instr.valid & is_STORE_or_AMO;
                instruction_o.valid = 0;
            end
        end
        // Waiting response of Dcache interface
        WaitResponse: begin
            if (kill_i) begin
                req_cpu_dcache_o.valid = 1'b0;              // Invalid instruction
                req_cpu_dcache_o.data_rs1 = stored_data_rs1;
                req_cpu_dcache_o.data_rs2 = stored_data_rs2;
                req_cpu_dcache_o.imm = stored_instr_to_dcache.instr.result;
                req_cpu_dcache_o.instr_type = stored_instr_to_dcache.instr.instr_type;
                req_cpu_dcache_o.mem_size = stored_instr_to_dcache.instr.mem_size;
                req_cpu_dcache_o.rd = 5'h0;
                next_state = ReadHead;        // Next state Read Head
                read_head_lsq = 1'b0;         
                mem_commit_stall_o = 1'b0;
                instruction_o.valid = 0;
            end else begin
                req_cpu_dcache_o.valid = stored_instr_to_dcache.instr.valid;
                req_cpu_dcache_o.data_rs1 = stored_data_rs1;
                req_cpu_dcache_o.data_rs2 = stored_data_rs2;
                req_cpu_dcache_o.instr_type = stored_instr_to_dcache.instr.instr_type;
                req_cpu_dcache_o.mem_size = stored_instr_to_dcache.instr.mem_size;
                req_cpu_dcache_o.rd = stored_instr_to_dcache.instr.rd;
                req_cpu_dcache_o.imm = stored_instr_to_dcache.instr.result;
                if (resp_dcache_cpu_i.lock) begin
                    instruction_o.valid = 0;
                    next_state = WaitResponse;
                    read_head_lsq = 1'b0;
                    mem_commit_stall_o = commit_store_or_amo_i;
                end else begin
                    instruction_o.valid         = stored_instr_to_dcache.instr.valid;
                    instruction_o.pc            = stored_instr_to_dcache.instr.pc;
                    instruction_o.bpred         = stored_instr_to_dcache.instr.bpred;
                    instruction_o.rs1           = stored_instr_to_dcache.instr.rs1;
                    instruction_o.rd            = stored_instr_to_dcache.instr.rd;
                    instruction_o.change_pc_ena = stored_instr_to_dcache.instr.change_pc_ena;
                    instruction_o.regfile_we    = stored_instr_to_dcache.instr.regfile_we;
                    instruction_o.instr_type    = stored_instr_to_dcache.instr.instr_type;
                    instruction_o.stall_csr_fence = stored_instr_to_dcache.instr.stall_csr_fence;
                    instruction_o.csr_addr      = stored_instr_to_dcache.instr.result[CSR_ADDR_SIZE-1:0];
                    instruction_o.prd           = stored_instr_to_dcache.prd;
                    instruction_o.checkpoint_done = stored_instr_to_dcache.checkpoint_done;
                    instruction_o.chkp          = stored_instr_to_dcache.chkp;
                    instruction_o.gl_index      = stored_instr_to_dcache.gl_index;
                    instruction_o.branch_taken  = 1'b0;
                    instruction_o.result_pc     = 0;
                    instruction_o.result        = resp_dcache_cpu_i.data;

                    next_state = ReadHead;
                    read_head_lsq = 1'b0;
                    mem_commit_stall_o = 1'b0;
                end
            end
        end
        WaitCommit: begin
            if (kill_i) begin
                req_cpu_dcache_o.valid = 1'b0;              // Invalid instruction
                req_cpu_dcache_o.data_rs1 = 64'h0;
                req_cpu_dcache_o.data_rs2 = 64'h0;
                req_cpu_dcache_o.instr_type = ADD;
                req_cpu_dcache_o.mem_size = 3'h0;
                req_cpu_dcache_o.rd = 5'h0;
                next_state = ReadHead;        // Next state Read Head
                read_head_lsq = 1'b1;          // Read head of LSQ
                mem_commit_stall_o = 1'b0;
                instruction_o.valid = 0;
            end else begin
                req_cpu_dcache_o.valid = commit_store_or_amo_i;
                req_cpu_dcache_o.data_rs1 = stored_data_rs1;
                req_cpu_dcache_o.data_rs2 = stored_data_rs2;
                req_cpu_dcache_o.instr_type = stored_instr_to_dcache.instr.instr_type;
                req_cpu_dcache_o.mem_size = stored_instr_to_dcache.instr.mem_size;
                req_cpu_dcache_o.rd = stored_instr_to_dcache.instr.rd;
                req_cpu_dcache_o.imm = stored_instr_to_dcache.instr.result;
                next_state = (commit_store_or_amo_i) ? WaitResponse : WaitCommit;
                read_head_lsq = 1'b0;
                mem_commit_stall_o = commit_store_or_amo_i;
                instruction_o.valid = 0;
            end
        end
        default: begin
            `ifdef ASSERTIONS
                assert(1 == 0);
            `endif
            next_state = ResetState;
        end
    endcase
end


assign is_STORE_or_AMO = (instruction_to_dcache.instr.instr_type == SD)          || 
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
                         (instruction_to_dcache.instr.instr_type == AMO_LRD)     ||
                         (instruction_to_dcache.instr.instr_type == SW)          ;


///////////////////////////////////////////////////////////////////////////////
///// Outputs
///////////////////////////////////////////////////////////////////////////////

always_comb begin
    instruction_o.ex.cause  = INSTR_ADDR_MISALIGNED;
    instruction_o.ex.origin = 0;
    instruction_o.ex.valid  = 0;
    exception_mem_commit_o.cause  = ST_AMO_ADDR_MISALIGNED;
    exception_mem_commit_o.origin = 0;
    exception_mem_commit_o.valid  = 0;
    if(stored_instr_to_dcache.instr.ex.valid) begin // Propagate exception from previous stages
        instruction_o.ex = stored_instr_to_dcache.instr.ex;
    end else if(stored_instr_to_dcache.instr.valid & ~resp_dcache_cpu_i.lock) begin // Check exceptions in exe stage
        if(resp_dcache_cpu_i.xcpt_ma_st && stored_instr_to_dcache.instr.unit == UNIT_MEM) begin // Misaligned store
            exception_mem_commit_o.cause  = ST_AMO_ADDR_MISALIGNED;
            exception_mem_commit_o.origin = resp_dcache_cpu_i.addr;
            exception_mem_commit_o.valid  = 1;
        end else if (resp_dcache_cpu_i.xcpt_ma_ld && stored_instr_to_dcache.instr.unit == UNIT_MEM) begin // Misaligned load
            instruction_o.ex.cause = LD_ADDR_MISALIGNED;
            instruction_o.ex.origin = resp_dcache_cpu_i.addr;
            instruction_o.ex.valid = 1;
        end else if (resp_dcache_cpu_i.xcpt_pf_st && stored_instr_to_dcache.instr.unit == UNIT_MEM) begin // Page fault store
            exception_mem_commit_o.cause  = ST_AMO_PAGE_FAULT;
            exception_mem_commit_o.origin = resp_dcache_cpu_i.addr;
            exception_mem_commit_o.valid  = 1;
        end else if (resp_dcache_cpu_i.xcpt_pf_ld && stored_instr_to_dcache.instr.unit == UNIT_MEM) begin // Page fault load
            instruction_o.ex.cause = LD_PAGE_FAULT;
            instruction_o.ex.origin = resp_dcache_cpu_i.addr;
            instruction_o.ex.valid = 1;
        end else if (((|resp_dcache_cpu_i.addr[63:40] != 0 && !resp_dcache_cpu_i.addr[39]) ||
                      ( !(&resp_dcache_cpu_i.addr[63:40]) && resp_dcache_cpu_i.addr[39] )) &&
                     stored_instr_to_dcache.instr.unit == UNIT_MEM) begin // invalid address
            case(stored_instr_to_dcache.instr.instr_type)
                SD, SW, SH, SB, AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
                AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW,
                AMO_MAXWU, AMO_MINW, AMO_MINWU, AMO_SWAPD, AMO_ADDD,
                AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU: begin
                    exception_mem_commit_o.cause  = ST_AMO_ACCESS_FAULT;
                    exception_mem_commit_o.origin = resp_dcache_cpu_i.addr;
                    exception_mem_commit_o.valid  = 1;
                end
                LD,LW,LWU,LH,LHU,LB,LBU: begin
                    instruction_o.ex.cause = LD_ACCESS_FAULT;
                    instruction_o.ex.origin = resp_dcache_cpu_i.addr;
                    instruction_o.ex.valid = 1;
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
end

logic lock;
assign lock = resp_dcache_cpu_i.lock;
assign req_cpu_dcache_o.kill = kill_i;
assign req_cpu_dcache_o.io_base_addr = io_base_addr_i;


assign lock_o   = full_lsq;

assign empty_o  = empty_lsq & ~req_cpu_dcache_o.valid;

endmodule
