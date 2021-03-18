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
    input  wire                  clk_i,                  // Clock signal
    input  wire                  rstn_i,                 // Reset signal
    input logic                  kill_i,                 // Exception detected at Commit
    input logic                  flush_i,                // Delete all load_store_queue entries
    input addr_t                 io_base_addr_i,         // Input_output_address

    input rr_exe_mem_instr_t     instruction_i,          // Interface to add new instuction
    input resp_dcache_cpu_t      resp_dcache_cpu_i,      // Response from dcache
    input wire                   commit_store_or_amo_i,  // Signal from commit enables writes.


    output req_cpu_dcache_t      req_cpu_dcache_o,       // Request to dcache
    output exe_wb_simd_instr_t   instruction_simd_o,     // Output instruction     
    output exe_wb_scalar_instr_t scalar_instruction_o,   // Output instruction
    output exe_wb_fp_instr_t     fp_instruction_o,       // Output instruction     
    output exception_t           exception_mem_commit_o, // Exception of the commit instruction
    output logic                 mem_commit_stall_o,     // Stall commit stage
    output logic 		         mem_store_or_amo_o,     // Instruction is a Store or Commit
    output gl_index_t            mem_gl_index_o,         // GL Index of the memory instruction
    output logic                 lock_o,                 // Mem unit is able to accept more petitions
    output logic                 empty_o,                // Mem unit has no pending Ops
    
    output logic                 pmu_load_after_store_o  // Load blocked by ongoing store
);

// Enum to select instruction to DCache interface
typedef enum logic[1:0] {
    NULL        = 2'b00,
    READ        = 2'b01,
    STORED      = 2'b10
} source_lsq_t;               

bus64_t data_src1;
bus_simd_t data_src2;

source_lsq_t source_dcache;

// Track Store and AMO in the pipeline and related Stall
logic is_STORE_or_AMO_s0_d;
logic is_STORE_or_AMO_s1_q;
logic is_STORE_or_AMO_s2_q;
logic is_STORE_s0_d;
logic is_STORE_s1_q;
logic is_STORE_s2_q;

logic flush_store;
logic flush_amo;
logic flush_amo_prmq;
logic flush_store_nack;
logic store_on_fly;
logic amo_on_fly;
logic mem_commit_stall_s0;

// Load Store Queue control signals
logic full_lsq;
logic empty_lsq;
logic flush_to_lsq;
logic read_next_lsq;
logic reset_next_lsq;
logic advance_exec_lsq;
logic advance_head_lsq;

// Instruction to LSQ and pipline
rr_exe_mem_instr_t instruction_to_lsq;
rr_exe_mem_instr_t instruction_to_dcache;
rr_exe_mem_instr_t stored_instr_to_dcache;
rr_exe_mem_instr_t instruction_to_wb;
rr_exe_mem_instr_t instruction_s1_d;
rr_exe_mem_instr_t instruction_s1_q;
rr_exe_mem_instr_t instruction_s2_q;

// Input/Output Pipeline
logic io_s1_q;
logic io_s2_q;

// Tag Counter and Pipeline
reg_t tag_id;
reg_t tag_id_s1_q;
reg_t tag_id_s2_q;

// Exception pipeline
logic xcpt;
logic xcpt_s1_q;
logic xcpt_s2_q;
logic xcpt_ma_st_s2_q; 
logic xcpt_ma_ld_s2_q;
logic xcpt_pf_st_s2_q;
logic xcpt_pf_ld_s2_q;
bus64_t xcpt_addr_s1_q;
bus64_t xcpt_addr_s2_q;
exception_t exception_to_wb;


rr_exe_mem_instr_t instruction_to_pmrq;
rr_exe_mem_instr_t instruction_from_pmrq;

// PMRQ control signals
logic advance_head_prmq;
logic full_pmrq;

// Select data source
bus_simd_t data_to_wb;

// State machine variables
logic [1:0] state;
logic [1:0] next_state;

logic fp_instr;

// Possible states of the control automata
parameter ResetState  = 2'b00,
          ReadHead = 2'b01,
          WaitReady = 2'b10,
          WaitCommit = 2'b11;

assign fp_instr = (instruction_to_wb.instr.instr_type == FLD || instruction_to_wb.instr.instr_type == FLW ||
                   instruction_to_wb.instr.instr_type == FSD || instruction_to_wb.instr.instr_type == FSW );

assign data_src1 = instruction_i.data_rs1;
assign data_src2 = instruction_i.data_rs2;

