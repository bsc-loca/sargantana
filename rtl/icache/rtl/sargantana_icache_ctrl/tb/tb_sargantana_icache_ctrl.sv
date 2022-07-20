/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : tb_icache_ctrl.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva Santes. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 * -----------------------------------------------
 */

import sargantana_icache_pkg::*;

//`ifndef FSM_ICTRL_TEST                                                 
//    `define FSM_ICTRL_TEST
//`endif                                          

`timescale 1 ns/ 1 ns
module tb_sargantana_icache_ctrl();

    logic clk_i              ;
    logic rstn_i             ;
    logic cache_enable_i     ; //-From CSR
    logic paddr_is_nc_i      ;
    logic flush_i            ;
    logic flush_done_i       ;
    logic ireq_valid_i       ; //- A valid request. 
    logic ireq_kill_s1_i     ; //- Kill the current request. 
    logic ireq_kill_s2_i     ; //- Kill the last request.
    reg   iresp_ready_o      ; //- iCache is ready.  
    reg   iresp_valid_o      ; //- A valid response.  
    reg   cmp_enable_o       ;
    reg   cache_rd_ena_o     ; //- Read enable
    reg   cache_wr_ena_o     ; //- Write enable
//`ifndef FSM_ICTRL_TEST                            
    logic mmu_resp_valid_i   ; //- A address translation valid. 
    logic mmu_ex_valid_i     ; //- Some exception occurred.
    logic ifill_resp_valid_i ; //- Packets delivered from an upper memory 
                               //  level by an IFILL request are valid.
    logic ifill_resp_ack_i   ; //- The IFILL request was received.
    logic ifill_sent_ack_i   ; //- The IFILL request has been sent.
    reg   ifill_req_valid_o  ; //- The IFILL request sent is valid.   
    reg   treq_valid_o       ; //. A valid translation request.
//`endif                                                                              
    logic [ICACHE_N_SET-1:0] cline_hit_i; //- A hit on any read cache line.  
    reg   miss_o;              
    reg   flush_en_o;              

sargantana_icache_ctrl i1 (
    .clk_i             ( clk_i              ),
    .rstn_i            ( rstn_i             ),
    .cache_enable_i    ( cache_enable_i     ),
    .paddr_is_nc_i     ( paddr_is_nc_i      ),
    .flush_i           ( flush_i            ),
    .flush_done_i      ( flush_done_i       ),
    .cmp_enable_o      ( cmp_enable_o       ),
    .cache_rd_ena_o    ( cache_rd_ena_o     ),
    .cache_wr_ena_o    ( cache_wr_ena_o     ),
    .ireq_valid_i      ( ireq_valid_i       ),
    .ireq_kill_s1_i    ( ireq_kill_s1_i     ),
    .ireq_kill_s2_i    ( ireq_kill_s2_i     ),
    .iresp_ready_o     ( iresp_ready_o      ),
    .iresp_valid_o     ( iresp_valid_o      ),
//`ifndef FSM_ICTRL_TEST                             
    .mmu_resp_valid_i  ( mmu_resp_valid_i   ),
    .mmu_ex_valid_i    ( mmu_ex_valid_i     ),
    .treq_valid_o      ( treq_valid_o       ),
    .ifill_resp_valid_i( ifill_resp_valid_i ),
    .ifill_resp_ack_i  ( ifill_resp_ack_i   ),
    .ifill_sent_ack_i  ( ifill_sent_ack_i   ),
    .ifill_req_valid_o ( ifill_req_valid_o  ),
//`endif                                                                              
    .cline_hit_i       ( cline_hit_i        ),
    .flush_en_o        ( flush_en_o         ),
    .miss_o            ( miss_o             )  
);


initial clk_i = 1'b1;
always #25 clk_i = ~clk_i;

task automatic reset;
    begin
        rstn_i <= 1'b0; 
        #50;
        rstn_i <= 1'b1;
    end
endtask

