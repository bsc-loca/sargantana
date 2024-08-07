/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : load_store_queue.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Victor.SP   |
 *  0.2        | Max Doblas  | Adding an Store Buffer  
 * -----------------------------------------------
 */

module load_store_queue
    import drac_pkg::*, riscv_pkg::*;
#(
    parameter drac_pkg::drac_cfg_t DracCfg     = drac_pkg::DracDefaultConfig
)(
    input logic                clk_i,            // Clock Singal
    input logic                rstn_i,           // Negated Reset Signal

    input rr_exe_mem_instr_t   instruction_i,    // All instruction input signals
    input logic                en_ld_st_translation_i,
     
    input logic                flush_i,          // Flush all entries
    input logic                read_next_i,      // Read next instruction of the ciruclar buffer
    input logic                rob_store_ack_i,
    input gl_index_t           rob_store_gl_idx_i,  // Signal from commit enables writes.
    output logic               blocked_store_o,

    output rr_exe_mem_instr_t  next_instr_exe_o, // Next Instruction to be executed 
       
    output logic               full_o,           // Lsq is full
    output logic               empty_o,          // Lsq is empty
    
    input tlb_cache_comm_t       dtlb_comm_i,
    output cache_tlb_comm_t      dtlb_comm_o,

    input logic [1:0] priv_lvl_i,
    
    output logic               pmu_load_after_store_o  // Load blocked by ongoing store
);

typedef logic [$clog2(LSQ_NUM_ENTRIES)-1:0] lsq_entry_pointer;

function [$clog2(LSQ_NUM_ENTRIES):0] trunc_lsq_num_sum(input [$clog2(LSQ_NUM_ENTRIES)+1:0] val_in);
  trunc_lsq_num_sum = val_in[$clog2(LSQ_NUM_ENTRIES):0];
endfunction

function [4:0] trunc_gl_ptr_sum(input [5:0] val_in);
  trunc_gl_ptr_sum = val_in[4:0];
endfunction

function [$clog2(LSQ_NUM_ENTRIES)-1:0] trunc_lsq_ptr_sum(input [$clog2(LSQ_NUM_ENTRIES):0] val_in);
  trunc_lsq_ptr_sum = val_in[$clog2(LSQ_NUM_ENTRIES)-1:0];
endfunction

// store buff signals
logic st_buff_full;
logic st_buff_empty;
logic st_buff_collision;
logic sb_write_enable;
rr_exe_mem_instr_t st_buff_inst_out;
logic is_next_store;
logic is_next_load;

// Points to the next available entry
lsq_entry_pointer tail;

// Points to the oldest executed entry
lsq_entry_pointer head;

// Points to the next entry to translate
lsq_entry_pointer tlb_tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(LSQ_NUM_ENTRIES):0] num_to_exe;
logic [$clog2(LSQ_NUM_ENTRIES):0] num_to_translate;

// FIFO Memory structure
rr_exe_mem_instr_t control_table[LSQ_NUM_ENTRIES-1:0];

// Internal Control Signals
logic write_enable;
logic read_enable;
logic read_enable_lsq;
logic read_enable_sb;
logic empty_int;
logic translate_enable;
logic translate_incoming;
gl_index_t ex_gl_index;
logic ex_reg;

logic io_address_space;

gl_index_t rob_store_gl_idx_next;

`ifdef SARG_BYPASS_LSQ
    logic bypass_lsq;
    assign bypass_lsq = empty_int && instruction_i.instr.valid && (instruction_i.instr.mem_type == LOAD) && translate_incoming && translate_enable;
`endif

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num_to_exe < LSQ_NUM_ENTRIES) & !((empty_int && (instruction_i.instr.mem_type == LOAD)) && read_enable);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = read_next_i & (!empty_int || (empty_int && (instruction_i.instr.valid && (instruction_i.instr.mem_type == LOAD)) && translate_incoming && translate_enable));

