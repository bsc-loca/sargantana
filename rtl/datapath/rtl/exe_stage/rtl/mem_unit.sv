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

module mem_unit 
    import drac_pkg::*;
    import riscv_pkg::*;
    import mmu_pkg::*;
(
    input  wire                  clk_i,                  // Clock signal
    input  wire                  rstn_i,                 // Reset signal
    input logic                  kill_i,                 // Exception detected at Commit
    input logic                  flush_i,                // Delete all load_store_queue entries
    input addr_t                 io_base_addr_i,         // Input_output_address
    input logic                  en_ld_st_translation_i,

    input rr_exe_mem_instr_t     instruction_i,          // Interface to add new instuction
    input resp_dcache_cpu_t      resp_dcache_cpu_i,      // Response from dcache
    input wire                   commit_store_or_amo_i,  // Signal from commit enables writes.
    input gl_index_t             commit_store_or_amo_gl_idx_i,  // Signal from commit enables writes.
    input tlb_cache_comm_t       dtlb_comm_i,


    output req_cpu_dcache_t      req_cpu_dcache_o,       // Request to dcache
    output exe_wb_simd_instr_t   instruction_simd_o,     // Output instruction     
    output exe_wb_scalar_instr_t instruction_scalar_o,   // Output instruction
    output exe_wb_fp_instr_t     instruction_fp_o,       // Output instruction     
    output exception_t           exception_mem_commit_o, // Exception of the commit instruction
    output logic                 mem_commit_stall_o,     // Stall commit stage
    output logic 		         mem_store_or_amo_o,     // Instruction is a Store or Commit
    output gl_index_t            mem_gl_index_o,         // GL Index of the memory instruction
    output logic                 lock_o,                 // Mem unit is able to accept more petitions
    output logic                 empty_o,                // Mem unit has no pending Ops
    output cache_tlb_comm_t      dtlb_comm_o,

    input logic [1:0] priv_lvl_i,

    `ifdef VERILATOR
    output addr_t                store_addr_o,
    output bus64_t               store_data_o,
    `endif

    output logic                 pmu_load_after_store_o  // Load blocked by ongoing store
);

// Enum to select instruction to DCache interface
typedef enum logic[2:0] {
    NULL             = 3'b000,
    READ             = 3'b001,
    STORED           = 3'b010,
    VALIGNED1        = 3'b100,
    STORED_VALIGNED1 = 3'b101,
    VALIGNED2        = 3'b110
} source_lsq_t;               

bus64_t data_src1;
bus_simd_t data_src2;

source_lsq_t source_dcache;

// Track Store and AMO in the pipeline and related Stall
logic is_STORE_or_AMO_s1_q;
logic is_STORE_or_AMO_s2_q;
logic is_STORE_s1_q;
logic is_STORE_s2_q;

// Instruction is the first part of an unaligned
// Vector Memory Access
logic is_unalign1_s1_d;
logic is_unalign1_s1_q;
logic is_unalign1_s2_q;

// Instruction is the second part of an unaligned
// Vector Memory Access
logic is_unalign2_s1_d;
logic is_unalign2_s1_q;
logic is_unalign2_s2_q;

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

logic advance_head_lsq;
logic blocked_store;

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
logic [6:0] tag_id;
logic [6:0] tag_id_s1_q;
logic [6:0] tag_id_s2_q;

rr_exe_mem_instr_t instruction_to_pmrq;
rr_exe_mem_instr_t instruction_from_pmrq;

// PMRQ control signals
logic advance_head_prmq;
logic mv_back_tail_prmq;
logic full_pmrq;
logic unaligned_to_pmrq;
logic unalign_from_pmrq;
bus_simd_t unalign_result_from_pmrq;

// Select data source
logic [6:0] offset;
logic [6:0] noffset;
bus_simd_t data_to_wb;
bus_simd_t data_to_wb_half;

// State machine variables
logic [2:0] state;
logic [2:0] next_state;

// Possible states of the control automata
parameter ResetState  = 3'b000,
          ReadHead = 3'b001,
          WaitReady = 3'b010,
          WaitCommit = 3'b011,
          Unaligned_VLE = 3'b100;

assign data_src1 = instruction_i.data_rs1;
assign data_src2 = instruction_i.data_rs2;

///////////////////////////////////////////////////////////////////////////////
///// LOAD STORE QUEUE
///////////////////////////////////////////////////////////////////////////////

// Flush LSQ
assign flush_to_lsq = kill_i | flush_i;

