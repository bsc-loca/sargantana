//`default_nettype none
import drac_pkg::*;

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

    input logic         valid_i,
    input logic         kill_i,
    input logic         csr_eret_i,
    input bus64_t       data_rs1_i,
    input bus64_t       data_rs2_i,
    input mem_op_t      mem_op_i,
    input mem_format_t  mem_format_i,
    input amo_op_t      amo_op_i,
    input logic [2:0]   funct3_i,
    input reg_t         rd_i,
    input bus64_t       imm_i,

    input  addr_t       io_base_addr_i,

    // DCACHE Answer
    input  logic         dmem_resp_replay_i,
    // data read from memory
    input  bus64_t       dmem_resp_data_i,
    // dcache ready to recieve a request
    input  logic         dmem_req_ready_i,
    // dcache responded
    input  logic         dmem_resp_valid_i,
    input  logic         dmem_resp_nack_i,
    input  logic         dmem_xcpt_ma_st_i,
    input  logic         dmem_xcpt_ma_ld_i,
    input  logic         dmem_xcpt_pf_st_i,
    input  logic         dmem_xcpt_pf_ld_i,

    // LOAD/STORE/AMO INTERFACE OUTPUTS TO DCACHE

    // Sending a valid request
    output logic        dmem_req_valid_o,
    // Command to dcache
    output logic [4:0]  dmem_req_cmd_o,
    // Address request
    output addr_t       dmem_req_addr_o,
    // Byte, half word ...
    output bus64_t      dmem_op_type_o,
    // Data to store
    output bus64_t      dmem_req_data_o,
    output logic [7:0]  dmem_req_tag_o,
    output logic        dmem_req_invalidate_lr_o,
    output logic        dmem_req_kill_o,

    // DCACHE Answer to WB
    output logic        ready_o,
    output bus64_t      data_o,
    output logic        lock_o
);

// Declarations
logic mem_xcpt;
logic io_address_space;
logic kill_io_resp;   
logic kill_mem_ope;
logic [1:0] state;
logic [1:0] next_state;

parameter ResetState  = 2'b00,
          Idle = 2'b01,
          MakeRequest = 2'b10,
          WaitResponse = 2'b11;


//-------------------------------------------------------------
// CONTROL SIGNALS
//-------------------------------------------------------------
assign mem_xcpt = dmem_xcpt_ma_st_i | dmem_xcpt_ma_ld_i | dmem_xcpt_pf_st_i | dmem_xcpt_pf_ld_i;

assign io_address_space = (dmem_req_addr_o >= io_base_addr_i) & (dmem_req_addr_o <= 40'h80020053);
assign kill_io_resp =  io_address_space & (mem_op_i == MEM_STORE);
assign kill_mem_ope = mem_xcpt | kill_i;

always@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
        state = ResetState;
    else
        state = next_state;
end


always_comb begin
    case(state)
        ResetState: begin
            dmem_req_valid_o = 1'b0;
            lock_o = 1'b0;
            next_state = Idle;
        end
        Idle: begin
            dmem_req_valid_o = !kill_i & valid_i & dmem_req_ready_i;
            lock_o = !kill_i & valid_i;
            next_state = dmem_req_valid_o ?  MakeRequest : Idle;
        end
        MakeRequest: begin
            if(dmem_resp_valid_i & dmem_req_ready_i) begin // case: io response uart
                dmem_req_valid_o = 1'b0;
                lock_o = 1'b0;
                next_state = Idle;
            end else begin
                dmem_req_valid_o = 1'b0;
                lock_o = !kill_i;
                next_state = (!kill_i & dmem_req_ready_i) ? WaitResponse : Idle;
            end
        end
        WaitResponse: begin
            if(dmem_resp_valid_i) begin
                dmem_req_valid_o = 1'b0;
                next_state = Idle;
                lock_o = 1'b0;
            end else if(dmem_resp_nack_i) begin
                dmem_req_valid_o = 1'b0;
                next_state = Idle;
                lock_o = 1'b1;
            end else begin
                dmem_req_valid_o = 1'b0;
                next_state = (kill_mem_ope | kill_io_resp) ? Idle : WaitResponse;
                lock_o = !(kill_mem_ope || kill_io_resp);
            end
        end
        default: next_state = ResetState;
    endcase
end

always_comb begin
    case(mem_op_i)
        MEM_AMO: begin
            case(amo_op_i)
                AMO_LR:      dmem_req_cmd_o = 5'b00110; // lr
                AMO_SC:      dmem_req_cmd_o = 5'b00111; // sc
                AMO_SWAP:    dmem_req_cmd_o = 5'b00100; // amoswap
                AMO_ADD:     dmem_req_cmd_o = 5'b01000; // amoadd
                AMO_XOR:     dmem_req_cmd_o = 5'b01001; // amoxor
                AMO_AND:     dmem_req_cmd_o = 5'b01011; // amoand
                AMO_OR:      dmem_req_cmd_o = 5'b01010; // amoor
                AMO_MIN:     dmem_req_cmd_o = 5'b01100; // amomin
                AMO_MAX:     dmem_req_cmd_o = 5'b01101; // amomax
                AMO_MINU:    dmem_req_cmd_o = 5'b01110; // amominu
                AMO_MAXU:    dmem_req_cmd_o = 5'b01111; // amomaxu
                default:    dmem_req_cmd_o = 5'b00000;
            endcase
        end
        MEM_LOAD:            dmem_req_cmd_o = 5'b00000;
        MEM_STORE:           dmem_req_cmd_o = 5'b00001;
        default:            dmem_req_cmd_o = 5'b00000;
    endcase
end

assign dmem_req_addr_o = (mem_op_i == MEM_AMO) ? data_rs1_i[39:0] : data_rs1_i[39:0] + imm_i[39:0];
assign dmem_op_type_o = {61'b0,funct3_i};
assign dmem_req_data_o = data_rs2_i;
assign dmem_req_tag_o = {2'b00,rd_i,1'b0}; //  bit 0 corresponde a int o fp
assign dmem_req_invalidate_lr_o = csr_eret_i;
assign dmem_req_kill_o = mem_xcpt | kill_i  | (dmem_resp_replay_i & valid_i);

// Outputs
assign ready_o  = dmem_resp_valid_i & (mem_op_i != MEM_STORE);
assign data_o   = dmem_resp_data_i;

endmodule
//`default_nettype wire