// We can translate the incoming instruction if there are no instructions to translate in the queue
assign translate_incoming = (instruction_i.instr.valid & (num_to_translate == '0)) & ~full_o;

rr_exe_mem_instr_t instr_to_translate;
assign instr_to_translate = translate_incoming ? instruction_i : control_table[tlb_tail];

// A translation can be done if there is a hit in the dTLB
assign translate_enable = dtlb_comm_i.tlb_ready & !dtlb_comm_i.resp.miss & instr_to_translate.instr.valid;

rr_exe_mem_instr_t translated_instr;

always_comb begin 
    logic is_load_reserved;
    is_load_reserved = (instr_to_translate.instr.instr_type == AMO_LRW) || (instr_to_translate.instr.instr_type == AMO_LRD);
    translated_instr = instr_to_translate;

    // Translation from TLB
    translated_instr.translated = translate_enable;
    translated_instr.data_rs1 = {dtlb_comm_i.resp.ppn, instr_to_translate.data_rs1[11:0]};
    
    // Exception treatment
    if ((ex_reg == 1'b1) && (translated_instr.gl_index == ex_gl_index)) begin // a previous request of the same instruction generated an exception
        translated_instr.ex.valid       = 1'b1;
    end else if (instr_to_translate.load_mask == 'h0) begin // Do not generate exceptions for fully masked requests 
        translated_instr.ex = 0;
    end else if (((instr_to_translate.instr.mem_size == 4'b0001) & (|instr_to_translate.data_rs1[0:0])) |
        ((instr_to_translate.instr.mem_size == 4'b0010) & (|instr_to_translate.data_rs1[1:0])) |
        ((instr_to_translate.instr.mem_size == 4'b0011) & (|instr_to_translate.data_rs1[2:0])) |
        ((instr_to_translate.instr.mem_size == 4'b0101) & (|instr_to_translate.data_rs1[0:0])) |
        ((instr_to_translate.instr.mem_size == 4'b0110) & (|instr_to_translate.data_rs1[1:0])) |
        ((instr_to_translate.instr.mem_size == 4'b0111) & (|instr_to_translate.data_rs1[2:0])) |
         instr_to_translate.vmisalign_xcpt) begin // Misaligned address
        translated_instr.ex.cause       = (instr_to_translate.is_amo_or_store && ~is_load_reserved) ? ST_AMO_ADDR_MISALIGNED : LD_ADDR_MISALIGNED;
        translated_instr.ex.origin      = instr_to_translate.data_rs1;
        translated_instr.ex.valid       = 1'b1;
    end else if (dtlb_comm_i.resp.xcpt.store & instr_to_translate.is_amo_or_store & ~is_load_reserved) begin // Page fault store
        translated_instr.ex.cause       = ST_AMO_PAGE_FAULT;
        translated_instr.ex.origin      = instr_to_translate.data_rs1;
        translated_instr.ex.valid       = 1'b1;
    end else if (dtlb_comm_i.resp.xcpt.load) begin // Page fault load
        translated_instr.ex.cause       = LD_PAGE_FAULT;
        translated_instr.ex.origin      = instr_to_translate.data_rs1;
        translated_instr.ex.valid       = 1'b1;
    `ifdef SIM_COMMIT_LOG
    end else if ((en_ld_st_translation_i && (instr_to_translate.data_rs1[VIRT_ADDR_SIZE-1] ? !(&instr_to_translate.data_rs1[63:VIRT_ADDR_SIZE]) : | instr_to_translate.data_rs1[63:VIRT_ADDR_SIZE])) ||
                  (~en_ld_st_translation_i && (~is_inside_mapped_sections(DracCfg, instr_to_translate.data_rs1) || (instr_to_translate.data_rs1 >= PHISIC_MEM_LIMIT))) ||
                  (en_ld_st_translation_i && translate_enable && (~is_inside_mapped_sections(DracCfg, translated_instr.data_rs1) || (translated_instr.data_rs1 >= PHISIC_MEM_LIMIT)))) begin // invalid address
    `else 
    end else if ((en_ld_st_translation_i && (instr_to_translate.data_rs1[VIRT_ADDR_SIZE-1] ? !(&instr_to_translate.data_rs1[63:VIRT_ADDR_SIZE]) : | instr_to_translate.data_rs1[63:VIRT_ADDR_SIZE])) ||
                  (~en_ld_st_translation_i && (~is_inside_mapped_sections(DracCfg, instr_to_translate.data_rs1) || (instr_to_translate.data_rs1 >= PHISIC_MEM_LIMIT)))) begin
    `endif
        translated_instr.ex.cause  = (instr_to_translate.is_amo_or_store && ~is_load_reserved) ? ST_AMO_ACCESS_FAULT : LD_ACCESS_FAULT;
        translated_instr.ex.origin = instr_to_translate.data_rs1;
        translated_instr.ex.valid  = 1'b1;
    end else begin
        translated_instr.ex = 0;
    end
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        ex_gl_index <= 'h0;
        ex_reg <= 1'b0;
    end else if (flush_i) begin
        ex_gl_index <= 'h0;
        ex_reg <= 1'b0;
    end else begin
        if ((translated_instr.ex.valid == 1'b1) && (translated_instr.instr.instr_type == VLEFF) && (translated_instr.velem_id != 'h0)) begin
            ex_gl_index <= translated_instr.gl_index;
            ex_reg <= 1'b1;
        end else if ((translated_instr.instr.valid == 1'b1) && (translated_instr.gl_index != ex_gl_index)) begin
            ex_gl_index <= 'h0;
            ex_reg <= 1'b0;
        end
    end
end

always_ff @(posedge clk_i)
begin
    // Write tail
    if (write_enable) begin
        control_table[tail] <= (translate_enable & translate_incoming) ? translated_instr : instruction_i;
    end
    // Update entry to be translated
    if (translate_enable && ~translate_incoming && (num_to_translate > 0)) begin
        control_table[tlb_tail] <= translated_instr;
    end
end


always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= 3'h0;
        tail <= 3'b0;
        num_to_exe   <= 4'b0;
        num_to_translate <= 4'b0;
        tlb_tail <= 3'b0;
    end
    else if (flush_i) begin
        head <= 3'h0;
        tail <= 3'b0;
        num_to_exe   <= 4'b0;
        num_to_translate <= 4'b0;
        tlb_tail <= 3'b0;
    end
    else begin
        head <= trunc_lsq_ptr_sum(head + {2'b00, read_enable_lsq});
        tail <= trunc_lsq_ptr_sum(tail + {2'b00, write_enable});
        `ifdef SARG_BYPASS_LSQ
            num_to_translate <= trunc_lsq_num_sum(num_to_translate + {3'b0, write_enable} - {3'b0, translate_enable & ((translate_incoming & (~bypass_lsq | (bypass_lsq & ~read_next_i))) || (num_to_translate > 0))});
            num_to_exe      <= trunc_lsq_num_sum(num_to_exe + {3'b0, translate_enable & ((translate_incoming & ((~bypass_lsq) | (bypass_lsq & (~read_next_i)))) || (num_to_translate > 0))} - {3'b0, read_enable_lsq});
            tlb_tail <= trunc_lsq_ptr_sum(tlb_tail + {2'b00, (translate_enable & ((translate_incoming & (~bypass_lsq | (bypass_lsq & ~read_next_i))) || (num_to_translate > 0)))});
        `else
            num_to_translate <= trunc_lsq_num_sum(num_to_translate + {3'b0, write_enable} - {3'b0, translate_enable & (translate_incoming || (num_to_translate > 0))});
            num_to_exe      <= trunc_lsq_num_sum(num_to_exe + {3'b0, translate_enable & (translate_incoming || (num_to_translate > 0))} - {3'b0, read_enable_lsq});
            tlb_tail <= trunc_lsq_ptr_sum(tlb_tail + {2'b00, (translate_enable & (translate_incoming || (num_to_translate > 0)))});
        `endif
    end
end

assign rob_store_gl_idx_next = trunc_gl_ptr_sum(rob_store_gl_idx_i + 1'b1);

always_comb begin
    read_enable_lsq = 1'b0;
    read_enable_sb = 1'b0;
    sb_write_enable = 1'b0;
    if (read_enable && is_next_load && !st_buff_collision && !io_address_space) begin // Load inside LSQ
        read_enable_lsq = 1'b1;
    end else if (read_enable && rob_store_ack_i && !st_buff_empty && ((st_buff_inst_out.gl_index == rob_store_gl_idx_i) || (st_buff_inst_out.gl_index == rob_store_gl_idx_next))) begin // Store inside SB
        read_enable_sb = 1'b1;
    end else if (read_enable && rob_store_ack_i && is_next_store && ((control_table[head].gl_index == rob_store_gl_idx_i) || (control_table[head].gl_index == rob_store_gl_idx_next))) begin // Store inside LSQ
        read_enable_lsq = 1'b1;
    end else if (read_enable && is_next_load && !st_buff_collision && io_address_space) begin // Load inside LSQ (IO)
        read_enable_lsq = 1'b1;
    end else if ((!read_enable || !rob_store_ack_i || ((control_table[head].gl_index != rob_store_gl_idx_i) && (control_table[head].gl_index != rob_store_gl_idx_next))) && is_next_store && !st_buff_full) begin
        sb_write_enable = 1'b1;
        read_enable_lsq = 1'b1;
    end
end 

always_comb begin
    next_instr_exe_o = 'h0;
    `ifdef SARG_BYPASS_LSQ
        if (bypass_lsq) begin
            next_instr_exe_o = translated_instr;
        end else if (is_next_load && !st_buff_collision && control_table[head].translated && !io_address_space) begin // Load inside LSQ
            next_instr_exe_o = control_table[head];
        end else if (rob_store_ack_i && !st_buff_empty && ((st_buff_inst_out.gl_index == rob_store_gl_idx_i) || (st_buff_inst_out.gl_index == rob_store_gl_idx_next))) begin // Store inside SB
            next_instr_exe_o = st_buff_inst_out;
        end else if ((rob_store_ack_i && is_next_store) && (((control_table[head].gl_index == rob_store_gl_idx_i) || (control_table[head].gl_index == rob_store_gl_idx_next)) & control_table[head].translated)) begin // Store inside LSQ
            next_instr_exe_o = control_table[head];
        end else if (is_next_load && !st_buff_collision && control_table[head].translated && io_address_space) begin // Load inside LSQ (IO)
            next_instr_exe_o = control_table[head];
        end
    `else
        if (is_next_load && !st_buff_collision && control_table[head].translated && !io_address_space) begin // Load inside LSQ
            next_instr_exe_o = control_table[head];
        end else if (rob_store_ack_i && !st_buff_empty && ((st_buff_inst_out.gl_index == rob_store_gl_idx_i) || (st_buff_inst_out.gl_index == rob_store_gl_idx_next))) begin // Store inside SB
            next_instr_exe_o = st_buff_inst_out;
        end else if ((rob_store_ack_i && is_next_store) && (((control_table[head].gl_index == rob_store_gl_idx_i) || (control_table[head].gl_index == rob_store_gl_idx_next)) & control_table[head].translated)) begin // Store inside LSQ
            next_instr_exe_o = control_table[head];
        end else if (is_next_load && !st_buff_collision && control_table[head].translated && io_address_space) begin // Load inside LSQ (IO)
            next_instr_exe_o = control_table[head];
        end
    `endif
end


// If the memory access is not using the virtualization and it is on the IO addr space, the io_address_space is 1.
assign io_address_space = is_inside_IO_sections(DracCfg, control_table[head].data_rs1);

always_comb begin
    blocked_store_o = 1'b1;
    `ifdef SARG_BYPASS_LSQ
        if (bypass_lsq) begin
            blocked_store_o = 1'b0;
        end else if (is_next_load && !st_buff_collision && !io_address_space) begin // Load inside LSQ
            blocked_store_o = 1'b0;
        end else if (!st_buff_empty && rob_store_ack_i && ((st_buff_inst_out.gl_index == rob_store_gl_idx_i) || (st_buff_inst_out.gl_index == rob_store_gl_idx_next))) begin // Store inside SB
            blocked_store_o = 1'b0;
        end else if (st_buff_empty && is_next_store && rob_store_ack_i && ((control_table[head].gl_index == rob_store_gl_idx_i) || (control_table[head].gl_index == rob_store_gl_idx_next))) begin // Store inside LSQ
            blocked_store_o = 1'b0;
        end else if (is_next_load && st_buff_empty && io_address_space) begin // Load inside LSQ (IO)
            blocked_store_o = 1'b0; 
        end
    `else
        if (is_next_load && !st_buff_collision && !io_address_space) begin // Load inside LSQ
            blocked_store_o = 1'b0;
        end else if (!st_buff_empty && rob_store_ack_i && ((st_buff_inst_out.gl_index == rob_store_gl_idx_i) || (st_buff_inst_out.gl_index == rob_store_gl_idx_next))) begin // Store inside SB
            blocked_store_o = 1'b0;
        end else if (st_buff_empty && is_next_store && rob_store_ack_i && ((control_table[head].gl_index == rob_store_gl_idx_i) || (control_table[head].gl_index == rob_store_gl_idx_next))) begin // Store inside LSQ
            blocked_store_o = 1'b0;
        end else if (is_next_load && st_buff_empty && io_address_space) begin // Load inside LSQ (IO)
            blocked_store_o = 1'b0; 
        end
    `endif
end

assign dtlb_comm_o.vm_enable = en_ld_st_translation_i;
assign dtlb_comm_o.priv_lvl = priv_lvl_i;
assign dtlb_comm_o.req.valid = (num_to_translate > 0) || translate_incoming;
assign dtlb_comm_o.req.vpn = instr_to_translate.data_rs1[PHY_VIRT_MAX_ADDR_SIZE-1:12];
assign dtlb_comm_o.req.passthrough = 1'b0;
assign dtlb_comm_o.req.instruction = 1'b0;
assign dtlb_comm_o.req.asid = '0;
assign dtlb_comm_o.req.store = instr_to_translate.is_amo_or_store; // TODO: Check this, might not be exactly right...

assign empty_int = (num_to_exe == '0) && st_buff_empty && (num_to_translate == '0);
`ifdef SARG_BYPASS_LSQ
    assign empty_o = empty_int && !bypass_lsq;
`else 
    assign empty_o = empty_int;
`endif
assign full_o  = (((num_to_exe + num_to_translate) == LSQ_NUM_ENTRIES) | flush_i | ~rstn_i);

assign is_next_load = (num_to_exe > '0) && (control_table[head].instr.mem_type == LOAD);

assign is_next_store = (num_to_exe > '0) && ((control_table[head].instr.mem_type == STORE)     || 
                                        (control_table[head].instr.mem_type == AMO));

assign pmu_load_after_store_o = st_buff_collision;


store_buffer store_buffer_inst(
    .clk_i(clk_i),  
    .rstn_i(rstn_i),
    .write_enable_i(sb_write_enable),
    .instruction_i(control_table[head]),
    .flush_i(flush_i),
    .advance_head_i(read_enable_sb),
    .load_addr_i(control_table[head].data_rs1),
    .load_size_i(control_table[head].instr.mem_size),
    .finish_instr_o(st_buff_inst_out),
    .empty_o(st_buff_empty),
    .full_o(st_buff_full),
    .collision_o(st_buff_collision)
);


endmodule

