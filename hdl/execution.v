`default_nettype none
`include "definitions.v"

/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : execution.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */


module execution (
    input wire         clk_i,
    input wire         rstn_i,
    // INPUTS
    input wire `ADDR   pc_i,
    input wire         valid_i,
    input wire `INST   inst_i,
    input wire [15:0]  control_i,
    input wire `DATA   src1_data_i,
    input wire `DATA   src2_data_i,
    input wire         xcpt_i,
    input wire `DATA   xcpt_cause_i,

    input wire `ADDR io_base_addr_i,

    // Response from cache
    input wire dmem_resp_bits_replay_i,
    input wire dmem_resp_bits_data_subw_i,
    input wire dmem_req_ready_i,
    input wire dmem_resp_valid_i,
    input wire dmem_resp_bits_nack_i,
    input wire dmem_xcpt_ma_st_i,
    input wire dmem_xcpt_ma_ld_i,
    input wire dmem_xcpt_pf_st_i,
    input wire dmem_xcpt_pf_ld_i,

    // OUTPUTS
    output `ADDR  pc_o,
    output        valid_o,
    output `INST  inst_o,
    output        write_enable_o,
    output `DATA  write_data_o,
    output [4:0]  write_reg_o,
    output        branch_o,
    output        xcpt_o,
    output `DATA  xcpt_cause_o,
    output        csr_o,
    output `DATA  csr_data_o,
    output `ADDR  addr_o,

    // Request to cache
    output wire dmem_req_valid_o,
    output wire dmem_op_type_o,
    output wire dmem_req_cmd_o,
    output wire dmem_req_bits_data_o,
    output wire dmem_req_bits_addr_o,
    output wire dmem_req_bits_tag_o,
    output wire dmem_req_invalidate_lr_o,
    output wire dmem_req_bits_kill_o,
    output wire dmem_lock_o
);

wire        predictor_hit;
wire        rr_exe_flush_p1;
wire        rr_exe_flush_p2;
wire        exception;
wire        pc_load_valid;
wire [4:0]  dst_field;
wire [6:0]  opcode;
wire [2:0]  funct3;
wire [6:0]  funct7;
wire [4:0]  rd_field;
wire        int_unit_valid;
wire        int_32;
wire        opcode_valid;
wire        immediate;
wire [11:0] imm12_int;
wire [19:0] imm20_int;
wire        jalr;
wire        jalr_valid;
wire        jal_valid;
wire `ADDR  jalr_target_addr;
wire [4:0]  src1_field;
wire [4:0]  src2_field;
wire `DATA  src1_data_bypass;
wire `DATA  src2_data_bypass;
wire        int1_ready;
wire `DATA  int1_result;
wire [4:0]  int1_write_addr;
wire        excepcion_invalid_inst;
wire excepcion_div_by_0;
wire excepcion_div_over;
wire        csr_enable;
wire        csr_eret;
reg `DATA xcpt_cause;
wire next_pc_missaligned;
wire dmem_xcpt_ma_st;
wire dmem_xcpt_ma_ld;
wire dmem_xcpt_pf_st;
wire dmem_xcpt_pf_ld;
wire xcpt;
wire wb_addr_to_bypass;
wire wb_we_to_bypass;
wire wb_data_to_bypass;
wire wb_xcpt;
wire lock_integer_unit;

// BRANCH UNIT
wire [11:0] imm12_branch;
wire `ADDR  branch_offset;
wire        branch;
wire        branch_taken;
wire `ADDR  branch_target;
wire `ADDR  branch_result;
wire        branch_valid;
wire        miss_prediction;

// MEMORY OPERATIONS LOAD/STore/amo 
wire        mem;
wire        amo;
wire [4:0]  amo_funct;
wire        load;
wire        store;
wire [11:0] imm12_load;
wire [11:0] imm12_store;
wire `ADDR  pc_load;
wire        load_ready;
wire `DATA  load_data;
wire [4:0]  load_write_addr;

assign mem = amo | store | load;

// Check exception priorities
always@(*) begin
    casex({xcpt_i,next_pc_missaligned,(dmem_xcpt_ma_st_i & mem),(dmem_xcpt_ma_ld_i & mem),(dmem_xcpt_pf_st_i & mem),(dmem_xcpt_pf_ld_i & mem)})
        6'b1xxxxx:    xcpt_cause = xcpt_cause_i;
        6'b01xxxx:    xcpt_cause = `misaligned_fetch;
        6'b001xxx:    xcpt_cause = `misaligned_store;
        6'b0001xx:    xcpt_cause = `misaligned_load;
        6'b00001x:    xcpt_cause = `fault_store;
        6'b000001:    xcpt_cause = `fault_load;
        default:      xcpt_cause = 64'b0;
    endcase
end
assign xcpt = xcpt_i | next_pc_missaligned | (dmem_xcpt_ma_st & mem) | (dmem_xcpt_ma_ld & mem) | (dmem_xcpt_pf_st & mem) | (dmem_xcpt_pf_ld & mem);

assign src1_field = inst_i[19:15];
assign src2_field = inst_i[24:20];

// Bypasses
assign src1_data_bypass = ((src1_field == wb_addr_to_bypass) & wb_we_to_bypass) ? wb_data_to_bypass : src1_data_i;
assign src2_data_bypass = ((src2_field == wb_addr_to_bypass) & wb_we_to_bypass) ? wb_data_to_bypass : src2_data_i;

assign opcode = inst_i[6:0];
assign funct3 = inst_i[14:12];
assign funct7 = inst_i[31:25];
assign dst_field = inst_i[11:7];

assign int_unit_valid = (control_i[0] | control_i[1]) & control_i[3] & ~control_i[5];
assign int_32 = control_i[9];
assign opcode_valid = control_i[10] & ~control_i[11];

