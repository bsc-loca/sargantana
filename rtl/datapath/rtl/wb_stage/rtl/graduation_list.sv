/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : graduation_list.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 */

module graduation_list 
    import drac_pkg::*;
    #(
        // How many different instructions can the GL keep. Must be multiple of 2.
        parameter unsigned NUM_ENTRIES  = 32
    )
    (
    input wire                                 clk_i,                             // Clock Singal
    input wire                                 rstn_i,                            // Negated Reset Signal

    // Input Signals of instruction from Read R
    input gl_instruction_t                     instruction_i,
    input logic                                is_csr_i,
    input logic                                is_vector_vl_0_i,
    input reg_csr_addr_t                       csr_addr_i,
    input exception_t                          ex_i,

    // Read Entry Interface
    input logic [1:0]                          read_head_i,                       // Read oldest instruction

    // Write Back Interface
    input gl_index_t       [NUM_SCALAR_WB-1:0] instruction_writeback_i,           // Mark instruction as finished
    input logic            [NUM_SCALAR_WB-1:0] instruction_writeback_enable_i,    // Write enabled for finished
    input gl_wb_data_t     [NUM_SCALAR_WB-1:0] instruction_writeback_data_i,      // Data of the generated exception

    input gl_index_t       [NUM_SIMD_WB-1:0] instruction_simd_writeback_i,        // Mark instruction as finished
    input logic            [NUM_SIMD_WB-1:0] instruction_simd_writeback_enable_i, // Write enabled for finished
    input gl_wb_data_t     [NUM_SIMD_WB-1:0] instruction_simd_writeback_data_i,   // Data of the generated exception
    input gl_index_t       [drac_pkg::NUM_FP_WB-1:0] instruction_fp_writeback_i,        // Mark instruction as finished
    input logic            [drac_pkg::NUM_FP_WB-1:0] instruction_fp_writeback_enable_i, // Write enabled for finished
    input gl_wb_data_t     [drac_pkg::NUM_FP_WB-1:0] instruction_fp_writeback_data_i,   // Data of the generated exception
    input exception_t                          ex_from_exe_i,
    input gl_index_t                           ex_from_exe_index_i, 

    input wire                                 flush_i,                           // Flush instructions from the graduation list
    input gl_index_t                           flush_index_i,                     // Index that selects the first correct instruction

    input wire                                 flush_commit_i,                    // Flush all instructions

    // Output Signal of instruction to Read Register 
    output gl_index_t                          assigned_gl_entry_o,

    // Output Signal of first finished instruction
    output gl_instruction_t [1:0]              instruction_o,
    output gl_index_t                          commit_gl_entry_o,

    // Output Control Signals 
    output logic                               full_o,                            // GL has no free entries
    output logic                               empty_o,                           // GL has no filled entries
    output reg_csr_addr_t                      csr_addr_o,                        // CSR Address
    output exception_t                         exception_o,                       // Exceptions
    output bus64_t                             result_o,                          // Result used by the CSR instructions
    output csr_addr_t                          vsetvl_vtype_o                     // Vtype for VSETVL
);


localparam NUM_BITS_INDEX = $clog2(NUM_ENTRIES);

gl_index_t head;
gl_index_t head_puls_one;
gl_index_t tail;

function [NUM_BITS_INDEX:0] trunc_gl_num_sum(input [NUM_BITS_INDEX+1:0] val_in);
  trunc_gl_num_sum = val_in[NUM_BITS_INDEX:0];
endfunction

function [NUM_BITS_INDEX-1:0] trunc_gl_ptr_sum(input [NUM_BITS_INDEX:0] val_in);
  trunc_gl_ptr_sum = val_in[NUM_BITS_INDEX-1:0];
endfunction

//Num must be 1 bit bigger than head and tail
logic [NUM_BITS_INDEX:0] num;

logic write_enable;
logic [1:0] read_enable;

logic is_store_or_amo;

// Register for valid bit
logic [NUM_ENTRIES-1:0] valid_bit_q, valid_bit_d;

// Unic entries

reg_csr_addr_t  csr_addr_q, csr_addr_d;               // CSR Address
exception_t     exception_q, exception_d;             // Exceptions
gl_index_t      exception_index_q, exception_index_d;
bus64_t         result_q, result_d;                   // Result or immediate
csr_addr_t      vsetvl_vtype_q, vsetvl_vtype_d;       // Vtype for VSETVL


// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.valid & (num < (NUM_ENTRIES-1)) & ~(flush_i) & (~flush_commit_i); 

// User can read the head of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = {1'b0,read_head_i[1]} + {1'b0,read_head_i[0]}; // & (num > 0) & (valid_bit[head]) & ~(flush_i) & (~flush_commit_i);


assign is_store_or_amo = (instruction_i.mem_type == STORE) || (instruction_i.mem_type == AMO) || 
                         (instruction_i.instr_type == VSSE) || (instruction_i.instr_type == VSXE);