// Input instruction to LSQ
assign instruction_to_lsq.instr = (instruction_i.instr.unit == UNIT_MEM && instruction_i.instr.valid) ? instruction_i.instr : 'h0 ;
assign instruction_to_lsq.data_rs1      = (instruction_to_lsq.is_amo) ? instruction_i.data_rs1 : instruction_i.data_rs1 + instruction_i.instr.imm;
assign instruction_to_lsq.data_rs2      = instruction_i.data_rs2;
assign instruction_to_lsq.data_old_vd   = instruction_i.data_old_vd;
assign instruction_to_lsq.data_vm       = instruction_i.data_vm;
assign instruction_to_lsq.sew           = instruction_i.sew;
assign instruction_to_lsq.prd           = instruction_i.prd;
assign instruction_to_lsq.pvd           = instruction_i.pvd;
assign instruction_to_lsq.fprd          = instruction_i.fprd;
assign instruction_to_lsq.gl_index      = instruction_i.gl_index;

assign instruction_to_lsq.is_amo_or_store  =  (instruction_i.instr.mem_type == STORE) || 
                                              (instruction_i.instr.mem_type == AMO);

assign instruction_to_lsq.is_store  = instruction_i.instr.mem_type == STORE;
                                      
assign instruction_to_lsq.is_amo  = (instruction_to_lsq.is_amo_or_store & !instruction_to_lsq.is_store);

`ifdef VERILATOR
assign instruction_to_lsq.vaddr = instruction_to_lsq.data_rs1;
`endif

// LSQ
load_store_queue load_store_queue_inst (
    .clk_i              (clk_i),
    .rstn_i             (rstn_i),
    .instruction_i      (instruction_to_lsq),
    .en_ld_st_translation_i (en_ld_st_translation_i),
    .flush_i            (flush_to_lsq),
    .read_next_i        (read_next_lsq),
    .reset_next_i       (reset_next_lsq),
    .advance_head_i     (advance_head_lsq),
    .next_instr_exe_o   (instruction_to_dcache),
    .rob_store_ack_i    (commit_store_or_amo_i),
    .rob_store_gl_idx_i (commit_store_or_amo_gl_idx_i),
    .full_o             (full_lsq),
    .empty_o            (empty_lsq),
    .blocked_store_o    (blocked_store),
    .dtlb_comm_i(dtlb_comm_i),
    .dtlb_comm_o(dtlb_comm_o),
    .priv_lvl_i(priv_lvl_i),
    .pmu_load_after_store_o (pmu_load_after_store_o)
);

///////////////////////////////////////////////////////////////////////////////
///// State machine Stage 0
///////////////////////////////////////////////////////////////////////////////


