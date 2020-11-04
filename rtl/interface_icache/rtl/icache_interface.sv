/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_icache_interface.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

import drac_pkg::*;
import riscv_pkg::*;

module icache_interface(
    input logic              clk_i,
    input logic              rstn_i,

    // Fetch stage interface - Request packet from fetch_stage
    input req_cpu_icache_t   req_fetch_icache_i,

    // Request input signals from ICache
    input icache_line_t      icache_resp_datablock_i , // ICACHE_RESP_BITS_DATABLOCK
    input addr_t             icache_resp_vaddr_i     , // ICACHE_RESP_BITS_VADDR
    input logic              icache_resp_valid_i     , // ICACHE_RESP_VALID,
    input logic              icache_req_ready_i      , // ICACHE_REQ_READY,
    input logic              tlb_resp_xcp_if_i       , // TLB_RESP_XCPT_IF,
    // Request output signals to Icache                      
    output logic             icache_invalidate_o     , // ICACHE_INVALIDATE
    output icache_idx_t      icache_req_bits_idx_o   , // ICACHE_REQ_BITS_IDX,
    output logic             icache_req_kill_o       , // ICACHE_REQ_BITS_KILL,
    output reg               icache_req_valid_o      , // ICACHE_REQ_VALID,
    output icache_vpn_t      icache_req_bits_vpn_o   , // ICACHE_REQ_BITS_VPN,
    
    // Fetch stage interface - Request packet icache to fetch
    output resp_icache_cpu_t  resp_icache_fetch_o

    
);

icache_line_reg_t icache_line_reg_q, icache_line_reg_d;
icache_line_t icache_line_int;
reg_addr_t pc_buffer_d, pc_buffer_q;
// pc requested on the last cycle
reg_addr_t old_pc_req_d, old_pc_req_q;
reg valid_buffer_q,valid_buffer_d;

logic buffer_diff_int;
// wire that says if we need to access icache
logic icache_access_needed_int;

//Internal wire to say if there is a buffer miss
logic buffer_miss_int;

// FSM icache
icache_state_t state_int, next_state_int;

// this signal codifies if a new request must be done
// to the icache
logic do_request_int;

logic new_addr_req ; //
logic is_same_addr ; //
logic a_valid_resp ; //
logic to_NoReqi    ; //
logic kill         ;

// Sequential procedure to update state
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        state_int <= NoReq;
    end else begin
        state_int <= next_state_int;
    end
end


// Icache_interface can do request to icache
assign do_request_int = icache_access_needed_int                & 
                        ~req_fetch_icache_i.invalidate_buffer   & 
                        icache_req_ready_i                      ;

assign new_addr_req = ( old_pc_req_q[ADDR_SIZE-1:4] != 
                            req_fetch_icache_i.vaddr[ADDR_SIZE-1:4] );

assign is_same_addr = (icache_resp_vaddr_i[ADDR_SIZE-1:4] == 
                              req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]);
                                          
assign a_valid_resp = icache_resp_valid_i & is_same_addr ;


assign to_NoReq = new_addr_req | 
                  a_valid_resp | 
                  req_fetch_icache_i.inval_fetch |
                  req_fetch_icache_i.invalidate_icache ;

assign icache_req_bits_vpn_o = (do_request_int) ? req_fetch_icache_i.vaddr[39:12] : 
                                                  old_pc_req_q[39:12]             ;
assign icache_req_bits_idx_o = (do_request_int) ? req_fetch_icache_i.vaddr[11:0]  :
                                                  old_pc_req_q[11:0]              ;


assign icache_req_kill_o = req_fetch_icache_i.inval_fetch | kill ;