gl_instruction_t [NUM_ENTRIES-1:0] entries_q;
gl_instruction_t [NUM_ENTRIES-1:0] entries_d;

always_comb begin
    for(int i = 0; i < NUM_ENTRIES ; i = i + 1) begin
        valid_bit_d[i] = valid_bit_q[i];
        entries_d[i] = entries_q[i];
    end

    if (write_enable) begin
        valid_bit_d[tail] = is_store_or_amo | instruction_i.ex_valid | is_vector_vl_0_i;
        entries_d[tail] = instruction_i;
    end

    for (int i = 0; i < NUM_SCALAR_WB; ++i) begin
        if (instruction_writeback_enable_i[i]) begin
            valid_bit_d[instruction_writeback_i[i]] = 1'b1;
            entries_d[instruction_writeback_i[i]].fp_status = instruction_writeback_data_i[i].fp_status;
            `ifdef SIM_COMMIT_LOG
                entries_d[instruction_writeback_i[i]].csr_addr  = instruction_writeback_data_i[i].csr_addr;
                entries_d[instruction_writeback_i[i]].exception = instruction_writeback_data_i[i].exception;
                entries_d[instruction_writeback_i[i]].result    = instruction_writeback_data_i[i].result;
                entries_d[instruction_writeback_i[i]].addr      = instruction_writeback_data_i[i].addr;
            `endif
            entries_d[instruction_writeback_i[i]].ex_valid  = instruction_writeback_data_i[i].exception.valid | entries_q[instruction_writeback_i[i]].ex_valid;
        end
    end

    for (int i = 0; i < NUM_SIMD_WB; ++i) begin
        if (instruction_simd_writeback_enable_i[i]) begin
            valid_bit_d[instruction_simd_writeback_i[i]] = 1'b1;
            entries_d[instruction_simd_writeback_i[i]].vs_ovf  = instruction_simd_writeback_data_i[i].vs_ovf;
            `ifdef SIM_COMMIT_LOG
                entries_d[instruction_simd_writeback_i[i]].csr_addr  = instruction_simd_writeback_data_i[i].csr_addr;
                entries_d[instruction_simd_writeback_i[i]].exception = instruction_simd_writeback_data_i[i].exception;
                entries_d[instruction_simd_writeback_i[i]].result    = instruction_simd_writeback_data_i[i].result;
                entries_d[instruction_simd_writeback_i[i]].addr    = instruction_simd_writeback_data_i[i].addr;
            `endif
            entries_d[instruction_simd_writeback_i[i]].ex_valid  = instruction_simd_writeback_data_i[i].exception.valid | entries_q[instruction_simd_writeback_i[i]].ex_valid;
        end
    end
    
    for (int i = 0; i < drac_pkg::NUM_FP_WB; ++i) begin
        if (instruction_fp_writeback_enable_i[i]) begin
            valid_bit_d[instruction_fp_writeback_i[i]] = 1'b1;
            entries_d[instruction_fp_writeback_i[i]].fp_status = instruction_fp_writeback_data_i[i].fp_status;
            `ifdef SIM_COMMIT_LOG
                entries_d[instruction_fp_writeback_i[i]].csr_addr  = instruction_fp_writeback_data_i[i].csr_addr;
                entries_d[instruction_fp_writeback_i[i]].exception = instruction_fp_writeback_data_i[i].exception;
                entries_d[instruction_fp_writeback_i[i]].result    = instruction_fp_writeback_data_i[i].result;
                entries_d[instruction_fp_writeback_i[i]].addr    = instruction_fp_writeback_data_i[i].addr;
            `endif
            entries_d[instruction_fp_writeback_i[i]].ex_valid  = instruction_fp_writeback_data_i[i].exception.valid | entries_q[instruction_fp_writeback_i[i]].ex_valid;
        end
    end

    // Update the exception information

    if (!flush_commit_i && ex_from_exe_i.valid && !exception_q.valid) begin
        exception_d = ex_from_exe_i;
        exception_index_d = ex_from_exe_index_i;   
    end else if (!flush_commit_i && ex_from_exe_i.valid && exception_q.valid && (
        ((ex_from_exe_index_i >= head) && (ex_from_exe_index_i < exception_index_q) && (head < exception_index_q)) ||
        ((ex_from_exe_index_i >= head) && (ex_from_exe_index_i > exception_index_q) && (head > exception_index_q)) ||
        ((ex_from_exe_index_i < head) && (ex_from_exe_index_i < exception_index_q) && (head > exception_index_q)))) begin
        exception_d = ex_from_exe_i;
        exception_index_d = ex_from_exe_index_i;   
    end else if (flush_commit_i || (flush_i && exception_q.valid && (
        ((flush_index_i >= head) && (flush_index_i < exception_index_q) && (head < exception_index_q)) ||
        ((flush_index_i >= head) && (flush_index_i > exception_index_q) && (head > exception_index_q)) ||
        ((flush_index_i < head) && (flush_index_i < exception_index_q) && (head > exception_index_q))))) begin
        exception_d = '0;
        exception_index_d = '0;
    end else if (write_enable && instruction_i.ex_valid && !exception_q.valid && !ex_from_exe_i.valid) begin
        exception_d = ex_i;
        exception_index_d = tail;
    end else begin
        exception_d = exception_q;
        exception_index_d = exception_index_q;
    end 


    if (instruction_writeback_enable_i[0]) begin
        result_d = instruction_writeback_data_i[0].result[63:0];
        vsetvl_vtype_d = instruction_writeback_data_i[0].csr_addr[CSR_ADDR_SIZE-1:0];
    end else begin
        result_d = result_q;
        vsetvl_vtype_d = vsetvl_vtype_q;
    end

    if(write_enable && is_csr_i)begin
        csr_addr_d = csr_addr_i;
    end else begin
        csr_addr_d = csr_addr_q;
    end
