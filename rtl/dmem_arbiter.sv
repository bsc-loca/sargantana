import riscv_pkg::*;
import mmu_pkg::*;

module dmem_arbiter (
    input wire clk_i,
    input wire rstn_i,
    
    // DCACHE Answer
    output  logic        datapath_resp_replay_o,  // Miss ready
    output  bus_simd_t   datapath_resp_data_o,    // Readed data from Cache
    output  logic        datapath_req_ready_o,    // Dcache ready to accept request
    output  logic        datapath_resp_valid_o,   // Response is valid
    output  logic [7:0]  datapath_resp_tag_o,     // Tag 
    output  logic        datapath_resp_nack_o,    // Cache request not accepted
    output  logic        datapath_resp_has_data_o,// Dcache response contains data
    output  logic        datapath_ordered_o,

    // Request TO DCACHE

    input logic        datapath_req_valid_i,    // Sending valid request
    input logic [4:0]  datapath_req_cmd_i,      // Type of memory access
    input addr_t       datapath_req_addr_i,     // Address of memory access
    input logic [3:0]  datapath_op_type_i,      // Granularity of memory access
    input bus_simd_t   datapath_req_data_i,     // Data to store
    input logic [7:0]  datapath_req_tag_i,      // Tag for the MSHR
    input logic        datapath_req_invalidate_lr_i, // Reset load-reserved/store-conditional
    input logic        datapath_req_kill_i,     // Kill actual memory access

    // PTW interface
    input ptw_dmem_comm_t ptw_req_i,
    output dmem_ptw_comm_t ptw_resp_o,

    // DCACHE Answer
    input  logic        dmem_resp_replay_i,  // Miss ready
    input  bus_simd_t   dmem_resp_data_i,    // Readed data from Cache
    input  logic        dmem_req_ready_i,    // Dcache ready to accept request
    input  logic        dmem_resp_valid_i,   // Response is valid
    input  logic [7:0]  dmem_resp_tag_i,     // Tag 
    input  logic        dmem_resp_nack_i,    // Cache request not accepted
    input  logic        dmem_resp_has_data_i,// Dcache response contains data
    input  logic        dmem_ordered_i,

    // Request TO DCACHE

    output logic        dmem_req_valid_o,    // Sending valid request
    output logic [4:0]  dmem_req_cmd_o,      // Type of memory access
    output addr_t       dmem_req_addr_o,     // Address of memory access
    output logic [3:0]  dmem_op_type_o,      // Granularity of memory access
    output bus_simd_t   dmem_req_data_o,     // Data to store
    output logic [7:0]  dmem_req_tag_o,      // Tag for the MSHR
    output logic        dmem_req_invalidate_lr_o, // Reset load-reserved/store-conditional
    output logic        dmem_req_kill_o     // Kill actual memory access
);

typedef enum logic [1:0] {
    NONE,
    SERVING_PTW,
    SERVING_DATAPATH
} mem_req_source_t;

mem_req_source_t current_source, next_source;
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        current_source <= NONE;
    end else begin
        current_source <= next_source;
    end
end

// next_source selection
always_comb begin
    if (datapath_req_valid_i) next_source = SERVING_DATAPATH;
    else if (ptw_req_i.req.valid) next_source = SERVING_PTW;
    else if (current_source == SERVING_DATAPATH && dmem_resp_valid_i == 1'b1) next_source = NONE;
    else if (current_source == SERVING_PTW && dmem_resp_valid_i == 1'b1) next_source = NONE;
    else next_source = current_source;
end

logic ready;
assign ready = current_source == NONE && dmem_req_ready_i;

// Req/resp forwarding
always_comb begin
    ptw_resp_o = 0;
    ptw_resp_o.dmem_ready = ready && next_source != SERVING_DATAPATH;
    ptw_resp_o.resp.ordered = dmem_ordered_i;

    datapath_resp_replay_o = 0;
    datapath_resp_data_o = 0;
    datapath_req_ready_o = ready && next_source != SERVING_PTW;
    datapath_resp_valid_o = 0;
    datapath_resp_tag_o = 0;
    datapath_resp_nack_o = 0;
    datapath_resp_has_data_o = 0;
    datapath_ordered_o = dmem_ordered_i;

    dmem_req_valid_o = 0;
    dmem_req_cmd_o = 0;
    dmem_req_addr_o = 0;
    dmem_op_type_o = 0;
    dmem_req_data_o = 0;
    dmem_req_tag_o = 0;
    dmem_req_invalidate_lr_o = 0;
    dmem_req_kill_o = 0;

    if (current_source == SERVING_PTW || (current_source == NONE && next_source == SERVING_PTW)) begin      
        ptw_resp_o.resp.replay = dmem_resp_replay_i;
        ptw_resp_o.resp.data = dmem_resp_data_i;
        ptw_resp_o.resp.addr = dmem_resp_data_i;
        ptw_resp_o.dmem_ready = dmem_req_ready_i;
        ptw_resp_o.resp.valid = dmem_resp_valid_i;
        //datapath_resp_tag_o = dmem_resp_tag_i;
        ptw_resp_o.resp.nack = dmem_resp_nack_i;
        ptw_resp_o.resp.has_data = dmem_resp_has_data_i;
        ptw_resp_o.resp.ordered = dmem_ordered_i;  

        dmem_req_valid_o = ptw_req_i.req.valid;
        dmem_req_cmd_o = ptw_req_i.req.cmd;
        dmem_req_addr_o = ptw_req_i.req.addr;
        dmem_op_type_o = ptw_req_i.req.typ;
        dmem_req_data_o = ptw_req_i.req.data;
        dmem_req_tag_o = '0;
        dmem_req_invalidate_lr_o = 1'b0;
        dmem_req_kill_o = ptw_req_i.req.kill;
    end else if (current_source == SERVING_DATAPATH || (current_source == NONE && next_source == SERVING_DATAPATH)) begin
        datapath_resp_replay_o = dmem_resp_replay_i;
        datapath_resp_data_o = dmem_resp_data_i;
        datapath_req_ready_o = dmem_req_ready_i;
        datapath_resp_valid_o = dmem_resp_valid_i;
        datapath_resp_tag_o = dmem_resp_tag_i;
        datapath_resp_nack_o = dmem_resp_nack_i;
        datapath_resp_has_data_o = dmem_resp_has_data_i;
        datapath_ordered_o = dmem_ordered_i;

        dmem_req_valid_o = datapath_req_valid_i;
        dmem_req_cmd_o = datapath_req_cmd_i;
        dmem_req_addr_o = datapath_req_addr_i;
        dmem_op_type_o = datapath_op_type_i;
        dmem_req_data_o = datapath_req_data_i;
        dmem_req_tag_o = datapath_req_tag_i;
        dmem_req_invalidate_lr_o = datapath_req_invalidate_lr_i;
        dmem_req_kill_o = datapath_req_kill_i;
    end
end


endmodule