///////////////////////////////////////////////////////////////////////////////
///// LOAD STORE QUEUE
///////////////////////////////////////////////////////////////////////////////

// Flush LSQ
assign flush_to_lsq = kill_i | flush_i;

// Input instruction to LSQreplay_data_i
assign instruction_to_lsq.instr = (instruction_i.instr.unit == UNIT_MEM && instruction_i.instr.valid) ? instruction_i.instr : 'h0 ;
assign instruction_to_lsq.data_rs1      = instruction_i.data_rs1;
assign instruction_to_lsq.data_rs2      = instruction_i.data_rs2;
assign instruction_to_lsq.prd           = instruction_i.prd;
assign instruction_to_lsq.pvd           = instruction_i.pvd;
assign instruction_to_lsq.fprd          = instruction_i.fprd;
assign instruction_to_lsq.gl_index      = instruction_i.gl_index;

// LSQ
load_store_queue load_store_queue_inst (
    .clk_i              (clk_i),
    .rstn_i             (rstn_i),
    .instruction_i      (instruction_to_lsq),
    .flush_i            (flush_to_lsq),
    .read_next_i        (read_next_lsq),
    .reset_next_i       (reset_next_lsq),
    .advance_head_i     (advance_head_lsq),
    .next_instr_exe_o   (instruction_to_dcache),
    .full_o             (full_lsq),
    .empty_o            (empty_lsq),
    .pmu_load_after_store_o (pmu_load_after_store_o)
);

///////////////////////////////////////////////////////////////////////////////
///// State machine Stage 0
///////////////////////////////////////////////////////////////////////////////


// Update State Machine and Stored Instruction
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        state <= ResetState;
        stored_instr_to_dcache.instr.valid <= 1'b0;
    end else if (reset_next_lsq) begin
        state <= ReadHead;
        stored_instr_to_dcache.instr.valid <= 1'b0;
    end else begin
        state <= next_state;
        if (read_next_lsq & instruction_to_dcache.instr.valid) begin
            stored_instr_to_dcache <= instruction_to_dcache;
        end
    end
end


