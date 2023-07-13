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
    import drac_pkg::*, mmu_pkg::*, riscv_pkg::*;
(
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
logic [$clog2(LSQ_NUM_ENTRIES):0] num;
logic [$clog2(LSQ_NUM_ENTRIES):0] num_to_exe;
logic [$clog2(LSQ_NUM_ENTRIES):0] num_to_translate;

// Internal Control Signals
logic write_enable;
logic read_enable;
logic read_enable_lsq;
logic read_enable_sb;
logic bypass_lsq;
logic empty_int;
logic translate_enable;
logic translate_incoming;

logic io_address_space;

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num_to_exe < LSQ_NUM_ENTRIES) & !(empty_int && instruction_i.instr.mem_type == LOAD && read_enable);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
//assign read_enable = read_next_i & (!empty_int || (empty_int && instruction_i.instr.valid && instruction_i.instr.mem_type == LOAD));
assign read_enable = read_next_i & !empty_int;

//assign bypass_lsq = empty_int && instruction_i.instr.valid && (instruction_i.instr.mem_type == LOAD);
assign bypass_lsq = 1'b0;

// We can translate the incoming instruction if there are no instructions to translate in the queue
assign translate_incoming = write_enable & num_to_translate == '0;

rr_exe_mem_instr_t instr_to_translate;
assign instr_to_translate = translate_incoming ? instruction_i : control_table[tlb_tail];

// A translation can be done if there is a hit in the dTLB
assign translate_enable = dtlb_comm_i.tlb_ready & !dtlb_comm_i.resp.miss & instr_to_translate.instr.valid;

rr_exe_mem_instr_t translated_instr;