assign jalr_valid = (control_i[0] & control_i[3] & control_i[5]) & (funct3 ==3'b000);
assign jal_valid = ~control_i[0] & control_i[3] & control_i[5] ;   

assign immediate = control_i[1] ;
assign imm12_int = inst_i[31:20];
assign imm20_int = inst_i[31:12];

integer_unit integer_unit(
    .clk_i                     (clk_i),
    .rstn_i                    (rstn_i),
    
    .wb_exception_i            (wb_xcpt),
    
    .pc_i                      (pc_i),
    .control_i                 (control_i),
    .inst_i                    (inst_i),
    
    .data_source_1_i           (src1_data_bypass),
    .data_source_2_i           (src2_data_bypass),
    
    .ready_o                   (int1_ready),
    .aluresult_o               (int1_result),
    .addr_write_o              (int1_write_addr),
    
    .lock_o                    (lock_integer_unit),
    
    .excepcion_illegal_inst_o  (excepcion_invalid_inst),
    .excepcion_div_by_0_o      (excepcion_div_by_0),
    .excepcion_div_over_o      (excepcion_div_over)
);

assign next_pc_missaligned = jalr & (jalr_target_addr[1:0] != 2'b00); 

assign imm12_branch = {inst_i[31],inst_i[7],inst_i[30:25],inst_i[11:8]};
assign branch_offset = {{27{imm12_branch[11]}},imm12_branch,1'b0}; 
assign branch = control_i[4] ;

branch_unit branch_unit(
    .pc_i                  (pc_i),
    .control_i             (control_i),
    .inst_i                (inst_i),

    .source1_i             (src1_data_bypass),
    .source2_i             (src2_data_bypass),

    .branch_valid_o        (branch_valid),
    .branch_taken_o        (branch_taken),
    .branch_target_o       (branch_target),
    .branch_result_o       (branch_result),

    .write_reg_o           (),
    .write_data_o          ()
);

assign miss_prediction = (branch && ~predictor_hit) ;

assign imm12_load = inst_i[31:20];
assign imm12_store = {inst_i[31:25],inst_i[11:7]};
assign load = control_i[2] & control_i[3];
assign store = control_i[2] & ~control_i[3];
assign amo = control_i[13];
assign amo_funct = inst_i[31:27];

mem_unit mem_unit_inst(
    .clk_i                                  (clk_i),
    .rstn_i                                 (rstn_i),
    .wb_exception_i                         (wb_xcpt),
    .csr_eret_i                             (csr_eret),

    .pc_i                                   (pc_i),
    .inst_i                                 (inst_i),
    .control_i                              (control_i),
    .source1_i                              (src1_data_bypass),
    .source2_i                              (src2_data_bypass),

    .io_base_addr_i                         (io_base_addr_i),

    // dcache answer
    .dmem_resp_bits_replay_i                (dmem_resp_bits_replay_i),
    .dmem_resp_bits_data_i                  (dmem_resp_bits_data_subw_i),
    .dmem_req_ready_i                       (dmem_req_ready_i),
    .dmem_resp_valid_i                      (dmem_resp_valid_i),
    .dmem_resp_bits_nack_i                  (dmem_resp_bits_nack_i),
    .dmem_xcpt_ma_st_i                      (dmem_xcpt_ma_st_i),
    .dmem_xcpt_ma_ld_i                      (dmem_xcpt_ma_ld_i),
    .dmem_xcpt_pf_st_i                      (dmem_xcpt_pf_st_i),
    .dmem_xcpt_pf_ld_i                      (dmem_xcpt_pf_ld_i),

    // output to wb
    .mem_pc_o                               (pc_load),
    .mem_ready_o                            (load_ready),
    .mem_data_o                             (load_data),
    .write_addr_o                           (load_write_addr),

    // request to dcache
    .mem_req_valid_o                        (dmem_req_valid_o),
    .mem_op_type_o                          (dmem_op_type_o),
    .mem_req_cmd_o                          (dmem_req_cmd_o),
    .mem_req_bits_data_o                    (dmem_req_bits_data_o),
    .mem_req_bits_addr_o                    (dmem_req_bits_addr_o),
    .mem_req_bits_tag_o                     (dmem_req_bits_tag_o),
    .mem_req_invalidate_lr_o                (dmem_req_invalidate_lr_o),
    .mem_req_bits_kill_o                    (dmem_req_bits_kill_o),
    .lock_o                                 (dmem_lock_o)
);

//---------------------------------------------------------------------------------------------------
// DATA  TO WRITE_BACK
//---------------------------------------------------------------------------------------------------
reg             we_exe;
reg `DATA       data_exe;
reg [4:0]       write_addr_exe;

assign csr_enable = control_i[12];

always@(*) begin
case({csr_enable,(load | amo),int1_ready})
    3'b010: begin
            we_exe   =  load_ready & (load_write_addr != 5'b00000);
            data_exe =  load_data;
            write_addr_exe =  load_write_addr;
            end
    3'b001: begin
            we_exe   =  int1_ready & (dst_field != 5'b00000);
            data_exe =  int1_result;
            write_addr_exe =  int1_write_addr;
            end
    3'b100: begin
            we_exe   =  (dst_field != 5'b00000);                                   //we to int-rf (the data is the given by csr)
            data_exe =  (funct3[2]) ? {28'b0,src1_field}:src1_data_bypass;  //dato to write in csr
            write_addr_exe =  dst_field;                                           //waddress for the data given by csr
            end
    default:begin
            we_exe   =  1'b0;
            data_exe =  64'b0;
            write_addr_exe =  5'b0;
            end
endcase
end

endmodule