// Mealy Output and Next State
always_comb begin
    if (kill_i) begin
        req_cpu_dcache_o.valid      = 1'b0;     // No Request
        source_dcache               = NULL;     
        read_next_lsq               = 1'b1;     // No Advance LSQ
        mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
        instruction_s1_d            = 'h0;      // No Instruction to next stage
        next_state                  = ReadHead; // Next state Read Head
    end else begin
        case(state)
            ////////////////////////////////////////////////// Reset state
            ResetState: begin
                req_cpu_dcache_o.valid      = 1'b0;         // No Request
                source_dcache               = NULL;         
                read_next_lsq               = 1'b0;         // No Read of LSQ
                mem_commit_stall_s0         = 1'b0;         // No Stall of Commit
                instruction_s1_d            = 'h0;          // No Instruction to next stage
                next_state                  = ReadHead;     // Next state Read Head
            end
            ////////////////////////////////////////////////// Read head of LSQ
            ReadHead: begin
                if (empty_lsq) begin
                    req_cpu_dcache_o.valid      = 1'b0;     // No Request
                    source_dcache               = NULL;     
                    read_next_lsq               = 1'b1;     // No Advance LSQ 
                    mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
                    instruction_s1_d            = 'h0;      // No Instruction to next stage
                    next_state                  = ReadHead; // Next state Read Head
                end else begin
                    // Request Logic
                    req_cpu_dcache_o.valid      = (instruction_to_dcache.instr.valid & resp_dcache_cpu_i.ready) & 
                                                  (~is_STORE_or_AMO_s0_d | commit_store_or_amo_i) & (~full_pmrq) &
                                                  (~(store_on_fly | amo_on_fly) | ~is_STORE_or_AMO_s0_d | 
                                                    (mem_gl_index_o == instruction_to_dcache.gl_index));
                                                  
                    source_dcache               = READ;     // Use instruction from LSQ
                    read_next_lsq               = 1'b1;     // Advance LSQ 
                    mem_commit_stall_s0         = instruction_to_dcache.instr.valid & (~full_pmrq) & // Stall Commit if Store
                                                  is_STORE_or_AMO_s0_d & commit_store_or_amo_i &
                                                  (~(store_on_fly | amo_on_fly) | (mem_gl_index_o == instruction_to_dcache.gl_index)); 
                    
                    // Next Stage Logic
                    if (instruction_to_dcache.instr.valid & ~resp_dcache_cpu_i.ready) begin
                        instruction_s1_d        = 'h0;
                    end else if (full_pmrq) begin
                        instruction_s1_d        = 'h0;
                    end else if (is_STORE_or_AMO_s0_d & !commit_store_or_amo_i) begin
                        instruction_s1_d        = 'h0;
                    end else if((store_on_fly | amo_on_fly) & is_STORE_or_AMO_s0_d &
                                ~(mem_gl_index_o == instruction_to_dcache.gl_index)) begin
                        instruction_s1_d        = 'h0;
                    end else begin
                        instruction_s1_d        = instruction_to_dcache;
                    end
                    
                    // Next Sate Logic                                          
                    next_state = (instruction_to_dcache.instr.valid & resp_dcache_cpu_i.ready & (~full_pmrq) &
                                 (~(store_on_fly | amo_on_fly) | ~is_STORE_or_AMO_s0_d | (mem_gl_index_o == instruction_to_dcache.gl_index))) ?
                                    (is_STORE_or_AMO_s0_d & !commit_store_or_amo_i) ? WaitCommit : ReadHead :
                                    WaitReady; 
                end
            end
            ////////////////////////////////////////////////// Wait for Ready DCACHE
            WaitReady: begin
                // Request Logic
                req_cpu_dcache_o.valid      = (stored_instr_to_dcache.instr.valid & resp_dcache_cpu_i.ready & 
                                              (commit_store_or_amo_i | ~is_STORE_or_AMO_s0_d) & (~full_pmrq) &
                                              (~(store_on_fly | amo_on_fly) | ~is_STORE_or_AMO_s0_d | 
                                                (mem_gl_index_o == stored_instr_to_dcache.gl_index)));
                                                 
                source_dcache               = STORED;   // Use instruction stored previously
                read_next_lsq               = 1'b0;     // Not Advance LSQ
                mem_commit_stall_s0         = stored_instr_to_dcache.instr.valid & (~full_pmrq) & // Stall Commit if Store
                                              is_STORE_or_AMO_s0_d & commit_store_or_amo_i & 
                                              (~(store_on_fly | amo_on_fly)| (mem_gl_index_o == stored_instr_to_dcache.gl_index));

                // Next Stage Logic
                if (stored_instr_to_dcache.instr.valid & ~resp_dcache_cpu_i.ready) begin
                    instruction_s1_d        = 'h0;
                end else if (full_pmrq) begin
                    instruction_s1_d        = 'h0;
                end else if (is_STORE_or_AMO_s0_d & !commit_store_or_amo_i) begin
                    instruction_s1_d        = 'h0;
                end else if((store_on_fly | amo_on_fly) & is_STORE_or_AMO_s0_d &
                             ~(mem_gl_index_o == stored_instr_to_dcache.gl_index)) begin
                    instruction_s1_d        = 'h0;
                end else begin
                    instruction_s1_d        = stored_instr_to_dcache;
                end
                    
                // Next Sate Logic
                next_state = (stored_instr_to_dcache.instr.valid & resp_dcache_cpu_i.ready  & (~full_pmrq) &
                             (~(store_on_fly | amo_on_fly)| ~is_STORE_or_AMO_s0_d | (mem_gl_index_o == stored_instr_to_dcache.gl_index))) ?
                                (is_STORE_or_AMO_s0_d & !commit_store_or_amo_i) ? WaitCommit : ReadHead :
                                 WaitReady; 
            end
            ////////////////////////////////////////////////// Wait for Store to DCACHE
            WaitCommit: begin
                // Request Logic
                req_cpu_dcache_o.valid      = commit_store_or_amo_i & ~(store_on_fly | amo_on_fly)&
                                              resp_dcache_cpu_i.ready & (~full_pmrq);
                source_dcache               = STORED;                   // Use instruction stored previously
                read_next_lsq               = 1'b0;                     // Not Advance LSQ
                mem_commit_stall_s0         = commit_store_or_amo_i & (~full_pmrq);

                // Next Stage Logic
                if (commit_store_or_amo_i & ~(store_on_fly | amo_on_fly) & resp_dcache_cpu_i.ready) begin
                    instruction_s1_d  = stored_instr_to_dcache;
                end else if (full_pmrq) begin
                    instruction_s1_d  = 'h0;
                end else begin
                    instruction_s1_d  = 'h0;
                end
                
                // Next Sate Logic
                next_state = (commit_store_or_amo_i & ~(store_on_fly | amo_on_fly) & resp_dcache_cpu_i.ready & (~full_pmrq)) ?
                                ReadHead : WaitCommit;
            end
        endcase
    end
