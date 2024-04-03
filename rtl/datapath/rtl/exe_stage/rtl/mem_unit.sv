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
#(
    parameter drac_pkg::drac_cfg_t DracCfg     = drac_pkg::DracDefaultConfig,
    parameter VECTOR_PACKER_NUM_ENTRIES = 2,
    parameter VECTOR_PACKER_NUM_LOG = $clog2(VECTOR_PACKER_NUM_ENTRIES)
)(
    input  wire                  clk_i,                  // Clock signal
    input  wire                  rstn_i,                 // Reset signal
    input logic                  kill_i,                 // Exception detected at Commit
    input logic                  flush_i,                // Delete all load_store_queue entries
    input logic                  en_ld_st_translation_i,

    input rr_exe_mem_instr_t     instruction_i,          // Interface to add new instuction
    input resp_dcache_cpu_t      resp_dcache_cpu_i,      // Response from dcache
    input wire [1:0]             commit_store_or_amo_i,  // Signal from commit enables writes.
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
    input logic [VMAXELEM_LOG:0] vl_i,

    `ifdef SIM_COMMIT_LOG
    output addr_t                store_addr_o,
    output bus_simd_t            store_data_o,
    `endif

    output logic                 pmu_load_after_store_o  // Load blocked by ongoing store
);

function [63:0] trunc_sum_64bits(input [64:0] val_in);
  trunc_sum_64bits = val_in[63:0];
endfunction

function [6:0] trunc_sum_7bits(input [7:0] val_in);
  trunc_sum_7bits = val_in[6:0];
endfunction

function [4:0] trunc_shift_7_5(input [6:0] val_in);
  trunc_shift_7_5 = val_in[4:0];
endfunction

function [6:0] trunc_9_7(input [8:0] val_in);
  trunc_9_7 = val_in[6:0];
endfunction

function [6:0] trunc_10_7(input [9:0] val_in);
  trunc_10_7 = val_in[6:0];
endfunction

function [6:0] trunc_11_7(input [10:0] val_in);
  trunc_11_7 = val_in[6:0];
endfunction

function [6:0] trunc_12_7(input [11:0] val_in);
  trunc_12_7 = val_in[6:0];
endfunction

function [4:0] trunc_6_5(input [5:0] val_in);
  trunc_6_5 = val_in[4:0];
endfunction

function [1:0] trunc_3_2(input [2:0] val_in);
  trunc_3_2 = val_in[1:0];
endfunction
             
// Track Store and AMO in the pipeline and related Stall
logic is_STORE_or_AMO_s1_q;
logic is_STORE_s1_q;

logic flush_store;
logic flush_amo;
logic flush_amo_prmq;
logic store_on_fly;
logic amo_on_fly;
logic mem_commit_stall_s0;

// Load Store Queue control signals
logic full_lsq;
logic empty_lsq;
logic flush_to_lsq;
logic read_next_lsq;
logic blocked_store;
logic reg_valid_req;
logic reg_ready_resp;
logic killed_dcache_req_d;
logic killed_dcache_req_q;
logic req_cpu_dcache_valid_int;
logic stall_after_flush_lsq;

// Instruction to LSQ and pipline
rr_exe_mem_instr_t instruction_to_lsq;
rr_exe_mem_instr_t instruction_to_dcache;
rr_exe_mem_instr_t instruction_to_wb;
rr_exe_mem_instr_t instruction_s1_d;
rr_exe_mem_instr_t instruction_s1_q;

// Input/Output Pipeline
logic io_s1_q;

// Tag Counter and Pipeline
logic [6:0] tag_id;
logic [6:0] tag_id_s1_q;

rr_exe_mem_instr_t instruction_to_pmrq;
pmrq_instr_t instruction_from_pmrq;

// PMRQ control signals
logic advance_head_prmq;
logic mv_back_tail_prmq;
logic full_pmrq;
logic replay;

// Select data source
bus_simd_t data_to_wb;
bus_simd_t vdata_to_wb;

bus_simd_t vload_packer_d [VECTOR_PACKER_NUM_ENTRIES-1:0];
gl_index_t vload_packer_id_d [VECTOR_PACKER_NUM_ENTRIES-1:0];
logic [VMAXELEM_LOG:0] vload_packer_nelem_d [VECTOR_PACKER_NUM_ENTRIES-1:0];
bus_simd_t vload_packer_q [VECTOR_PACKER_NUM_ENTRIES-1:0];
gl_index_t vload_packer_id_q [VECTOR_PACKER_NUM_ENTRIES-1:0];
logic [VMAXELEM_LOG:0] vload_packer_nelem_q [VECTOR_PACKER_NUM_ENTRIES-1:0];
logic vload_packer_write_hit, vload_packer_read_hit;
logic vload_packer_complete;
logic [VECTOR_PACKER_NUM_LOG-1:0] vload_packer_write_idx;
logic [VECTOR_PACKER_NUM_LOG:0] vload_packer_nfree_d, vload_packer_nfree_q;
logic vload_packer_write, vload_packer_free;
gl_index_t vstore_packer_id_d [VECTOR_PACKER_NUM_ENTRIES-1:0];
logic [VMAXELEM_LOG:0] vstore_packer_nelem_d [VECTOR_PACKER_NUM_ENTRIES-1:0];
gl_index_t vstore_packer_id_q [VECTOR_PACKER_NUM_ENTRIES-1:0];
logic [VMAXELEM_LOG:0] vstore_packer_nelem_q [VECTOR_PACKER_NUM_ENTRIES-1:0];
logic vstore_packer_write_hit, vstore_packer_read_hit;
logic vstore_packer_complete;
logic [VECTOR_PACKER_NUM_LOG:0] vstore_packer_nfree_d, vstore_packer_nfree_q;
logic [VECTOR_PACKER_NUM_LOG-1:0] vstore_packer_write_idx;
logic vstore_packer_write, vstore_packer_free;
logic vload_packer_full, vstore_packer_full;
logic vlm_inst_wb, vlsm_inst_s1;

`ifdef REGISTER_HPDC_OUTPUT
logic is_STORE_or_AMO_s2_q;
logic is_STORE_s2_q;
rr_exe_mem_instr_t instruction_s2_q;
resp_dcache_cpu_t resp_dcache_cpu_q;
logic io_s2_q;
logic [6:0] tag_id_s2_q;
`endif