task automatic set;
    begin
        clk_i              <= 1'b1;  
        rstn_i             <= 1'b0; 
        cache_enable_i     <= 1'b0; 
        paddr_is_nc_i      <= 1'b0; 
        flush_i            <= 1'b0; 
        flush_done_i       <= 1'b0; 
        ireq_valid_i       <= 1'b0; 
        ireq_kill_s1_i     <= 1'b0;   
        ireq_kill_s2_i     <= 1'b0;   
        mmu_resp_valid_i   <= 1'b0; 
        mmu_ex_valid_i     <= 1'b0; 
        ifill_resp_valid_i <= 1'b0; 
        ifill_resp_ack_i   <= 1'b0;         
        ifill_sent_ack_i   <= 1'b0;         
        cline_hit_i        <= '0;       
        $display("Running testbench");
    end
endtask

task automatic test_1;
    begin
    //- Non-cacheable address and page no found in TLB.
    #50
    ireq_valid_i       <= 1'b1; 
    #50 // -Signal down...
    ireq_valid_i       <= 1'b0; 
    
    //- PTW walking ....
    
    #300  
    //- MMU sends a valid response,
    //  notifying that has a valid PTE
    mmu_resp_valid_i   <= 1'b1; 
    #50 
    //- IFILL request is sent....
    //  The MMU notify that an IFILL request 
    //  has been sent.
    mmu_resp_valid_i   <= 1'b1; 
    ifill_sent_ack_i   <= 1'b1;
    #50 // -Signals down...
    mmu_resp_valid_i   <= 1'b0;
    ifill_sent_ack_i   <= 1'b0;
    
    //- Wait for delivery...    
   
    #300
    //- IFIL response is delivered.  
    ifill_resp_valid_i <= 1'b1; 
    ifill_resp_ack_i   <= 1'b1;         
    #50  // -Signals down...
    ifill_resp_valid_i <= 1'b0; 
    ifill_resp_ack_i   <= 1'b0;         
    
    end
endtask

task automatic test_2;
    begin
    //- Non-cacheable or cacheable address and page found in TLB.
    #50
    ireq_valid_i       <= 1'b1; 
    
    #50 
    ireq_valid_i       <= 1'b0; // -Signal down...
    //- IFILL request is sent....
    //  The MMU notify that an IFILL request 
    //  has been sent.
    mmu_resp_valid_i   <= 1'b1; 
    ifill_sent_ack_i   <= 1'b1;
    
    #300
    //- IFIL response is delivered.  
    ifill_resp_valid_i <= 1'b1; 
    ifill_resp_ack_i   <= 1'b1;         
    #50  // -Signals down...
    ifill_resp_valid_i <= 1'b0; 
    ifill_resp_ack_i   <= 1'b0;         
    end
endtask

task automatic test_3;
    begin
    //- Cacheable address and page found in TLB.
    #50
    ireq_valid_i       <= 1'b1; 
    
    #50 
    ireq_valid_i       <= 1'b0; // -Signal down...
    mmu_resp_valid_i   <= 1'b1; 
    cache_enable_i     <= 1'b1; 
    cline_hit_i        <= 4'b0001;       
    #50 
    ireq_valid_i       <= 1'b0; // -Signal down...
    mmu_resp_valid_i   <= 1'b0; 
    cache_enable_i     <= 1'b0; 
    cline_hit_i        <= 4'b0000;       
    end
endtask

task automatic test_4;
    begin
    //-Continuous requests
    #50
    ireq_valid_i       <= 1'b1; 
    
    #50 
    ireq_valid_i       <= 1'b1; 
    mmu_resp_valid_i   <= 1'b1; 
    cache_enable_i     <= 1'b1; 
    cline_hit_i        <= 4'b0001;       
    
    #50 
    ireq_valid_i       <= 1'b1; 
    mmu_resp_valid_i   <= 1'b1; 
    cache_enable_i     <= 1'b1; 
    cline_hit_i        <= 4'b0010;       
    
    #50 
    ireq_valid_i       <= 1'b1; 
    mmu_resp_valid_i   <= 1'b1; 
    cache_enable_i     <= 1'b1; 
    cline_hit_i        <= 4'b1000;       
    
    #50 
    ireq_valid_i       <= 1'b0; 
    mmu_resp_valid_i   <= 1'b1; 
    cache_enable_i     <= 1'b1; 
    cline_hit_i        <= 4'b1000;       
    end
endtask

initial begin
    set();
    reset();
    //test_1();
    //test_2();
    test_4();
    

end


endmodule