end

// Update State Machine and Stored Instruction
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        tag_id <= 'h0;
    end else if (reset_next_lsq) begin
        tag_id <= tag_id_s2_q;
    end else begin
        if (req_cpu_dcache_o.valid) begin
            tag_id <= tag_id + 5'h1;
        end
    end
end

//// Select source to DCACHE interface
always_comb begin
    req_cpu_dcache_o.data_rs1   = 64'h0;
    req_cpu_dcache_o.instr_type = ADD;
    req_cpu_dcache_o.mem_size   = 3'h0;
    req_cpu_dcache_o.rd         = 5'h0;
    req_cpu_dcache_o.imm        = 64'h0;
    case(source_dcache)
        NULL:         begin
            req_cpu_dcache_o.data_rs1   = 64'h0;
            req_cpu_dcache_o.instr_type = ADD;
            req_cpu_dcache_o.mem_size   = 3'h0;
            req_cpu_dcache_o.rd         = 5'h0;
        end
        READ:         begin
            req_cpu_dcache_o.data_rs1   = instruction_to_dcache.data_rs1;
            req_cpu_dcache_o.instr_type = instruction_to_dcache.instr.instr_type;
            req_cpu_dcache_o.mem_size   = instruction_to_dcache.instr.mem_size;
            req_cpu_dcache_o.rd         = tag_id;
            req_cpu_dcache_o.imm        = instruction_to_dcache.instr.imm;
        end
        STORED:         begin
            req_cpu_dcache_o.data_rs1   = stored_instr_to_dcache.data_rs1;
            req_cpu_dcache_o.instr_type = stored_instr_to_dcache.instr.instr_type;
            req_cpu_dcache_o.mem_size   = stored_instr_to_dcache.instr.mem_size;
            req_cpu_dcache_o.rd         = tag_id;
            req_cpu_dcache_o.imm        = stored_instr_to_dcache.instr.imm;
        end
    endcase
end
// FLD, FLW, FSD, FSW,
//// Detect if instruction to Dcache is store or AMO
assign is_STORE_or_AMO_s0_d = (req_cpu_dcache_o.instr_type == SD)          || 
                              (req_cpu_dcache_o.instr_type == SW)          ||
                              (req_cpu_dcache_o.instr_type == SH)          ||
                              (req_cpu_dcache_o.instr_type == SB)          ||
                              (req_cpu_dcache_o.instr_type == VSE)         ||
                              (req_cpu_dcache_o.instr_type == FSD)         ||
                              (req_cpu_dcache_o.instr_type == FSW)         ||
                              (req_cpu_dcache_o.instr_type == AMO_MAXWU)   ||
                              (req_cpu_dcache_o.instr_type == AMO_MAXDU)   ||
                              (req_cpu_dcache_o.instr_type == AMO_MINWU)   ||
                              (req_cpu_dcache_o.instr_type == AMO_MINDU)   ||
                              (req_cpu_dcache_o.instr_type == AMO_MAXW)    ||
                              (req_cpu_dcache_o.instr_type == AMO_MAXD)    ||
                              (req_cpu_dcache_o.instr_type == AMO_MINW)    ||
                              (req_cpu_dcache_o.instr_type == AMO_MIND)    ||
                              (req_cpu_dcache_o.instr_type == AMO_ORW)     ||
                              (req_cpu_dcache_o.instr_type == AMO_ORD)     ||
                              (req_cpu_dcache_o.instr_type == AMO_ANDW)    ||
                              (req_cpu_dcache_o.instr_type == AMO_ANDD)    ||
                              (req_cpu_dcache_o.instr_type == AMO_XORW)    ||
                              (req_cpu_dcache_o.instr_type == AMO_XORD)    ||
                              (req_cpu_dcache_o.instr_type == AMO_ADDW)    ||
                              (req_cpu_dcache_o.instr_type == AMO_ADDD)    ||
                              (req_cpu_dcache_o.instr_type == AMO_SWAPW)   ||
                              (req_cpu_dcache_o.instr_type == AMO_SWAPD)   ||
                              (req_cpu_dcache_o.instr_type == AMO_SCW)     ||
                              (req_cpu_dcache_o.instr_type == AMO_SCD)     ||
                              (req_cpu_dcache_o.instr_type == AMO_LRW)     ||
                              (req_cpu_dcache_o.instr_type == AMO_LRD)     ;