always_comb begin 
    translated_instr = instr_to_translate;

    // Translation from TLB
    translated_instr.translated = translate_enable;
    translated_instr.data_rs1 = {dtlb_comm_i.resp.ppn, instr_to_translate.data_rs1[11:0]};
    
    // Exception treatment
    if ((instr_to_translate.instr.mem_size == 4'b0001 & |instr_to_translate.data_rs1[0:0]) |
        (instr_to_translate.instr.mem_size == 4'b0010 & |instr_to_translate.data_rs1[1:0]) |
        (instr_to_translate.instr.mem_size == 4'b0011 & |instr_to_translate.data_rs1[2:0]) |
        (instr_to_translate.instr.mem_size == 4'b0101 & |instr_to_translate.data_rs1[0:0]) |
        (instr_to_translate.instr.mem_size == 4'b0110 & |instr_to_translate.data_rs1[1:0]) |
        (instr_to_translate.instr.mem_size == 4'b0111 & |instr_to_translate.data_rs1[2:0])) begin // Misaligned address
        translated_instr.ex.cause       = instr_to_translate.is_amo_or_store ? ST_AMO_ADDR_MISALIGNED : LD_ADDR_MISALIGNED;
        translated_instr.ex.origin      = instr_to_translate.data_rs1;
        translated_instr.ex.valid       = 1'b1;
    end else if (dtlb_comm_i.resp.xcpt.store & instr_to_translate.is_amo_or_store) begin // Page fault store
        translated_instr.ex.cause       = ST_AMO_PAGE_FAULT;
        translated_instr.ex.origin      = instr_to_translate.data_rs1;
        translated_instr.ex.valid       = 1'b1;
    end else if (dtlb_comm_i.resp.xcpt.load) begin // Page fault load
        translated_instr.ex.cause       = LD_PAGE_FAULT;
        translated_instr.ex.origin      = instr_to_translate.data_rs1;
        translated_instr.ex.valid       = 1'b1;
    end else if ((en_ld_st_translation_i && (instr_to_translate.data_rs1[38] ? !(&instr_to_translate.data_rs1[63:39]) : |instr_to_translate.data_rs1[63:39]) ||
                  ~en_ld_st_translation_i && (( instr_to_translate.data_rs1 >= UNMAPPED_ADDR_LOWER 
                                             && instr_to_translate.data_rs1 < UNMAPPED_ADDR_UPPER )
                                             || instr_to_translate.data_rs1 >= PHISIC_MEM_LIMIT))) begin // invalid address

        translated_instr.ex.cause  = instr_to_translate.is_amo_or_store ? ST_AMO_ACCESS_FAULT : LD_ACCESS_FAULT;
        translated_instr.ex.origin = instr_to_translate.data_rs1;
        translated_instr.ex.valid  = 1'b1;
    end
end

// FIFO Memory structure
rr_exe_mem_instr_t control_table[0:LSQ_NUM_ENTRIES-1];

always_ff @(posedge clk_i)
begin
    // Write tail
    if (write_enable) begin
        control_table[tail] <= (translate_enable & translate_incoming) ? translated_instr : instruction_i;
    end
    // Update entry to be translated
    if (translate_enable & ~translate_incoming && (num_to_translate > 0)) begin
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
        head <= head + {2'b00, read_enable_lsq};
        tail <= tail + {2'b00, write_enable};
        num_to_translate <= num_to_translate + {3'b0, write_enable} - {3'b0, translate_enable & (translate_incoming || num_to_translate > 0)};
        num_to_exe      <= num_to_exe + {3'b0, translate_enable & (translate_incoming || num_to_translate > 0)} - {3'b0, read_enable_lsq};
        tlb_tail <= tlb_tail + {2'b00, translate_enable & (translate_incoming || num_to_translate > 0)};
    end
end

always_comb begin
    read_enable_lsq = 1'b0;
    read_enable_sb = 1'b0;
    sb_write_enable = 1'b0;
    if (read_enable && rob_store_ack_i && !st_buff_empty && st_buff_inst_out.gl_index == rob_store_gl_idx_i) begin
        read_enable_sb = 1'b1;
    end else if (read_enable && rob_store_ack_i && is_next_store && control_table[head].gl_index == rob_store_gl_idx_i) begin
        read_enable_lsq = 1'b1;
    end else if (read_enable && is_next_load && !st_buff_collision) begin
        read_enable_lsq = 1'b1;
    end else if ((!read_enable || !rob_store_ack_i || control_table[head].gl_index != rob_store_gl_idx_i) && is_next_store && !st_buff_full) begin
        sb_write_enable = 1'b1;
        read_enable_lsq = 1'b1;
    end
end 

always_comb begin
    next_instr_exe_o = 'h0;
    if (rob_store_ack_i && !st_buff_empty && st_buff_inst_out.gl_index == rob_store_gl_idx_i) begin
        next_instr_exe_o = st_buff_inst_out;
    end else if (rob_store_ack_i && is_next_store && control_table[head].gl_index == rob_store_gl_idx_i & control_table[head].translated) begin
        next_instr_exe_o = control_table[head];
    end else if (is_next_load && !st_buff_collision & control_table[head].translated) begin
        next_instr_exe_o = control_table[head];
    end else if (bypass_lsq) begin
        next_instr_exe_o = instruction_i;
    end
end

// If the memory access is not using the virtualization and it is on the IO addr space, the io_address_space is 1.
assign io_address_space = (control_table[head].data_rs1 >= 40'h40000000) && (control_table[head].data_rs1 < 40'h80000000) && !en_ld_st_translation_i;

always_comb begin
    blocked_store_o = 1'b1;
    if (!st_buff_empty && rob_store_ack_i && (st_buff_inst_out.gl_index == rob_store_gl_idx_i)) begin
        blocked_store_o = 1'b0;
    end else if (st_buff_empty && is_next_store && rob_store_ack_i && (control_table[head].gl_index == rob_store_gl_idx_i)) begin
        blocked_store_o = 1'b0;
    end else if (is_next_load && !st_buff_empty && io_address_space) begin 
        // If the memory access is IO should not advance any store
        blocked_store_o = 1'b1;
    end else if (is_next_load && !st_buff_collision) begin
        blocked_store_o = 1'b0;
    end else if (bypass_lsq) begin
        blocked_store_o = 1'b0;
    end
end

assign dtlb_comm_o.vm_enable = en_ld_st_translation_i;
assign dtlb_comm_o.priv_lvl = priv_lvl_i;
assign dtlb_comm_o.req.valid = num_to_translate > 0 || translate_incoming;
assign dtlb_comm_o.req.vpn = instr_to_translate.data_rs1[63:12];
assign dtlb_comm_o.req.passthrough = 1'b0;
assign dtlb_comm_o.req.instruction = 1'b0;
assign dtlb_comm_o.req.asid = '0;
assign dtlb_comm_o.req.store = instr_to_translate.is_amo_or_store; // TODO: Check this, might not be exactly right...

assign empty_int = num_to_exe == '0 && st_buff_empty && num_to_translate == '0;
assign empty_o = empty_int && !bypass_lsq;
assign full_o  = (((num_to_exe + num_to_translate) == LSQ_NUM_ENTRIES) | flush_i | ~rstn_i);

assign is_next_load = num_to_exe > '0 && (control_table[head].instr.mem_type == LOAD);

assign is_next_store = num_to_exe > '0 && (control_table[head].instr.mem_type == STORE     || 
                                        control_table[head].instr.mem_type == AMO);

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

