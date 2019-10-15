`default_nettype none
`include "definitions.v"

/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : mem_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */


module mem_unit (
    input  wire         clk_i,
    input  wire         rstn_i,
    input  wire         wb_exception_i,
    input  wire         csr_eret_i,

    input  wire `ADDR   pc_i,
    input  wire `INST   inst_i,
    input  wire [15:0]  control_i,
    input  wire `DATA   source1_i,                                    
    input  wire `DATA   source2_i,    

    input  wire `ADDR   io_base_addr_i,

    // DCACHE Answer
    input  wire         dmem_resp_bits_replay_i,
    input  wire `DATA   dmem_resp_bits_data_i,
    input  wire         dmem_req_ready_i,
    input  wire         dmem_resp_valid_i,
    input  wire         dmem_resp_bits_nack_i,
    input  wire         dmem_xcpt_ma_st_i,
    input  wire         dmem_xcpt_ma_ld_i,
    input  wire         dmem_xcpt_pf_st_i,
    input  wire         dmem_xcpt_pf_ld_i,

    // DCACHE Answer to WB
    output wire `ADDR   mem_pc_o,
    output wire         mem_ready_o,
    output wire `DATA   mem_data_o,
    output wire [4:0]   write_addr_o,

    // LOAD/STORE/AMO INTERFACE OUTPUTS TO DCACHE
    output reg          mem_req_valid_o,
    output wire `DATA   mem_op_type_o,
    output reg  [4:0]   mem_req_cmd_o,
    output reg  `DATA   mem_req_bits_data_o,
    output reg  `ADDR   mem_req_bits_addr_o,
    output wire [7:0]   mem_req_bits_tag_o,
    output wire         mem_req_invalidate_lr_o,
    output wire         mem_req_bits_kill_o,
    output reg          lock_o
);

// Declarations
wire load;
wire amo;
wire store;
wire dmem_xcpt;
wire [11:0] immediate_load;
wire [11:0] immediate_store;
wire [2:0] funct3_field;
wire [4:0] dst_field;
wire `ADDR imm_load;
wire `ADDR imm_store;
wire `ADDR store_addr;
wire `DATA store_data;
wire `ADDR load_addr;
wire mem_req_valid_aux;
wire io_address_space;
wire kill_io_resp;   
wire kill_mem_ope;
reg [1:0] state;
reg [1:0] next_state;
reg icache_miss;
wire kill_mem_ope_aux;
wire [4:0] amo_funct;

parameter req_valid  = 2'b00,
          resp_ready = 2'b01,
          resp_valid = 2'b10;


// Determine operation
assign load = control_i[2] & control_i[3];
assign amo = control_i[13];
assign store = control_i[2] & ~control_i[3];

//-------------------------------------------------------------
// CONTROL SIGNALS
//-------------------------------------------------------------
assign dmem_xcpt = dmem_xcpt_ma_st_i | dmem_xcpt_ma_ld_i | dmem_xcpt_pf_st_i | dmem_xcpt_pf_ld_i;
assign immediate_load = inst_i[31:20];
assign immediate_store = {inst_i[31:25],inst_i[11:7]};
assign funct3_field = inst_i[14:12];
assign dst_field = inst_i[11:7];
assign imm_load = {{28{immediate_load[11]}},immediate_load[11:0]} ;
assign imm_store = {{28{immediate_store[11]}},immediate_store[11:0]} ;
assign amo_funct = inst_i[31:27];

//-------------------------------------------------------------
// STORE
//-------------------------------------------------------------
assign store_addr = source1_i[39:0] + imm_store;
assign store_data = source2_i;

//-------------------------------------------------------------
// LOAD - 1st stage
//-------------------------------------------------------------
assign load_addr = source1_i[39:0] + imm_load;

assign mem_op_type_o = {1'b0,funct3_field};
assign mem_req_bits_data_o = amo ? source2_i : store ? store_data : load ? 64'b0 : 64'b0;
assign mem_req_bits_addr_o = amo ? source1_i[39:0] : store ? store_addr : load ? load_addr : `ZERO_ADDR;
assign mem_req_bits_tag_o = {2'b00,dst_field,1'b0}; //  bit 0 corresponde a int o fp
assign mem_req_invalidate_lr_o = wb_exception_i;
assign mem_req_bits_kill_o = dmem_xcpt | wb_exception_i | csr_eret_i  | (dmem_resp_bits_replay_i & mem_req_valid_aux);

always@(*) begin
    case({store,load,amo})
        3'b001: begin
            case(amo_funct)
                5'b00010:mem_req_cmd_o = 5'b00110; // lr
                5'b00011:mem_req_cmd_o = 5'b00111; // sc
                5'b00001:mem_req_cmd_o = 5'b00100; // amoswap
                5'b00000:mem_req_cmd_o = 5'b01000; // amoadd
                5'b00100:mem_req_cmd_o = 5'b01001; // amoxor                  
                5'b01100:mem_req_cmd_o = 5'b01011; // amoand                
                5'b01000:mem_req_cmd_o = 5'b01010; // amoor
                5'b10000:mem_req_cmd_o = 5'b01100; // amomin
                5'b10100:mem_req_cmd_o = 5'b01101; // amomax
                5'b11000:mem_req_cmd_o = 5'b01110; // amominu
                5'b11100:mem_req_cmd_o = 5'b01111; // amomaxu                 
                default: mem_req_cmd_o = 5'b00000;
            endcase
        end
        3'b010: mem_req_cmd_o = 5'b00000;
        3'b100: mem_req_cmd_o = 5'b00001;
        default: mem_req_cmd_o = 5'b00000;  
    endcase
end

assign mem_req_valid_aux = store |  load | amo ;
assign io_address_space = ((mem_req_bits_addr_o >= io_base_addr_i) & (mem_req_bits_addr_o <= 40'h80020053)) ? 1'b1 : 1'b0;
assign kill_io_resp =  io_address_space & store;
assign kill_mem_ope = dmem_xcpt | wb_exception_i | csr_eret_i;

always@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
        state <= 2'b00;
    else
        state <= next_state;
end

assign kill_mem_ope_aux = wb_exception_i | csr_eret_i;

always@(*) begin
    case (state)
        req_valid: begin
            mem_req_valid_o = kill_mem_ope_aux ? 1'b0: mem_req_valid_aux & dmem_req_ready_i;
            next_state = kill_mem_ope_aux ? req_valid : (mem_req_valid_o) ?  resp_ready : req_valid;
            lock_o = kill_mem_ope_aux ? 1'b0: (mem_req_valid_aux) ? 1'b1 : 1'b0;
        end
        resp_ready: begin
            if(dmem_resp_valid_i & dmem_req_ready_i) begin // case: io response uart
                mem_req_valid_o = 1'b0;
                next_state = req_valid;
                lock_o = 1'b0;
            end else begin
                mem_req_valid_o = 1'b0;
                next_state = kill_mem_ope ? req_valid : dmem_req_ready_i ? resp_valid : req_valid;
                lock_o = kill_mem_ope ? 1'b0 : 1'b1;
            end
        end
        resp_valid: begin
            if(dmem_resp_valid_i) begin
                mem_req_valid_o = 1'b0;
                next_state = req_valid;
                lock_o = 1'b0;
            end else if(dmem_resp_bits_nack_i) begin
                mem_req_valid_o = 1'b0;
                next_state = req_valid;
                lock_o = 1'b1;
            end else begin
                mem_req_valid_o = 1'b0;
                next_state = (kill_mem_ope | kill_io_resp) ? req_valid : resp_valid;
                lock_o = (kill_mem_ope | kill_io_resp) ? 1'b0: 1'b1;
            end
        end
        default: begin
            mem_req_valid_o = 1'b0;
            next_state = req_valid;
            lock_o = 1'b0;
        end
    endcase
end

// Outputs
assign mem_pc_o     = pc_i;
assign mem_ready_o  = dmem_resp_valid_i & (load | amo);
assign mem_data_o   = dmem_resp_bits_data_i;
assign write_addr_o = dst_field;

endmodule
`default_nettype wire