//// Detect if instruction to Dcache is store or AMO
assign is_STORE_s0_d = (req_cpu_dcache_o.instr_type == SD)          || 
                       (req_cpu_dcache_o.instr_type == SW)          ||
                       (req_cpu_dcache_o.instr_type == SH)          ||
                       (req_cpu_dcache_o.instr_type == SB)          ;

//// Store in the Pipeline Send the GL index to commit to match the commiting instruction with the Store
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        store_on_fly    <= 1'b0;
        amo_on_fly      <= 1'b0;
        mem_gl_index_o  <= 'h0;
    end 
    else if (instruction_s1_d.instr.valid & is_STORE_or_AMO_s0_d) begin
        store_on_fly    <= is_STORE_s0_d; 
        amo_on_fly      <= !is_STORE_s0_d; 
        mem_gl_index_o  <= instruction_s1_d.gl_index;
    end
    else if (flush_store) begin
        store_on_fly    <= 1'b0; 
        mem_gl_index_o  <= 'h0;
    end
    else if (flush_amo | flush_amo_prmq) begin
        amo_on_fly      <= 1'b0; 
        mem_gl_index_o  <= 'h0;
    end
end

//// Pipeline the Memory access and the responses to track the state
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        instruction_s1_q     <= 'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_s1_q        <= 1'b0;
        io_s1_q              <= 1'b0;
        tag_id_s1_q          <= 'h0;
        
        instruction_s2_q     <= 'h0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        is_STORE_s2_q        <= 1'b0;
        xcpt_ma_st_s2_q      <= 1'b0;
        xcpt_ma_ld_s2_q      <= 1'b0;
        xcpt_pf_st_s2_q      <= 1'b0;
        xcpt_pf_ld_s2_q      <= 1'b0;
        xcpt_addr_s2_q       <= 'h0;
        io_s2_q              <= 1'b0;
        tag_id_s2_q          <= 'h0;
    end else if (reset_next_lsq) begin       // In case of miss flush the pipeline
        instruction_s1_q     <= 'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_s1_q        <= 1'b0;
        io_s1_q              <= 1'b0;
        tag_id_s1_q          <= 'h0;
        
        instruction_s2_q     <= 'h0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        is_STORE_s2_q        <= 1'b0;
        xcpt_ma_st_s2_q      <= 1'b0;
        xcpt_ma_ld_s2_q      <= 1'b0;
        xcpt_pf_st_s2_q      <= 1'b0;
        xcpt_pf_ld_s2_q      <= 1'b0;
        xcpt_addr_s2_q       <= 'h0;
        io_s2_q              <= 1'b0;
        tag_id_s2_q          <= 'h0;
    end else begin          // Update the Pipeline    
        instruction_s1_q     <= instruction_s1_d;
        is_STORE_or_AMO_s1_q <= is_STORE_or_AMO_s0_d;
        is_STORE_s1_q        <= is_STORE_s0_d;
        xcpt_addr_s1_q       <= resp_dcache_cpu_i.addr;
        io_s1_q              <= resp_dcache_cpu_i.io_address_space;
        tag_id_s1_q          <= tag_id;
                
        instruction_s2_q     <= instruction_s1_q;
        is_STORE_or_AMO_s2_q <= is_STORE_or_AMO_s1_q;
        is_STORE_s2_q        <= is_STORE_s1_q;
        xcpt_ma_st_s2_q      <= resp_dcache_cpu_i.xcpt_ma_st;
        xcpt_ma_ld_s2_q      <= resp_dcache_cpu_i.xcpt_ma_ld;
        xcpt_pf_st_s2_q      <= resp_dcache_cpu_i.xcpt_pf_st;
        xcpt_pf_ld_s2_q      <= resp_dcache_cpu_i.xcpt_pf_ld;
        xcpt_addr_s2_q       <= xcpt_addr_s1_q;
        io_s2_q              <= io_s1_q;
        tag_id_s2_q          <= tag_id_s1_q;
    end
end

//// In case of Store or AMO the Data to be written is sent at second stage
assign req_cpu_dcache_o.data_rs2 = instruction_s1_q.data_rs2;

//// Keep tracking an AMO or STORE if it is in the pipeline to stall the commit until access finished
assign mem_commit_stall_s1 = instruction_s1_q.instr.valid & is_STORE_or_AMO_s1_q;