always_comb begin
    case (state_int)
        NoReq: begin //01
            // If req from fetch valid change state_int to REQ VALID
            next_state_int     = (do_request_int && !tlb_resp_xcp_if_i) ? ReqValid : 
                                                                          NoReq    ;
            icache_req_valid_o = do_request_int;
            //icache_req_valid_o = do_request_int && !tlb_resp_xcp_if_i;
            resp_icache_fetch_o.valid =  ~buffer_miss_int  | 
                                        (tlb_resp_xcp_if_i & do_request_int);
            kill = 1'b0;
        end
        ReqValid: begin //10
            next_state_int        = (to_NoReq) ? NoReq : ReqValid;
            icache_req_valid_o    = 1'b0;
            resp_icache_fetch_o.valid = ~buffer_miss_int | a_valid_resp;
            kill                  = new_addr_req;
        end
        default: begin
            next_state_int =  NoReq;
            icache_req_valid_o = 1'b0;
            resp_icache_fetch_o.valid = 1'b0;
            kill = 1'b0;
        end
    endcase;
end

// We need and access when:
//    - there is a new request that is valid and
//      there is a miss buffer
assign icache_access_needed_int = req_fetch_icache_i.valid & buffer_miss_int;

// Icache output connections
// when we want to send invalidation of request?
assign icache_invalidate_o = req_fetch_icache_i.invalidate_icache;

assign tlb_req_valid_o = icache_req_valid_o;

assign resp_icache_fetch_o.instr_page_fault = tlb_resp_xcp_if_i & buffer_miss_int;

// sequential logic cacheline register buffer
always_ff @(posedge clk_i, negedge rstn_i) begin 
    if(!rstn_i) begin
        icache_line_reg_q <= 128'b0;
        valid_buffer_q <= 1'b0;
    end else begin 
        icache_line_reg_q <= icache_line_int;
        valid_buffer_q <= valid_buffer_d;
    end
end

always_comb begin
    valid_buffer_d = (valid_buffer_q | icache_resp_valid_i) & 
                    ~req_fetch_icache_i.invalidate_buffer   ;
end

// Manage the pc_int_register
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        pc_buffer_q <= {ADDR_SIZE{1'b0}};
        old_pc_req_q <= {ADDR_SIZE{1'b0}};
    end else begin
        pc_buffer_q <= pc_buffer_d;
        old_pc_req_q <= old_pc_req_d;
    end
end

// old pc is the pc of the last cycle
assign old_pc_req_d = do_request_int && (state_int == NoReq) ? 
                                            req_fetch_icache_i.vaddr : 
                                            old_pc_req_q             ;   

// Multiplexor to select the correct cacheline
assign icache_line_int = (icache_resp_valid_i & !tlb_resp_xcp_if_i & 
     (icache_resp_vaddr_i[ADDR_SIZE-1:4] ==  req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]))  
                    ? icache_resp_datablock_i : icache_line_reg_q;

// It is a miss on the datablock buffered
// We check for all the address if there is the need to access the TLB
// don't speculate
assign pc_buffer_d = (icache_resp_valid_i & !tlb_resp_xcp_if_i & 
      (icache_resp_vaddr_i[ADDR_SIZE-1:4] == req_fetch_icache_i.vaddr[ADDR_SIZE-1:4])) 
                    ? req_fetch_icache_i.vaddr : pc_buffer_q; 

// whether the buffer addr is different than the pc req
assign buffer_diff_int = valid_buffer_q & 
             (pc_buffer_q[ADDR_SIZE-1:4] != req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]);

// whether we don't have a valid buffer
//         or we have a different addr 
//         or we have an invalidate cache
assign buffer_miss_int = !valid_buffer_q | 
                         buffer_diff_int;

// return the datablock asked
always_comb begin
    if(tlb_resp_xcp_if_i & buffer_miss_int) begin
        resp_icache_fetch_o.data = 32'h0;
    end else begin
        case(req_fetch_icache_i.vaddr[3:2])
            2'b00: begin
                resp_icache_fetch_o.data = icache_line_int[31:0];
            end
            2'b01: begin
                resp_icache_fetch_o.data = icache_line_int[63:32]; 
            end
            2'b10: begin
                resp_icache_fetch_o.data = icache_line_int[95:64]; 
            end
            2'b11: begin
                resp_icache_fetch_o.data = icache_line_int[127:96]; 
            end
            default: begin
                resp_icache_fetch_o.data = 32'h0;
            end
        endcase
    end
end

endmodule