// Update State Machine and Stored Instruction
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        state <= ResetState;
        stored_instr_to_dcache <= '0;
    end else if (flush_to_lsq) begin
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
    req_cpu_dcache_o.valid      = 1'b0;     // No Request
    source_dcache               = NULL;     
    read_next_lsq               = 1'b1;     // No Advance LSQ
    mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
    instruction_s1_d            =  'h0;     // No Instruction to next stage
    is_unalign1_s1_d            = 1'b0;
    is_unalign2_s1_d            = 1'b0;
    next_state                  = ReadHead; // Next state Read Head
    if (flush_to_lsq) begin
        req_cpu_dcache_o.valid      = 1'b0;     // No Request
        source_dcache               = NULL;     
        read_next_lsq               = 1'b1;     // No Advance LSQ
        mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
        instruction_s1_d            =  'h0;     // No Instruction to next stage
        is_unalign1_s1_d            = 1'b0;
        is_unalign2_s1_d            = 1'b0;
        next_state                  = resp_dcache_cpu_i.ordered ? ReadHead : ResetState ; // Next state Read Head
    end else begin
        case(state)
            ////////////////////////////////////////////////// Reset state
            ResetState: begin
                req_cpu_dcache_o.valid      = 1'b0;         // No Request
                source_dcache               = NULL;         
                read_next_lsq               = 1'b0;         // No Read of LSQ
                mem_commit_stall_s0         = 1'b0;         // No Stall of Commit
                instruction_s1_d            =  'h0;         // No Instruction to next stage
                is_unalign1_s1_d            = 1'b0;
                is_unalign2_s1_d            = 1'b0;
                next_state                  = resp_dcache_cpu_i.ordered ? ReadHead : ResetState; // Next state Read Head
            end
            ////////////////////////////////////////////////// Read head of LSQ
            ReadHead: begin
                if (empty_lsq || blocked_store) begin
                    req_cpu_dcache_o.valid      = 1'b0;     // No Request
                    source_dcache               = NULL;     
                    read_next_lsq               = 1'b0;     // No Advance LSQ 
                    mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
                    instruction_s1_d            =  'h0;     // No Instruction to next stage
                    is_unalign1_s1_d            = 1'b0;
                    is_unalign2_s1_d            = 1'b0; 
                    next_state                  = ReadHead; // Next state Read Head
                end else begin
                    // Request Logic
                    source_dcache = (|instruction_to_dcache.data_rs1[3:0] &
                                     instruction_to_dcache.instr.instr_type == VLE) ?
                                     VALIGNED1 : READ;     // Use instruction from LSQ
                    read_next_lsq = 1'b1;     // Advance LSQ 
                    
                    //// Set request valid bit, stall_commit and next state signals 
                    if (!instruction_to_dcache.instr.valid | full_pmrq | resp_dcache_cpu_i.nack) begin
                        // If not valid instruction or full Pending Request Memory Queue
                        // Wait until next state
                        req_cpu_dcache_o.valid = 1'b0;
                        mem_commit_stall_s0    = 1'b0;
                        next_state             = WaitReady;
                        instruction_s1_d        = 'h0;
                    end else if (!req_cpu_dcache_o.is_amo_or_store) begin
                        // If the instruction is not a Store or AMO
                        req_cpu_dcache_o.valid = resp_dcache_cpu_i.ready & ~instruction_to_dcache.ex.valid;
                        mem_commit_stall_s0    = 1'b0;
                        next_state  = (!resp_dcache_cpu_i.ready) ? WaitReady : 
                                  (|instruction_to_dcache.data_rs1[3:0] &
                                  instruction_to_dcache.instr.instr_type == VLE) ? Unaligned_VLE : ReadHead;
                        is_unalign1_s1_d = resp_dcache_cpu_i.ready &&
                                           (|instruction_to_dcache.data_rs1[3:0] &
                                             instruction_to_dcache.instr.instr_type == VLE);
                        is_unalign2_s1_d       = 1'b0;
                        instruction_s1_d = resp_dcache_cpu_i.ready | instruction_to_dcache.ex.valid ? instruction_to_dcache : 'h0;
                    end else if (!(store_on_fly | amo_on_fly) |
                                 (mem_gl_index_o == instruction_to_dcache.gl_index)) begin
                        // If there is not a Store or AMO on fly or the current instruction
                        //  was sent to dache previously
                        
                        // Make request If L1 ready and current instruction is either load
                        //  or store with commit permission
                        req_cpu_dcache_o.valid = resp_dcache_cpu_i.ready &
                                          (!req_cpu_dcache_o.is_amo_or_store | commit_store_or_amo_i)
                                           & ~instruction_to_dcache.ex.valid;
                       
                        // Stall the commit stage if it is a commiting store or amo
                        mem_commit_stall_s0 = req_cpu_dcache_o.is_amo_or_store & commit_store_or_amo_i;
                        // If cache is not ready wait for it
                        // Otherwise if store or amo is launched, continue reading, otherwise wait
                        // until arriving to commit
                        next_state  = (!resp_dcache_cpu_i.ready) ? WaitReady :
                                          (req_cpu_dcache_o.is_amo_or_store & !commit_store_or_amo_i) ?
                                           WaitCommit : ReadHead;
                        is_unalign1_s1_d       = 1'b0;
                        is_unalign2_s1_d       = 1'b0;
                        instruction_s1_d = (resp_dcache_cpu_i.ready & (!req_cpu_dcache_o.is_amo_or_store | commit_store_or_amo_i)) | instruction_to_dcache.ex.valid ? instruction_to_dcache : 'h0;
                    end else begin
                        req_cpu_dcache_o.valid = 1'b0;
                        mem_commit_stall_s0    = 1'b0;
                        is_unalign1_s1_d       = 1'b0;
                        is_unalign2_s1_d       = 1'b0;
                        instruction_s1_d = 'h0;
                        next_state  = WaitReady;
                    end
                end
            end
            ////////////////////////////////////////////////// Wait for Ready DCACHE
            WaitReady: begin
                // Request Logic                                             
                source_dcache = (|stored_instr_to_dcache.data_rs1[3:0] &
                                  stored_instr_to_dcache.instr.instr_type == VLE) ?
                                  STORED_VALIGNED1 : STORED;   // Use instruction stored previously
                read_next_lsq = 1'b0;     // Not Advance LSQ
                
                //// Set request valid bit, stall_commit and next state signals 
                if (!stored_instr_to_dcache.instr.valid | full_pmrq | resp_dcache_cpu_i.nack) begin
                    // If not valid instruction or full Pending Request Memory Queue
                    // Wait until next state
                    req_cpu_dcache_o.valid = 1'b0;
                    mem_commit_stall_s0    = 1'b0;
                    next_state             = WaitReady;
                end else if (!req_cpu_dcache_o.is_amo_or_store) begin
                    // If the instruction is not a Store or AMO
                    req_cpu_dcache_o.valid = resp_dcache_cpu_i.ready;
                    mem_commit_stall_s0 = 1'b0;
                    next_state  = (!resp_dcache_cpu_i.ready) ? WaitReady : 
                                  (|stored_instr_to_dcache.data_rs1[3:0] &
                                  stored_instr_to_dcache.instr.instr_type == VLE) ? Unaligned_VLE : ReadHead;
                    is_unalign1_s1_d = resp_dcache_cpu_i.ready &&
                                       (|stored_instr_to_dcache.data_rs1[3:0] &
                                         stored_instr_to_dcache.instr.instr_type == VLE);
                    is_unalign2_s1_d       = 1'b0;
                end else if (!(store_on_fly | amo_on_fly) |
                             (mem_gl_index_o == stored_instr_to_dcache.gl_index)) begin
                    // If there is not a Store or AMO on fly or the current instruction
                    //  was sent to dache previously
                       
                    // Make request If L1 ready and current instruction is either load
                    //  or store with commit permission
                    req_cpu_dcache_o.valid = resp_dcache_cpu_i.ready &
                                          (!req_cpu_dcache_o.is_amo_or_store | commit_store_or_amo_i);
                       
                    // Stall the commit stage if it is a commiting store or amo
                    mem_commit_stall_s0 = req_cpu_dcache_o.is_amo_or_store & commit_store_or_amo_i;
                    // If cache is not ready wait for it
                    // Otherwise if store or amo is launched, continue reading, otherwise wait
                    // until arriving to commit
                    next_state  = (!resp_dcache_cpu_i.ready) ? WaitReady :
                                  (req_cpu_dcache_o.is_amo_or_store & !commit_store_or_amo_i) ?
                                    WaitCommit : ReadHead;
                    is_unalign1_s1_d       = 1'b0;
                    is_unalign2_s1_d       = 1'b0;
                end else begin
                    req_cpu_dcache_o.valid = 1'b0;
                    mem_commit_stall_s0    = 1'b0;
                    is_unalign1_s1_d       = 1'b0;
                    is_unalign2_s1_d       = 1'b0;
                    next_state             = WaitReady;
                end

                // Next Stage Logic
                if (!req_cpu_dcache_o.valid) begin
                    instruction_s1_d = 'h0;
                end else begin
                    instruction_s1_d = stored_instr_to_dcache;
                end
            end
            ////////////////////////////////////////////////// Wait for Store to DCACHE
            WaitCommit: begin
                // Request Logic
                req_cpu_dcache_o.valid      = commit_store_or_amo_i & ~(store_on_fly | amo_on_fly)&
                                              resp_dcache_cpu_i.ready & (~full_pmrq) & ~resp_dcache_cpu_i.nack;
                source_dcache               = STORED;                   // Use instruction stored previously
                read_next_lsq               = 1'b0;                     // Not Advance LSQ
                mem_commit_stall_s0         = commit_store_or_amo_i & (~full_pmrq);
                is_unalign1_s1_d            = 1'b0;
                is_unalign2_s1_d            = 1'b0;

                // Next Stage Logicww
                if (commit_store_or_amo_i & ~(store_on_fly | amo_on_fly) & resp_dcache_cpu_i.ready) begin
                    instruction_s1_d  = stored_instr_to_dcache;
                end else if (full_pmrq) begin
                    instruction_s1_d  = 'h0;
                end else begin
                    instruction_s1_d  = 'h0;
                end
                
                // Next Sate Logic
                next_state = (commit_store_or_amo_i & ~(store_on_fly | amo_on_fly) & resp_dcache_cpu_i.ready & (~full_pmrq) & ~resp_dcache_cpu_i.nack) ?
                                ReadHead : WaitCommit;
            end
            Unaligned_VLE: begin
                // Request Logic
                req_cpu_dcache_o.valid      = resp_dcache_cpu_i.ready;
                source_dcache               = VALIGNED2;                // Use instruction stored previously
                read_next_lsq               = 1'b0;                     // Not Advance LSQ
                mem_commit_stall_s0         = 1'b0;                     // Load dont stall commit
                is_unalign1_s1_d            = 1'b0;
                is_unalign2_s1_d            = resp_dcache_cpu_i.ready;

                // Next Stage Logic
                if (req_cpu_dcache_o.valid) begin
                    instruction_s1_d  = stored_instr_to_dcache;
                end else begin
                    instruction_s1_d  = 'h0;
                end
                
                // Next Sate Logic
                next_state = (resp_dcache_cpu_i.ready) ? ReadHead : Unaligned_VLE;
            end
        endcase
    end