//// Check if there has been an exception, to send the instruction with the exception to writeback
assign xcpt_s2_q = instruction_s2_q.instr.valid & (instruction_s2_q.instr.ex.valid |
                        xcpt_ma_st_s2_q | xcpt_ma_ld_s2_q | xcpt_pf_st_s2_q | xcpt_pf_ld_s2_q |
                        (|xcpt_addr_s2_q[63:40] != 0 && !xcpt_addr_s2_q[39]) |
                        (!(&xcpt_addr_s2_q[63:40]) && xcpt_addr_s2_q[39] )   );

//// Decide if the pipeline needs to be flushed.
always_comb begin
    reset_next_lsq      = 1'b0;
    advance_head_lsq    = 1'b0;
    flush_store         = 1'b0;
    flush_amo           = 1'b0;
    instruction_to_pmrq = 'h0;
    if(instruction_s2_q.instr.valid & resp_dcache_cpu_i.nack) begin
        reset_next_lsq      = 1'b1;
    end else if (instruction_s2_q.instr.valid & resp_dcache_cpu_i.valid & 
                 ~resp_dcache_cpu_i.replay) begin 
        advance_head_lsq    = 1'b1;
        flush_store         = is_STORE_s2_q;
        flush_amo           = is_STORE_or_AMO_s2_q & !is_STORE_s2_q;
    end else if (instruction_s2_q.instr.valid & xcpt_s2_q) begin 
        advance_head_lsq    = 1'b1;
        instruction_to_pmrq = 'h0;
        flush_store         = is_STORE_s2_q;
        flush_amo           = is_STORE_or_AMO_s2_q & !is_STORE_s2_q;
    end else if (instruction_s2_q.instr.valid & io_s2_q & is_STORE_or_AMO_s2_q) begin
        advance_head_lsq    = 1'b1;
        instruction_to_pmrq = 'h0;
        flush_store         = 1'b1;
        flush_amo           = 1'b1;
    end else if (instruction_s2_q.instr.valid & !is_STORE_s2_q) begin 
        advance_head_lsq    = 1'b1;
        instruction_to_pmrq = instruction_s2_q;
    end else if (instruction_s2_q.instr.valid & is_STORE_s2_q) begin
        advance_head_lsq    = 1'b1;
        flush_store         = 1'b1;
    end
end

///////////////////////////////////////////////////////////////////////////////
///// Exception Treatment for Loads (to WB) and Stores (to Commit)
///////////////////////////////////////////////////////////////////////////////

always_comb begin
    exception_to_wb.cause  = INSTR_ADDR_MISALIGNED;
    exception_to_wb.origin = 'h0;
    exception_to_wb.valid  = 1'b0;
    if(instruction_s2_q.instr.ex.valid) begin // Propagate exception from previous stages
        exception_to_wb = instruction_s2_q.instr.ex;
    end else if(xcpt_ma_st_s2_q & instruction_s2_q.instr.valid) begin // Misaligned store
        exception_to_wb.cause       = ST_AMO_ADDR_MISALIGNED;
        exception_to_wb.origin      = xcpt_addr_s2_q;
        exception_to_wb.valid       = 1'b1;
    end else if (xcpt_ma_ld_s2_q & instruction_s2_q.instr.valid) begin // Misaligned load
        exception_to_wb.cause       = LD_ADDR_MISALIGNED;
        exception_to_wb.origin      = xcpt_addr_s2_q;
        exception_to_wb.valid       = 1'b1;
    end else if (xcpt_pf_st_s2_q & instruction_s2_q.instr.valid) begin // Page fault store
        exception_to_wb.cause       = ST_AMO_PAGE_FAULT;
        exception_to_wb.origin      = xcpt_addr_s2_q;
        exception_to_wb.valid    = 1'b1;
    end else if (xcpt_pf_ld_s2_q & instruction_s2_q.instr.valid) begin // Page fault load
        exception_to_wb.cause       = LD_PAGE_FAULT;
        exception_to_wb.origin      = xcpt_addr_s2_q;
        exception_to_wb.valid       = 1'b1;
    end else if (((|xcpt_addr_s2_q[63:40] != 0 && !xcpt_addr_s2_q[39]) ||
                   ( !(&xcpt_addr_s2_q[63:40]) && xcpt_addr_s2_q[39] )) &&
                   instruction_s2_q.instr.valid) begin // invalid address
        case(instruction_s2_q.instr.instr_type)
            SD, SW, SH, SB, VSE, AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
            AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW,
            AMO_MAXWU, AMO_MINW, AMO_MINWU, AMO_SWAPD, AMO_ADDD,
            AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU,
            FSD, FSW: begin
                exception_to_wb.cause  = ST_AMO_ACCESS_FAULT;
                exception_to_wb.origin = xcpt_addr_s2_q;
                exception_to_wb.valid  = 1'b1;
            end
            LD,LW,LWU,LH,LHU,LB,LBU,FLD,FLW: begin
                exception_to_wb.cause  = LD_ACCESS_FAULT;
                exception_to_wb.origin = xcpt_addr_s2_q;
                exception_to_wb.valid  = 1'b1;
            end
        endcase
    end