end

always_ff @(posedge clk_i, negedge rstn_i)
begin 
    if (~rstn_i) begin
        for(int i = 0; i < NUM_ENTRIES ; i = i + 1) begin
            valid_bit_q[i] <= 1'b0;
            entries_q[i] <= '0;
        end
        exception_index_q <= '0;
        exception_q <= '0;
        csr_addr_q <= '0;
        result_q <= '0;
        vsetvl_vtype_q <= '0;
    end else begin
        for(int i = 0; i < NUM_ENTRIES ; i = i + 1) begin
            valid_bit_q[i] <= valid_bit_d[i];
            entries_q[i] <= entries_d[i];
        end
        exception_index_q <= exception_index_d;
        exception_q <= exception_d;
        csr_addr_q <= csr_addr_d;
        result_q <= result_d;
        vsetvl_vtype_q <= vsetvl_vtype_d;
    end
end

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= {NUM_BITS_INDEX{1'b0}};
        tail <= {NUM_BITS_INDEX{1'b0}};
        num  <= {(NUM_BITS_INDEX+1){1'b0}};
    end else if (flush_commit_i) begin
        head <= {NUM_BITS_INDEX{1'b0}};
        tail <= {NUM_BITS_INDEX{1'b0}};
        num  <= {(NUM_BITS_INDEX+1){1'b0}};
    end else if (flush_i & (num > 0)) begin
        tail <= trunc_gl_ptr_sum(flush_index_i + {{NUM_BITS_INDEX-1{1'b0}}, 1'b1}); 
        head <= trunc_gl_ptr_sum(head + {{NUM_BITS_INDEX-2{1'b0}}, read_enable});
        if (((flush_index_i + {{NUM_BITS_INDEX-1{1'b0}}, 1'b1}) >= (head + {{NUM_BITS_INDEX-2{1'b0}}, read_enable})) && (num != (NUM_BITS_INDEX+1)'(NUM_ENTRIES))) begin   // Recompute number of entries
            num <= {1'b0, (flush_index_i + {{NUM_BITS_INDEX-1{1'b0}}, 1'b1})} - {1'b0 , (head + {{NUM_BITS_INDEX-2{1'b0}}, read_enable} )};
        end else begin
            num <= NUM_ENTRIES[NUM_BITS_INDEX:0] - {1'b0, (head + {{NUM_BITS_INDEX-2{1'b0}}, read_enable})} +  {1'b0, (flush_index_i + {{NUM_BITS_INDEX-1{1'b0}}, 1'b1})};
        end
    end else begin
        tail <= trunc_gl_ptr_sum(tail + {{NUM_BITS_INDEX-1{1'b0}}, write_enable});
        head <= trunc_gl_ptr_sum(head + {{NUM_BITS_INDEX-2{1'b0}}, read_enable});
        num  <= trunc_gl_num_sum(num + {{NUM_BITS_INDEX-1{1'b0}}, write_enable} - {{NUM_BITS_INDEX-2{1'b0}}, read_enable});
    end
end

always_comb begin
    instruction_o[0] = 'b0;
    instruction_o[1] = 'b0;
    commit_gl_entry_o = head;
    head_puls_one = trunc_gl_ptr_sum(head + 1);

    if ((~flush_commit_i)) begin
        if (((num == 1) & valid_bit_q[head]) || ((num > 1) & valid_bit_q[head] & !valid_bit_q[head_puls_one])) begin // Imposible case
            instruction_o[0] = entries_q[head];
        end else if ((num > 1) & valid_bit_q[head] & valid_bit_q[head_puls_one]) begin
            instruction_o[0] = entries_q[head];
            instruction_o[1] = entries_q[head_puls_one];
        end
    end
end

assign assigned_gl_entry_o = tail;
assign empty_o = (num == 0);
assign full_o  = (num == (NUM_BITS_INDEX+1)'(NUM_ENTRIES-1));
assign result_o = result_q;
assign exception_o = exception_q;
assign csr_addr_o = csr_addr_q;
assign vsetvl_vtype_o = vsetvl_vtype_q;

endmodule