end

// Update State Machine and Stored Instruction
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        tag_id <= 'h0;
    end else if (reset_next_lsq) begin
        if (is_unalign2_s2_q) begin
           tag_id <= tag_id_s2_q - 5'h1;
        end else begin
           tag_id <= tag_id_s2_q;
        end
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
    req_cpu_dcache_o.is_amo_or_store = 1'b0;
    req_cpu_dcache_o.is_store   = 1'b0;
    req_cpu_dcache_o.is_amo     = 1'b0;
    case(source_dcache)
        NULL:         begin
            req_cpu_dcache_o.data_rs1        = 64'h0;
            req_cpu_dcache_o.instr_type      = ADD;
            req_cpu_dcache_o.mem_size        = 3'h0;
            req_cpu_dcache_o.rd              = 5'h0;
            req_cpu_dcache_o.is_amo_or_store = 1'b0;
        end
        READ:         begin
            req_cpu_dcache_o.data_rs1        = instruction_to_dcache.data_rs1;
            req_cpu_dcache_o.instr_type      = instruction_to_dcache.instr.instr_type;
            req_cpu_dcache_o.mem_size        = instruction_to_dcache.instr.mem_size;
            req_cpu_dcache_o.rd              = tag_id;
            req_cpu_dcache_o.is_amo_or_store = instruction_to_dcache.is_amo_or_store;
            req_cpu_dcache_o.is_amo          = instruction_to_dcache.is_amo;
            req_cpu_dcache_o.is_store        = instruction_to_dcache.is_store;
        end
        STORED:       begin
            req_cpu_dcache_o.data_rs1        = stored_instr_to_dcache.data_rs1;
            req_cpu_dcache_o.instr_type      = stored_instr_to_dcache.instr.instr_type;
            req_cpu_dcache_o.mem_size        = stored_instr_to_dcache.instr.mem_size;
            req_cpu_dcache_o.rd              = tag_id;
            req_cpu_dcache_o.is_amo_or_store = stored_instr_to_dcache.is_amo_or_store;
            req_cpu_dcache_o.is_amo          = stored_instr_to_dcache.is_amo;
            req_cpu_dcache_o.is_store        = stored_instr_to_dcache.is_store;
        end
        VALIGNED1:    begin
            req_cpu_dcache_o.data_rs1        = {instruction_to_dcache.data_rs1[63:4], 4'b0000};
            req_cpu_dcache_o.instr_type      = instruction_to_dcache.instr.instr_type;
            req_cpu_dcache_o.mem_size        = instruction_to_dcache.instr.mem_size;
            req_cpu_dcache_o.rd              = tag_id;
            req_cpu_dcache_o.is_amo_or_store = instruction_to_dcache.is_amo_or_store;
            req_cpu_dcache_o.is_amo          = instruction_to_dcache.is_amo;
            req_cpu_dcache_o.is_store        = instruction_to_dcache.is_store;
        end
        STORED_VALIGNED1:    begin
            req_cpu_dcache_o.data_rs1        = {stored_instr_to_dcache.data_rs1[63:4], 4'b0000};
            req_cpu_dcache_o.instr_type      = stored_instr_to_dcache.instr.instr_type;
            req_cpu_dcache_o.mem_size        = stored_instr_to_dcache.instr.mem_size;
            req_cpu_dcache_o.rd              = tag_id;
            req_cpu_dcache_o.is_amo_or_store = stored_instr_to_dcache.is_amo_or_store;
            req_cpu_dcache_o.is_amo          = stored_instr_to_dcache.is_amo;
            req_cpu_dcache_o.is_store        = stored_instr_to_dcache.is_store;
        end
        VALIGNED2:    begin
            req_cpu_dcache_o.data_rs1        = {stored_instr_to_dcache.data_rs1[63:4] + 60'h1, 4'b0000};
            req_cpu_dcache_o.instr_type      = stored_instr_to_dcache.instr.instr_type;
            req_cpu_dcache_o.mem_size        = stored_instr_to_dcache.instr.mem_size;
            req_cpu_dcache_o.rd              = tag_id;
            req_cpu_dcache_o.is_amo_or_store = stored_instr_to_dcache.is_amo_or_store;
            req_cpu_dcache_o.is_amo          = stored_instr_to_dcache.is_amo;
            req_cpu_dcache_o.is_store        = stored_instr_to_dcache.is_store;
        end
    endcase
end

//// Store in the Pipeline Send the GL index to commit to match the commiting instruction with the Store
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        store_on_fly    <= 1'b0;
        amo_on_fly      <= 1'b0;
        mem_gl_index_o  <= 'h0;
    end 
    else if (instruction_s1_d.instr.valid & req_cpu_dcache_o.is_amo_or_store) begin
        store_on_fly    <= req_cpu_dcache_o.is_store; 
        amo_on_fly      <= req_cpu_dcache_o.is_amo; 
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
        instruction_s1_q     <=  'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_s1_q        <= 1'b0;
        is_unalign1_s1_q     <= 1'b0;
        is_unalign2_s1_q     <= 1'b0;
        io_s1_q              <= 1'b0;
        tag_id_s1_q          <=  'h0;
        
        instruction_s2_q     <=  'h0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        is_STORE_s2_q        <= 1'b0;
        is_unalign1_s2_q     <= 1'b0;
        is_unalign2_s2_q     <= 1'b0;
        io_s2_q              <= 1'b0;
        tag_id_s2_q          <=  'h0;
        
    end else if (reset_next_lsq || flush_to_lsq) begin       // In case of miss flush the pipeline
        instruction_s1_q     <=  'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_s1_q        <= 1'b0;
        is_unalign1_s1_q     <= 1'b0;
        is_unalign2_s1_q     <= 1'b0;
        io_s1_q              <= 1'b0;
        tag_id_s1_q          <=  'h0;
        
        instruction_s2_q     <=  'h0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        is_STORE_s2_q        <= 1'b0;
        is_unalign1_s2_q     <= 1'b0;
        is_unalign2_s2_q     <= 1'b0;
        io_s2_q              <= 1'b0;
        tag_id_s2_q          <=  'h0;
        
    end else begin          // Update the Pipeline    
        instruction_s1_q     <= instruction_s1_d;
        is_STORE_or_AMO_s1_q <= req_cpu_dcache_o.is_amo_or_store;
        is_STORE_s1_q        <= req_cpu_dcache_o.is_store;
        is_unalign1_s1_q     <= is_unalign1_s1_d;
        is_unalign2_s1_q     <= is_unalign2_s1_d;
        io_s1_q              <= resp_dcache_cpu_i.io_address_space;
        tag_id_s1_q          <= tag_id;
                
        instruction_s2_q     <= instruction_s1_q;
        is_STORE_or_AMO_s2_q <= is_STORE_or_AMO_s1_q;
        is_STORE_s2_q        <= is_STORE_s1_q;
        is_unalign1_s2_q     <= is_unalign1_s1_q;
        is_unalign2_s2_q     <= is_unalign2_s1_q;
        io_s2_q              <= io_s1_q;
        tag_id_s2_q          <= tag_id_s1_q;
    end
end

//// In case of Store or AMO the Data to be written is sent at second stage
assign req_cpu_dcache_o.data_rs2 = instruction_s1_q.data_rs2;

//// Keep tracking an AMO or STORE if it is in the pipeline to stall the commit until access finished
assign mem_commit_stall_s1 = instruction_s1_q.instr.valid & is_STORE_or_AMO_s1_q;

//// Decide if the pipeline needs to be flushed.
always_comb begin
    reset_next_lsq      = 1'b0;
    advance_head_lsq    = 1'b0;
    flush_store         = 1'b0;
    flush_amo           = 1'b0;
    unaligned_to_pmrq   = 1'b0;
    mv_back_tail_prmq   = 1'b0;
    instruction_to_pmrq =  'h0;
    if(instruction_s2_q.instr.valid & resp_dcache_cpu_i.nack) begin
        reset_next_lsq      = 1'b1;
        mv_back_tail_prmq   = is_unalign2_s2_q;
    end else if (instruction_s2_q.instr.valid & resp_dcache_cpu_i.valid & 
                 ~resp_dcache_cpu_i.replay) begin
        if (is_unalign1_s2_q) begin
            advance_head_lsq    = 1'b0;
            unaligned_to_pmrq   = 1'b1;
            instruction_to_pmrq = instruction_s2_q;
            flush_store         = 1'b0;
            flush_amo           = 1'b0;
        end else if (is_unalign2_s2_q) begin
            advance_head_lsq    = 1'b1;
            unaligned_to_pmrq   = 1'b1;
            instruction_to_pmrq =  'h0;
            flush_store         = 1'b0;
            flush_amo           = 1'b0;
        end else begin
            advance_head_lsq    = 1'b1;
            unaligned_to_pmrq   = 1'b0;
            flush_store         = is_STORE_s2_q;
            flush_amo           = is_STORE_or_AMO_s2_q & !is_STORE_s2_q;  
        end
    end else if (instruction_s2_q.instr.valid & instruction_s2_q.ex.valid) begin 
        advance_head_lsq    = 1'b1;
        instruction_to_pmrq =  'h0;
        flush_store         = is_STORE_s2_q;
        flush_amo           = is_STORE_or_AMO_s2_q & !is_STORE_s2_q;
    end else if (instruction_s2_q.instr.valid & io_s2_q & is_STORE_or_AMO_s2_q) begin
        advance_head_lsq    = 1'b1;
        instruction_to_pmrq =  'h0;
        flush_store         = 1'b1;
        flush_amo           = 1'b1;
    end else if (instruction_s2_q.instr.valid & !is_STORE_s2_q) begin 
        advance_head_lsq    = !is_unalign1_s2_q;
        instruction_to_pmrq = (is_unalign2_s2_q) ? 'h0 : instruction_s2_q;
    end else if (instruction_s2_q.instr.valid & is_STORE_s2_q) begin
        advance_head_lsq    = 1'b1;
        flush_store         = 1'b1;
    end
end

// Pending Memory Request Table (PMRQ)
pending_mem_req_queue pending_mem_req_queue_inst (
    .clk_i                 (clk_i),
    .rstn_i                (rstn_i),
    .instruction_i         (instruction_to_pmrq),
    .tag_i                 (tag_id_s2_q),
    .unaligned_inst_i      (is_unalign1_s2_q),
    .unaligned_res_valid_i (unaligned_to_pmrq),
    .unaligned_res_data_i  (resp_dcache_cpu_i.data),
    .flush_i               (flush_to_lsq),
    .replay_valid_i        (resp_dcache_cpu_i.valid & resp_dcache_cpu_i.replay
                            & resp_dcache_cpu_i.has_data),
    .tag_next_i            (resp_dcache_cpu_i.rd),
    .replay_data_i         (resp_dcache_cpu_i.data),
    .response_valid_i      (resp_dcache_cpu_i.valid),
    .advance_head_i        (advance_head_prmq),
    .mv_back_tail_i        (mv_back_tail_prmq),
    .finish_instr_o        (instruction_from_pmrq),
    .unalign_instr_o       (unalign_from_pmrq),
    .unalign_result_o      (unalign_result_from_pmrq),
    .full_o                (full_pmrq)
);

//// Decide if the instruction should be sent to writeback, it must wait for response or
////    the request must be replayed. It also controls the LSQ head and pipeline flush.
always_comb begin
    instruction_to_wb      =  'h0;
    data_to_wb             =  'h0;
    advance_head_prmq      = 1'b0;
    flush_amo_prmq         = 1'b0;
    if(instruction_s2_q.instr.valid & resp_dcache_cpu_i.valid &
               !resp_dcache_cpu_i.replay & !is_STORE_s2_q &
               !is_unalign1_s2_q & !is_unalign2_s2_q) begin
        instruction_to_wb      = instruction_s2_q;
        advance_head_prmq      = 1'b0;
        data_to_wb             = resp_dcache_cpu_i.data;
    end
    else if(instruction_s2_q.instr.valid & instruction_s2_q.ex.valid) begin
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
        flush_amo_prmq         = instruction_from_pmrq.is_amo;
        
        if (unalign_from_pmrq) begin 
            offset = instruction_from_pmrq.data_rs1[3:0] << 3;
            noffset = ((~offset) + 1);
            data_to_wb_half = unalign_result_from_pmrq << noffset;
            data_to_wb = (instruction_from_pmrq.data_rs2 >> offset) | data_to_wb_half;
        end else begin
            data_to_wb = instruction_from_pmrq.data_rs2;
        end
    end
end

bus_simd_t masked_data_to_wb;

//Apply the mask to the vector result
always_comb begin
    masked_data_to_wb = instruction_to_wb.data_old_vd;
    case (instruction_to_wb.sew)
        SEW_8: begin
            for (int i = 0; i<VLEN/8; ++i) begin
                if (instruction_to_wb.data_vm[i]) begin
                    masked_data_to_wb[(8*i)+:8] = data_to_wb[(8*i)+:8];
                end
            end
        end
        SEW_16: begin
            for (int i = 0; i<VLEN/16; ++i) begin
                if (instruction_to_wb.data_vm[i*2]) begin
                    masked_data_to_wb[(16*i)+:16] = data_to_wb[(16*i)+:16];
                end
            end
        end
        SEW_32: begin
            for (int i = 0; i<VLEN/32; ++i) begin
                if (instruction_to_wb.data_vm[i*4]) begin
                    masked_data_to_wb[(32*i)+:32] = data_to_wb[(32*i)+:32];
                end
            end
        end
        SEW_64: begin
            for (int i = 0; i<VLEN/64; ++i) begin
                if (instruction_to_wb.data_vm[i*8]) begin
                    masked_data_to_wb[(64*i)+:64] = data_to_wb[(64*i)+:64];
                end
            end
        end
    endcase
end

// Output Instruction
assign instruction_scalar_o.valid         = instruction_to_wb.instr.valid && instruction_to_wb.instr.regfile_we;
assign instruction_scalar_o.pc            = instruction_to_wb.instr.pc;
assign instruction_scalar_o.bpred         = instruction_to_wb.instr.bpred;
assign instruction_scalar_o.rs1           = instruction_to_wb.instr.rs1;
assign instruction_scalar_o.rd            = instruction_to_wb.instr.rd;
assign instruction_scalar_o.change_pc_ena = instruction_to_wb.instr.change_pc_ena;
assign instruction_scalar_o.regfile_we    = instruction_to_wb.instr.regfile_we;
assign instruction_scalar_o.instr_type    = instruction_to_wb.instr.instr_type;
`ifdef VERILATOR
assign instruction_scalar_o.id	          = instruction_to_wb.instr.id;
assign instruction_scalar_o.addr          = instruction_to_wb.vaddr;
`endif
assign instruction_scalar_o.stall_csr_fence = instruction_to_wb.instr.stall_csr_fence;
assign instruction_scalar_o.csr_addr      = instruction_to_wb.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_scalar_o.prd           = instruction_to_wb.prd;
assign instruction_scalar_o.checkpoint_done = instruction_to_wb.checkpoint_done;
assign instruction_scalar_o.chkp          = instruction_to_wb.chkp;
assign instruction_scalar_o.gl_index      = instruction_to_wb.gl_index;
assign instruction_scalar_o.branch_taken  = 1'b0;
assign instruction_scalar_o.result_pc     = 0;
assign instruction_scalar_o.result        = data_to_wb;
assign instruction_scalar_o.ex            = instruction_to_wb.ex;
assign instruction_scalar_o.fp_status     = 'h0;
assign instruction_scalar_o.mem_type      = instruction_to_wb.instr.mem_type;

// Output Float Instruction
assign instruction_fp_o.valid             = instruction_to_wb.instr.valid && instruction_to_wb.instr.fregfile_we; //fp_instr;
assign instruction_fp_o.pc                = instruction_to_wb.instr.pc;
assign instruction_fp_o.bpred             = instruction_to_wb.instr.bpred;
assign instruction_fp_o.rs1               = instruction_to_wb.instr.rs1;
assign instruction_fp_o.rd                = instruction_to_wb.instr.rd;
assign instruction_fp_o.change_pc_ena     = instruction_to_wb.instr.change_pc_ena;
assign instruction_fp_o.regfile_we        = instruction_to_wb.instr.fregfile_we;
assign instruction_fp_o.instr_type        = instruction_to_wb.instr.instr_type;
`ifdef VERILATOR
assign instruction_fp_o.id	              = instruction_to_wb.instr.id;
assign instruction_fp_o.addr              = instruction_to_wb.vaddr;
`endif
assign instruction_fp_o.stall_csr_fence   = instruction_to_wb.instr.stall_csr_fence;
assign instruction_fp_o.csr_addr          = instruction_to_wb.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_fp_o.fprd              = instruction_to_wb.fprd;
assign instruction_fp_o.checkpoint_done   = instruction_to_wb.checkpoint_done;
assign instruction_fp_o.chkp              = instruction_to_wb.chkp;
assign instruction_fp_o.gl_index          = instruction_to_wb.gl_index;
assign instruction_fp_o.branch_taken      = 1'b0;
assign instruction_fp_o.result_pc         = 0;
assign instruction_fp_o.result            = instruction_to_wb.instr.instr_type == FLW ? {32'hFFFFFFFF, data_to_wb[31:0]} : data_to_wb;
assign instruction_fp_o.ex                = instruction_to_wb.ex;
assign instruction_fp_o.fp_status         = 'h0;

// Output SIMD Instruction
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
assign instruction_simd_o.addr            = instruction_to_wb.vaddr;
`endif
assign instruction_simd_o.stall_csr_fence = instruction_to_wb.instr.stall_csr_fence;
assign instruction_simd_o.csr_addr        = instruction_to_wb.instr.imm[CSR_ADDR_SIZE-1:0];
assign instruction_simd_o.pvd             = instruction_to_wb.pvd;
assign instruction_simd_o.checkpoint_done = instruction_to_wb.checkpoint_done;
assign instruction_simd_o.chkp            = instruction_to_wb.chkp;
assign instruction_simd_o.gl_index        = instruction_to_wb.gl_index;
assign instruction_simd_o.branch_taken    = 1'b0;
assign instruction_simd_o.result_pc       = 0;
assign instruction_simd_o.vresult         = masked_data_to_wb;
assign instruction_simd_o.ex              = instruction_to_wb.ex;

assign exception_mem_commit_o = (instruction_to_wb.ex.valid & is_STORE_or_AMO_s2_q) ? instruction_to_wb.ex : 'h0;

///////////////////////////////////////////////////////////////////////////////
///// Outputs for the execution module or Dcache interface
///////////////////////////////////////////////////////////////////////////////

assign mem_store_or_amo_o = store_on_fly | amo_on_fly;

//// Stall committing instruction because it is a store
assign mem_commit_stall_o = mem_commit_stall_s0 | (store_on_fly & ~flush_store) | (amo_on_fly & ~flush_amo & ~flush_amo_prmq);

//// Kill the dcache interface instruction
assign req_cpu_dcache_o.kill = kill_i | reset_next_lsq;

//// Input/Output Address Base Pointer
assign req_cpu_dcache_o.io_base_addr = io_base_addr_i;

//// Block incoming Mem instructions
assign lock_o   = full_lsq;
assign empty_o  = empty_lsq & ~req_cpu_dcache_o.valid;

`ifdef VERILATOR
assign store_addr_o = instruction_s2_q.vaddr;
assign store_data_o = instruction_s2_q.data_rs2;
`endif

endmodule