end


// Pending Memory Request Table (PMRQ)
pending_mem_req_queue pending_mem_req_queue_inst (
    .clk_i              (clk_i),
    .rstn_i             (rstn_i),
    .instruction_i      (instruction_to_pmrq),
    .tag_i              (tag_id_s2_q),
    .flush_i            (flush_to_lsq),
    .replay_valid_i     (resp_dcache_cpu_i.valid & resp_dcache_cpu_i.replay),
    .tag_next_i         (resp_dcache_cpu_i.rd),
    .replay_data_i      (resp_dcache_cpu_i.data),
    .advance_head_i     (advance_head_prmq),
    .finish_instr_o     (instruction_from_pmrq),
    .full_o             (full_pmrq)
);

//// Decide if the instruction should be sent to writeback, it must wait for response or
////    the request must be replayed. It also controls the LSQ head and pipeline flush.
always_comb begin
    instruction_to_wb      = 'h0;
    data_to_wb             = 'h0;
    advance_head_prmq      = 1'b0;
    flush_amo_prmq         = 1'b0;
    if(instruction_s2_q.instr.valid & resp_dcache_cpu_i.valid & 
                 ~resp_dcache_cpu_i.replay & !is_STORE_s2_q) begin
        instruction_to_wb      = instruction_s2_q;
        advance_head_prmq      = 1'b0;
        data_to_wb             = resp_dcache_cpu_i.data;
    end
    else if(instruction_s2_q.instr.valid & xcpt_s2_q) begin
        instruction_to_wb      = instruction_s2_q;
        advance_head_prmq      = 1'b0;
    end
    else if (instruction_s2_q.instr.valid & io_s2_q & is_STORE_or_AMO_s2_q) begin
        instruction_to_wb      = instruction_s2_q;
        advance_head_prmq      = 1'b0;
    end
    else if(instruction_from_pmrq.instr.valid) begin
        instruction_to_wb      = instruction_from_pmrq;
        advance_head_prmq      = 1'b1;
        data_to_wb             = instruction_from_pmrq.instr.imm;
        flush_amo_prmq         = (instruction_from_pmrq.instr.instr_type == AMO_MAXWU)   ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_MAXDU)   ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_MINWU)   ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_MINDU)   ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_MAXW)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_MAXD)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_MINW)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_MIND)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_ORW)     ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_ORD)     ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_ANDW)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_ANDD)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_XORW)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_XORD)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_ADDW)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_ADDD)    ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_SWAPW)   ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_SWAPD)   ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_SCW)     ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_SCD)     ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_LRW)     ||
                                 (instruction_from_pmrq.instr.instr_type == AMO_LRD)     ;
    end
end

// Output Instruction
assign scalar_instruction_o.valid         = instruction_to_wb.instr.valid && !fp_instr;;//  && instruction_to_wb.instr.regfile_we;
assign scalar_instruction_o.pc            = instruction_to_wb.instr.pc;
assign scalar_instruction_o.bpred         = instruction_to_wb.instr.bpred;
assign scalar_instruction_o.rs1           = instruction_to_wb.instr.rs1;
assign scalar_instruction_o.rd            = instruction_to_wb.instr.rd;
assign scalar_instruction_o.change_pc_ena = instruction_to_wb.instr.change_pc_ena;
assign scalar_instruction_o.regfile_we    = instruction_to_wb.instr.regfile_we;
assign scalar_instruction_o.instr_type    = instruction_to_wb.instr.instr_type;
`ifdef VERILATOR
assign scalar_instruction_o.id	           = instruction_to_wb.instr.id;
`endif
assign scalar_instruction_o.stall_csr_fence = instruction_to_wb.instr.stall_csr_fence;
assign scalar_instruction_o.csr_addr      = instruction_to_wb.instr.imm[CSR_ADDR_SIZE-1:0];
assign scalar_instruction_o.prd           = instruction_to_wb.prd;
assign scalar_instruction_o.checkpoint_done = instruction_to_wb.checkpoint_done;
assign scalar_instruction_o.chkp          = instruction_to_wb.chkp;
assign scalar_instruction_o.gl_index      = instruction_to_wb.gl_index;
assign scalar_instruction_o.branch_taken  = 1'b0;
assign scalar_instruction_o.result_pc     = 0;
assign scalar_instruction_o.result        = data_to_wb;
assign scalar_instruction_o.ex            = exception_to_wb;