assign vload_packer_full = (vload_packer_nfree_q == 'h0);
assign vstore_packer_full = (vstore_packer_nfree_q == 'h0);

// State machine variables
logic [2:0] state;
logic [2:0] next_state;

// Possible states of the control automata
parameter ResetState  = 3'b000,
          ReadHead = 3'b001;

///////////////////////////////////////////////////////////////////////////////
///// LOAD STORE QUEUE
///////////////////////////////////////////////////////////////////////////////

// Flush LSQ
assign flush_to_lsq = kill_i | flush_i;

// Input instruction to LSQ
assign instruction_to_lsq.instr         = ((instruction_i.instr.unit == UNIT_MEM) && instruction_i.instr.valid) ? instruction_i.instr : 'h0 ;
assign instruction_to_lsq.data_rs1      = (instruction_i.instr.mem_type == AMO) ? instruction_i.data_rs1 : trunc_sum_64bits(instruction_i.data_rs1 + instruction_i.instr.imm);
assign instruction_to_lsq.data_rs2      = instruction_i.data_rs2;
assign instruction_to_lsq.data_old_vd   = instruction_i.data_old_vd;
assign instruction_to_lsq.data_vm       = instruction_i.data_vm;
assign instruction_to_lsq.sew           = instruction_i.sew;
assign instruction_to_lsq.prd           = instruction_i.prd;
assign instruction_to_lsq.pvd           = instruction_i.pvd;
assign instruction_to_lsq.fprd          = instruction_i.fprd;
assign instruction_to_lsq.gl_index      = instruction_i.gl_index;

assign instruction_to_lsq.is_amo_or_store  = instruction_i.is_amo_or_store;

assign instruction_to_lsq.is_store  = instruction_i.is_store;
                                      
assign instruction_to_lsq.is_amo  = instruction_i.is_amo;

assign instruction_to_lsq.vmisalign_xcpt = instruction_i.vmisalign_xcpt;
assign instruction_to_lsq.velem_id = instruction_i.velem_id;
assign instruction_to_lsq.load_mask = instruction_i.load_mask;
assign instruction_to_lsq.velem_off = instruction_i.velem_off;
assign instruction_to_lsq.velem_incr = instruction_i.velem_incr;
assign instruction_to_lsq.neg_stride = instruction_i.neg_stride;

assign instruction_to_lsq.ex = 'h0; // Exceptions in earlier stages do not enter the mem unit
assign instruction_to_lsq.rdy1 = 'h0;
assign instruction_to_lsq.rdy2 = 'h0;
assign instruction_to_lsq.old_pvd = 'h0;
assign instruction_to_lsq.old_prd = 'h0;
assign instruction_to_lsq.chkp = 'h0;
assign instruction_to_lsq.prs2 = 'h0;
assign instruction_to_lsq.agu_req_tag = 'h0;
assign instruction_to_lsq.old_fprd = 'h0;
assign instruction_to_lsq.prs1 = 'h0;
assign instruction_to_lsq.translated = 'h0;
assign instruction_to_lsq.checkpoint_done = 'h0;


`ifdef SIM_COMMIT_LOG
assign instruction_to_lsq.vaddr = instruction_to_lsq.data_rs1;
`endif

// LSQ
load_store_queue  #(
    .DracCfg(DracCfg)
) load_store_queue_inst (
    .clk_i              (clk_i),
    .rstn_i             (rstn_i),
    .instruction_i      (instruction_to_lsq),
    .en_ld_st_translation_i (en_ld_st_translation_i),
    .flush_i            (flush_to_lsq),
    .read_next_i        (read_next_lsq),
    .next_instr_exe_o   (instruction_to_dcache),
    .rob_store_ack_i    (|commit_store_or_amo_i),
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
    end else if (flush_to_lsq) begin
        state <= ResetState;
    end else begin
        state <= next_state;
    end
end


// Mealy Output and Next State
always_comb begin
    req_cpu_dcache_valid_int    = 1'b0;     // No Request
    read_next_lsq               = 1'b1;     // No Advance LSQ
    mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
    instruction_s1_d            =  'h0;     // No Instruction to next stage
    next_state                  = ReadHead; // Next state Read Head
    if (flush_to_lsq) begin
        req_cpu_dcache_valid_int    = 1'b0;     // No Request
        read_next_lsq               = 1'b1;     // No Advance LSQ
        mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
        instruction_s1_d            =  'h0;     // No Instruction to next stage
        next_state                  = resp_dcache_cpu_i.ordered ? ReadHead : ResetState ; // Next state Read Head
    end else begin
        case(state)
            ////////////////////////////////////////////////// Reset state
            ResetState: begin
                req_cpu_dcache_valid_int    = 1'b0;         // No Request
                read_next_lsq               = 1'b0;         // No Read of LSQ
                mem_commit_stall_s0         = 1'b0;         // No Stall of Commit
                instruction_s1_d            =  'h0;         // No Instruction to next stage
                next_state                  = resp_dcache_cpu_i.ordered ? ReadHead : ResetState; // Next state Read Head
            end
            ////////////////////////////////////////////////// Read head of LSQ
            ReadHead: begin
                if (empty_lsq || blocked_store) begin
                    req_cpu_dcache_valid_int    = 1'b0;     // No Request
                    read_next_lsq               = 1'b0;     // No Advance LSQ 
                    mem_commit_stall_s0         = 1'b0;     // No Stall of Commit
                    instruction_s1_d            =  'h0;     // No Instruction to next stage
                    next_state                  = ReadHead; // Next state Read Head
                end else begin
                    // Request Logic
                    next_state             = ReadHead;
                    
                    //// Set request valid bit, stall_commit and next state signals 
                    if (!instruction_to_dcache.instr.valid | full_pmrq | 
                       ((instruction_to_dcache.velem_incr < vl_i[VMAXELEM_LOG:0]) & // partial vector
                       ((vload_packer_full & ~req_cpu_dcache_o.is_store) | (vstore_packer_full & req_cpu_dcache_o.is_store)))) begin
                        // If not valid instruction or full Pending Request Memory Queue or full vpacker with partial vector instruction
                        // Wait until next state
                        req_cpu_dcache_valid_int = 1'b0;
                        mem_commit_stall_s0    = 1'b0;
                        instruction_s1_d        = 'h0;
                    end else if (!req_cpu_dcache_o.is_amo_or_store) begin
                        // If the instruction is not a Store or AMO
                        req_cpu_dcache_valid_int = ~instruction_to_dcache.ex.valid & ~stall_after_flush_lsq; // Don't send new request before sending the killed one
                        mem_commit_stall_s0    = 1'b0;
                        instruction_s1_d = ((resp_dcache_cpu_i.ready & ~stall_after_flush_lsq) | instruction_to_dcache.ex.valid) ? instruction_to_dcache : 'h0;
                    end else if (!((store_on_fly & req_cpu_dcache_o.is_amo) | amo_on_fly) |
                                 (mem_gl_index_o == instruction_to_dcache.gl_index)) begin // TODO: PReguntar al NArcis a veure si es pot treure
                        // If there is not a Store or AMO on fly or the current instruction
                        //  was sent to dache previously
                        
                        // Make request If L1 ready and current instruction is either load
                        //  or store with commit permission
                        req_cpu_dcache_valid_int = 
                                          (!req_cpu_dcache_o.is_amo_or_store | commit_store_or_amo_i[0] | commit_store_or_amo_i[1])
                                           & ~instruction_to_dcache.ex.valid & ~stall_after_flush_lsq & instruction_to_dcache.load_mask[0]; // Don't send new request before sending the killed one
                       
                        // Stall the commit stage if it is a commiting store or amo
                        mem_commit_stall_s0 = req_cpu_dcache_o.is_amo_or_store & commit_store_or_amo_i[0] & ~flush_store;
                        // If cache is not ready wait for it
                        // Otherwise if store or amo is launched, continue reading, otherwise wait
                        // until arriving to commit
                        instruction_s1_d = ((resp_dcache_cpu_i.ready & ~stall_after_flush_lsq 
                                            & (!req_cpu_dcache_o.is_amo_or_store | commit_store_or_amo_i[0] | commit_store_or_amo_i[1])) 
                                            | instruction_to_dcache.ex.valid | 
                                            ((commit_store_or_amo_i[0] | commit_store_or_amo_i[1]) & ~instruction_to_dcache.load_mask[0])) ? instruction_to_dcache : 'h0;
                    end else begin
                        req_cpu_dcache_valid_int = 1'b0;
                        mem_commit_stall_s0    = 1'b0;
                        instruction_s1_d = 'h0;
                    end

                    // Advance LSQ when a transaction is performed OR if the instruction has an exception
                    read_next_lsq = (req_cpu_dcache_valid_int & resp_dcache_cpu_i.ready & ~stall_after_flush_lsq) | instruction_to_dcache.ex.valid | 
                                    (((commit_store_or_amo_i[0] | commit_store_or_amo_i[1]) & ~instruction_to_dcache.ex.valid) & ~instruction_to_dcache.load_mask[0]);
                end
            end
        endcase
    end
end

assign killed_dcache_req_d = ~reg_ready_resp & reg_valid_req & ~req_cpu_dcache_valid_int;
assign req_cpu_dcache_o.valid = req_cpu_dcache_valid_int | killed_dcache_req_d | killed_dcache_req_q;

// Update State Machine and Stored Instruction
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        tag_id <= 'h0;
        reg_ready_resp <= 1'b0;
        reg_valid_req <= 1'b0;
        killed_dcache_req_q <= 1'b0;
        stall_after_flush_lsq <= 1'b0;
    end else begin
        if (req_cpu_dcache_o.valid & resp_dcache_cpu_i.ready) begin // Sent or killed request
            tag_id <= trunc_sum_7bits(tag_id + 7'h1);
            killed_dcache_req_q <= 1'b0;
            stall_after_flush_lsq <= 1'b0;
        end else if (killed_dcache_req_d) begin
            killed_dcache_req_q <= 1'b1;
            stall_after_flush_lsq <= flush_to_lsq;
        end
        reg_ready_resp <= resp_dcache_cpu_i.ready;
        reg_valid_req <= req_cpu_dcache_o.valid;
    end
end

//// Select source to DCACHE interface
always_comb begin
    req_cpu_dcache_o.data_rs1        = instruction_to_dcache.data_rs1;
    req_cpu_dcache_o.data_rs2        = instruction_to_dcache.data_rs2;
    req_cpu_dcache_o.instr_type      = instruction_to_dcache.instr.instr_type;
    req_cpu_dcache_o.mem_size        = instruction_to_dcache.instr.mem_size;
    req_cpu_dcache_o.rd              = tag_id;
    req_cpu_dcache_o.is_amo_or_store = instruction_to_dcache.is_amo_or_store;
    req_cpu_dcache_o.is_amo          = instruction_to_dcache.is_amo;
    req_cpu_dcache_o.is_store        = instruction_to_dcache.is_store;
end

//// Store in the Pipeline Send the GL index to commit to match the commiting instruction with the Store
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        store_on_fly    <= 1'b0;
        amo_on_fly      <= 1'b0;
        mem_gl_index_o  <= 'h0;
    end 
    else begin
        `ifdef REGISTER_HPDC_OUTPUT
        if (instruction_s1_q.instr.valid & is_STORE_or_AMO_s1_q & !flush_to_lsq) begin
            mem_gl_index_o  <= instruction_s1_q.gl_index;
        end
        else if (instruction_s1_d.instr.valid & req_cpu_dcache_o.is_amo_or_store) begin
            store_on_fly    <= req_cpu_dcache_o.is_store; 
            amo_on_fly      <= req_cpu_dcache_o.is_amo; 
        end
        `else
        if (instruction_s1_d.instr.valid & req_cpu_dcache_o.is_amo_or_store) begin
            store_on_fly    <= req_cpu_dcache_o.is_store; 
            amo_on_fly      <= req_cpu_dcache_o.is_amo;
            mem_gl_index_o  <= instruction_s1_d.gl_index;
        end
        `endif   
        else if (flush_store && vstore_packer_complete) begin
            store_on_fly    <= 1'b0;
            mem_gl_index_o  <= 'h0;
        end
        else if (flush_amo | flush_amo_prmq) begin
            amo_on_fly      <= 1'b0; 
            mem_gl_index_o  <= 'h0;
        end
    end
end

//// Pipeline the Memory access and the responses to track the state
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        instruction_s1_q     <=  'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_s1_q        <= 1'b0;
        io_s1_q              <= 1'b0;
        tag_id_s1_q          <=  'h0;
        
        `ifdef REGISTER_HPDC_OUTPUT
        instruction_s2_q     <=  'h0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        is_STORE_s2_q        <= 1'b0;
        io_s2_q              <= 1'b0;
        tag_id_s2_q          <=  'h0;
        resp_dcache_cpu_q    <=  'h0;
        `endif
    end else if (flush_to_lsq) begin       // In case of miss flush the pipeline
        instruction_s1_q     <=  'h0;
        is_STORE_or_AMO_s1_q <= 1'b0;
        is_STORE_s1_q        <= 1'b0;
        io_s1_q              <= 1'b0;
        tag_id_s1_q          <=  'h0;

        `ifdef REGISTER_HPDC_OUTPUT
        instruction_s2_q     <=  'h0;
        is_STORE_or_AMO_s2_q <= 1'b0;
        is_STORE_s2_q        <= 1'b0;
        io_s2_q              <= 1'b0;
        tag_id_s2_q          <=  'h0;
        resp_dcache_cpu_q    <=  'h0;
        `endif
    end else begin          // Update the Pipeline    
        instruction_s1_q     <= instruction_s1_d;
        is_STORE_or_AMO_s1_q <= req_cpu_dcache_o.is_amo_or_store;
        is_STORE_s1_q        <= req_cpu_dcache_o.is_store;
        io_s1_q              <= resp_dcache_cpu_i.io_address_space;
        tag_id_s1_q          <= tag_id;
        
        `ifdef REGISTER_HPDC_OUTPUT
        instruction_s2_q     <= instruction_s1_q;
        is_STORE_or_AMO_s2_q <= is_STORE_or_AMO_s1_q;
        is_STORE_s2_q        <= is_STORE_s1_q;
        io_s2_q              <= io_s1_q;
        tag_id_s2_q          <= tag_id_s1_q;
        resp_dcache_cpu_q    <= resp_dcache_cpu_i;
        `endif
    end
end

//// Decide if the pipeline needs to be flushed.
always_comb begin
    flush_store         = 1'b0;
    flush_amo           = 1'b0;
    mv_back_tail_prmq   = 1'b0;
    instruction_to_pmrq =  'h0;
    `ifdef REGISTER_HPDC_OUTPUT
    if (instruction_s2_q.instr.valid && resp_dcache_cpu_q.valid && (resp_dcache_cpu_q.rd == tag_id_s2_q)) begin
        flush_store         = is_STORE_s2_q;
        flush_amo           = is_STORE_or_AMO_s2_q & !is_STORE_s2_q; 
    end else if (instruction_s2_q.instr.valid & instruction_s2_q.ex.valid) begin 
        instruction_to_pmrq =  'h0;
        flush_store         = is_STORE_s2_q;
        flush_amo           = is_STORE_or_AMO_s2_q & !is_STORE_s2_q;
    end else if (instruction_s2_q.instr.valid & io_s2_q & is_STORE_or_AMO_s2_q) begin
        instruction_to_pmrq =  'h0;
        flush_store         = 1'b1;
        flush_amo           = 1'b1;
    end else if (instruction_s2_q.instr.valid & !is_STORE_s2_q) begin 
        instruction_to_pmrq = instruction_s2_q; // TODO: Parlar amb en NArcis a veure si podem tenir més d'un store en vol
    end else if (instruction_s2_q.instr.valid & is_STORE_s2_q) begin
        flush_store         = 1'b1;
    end else if (flush_to_lsq) begin
        flush_store         = 1'b1;
        flush_amo           = 1'b1;
    end
    `else
    if (instruction_s1_q.instr.valid && resp_dcache_cpu_i.valid && (resp_dcache_cpu_i.rd == tag_id_s1_q)) begin
        flush_store         = is_STORE_s1_q;
        flush_amo           = is_STORE_or_AMO_s1_q & !is_STORE_s1_q; 
    end else if (instruction_s1_q.instr.valid & instruction_s1_q.ex.valid) begin 
        instruction_to_pmrq =  'h0;
        flush_store         = is_STORE_s1_q;
        flush_amo           = is_STORE_or_AMO_s1_q & !is_STORE_s1_q;
    end else if (instruction_s1_q.instr.valid & io_s1_q & is_STORE_or_AMO_s1_q) begin
        instruction_to_pmrq =  'h0;
        flush_store         = 1'b1;
        flush_amo           = 1'b1;
    end else if (instruction_s1_q.instr.valid & !is_STORE_s1_q) begin 
        instruction_to_pmrq = instruction_s1_q; // TODO: Parlar amb en NArcis a veure si podem tenir més d'un store en vol
    end else if (instruction_s1_q.instr.valid & is_STORE_s1_q) begin
        flush_store         = 1'b1;
    end
    `endif
end

`ifdef REGISTER_HPDC_OUTPUT
assign replay = resp_dcache_cpu_q.valid && (!instruction_s2_q.instr.valid || (resp_dcache_cpu_q.rd != tag_id_s2_q));
`else 
assign replay = resp_dcache_cpu_i.valid && (!instruction_s1_q.instr.valid || (resp_dcache_cpu_i.rd != tag_id_s1_q));
`endif

// Pending Memory Request Table (PMRQ)
pending_mem_req_queue pending_mem_req_queue_inst (
    .clk_i                 (clk_i),
    .rstn_i                (rstn_i),
    .instruction_i         (instruction_to_pmrq),
    .flush_i               (flush_to_lsq),
    .replay_valid_i        (replay),
    `ifdef REGISTER_HPDC_OUTPUT
    .tag_i                 (tag_id_s2_q),
    .tag_next_i            (resp_dcache_cpu_q.rd),
    .replay_data_i         (resp_dcache_cpu_q.data),
    .response_valid_i      (resp_dcache_cpu_q.valid),
    `else
    .tag_i                 (tag_id_s1_q),
    .tag_next_i            (resp_dcache_cpu_i.rd),
    .replay_data_i         (resp_dcache_cpu_i.data),
    .response_valid_i      (resp_dcache_cpu_i.valid),
    `endif
    .advance_head_i        (advance_head_prmq),
    .mv_back_tail_i        (mv_back_tail_prmq),
    .finish_instr_o        (instruction_from_pmrq),
    .full_o                (full_pmrq)
);

bus_dcache_data_t data_dcache;

logic [255:0]data_8word; 
logic [127:0]data_qword;
logic [63:0] data_dword;
logic [31:0] data_word;
logic [15:0] data_half;
logic [7:0]  data_byte;

//// Decide if the instruction should be sent to writeback, it must wait for response or
////    the request must be replayed. It also controls the LSQ head and pipeline flush.
always_comb begin
    instruction_to_wb      =  'h0;
    data_dcache            =  'h0;
    advance_head_prmq      = 1'b0;
    flush_amo_prmq         = 1'b0;
    `ifdef REGISTER_HPDC_OUTPUT
    if(instruction_s2_q.instr.valid && resp_dcache_cpu_q.valid && !is_STORE_s2_q && (resp_dcache_cpu_q.rd == tag_id_s2_q)) begin
        instruction_to_wb      = instruction_s2_q;
        advance_head_prmq      = 1'b0;
        data_dcache            = resp_dcache_cpu_q.data;
    end
    else if(instruction_s2_q.instr.valid & instruction_s2_q.ex.valid) begin
        instruction_to_wb      = instruction_s2_q;
        advance_head_prmq      = 1'b0;
    end
    else if (instruction_s2_q.instr.valid & io_s2_q & is_STORE_or_AMO_s2_q) begin // TODO: Mirar com respon la cache als stores
        instruction_to_wb      = instruction_s2_q;
        advance_head_prmq      = 1'b0;
    end
    `else
    if(instruction_s1_q.instr.valid && resp_dcache_cpu_i.valid && !is_STORE_s1_q && (resp_dcache_cpu_i.rd == tag_id_s1_q)) begin
        instruction_to_wb      = instruction_s1_q;
        advance_head_prmq      = 1'b0;
        data_dcache            = resp_dcache_cpu_i.data;
    end
    else if(instruction_s1_q.instr.valid & instruction_s1_q.ex.valid) begin
        instruction_to_wb      = instruction_s1_q;
        advance_head_prmq      = 1'b0;
    end
    else if (instruction_s1_q.instr.valid & io_s1_q & is_STORE_or_AMO_s1_q) begin // TODO: Mirar com respon la cache als stores
        instruction_to_wb      = instruction_s1_q;
        advance_head_prmq      = 1'b0;
    end
    `endif
    else if(instruction_from_pmrq.instr.valid) begin
        instruction_to_wb.data_rs2        = data_dword; 
        instruction_to_wb.instr           = instruction_from_pmrq.instr;           
        instruction_to_wb.data_rs1        = instruction_from_pmrq.data_rs1;
        instruction_to_wb.data_old_vd     = instruction_from_pmrq.data_old_vd;     
        instruction_to_wb.data_vm         = instruction_from_pmrq.data_vm;         
        instruction_to_wb.sew             = instruction_from_pmrq.sew;             
        instruction_to_wb.prs1            = instruction_from_pmrq.prs1;            
        instruction_to_wb.rdy1            = instruction_from_pmrq.rdy1;            
        instruction_to_wb.prs2            = instruction_from_pmrq.prs2;            
        instruction_to_wb.rdy2            = instruction_from_pmrq.rdy2;            
        instruction_to_wb.prd             = instruction_from_pmrq.prd;             
        instruction_to_wb.pvd             = instruction_from_pmrq.pvd;             
        instruction_to_wb.old_prd         = instruction_from_pmrq.old_prd;         
        instruction_to_wb.old_pvd         = instruction_from_pmrq.old_pvd;         
        instruction_to_wb.fprd            = instruction_from_pmrq.fprd;            
        instruction_to_wb.old_fprd        = instruction_from_pmrq.old_fprd;        
        instruction_to_wb.is_amo_or_store = instruction_from_pmrq.is_amo_or_store; 
        instruction_to_wb.is_amo          = instruction_from_pmrq.is_amo;          
        instruction_to_wb.is_store        = instruction_from_pmrq.is_store;        
        instruction_to_wb.checkpoint_done = instruction_from_pmrq.checkpoint_done; 
        instruction_to_wb.chkp            = instruction_from_pmrq.chkp;            
        instruction_to_wb.translated      = instruction_from_pmrq.translated;      
        instruction_to_wb.ex              = instruction_from_pmrq.ex;
        instruction_to_wb.gl_index        = instruction_from_pmrq.gl_index;        
        instruction_to_wb.agu_req_tag     = instruction_from_pmrq.agu_req_tag;
        instruction_to_wb.vmisalign_xcpt  = instruction_from_pmrq.vmisalign_xcpt;  
        instruction_to_wb.velem_id        = instruction_from_pmrq.velem_id;  
        instruction_to_wb.load_mask       = instruction_from_pmrq.load_mask;     
        instruction_to_wb.velem_off       = instruction_from_pmrq.velem_off; 
        instruction_to_wb.velem_incr      = instruction_from_pmrq.velem_incr;  
        instruction_to_wb.neg_stride      = instruction_from_pmrq.neg_stride;     
        `ifdef SIM_COMMIT_LOG
        instruction_to_wb.vaddr      = instruction_from_pmrq.vaddr; 
        `endif
        advance_head_prmq      = 1'b1;
        flush_amo_prmq         = instruction_from_pmrq.is_amo;
        data_dcache            = instruction_from_pmrq.data_rs2;
    end
end

// Select bits from whole double word depending on offset

assign data_8word= (DCACHE_MAXELEM == 32) ? data_dcache : data_dcache[{instruction_to_wb.data_rs1[DCACHE_MAXELEM_LOG-1+(DCACHE_MAXELEM<=8)+(DCACHE_MAXELEM<=16)+(DCACHE_MAXELEM<=32):5],8'b0} +: 256];
assign data_qword= (DCACHE_MAXELEM == 16) ? data_dcache : data_dcache[{instruction_to_wb.data_rs1[DCACHE_MAXELEM_LOG-1+(DCACHE_MAXELEM<=8)+(DCACHE_MAXELEM<=16):4],   7'b0} +: 128];
assign data_dword= (DCACHE_MAXELEM == 8)  ? data_dcache : data_dcache[{instruction_to_wb.data_rs1[DCACHE_MAXELEM_LOG-1+(DCACHE_MAXELEM<=8):3],   6'b0} +: 64];
assign data_word = data_dcache[{instruction_to_wb.data_rs1[DCACHE_MAXELEM_LOG-1:2], 5'b0} +: 32];
assign data_half = data_dcache[{instruction_to_wb.data_rs1[DCACHE_MAXELEM_LOG-1:1], 4'b0} +: 16];
assign data_byte = data_dcache[{instruction_to_wb.data_rs1[DCACHE_MAXELEM_LOG-1:0], 3'b0} +: 8];

// Select data depending on memory size & do sign extension if needed

always_comb begin
    data_to_wb = 'h0;
    case (instruction_to_wb.instr.mem_size)
        4'b0000: data_to_wb = {{(VLEN-8){data_byte[7]}},data_byte};
        4'b0001: data_to_wb = {{(VLEN-16){data_half[15]}},data_half};
        4'b0010: data_to_wb = {{(VLEN-32){data_word[31]}},data_word};
        4'b0011: data_to_wb = (VMAXELEM == 8) ? data_dword : {{(VLEN-64+(VLEN==64)){data_dword[63]}},data_dword};
        4'b0100: data_to_wb = data_byte;
        4'b0101: data_to_wb = data_half;
        4'b0110: data_to_wb = data_word;
        4'b0111: data_to_wb = data_dword;
        4'b1000: data_to_wb = data_qword;
        4'b1001: data_to_wb = data_8word[VLEN-1:0];
        default: data_to_wb = data_dcache[VLEN-1:0];
    endcase
end

bus_simd_t masked_data_to_wb;
logic [VMAXELEM_LOG:0] packed_velems;
assign vlm_inst_wb = (instruction_to_wb.instr.instr_type == VLM) ? 1'b1 : 1'b0;
assign vlsm_inst_s1 = ((instruction_s1_d.instr.instr_type == VLM) || (instruction_s1_d.instr.instr_type == VSM)) ? 1'b1 : 1'b0;

//Apply the mask to the vector result
always_comb begin
    masked_data_to_wb = instruction_to_wb.data_old_vd;
    vdata_to_wb = instruction_to_wb.data_old_vd;
    packed_velems = 'h0;
    for (int i = (VECTOR_PACKER_NUM_ENTRIES-1); i>=0; --i) begin
        if ((vload_packer_id_q[i] == instruction_to_wb.gl_index) && instruction_to_wb.instr.valid && instruction_to_wb.instr.vregfile_we &&
            (vload_packer_nelem_q[i] != '1)) begin
            vdata_to_wb = vload_packer_q[i];
        end
    end 
    case (instruction_to_wb.sew)
        SEW_8: begin
            if (~instruction_to_wb.neg_stride) begin
                for (int i = 0; i<(VLEN/8); ++i) begin
                    if (i >= instruction_to_wb.velem_off) begin
                        if (instruction_to_wb.load_mask[i-instruction_to_wb.velem_off]) begin
                            vdata_to_wb[(trunc_9_7(8*(packed_velems+instruction_to_wb.velem_id)))+:8] = data_to_wb[(8*i)+:8];
                            packed_velems = trunc_6_5(packed_velems + 1'b1);
                        end
                    end
                end
            end else begin
                packed_velems = instruction_to_wb.velem_incr - 1'b1;
                for (int i = 0; i<(VLEN/8); ++i) begin
                    if (instruction_to_wb.load_mask[i]) begin
                        vdata_to_wb[(trunc_9_7(8*(packed_velems+instruction_to_wb.velem_id)))+:8] = data_to_wb[(8*i)+:8];
                        packed_velems = packed_velems - 1'b1;
                    end
                end 
            end
            for (int i = 0; i<(VLEN/8); ++i) begin
                if (instruction_to_wb.data_vm[i] || (vlm_inst_wb && (i < instruction_to_wb.velem_incr))) begin
                    masked_data_to_wb[(8*i)+:8] = vdata_to_wb[(8*i)+:8];
                end
            end
        end
        SEW_16: begin
            if (~instruction_to_wb.neg_stride) begin
                for (int i = 0; i<(VLEN/16); ++i) begin
                    if (i >= instruction_to_wb.velem_off) begin
                        if (instruction_to_wb.load_mask[(i-instruction_to_wb.velem_off)]) begin
                            vdata_to_wb[(trunc_10_7(16*(packed_velems+instruction_to_wb.velem_id)))+:16] = data_to_wb[(16*i)+:16];
                            packed_velems = trunc_6_5(packed_velems + 1'b1);
                        end
                    end
                end
            end else begin
                packed_velems = instruction_to_wb.velem_incr - 1'b1;
                for (int i = 0; i<(VLEN/16); ++i) begin
                    if (instruction_to_wb.load_mask[i]) begin
                        vdata_to_wb[(trunc_10_7(16*(packed_velems+instruction_to_wb.velem_id)))+:16] = data_to_wb[(16*i)+:16];
                        packed_velems = packed_velems - 1'b1;
                    end
                end 
            end
            for (int i = 0; i<(VLEN/16); ++i) begin
                if (instruction_to_wb.data_vm[i]) begin
                    masked_data_to_wb[(16*i)+:16] = vdata_to_wb[(16*i)+:16];
                end
            end
        end
        SEW_32: begin
            if (~instruction_to_wb.neg_stride) begin
                for (int i = 0; i<(VLEN/32); ++i) begin
                    if (i >= instruction_to_wb.velem_off) begin
                        if (instruction_to_wb.load_mask[(i-instruction_to_wb.velem_off)]) begin
                            vdata_to_wb[(trunc_11_7(32*(packed_velems+instruction_to_wb.velem_id)))+:32] = data_to_wb[(32*i)+:32];
                            packed_velems = trunc_6_5(packed_velems + 1'b1);
                        end
                    end
                end
            end else begin
                packed_velems = instruction_to_wb.velem_incr - 1'b1;
                for (int i = 0; i<(VLEN/32); ++i) begin
                    if (instruction_to_wb.load_mask[i]) begin
                        vdata_to_wb[(trunc_11_7(32*(packed_velems+instruction_to_wb.velem_id)))+:32] = data_to_wb[(32*i)+:32];
                        packed_velems = packed_velems - 1'b1;
                    end
                end 
            end
            for (int i = 0; i<(VLEN/32); ++i) begin
                if (instruction_to_wb.data_vm[i]) begin
                    masked_data_to_wb[(32*i)+:32] = vdata_to_wb[(32*i)+:32];
                end
            end
        end
        SEW_64: begin
            if (~instruction_to_wb.neg_stride) begin
                for (int i = 0; i<(VLEN/64); ++i) begin
                    if (i >= instruction_to_wb.velem_off) begin
                        if (instruction_to_wb.load_mask[(i-instruction_to_wb.velem_off)]) begin
                            vdata_to_wb[(trunc_12_7(64*(packed_velems+instruction_to_wb.velem_id)))+:64] = data_to_wb[(64*i)+:64];
                            packed_velems = trunc_6_5(packed_velems + 1'b1);
                        end
                    end
                end
            end else begin
                packed_velems = instruction_to_wb.velem_incr - 1'b1;
                for (int i = 0; i<(VLEN/64); ++i) begin
                    if (instruction_to_wb.load_mask[i]) begin
                        vdata_to_wb[(trunc_12_7(64*(packed_velems+instruction_to_wb.velem_id)))+:64] = data_to_wb[(64*i)+:64];
                        packed_velems = packed_velems - 1'b1;
                    end
                end 
            end
            for (int i = 0; i<(VLEN/64); ++i) begin
                if (instruction_to_wb.data_vm[i]) begin
                    masked_data_to_wb[(64*i)+:64] = vdata_to_wb[(64*i)+:64];
                end
            end
        end
    endcase
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        vload_packer_nfree_q <= 1'b1 << VECTOR_PACKER_NUM_LOG;
        vstore_packer_nfree_q <= 1'b1 << VECTOR_PACKER_NUM_LOG;
        for (int i = 0; i<VECTOR_PACKER_NUM_ENTRIES; ++i) begin
            vload_packer_q[i]      <= 'h0;
            vload_packer_id_q[i]   <= 'h0;
            vload_packer_nelem_q[i] <= '1;
            vstore_packer_id_q[i] <= 'h0;
            vstore_packer_nelem_q[i] <= '1;
        end
    end else begin
        vload_packer_q      <= vload_packer_d;
        vload_packer_id_q   <= vload_packer_id_d;
        vload_packer_nelem_q <= vload_packer_nelem_d;
        vload_packer_nfree_q <= vload_packer_nfree_d;
        vstore_packer_id_q <= vstore_packer_id_d;
        vstore_packer_nelem_q <= vstore_packer_nelem_d;
        vstore_packer_nfree_q <= vstore_packer_nfree_d;
    end
end

always_comb begin
    vload_packer_write_hit = 1'b0;
    vload_packer_read_hit = 1'b0;
    vload_packer_complete = 1'b0;
    vload_packer_write_idx = 'b0;
    vload_packer_write = 1'b0;
    vload_packer_free = 1'b0;
    vload_packer_nfree_d = vload_packer_nfree_q;
    vload_packer_nelem_d = vload_packer_nelem_q;
    vload_packer_id_d = vload_packer_id_q;
    vload_packer_d = vload_packer_q;
    vstore_packer_id_d = vstore_packer_id_q;
    vstore_packer_nelem_d = vstore_packer_nelem_q;
    vstore_packer_nfree_d = vstore_packer_nfree_q;
    vstore_packer_complete = 1'b0;
    vstore_packer_write_hit = 1'b0;
    vstore_packer_read_hit = 1'b0;
    vstore_packer_write_idx = 'b0;
    vstore_packer_write = 1'b0;
    vstore_packer_free = 1'b0;
    if (flush_to_lsq) begin
        for (int i = 0; i<VECTOR_PACKER_NUM_ENTRIES; ++i) begin
            vload_packer_id_d[i] = 'h0;
            vload_packer_nelem_d[i] = '1;
            vload_packer_nfree_d = 1'b1 << VECTOR_PACKER_NUM_LOG;
            vstore_packer_id_d[i] = 'h0;
            vstore_packer_nelem_d[i] = '1;
            vstore_packer_nfree_d = 1'b1 << VECTOR_PACKER_NUM_LOG;
        end
        vload_packer_complete = 1'b1;
        vstore_packer_complete = 1'b1;
    end else begin
        if (instruction_s1_d.instr.valid && instruction_s1_d.instr.vregfile_we && !(instruction_s1_d.velem_incr >= vl_i[VMAXELEM_LOG:0]) && ~vlsm_inst_s1) begin
            for (int i = (VECTOR_PACKER_NUM_ENTRIES-1); i>=0; --i) begin
                if ((vload_packer_id_q[i] == instruction_s1_d.gl_index) && !vload_packer_write_hit && (vload_packer_nelem_q[i] != '1)) begin
                    vload_packer_write_hit = 1'b1;
                end else if (vload_packer_nelem_q[i] == '1) begin
                    vload_packer_write_idx = i;
                end
            end
            if (!vload_packer_write_hit) begin
                vload_packer_id_d[vload_packer_write_idx] = instruction_s1_d.gl_index;
                vload_packer_d[vload_packer_write_idx] = 'h0;
                vload_packer_nelem_d[vload_packer_write_idx] = 'h0;
                vload_packer_write = 1'b1;
            end
        end else if (instruction_s1_d.instr.valid && !(instruction_s1_d.velem_incr >= vl_i[VMAXELEM_LOG:0]) && ~vlsm_inst_s1) begin
            for (int i = (VECTOR_PACKER_NUM_ENTRIES-1); i>=0; --i) begin
                if ((vstore_packer_id_q[i] == instruction_s1_d.gl_index) && !vstore_packer_write_hit && (vstore_packer_nelem_q[i] != '1)) begin
                    vstore_packer_write_hit = 1'b1;
                end else if (vstore_packer_nelem_q[i] == '1) begin
                    vstore_packer_write_idx = i;
                end
            end
            if (!vstore_packer_write_hit) begin
                vstore_packer_id_d[vstore_packer_write_idx] = instruction_s1_d.gl_index;
                vstore_packer_nelem_d[vstore_packer_write_idx] = 'h0;
                vstore_packer_write = 1'b1;
            end
        end
        
        if ((instruction_to_wb.instr.valid && instruction_to_wb.instr.vregfile_we && (instruction_to_wb.velem_incr >= vl_i[VMAXELEM_LOG:0])) || vlm_inst_wb) begin
            vload_packer_complete = 1'b1;
        end else if (instruction_to_wb.instr.valid && instruction_to_wb.instr.vregfile_we) begin
            for (int i = 0; i<VECTOR_PACKER_NUM_ENTRIES; ++i) begin
                if ((vload_packer_id_q[i] == instruction_to_wb.gl_index) && !vload_packer_read_hit && (vload_packer_nelem_q[i] != '1)) begin
                    vload_packer_read_hit = 1'b1;
                    if ((vload_packer_nelem_q[i] + instruction_to_wb.velem_incr) >= vl_i[VMAXELEM_LOG:0]) begin
                        vload_packer_nelem_d[i] = '1;
                        vload_packer_complete = 1'b1;
                        vload_packer_free = 1'b1;
                    end else begin 
                        vload_packer_d[i] = masked_data_to_wb;
                        vload_packer_nelem_d[i] = trunc_6_5(vload_packer_nelem_q[i] + instruction_to_wb.velem_incr);
                    end
                end
            end
        `ifdef REGISTER_HPDC_OUTPUT
        end
        if (flush_store) begin
            if ((instruction_s2_q.velem_incr >= vl_i[VMAXELEM_LOG:0]) || (instruction_s2_q.instr.instr_type == VSM)) begin
                vstore_packer_complete = 1'b1;
            end else begin
                for (int i = 0; i<VECTOR_PACKER_NUM_ENTRIES; ++i) begin
                    if ((vstore_packer_id_q[i] == instruction_s2_q.gl_index) && !vstore_packer_read_hit && (vstore_packer_nelem_q[i] != '1)) begin
                        vstore_packer_read_hit = 1'b1;
                        if ((vstore_packer_nelem_q[i] + instruction_s2_q.velem_incr) >= vl_i[VMAXELEM_LOG:0]) begin
                            vstore_packer_nelem_d[i] = '1;
                            vstore_packer_complete = 1'b1;
                            vstore_packer_free = 1'b1;
                        end else begin 
                            vstore_packer_nelem_d[i] = trunc_6_5(vstore_packer_nelem_q[i] + instruction_s2_q.velem_incr);
                        end
                    end
                end
            end
        end
        `else
        end else if (flush_store) begin
            if ((instruction_s1_q.velem_incr >= vl_i[VMAXELEM_LOG:0]) || (instruction_s1_q.instr.instr_type == VSM)) begin
                vstore_packer_complete = 1'b1;
            end else begin
                for (int i = 0; i<VECTOR_PACKER_NUM_ENTRIES; ++i) begin
                    if ((vstore_packer_id_q[i] == instruction_s1_q.gl_index) && !vstore_packer_read_hit && (vstore_packer_nelem_q[i] != '1)) begin
                        vstore_packer_read_hit = 1'b1;
                        if ((vstore_packer_nelem_q[i] + instruction_s1_q.velem_incr) >= vl_i[VMAXELEM_LOG:0]) begin
                            vstore_packer_nelem_d[i] = '1;
                            vstore_packer_complete = 1'b1;
                            vstore_packer_free = 1'b1;
                        end else begin 
                            vstore_packer_nelem_d[i] = trunc_6_5(vstore_packer_nelem_q[i] + instruction_s1_q.velem_incr);
                        end
                    end
                end
            end
        end
        `endif
        vload_packer_nfree_d  = trunc_3_2(vload_packer_nfree_q  + vload_packer_free  - vload_packer_write);
        vstore_packer_nfree_d = trunc_3_2(vstore_packer_nfree_q + vstore_packer_free - vstore_packer_write);
    end
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
`ifdef SIM_KONATA_DUMP
assign instruction_scalar_o.id	          = instruction_to_wb.instr.id;
`endif
`ifdef SIM_COMMIT_LOG
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
assign instruction_scalar_o.result        = data_to_wb[63:0];
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
`ifdef SIM_KONATA_DUMP
assign instruction_fp_o.id	              = instruction_to_wb.instr.id;
`endif
`ifdef SIM_COMMIT_LOG
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
assign instruction_fp_o.result            = (instruction_to_wb.instr.instr_type == FLW) ? {32'hFFFFFFFF, data_to_wb[31:0]} : data_to_wb[63:0];
assign instruction_fp_o.ex                = instruction_to_wb.ex;
assign instruction_fp_o.fp_status         = 'h0;

// Output SIMD Instruction
assign instruction_simd_o.valid           = instruction_to_wb.instr.valid & instruction_to_wb.instr.vregfile_we & (vload_packer_complete | instruction_to_wb.ex.valid);
assign instruction_simd_o.pc              = instruction_to_wb.instr.pc;
assign instruction_simd_o.bpred           = instruction_to_wb.instr.bpred;
assign instruction_simd_o.rs1             = instruction_to_wb.instr.rs1;
assign instruction_simd_o.vd              = instruction_to_wb.instr.vd;
assign instruction_simd_o.change_pc_ena   = instruction_to_wb.instr.change_pc_ena;
assign instruction_simd_o.vregfile_we     = instruction_to_wb.instr.vregfile_we;
assign instruction_simd_o.instr_type      = instruction_to_wb.instr.instr_type;
`ifdef SIM_KONATA_DUMP
assign instruction_simd_o.id	          = instruction_to_wb.instr.id;
`endif
`ifdef SIM_COMMIT_LOG
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

`ifdef REGISTER_HPDC_OUTPUT
assign exception_mem_commit_o = (instruction_to_wb.ex.valid & is_STORE_or_AMO_s2_q) ? instruction_to_wb.ex : 'h0;
`else
assign exception_mem_commit_o = (instruction_to_wb.ex.valid & is_STORE_or_AMO_s1_q) ? instruction_to_wb.ex : 'h0;
`endif

///////////////////////////////////////////////////////////////////////////////
///// Outputs for the execution module or Dcache interface
///////////////////////////////////////////////////////////////////////////////

assign mem_store_or_amo_o = store_on_fly | amo_on_fly;

//// Stall committing instruction because it is a store
assign mem_commit_stall_o = mem_commit_stall_s0 | (store_on_fly & ~(flush_store & vstore_packer_complete)) | (amo_on_fly & ~flush_amo & ~flush_amo_prmq);

//// Block incoming Mem instructions
assign lock_o   = full_lsq;
assign empty_o  = empty_lsq & ~req_cpu_dcache_o.valid;

`ifdef SIM_COMMIT_LOG
    `ifdef REGISTER_HPDC_OUTPUT
    assign store_addr_o = instruction_s2_q.vaddr;
    assign store_data_o = instruction_s2_q.data_rs2;
    `else 
    assign store_addr_o = instruction_s1_q.vaddr;
    assign store_data_o = instruction_s1_q.data_rs2;
    `endif
`endif

endmodule