// Output Instruction
assign fp_instruction_o.valid         = instruction_to_wb.instr.valid && fp_instr;
assign fp_instruction_o.pc            = instruction_to_wb.instr.pc;
assign fp_instruction_o.bpred         = instruction_to_wb.instr.bpred;
assign fp_instruction_o.rs1           = instruction_to_wb.instr.rs1;
assign fp_instruction_o.rd            = instruction_to_wb.instr.rd;
assign fp_instruction_o.change_pc_ena = instruction_to_wb.instr.change_pc_ena;
assign fp_instruction_o.regfile_we    = instruction_to_wb.instr.regfile_fp_we;
assign fp_instruction_o.instr_type    = instruction_to_wb.instr.instr_type;
`ifdef VERILATOR
assign fp_instruction_o.id	           = instruction_to_wb.instr.id;
`endif
assign fp_instruction_o.stall_csr_fence = instruction_to_wb.instr.stall_csr_fence;
assign fp_instruction_o.csr_addr      = instruction_to_wb.instr.imm[CSR_ADDR_SIZE-1:0];
assign fp_instruction_o.fprd          = instruction_to_wb.fprd;
assign fp_instruction_o.checkpoint_done = instruction_to_wb.checkpoint_done;
assign fp_instruction_o.chkp          = instruction_to_wb.chkp;
assign fp_instruction_o.gl_index      = instruction_to_wb.gl_index;
assign fp_instruction_o.branch_taken  = 1'b0;
assign fp_instruction_o.result_pc     = 0;
assign fp_instruction_o.result        = data_to_wb;
assign fp_instruction_o.ex            = exception_to_wb;

assign instruction_simd_o.valid           = instruction_to_wb.instr.valid & instruction_to_wb.instr.vregfile_we;
assign instruction_simd_o.pc              = instruction_to_wb.instr.pc;
assign instruction_simd_o.bpred           = instruction_to_wb.instr.bpred;
assign instruction_simd_o.rs1             = instruction_to_wb.instr.rs1;
assign instruction_simd_o.vd              = instruction_to_wb.instr.vd;
assign instruction_simd_o.change_pc_ena   = instruction_to_wb.instr.change_pc_ena;
assign instruction_simd_o.vregfile_we     = instruction_to_wb.instr.vregfile_we;
assign instruction_simd_o.instr_type      = instruction_to_wb.instr.instr_type;
`ifdef VERILATOR
assign instruction_simd_o.id	          = instruction_to_wb.instr.id;
`endif
assign instruction_simd_o.stall_csr_fence = instruction_to_wb.instr.stall_csr_fence;
assign instruction_simd_o.csr_addr        = instruction_to_wb.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_simd_o.pvd             = instruction_to_wb.pvd;
assign instruction_simd_o.checkpoint_done = instruction_to_wb.checkpoint_done;
assign instruction_simd_o.chkp            = instruction_to_wb.chkp;
assign instruction_simd_o.simd_chkp       = instruction_to_wb.simd_chkp;
assign instruction_simd_o.gl_index        = instruction_to_wb.gl_index;
assign instruction_simd_o.branch_taken    = 1'b0;
assign instruction_simd_o.result_pc       = 0;
assign instruction_simd_o.vresult         = data_to_wb;
assign instruction_simd_o.ex              = exception_to_wb;

assign exception_mem_commit_o      = (exception_to_wb.valid & is_STORE_or_AMO_s2_q) ? exception_to_wb : 'h0;

///////////////////////////////////////////////////////////////////////////////
///// Outputs for the execution module or Dcache interface
///////////////////////////////////////////////////////////////////////////////

assign mem_store_or_amo_o = store_on_fly | amo_on_fly;

//// Stall committing instruction because it is a store
assign mem_commit_stall_o = mem_commit_stall_s0 | (store_on_fly & ~flush_store) | (amo_on_fly & ~flush_amo & ~flush_amo_prmq);

//// Kill the dcache interface instruction
assign req_cpu_dcache_o.kill = kill_i;

//// Input/Output Address Base Pointer
assign req_cpu_dcache_o.io_base_addr = io_base_addr_i;

//// Block incoming Mem instructions
assign lock_o   = full_lsq;
assign empty_o  = empty_lsq & ~req_cpu_dcache_o.valid;

endmodule
