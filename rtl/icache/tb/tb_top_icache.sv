/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : tb_top_icache.sv
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

import drac_icache_pkg::*;
//`include "drac_config.v"

`define RAM tb_top_icache.i1.icache_memory
`define LRU tb_top_icache.i1.replace_unit
`define FSM tb_top_icache.i1.icache_ctrl
 

`timescale 1 ns/ 1 ns
module tb_top_icache();

//- Inputs                              
logic          clk_i              ;
logic          rstn_i             ;
logic          flush_i            ; //- From CSR.
logic          cache_enable_i     ; //- From CSR.
ireq_i_t       lagarto_ireq_i     ; //- From Lagarto.
ifill_resp_i_t ifill_resp_i       ; //- From upper levels.
tresp_i_t      mmu_tresp_i        ; //- From MMU.
//- Output                                              
iresp_o_t      icache_resp_o      ; //- To Lagarto.
treq_o_t       icache_treq_o      ; //- To MMU.
ifill_req_o_t  icache_ifill_req_o ;  //- To upper levels.

top_icache i1(
    .clk_i             ( clk_i              ),       
    .rstn_i            ( rstn_i             ),
    .flush_i           ( flush_i            ),
    .cache_enable_i    ( cache_enable_i     ),
    .lagarto_ireq_i    ( lagarto_ireq_i     ),
    .ifill_resp_i      ( ifill_resp_i       ),
    .mmu_tresp_i       ( mmu_tresp_i        ),
    .icache_resp_o     ( icache_resp_o      ),
    .icache_treq_o     ( icache_treq_o      ),
    .icache_ifill_req_o( icache_ifill_req_o )
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
        flush_i            <=  '{default:0};   
        cache_enable_i     <=  '{default:0};   
        lagarto_ireq_i     <=  '{default:0};  
        ifill_resp_i       <=  '{default:0};  
        mmu_tresp_i        <=  '{default:0}; 
        $display("Running testbench");
    end
endtask

initial begin
    set();
    reset();
    #50
    // The cache is enabled. 
    cache_enable_i <= 1'b1;
    //***FLUSH***//
    #6700 //- The time needed to flush the valid bits.
    tlbmiss_0_test();
    tlbmiss_1_test();
    ifill_0_test();
    ifill_1_test();
    ifill_2_test();
    ifill_same_addr_0();
    ifill_same_addr_1();
    ifill_same_addr_2();
    ifill_same_addr_3();
    ifill_same_addr_rdm();
    ifill_same_addr_rdm();
    fetch_request(); 
    kill_0_test();
    kill_1_test();
    kill_2_test();
    kill_3_test();
    flush_0_test();
    flush_1_test();
end

task automatic tlbmiss_0_test;
// Fetch to cacheable address
// TLB miss and PTW walking
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h84;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};

    #200
    mmu_tresp_i.valid  <=  1'b1;
    ifill_resp_i.sent  <=  1'b1;
    mmu_tresp_i.paddr  <= 64'h8000_0000; 
    
    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    
    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h1C1C_1C1C_1818_1818_1414_1414_1010_1010_CCCC_CCCC_8888_8888_4444_4444_0000_0000;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'hCCCC_CCCC_8888_8888_4444_4444_0000_0000) begin
            $display ("------");
            $display ($time);
            $display ("Fetch to cacheable address 0,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Fetch to cacheable address 0,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h8888_8888) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Fetch to cacheable address 0,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Fetch to cacheable address 0,  ERROR! "     );
    //`endif
    end
endtask

task automatic tlbmiss_1_test;
// Fetch to cacheable address
// TLB miss and PTW walking
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'hBC;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};

    #200
    mmu_tresp_i.valid  <=  1'b1;
    ifill_resp_i.sent  <=  1'b1;
    mmu_tresp_i.paddr  <= 64'h8000_0000; 
    
    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    
    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h1C1C_1C1C_1818_1818_1414_1414_1010_1010_CCCC_CCCC_8888_8888_4444_4444_0000_0000;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'h1C1C_1C1C_1818_1818_1414_1414_1010_1010) begin
            $display ("------");
            $display ($time);
            $display ("Fetch to cacheable address 1,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Fetch to cacheable address 1,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h8888_8888) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Fetch to cacheable address 1,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Fetch to cacheable address 1,  ERROR! "     );
    //`endif
    end
endtask


task automatic ifill_0_test;
// Fetch to cacheable address
// TLB miss
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h8;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h1C1C_1C1C_1818_1818_1414_1414_1010_1010_CCCC_CCCC_8888_8888_4444_4444_0000_0000;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'hCCCC_CCCC_8888_8888_4444_4444_0000_0000) begin
            $display ("------");
            $display ($time);
            $display ("Fetch to cacheable address 3,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Fetch to cacheable address 3,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h8888_8888) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Fetch to cacheable address 3,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Fetch to cacheable address 3,  ERROR! "     );
    //`endif
    end
endtask

task automatic ifill_1_test;
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h34;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h3C3C_3C3C_3838_3838_3434_3434_3030_3030_2C2C_2C2C_2828_2828_2424_2424_2020_2020;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'h3C3C_3C3C_3838_3838_3434_3434_3030_3030) begin
            $display ("------");
            $display ($time);
            $display ("Fetch to cacheable address 4,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Fetch to cacheable address 4,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h3434_3434) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Fetch to cacheable address 4,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Fetch to cacheable address 4,  ERROR! "     );
    //`endif
    end
endtask

task automatic ifill_2_test;
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h54;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h5C5C_5C5C_5858_5858_5454_5454_5050_5050_4C4C_4C4C_4848_4848_4444_4444_4040_4040;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'h5C5C_5C5C_5858_5858_5454_5454_5050_5050) begin
            $display ("------");
            $display ($time);
            $display ("Fetch to cacheable address 5,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Fetch to cacheable address 5,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h5454_5454) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Fetch to cacheable address 5,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Fetch to cacheable address 5,  ERROR! "     );
    //`endif
    end
endtask


task automatic ifill_same_addr_0;
//Write on another way, Replacement Unit working...
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h54;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h2222_5C5C_2222_5858_2222_5454_2222_5050_2222_4C4C_2222_4848_2222_4444_2222_4040;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'h2222_5C5C_2222_5858_2222_5454_2222_5050) begin
            $display ("------");
            $display ($time);
            $display ("Logic replace unit test 0,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else begin   
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
            $erro ("Logic replace unit test 0,  ERROR! "     );
        end
    //`else
    //    if(icache_resp_o.data == 32'h2222_5454) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Logic replace unit test 0,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else begin   
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //        $erro ("Logic replace unit test 0,  ERROR! "     );
    //    end
    //`endif
    end
endtask

task automatic ifill_same_addr_1;
//Write on another way, Replacement Unit working...
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h30;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr    <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h2222_5C5C_2222_5858_2222_5454_2222_5050_2222_4C4C_2222_4848_2222_4444_2222_4040;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'h2222_5C5C_2222_5858_2222_5454_2222_5050) begin
            $display ("------");
            $display ($time);
            $display ("Logic replace unit test 1,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else begin   
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
            $erro ("Logic replace unit test 1,  ERROR! "     );
        end
    //`else
    //    if(icache_resp_o.data == 32'h2222_5050) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Logic replace unit test 1,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Logic replace unit test 1,  ERROR! "     );
    //`endif
    end
endtask

task automatic ifill_same_addr_2;
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h30;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h2222_5C5C_2222_5858_2222_5454_2222_5050_2222_4C4C_2222_4848_2222_4444_2222_4040;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'h2222_5C5C_2222_5858_2222_5454_2222_5050) begin
            $display ("------");
            $display ($time);
            $display ("Logic replace unit test 2,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Logic replace unit test 2,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h2222_5050) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Logic replace unit test 2,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Logic replace unit test 2,  ERROR! "     );
    //`endif
    end
endtask

task automatic ifill_same_addr_3;
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h30;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'h2222_5C5C_2222_5858_2222_5454_2222_5050_2222_4C4C_2222_4848_2222_4444_2222_4040;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'h2222_5C5C_2222_5858_2222_5454_2222_5050) begin
            $display ("------");
            $display ($time);
            $display ("Logic replace unit test 3,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Logic replace unit test 3,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h2222_5050) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Logic replace unit test 3,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Logic replace unit test 3,  ERROR! "     );
    //`endif
    end
endtask

task automatic ifill_same_addr_rdm;
// Select a random way to replace 
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h30;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 
    ifill_resp_i.sent    <=  1'b1;

    #50
    mmu_tresp_i.valid  <=  1'b0;
    ifill_resp_i.sent  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 

    #150 //ifill valid return
    #50 //ifill valid return
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'hFFFF_5C5C_2222_5858_2222_5454_2222_5050_2222_4C4C_2222_4848_2222_4444_2222_4040;

    #50 
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= '0;
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'hFFFF_5C5C_2222_5858_2222_5454_2222_5050) begin
            $display ("------");
            $display ($time);
            $display ("Select a random way to replace,  TEST PASSED!");
            $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
            $display ("ADDR         =  %h", `RAM.addr_i           );
            $display ("WAY          =  %h", `LRU.way_to_replace_d );
        end
        else $error   ("Select a random way to replace,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h2222_5050) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Select a random way to replace,  TEST PASSED!");
    //        $display ("Write enable =  %h", `FSM.cache_wr_ena_o   );
    //        $display ("ADDR         =  %h", `RAM.addr_i           );
    //        $display ("WAY          =  %h", `LRU.way_to_replace_d );
    //    end
    //    else $error   ("Select a random way to replace,  ERROR! "     );
    //`endif
    end
endtask

task automatic fetch_request;
// Continuos Fetch request from core. i
// 1 clock cycle of response.
    begin
    #200
    lagarto_ireq_i.valid   <=  1'b1; //New request  
    lagarto_ireq_i.vaddr   <= 64'h0;
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 

    #50
    mmu_tresp_i.valid       <=  1'b0;
    mmu_tresp_i.paddr       <= 64'h0; 
    lagarto_ireq_i.valid    <=  1'b1; //New request  
    lagarto_ireq_i.vaddr    <= 64'h30;
    
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'hCCCC_CCCC_8888_8888_4444_4444_0000_0000) begin
            $display ("------");
            $display ($time);
            $display ("Continuos Fetch 0,  TEST PASSED!");
        end
        else $error   ("Continuos Fetch 0,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h0000_0000) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Continuos Fetch 0,  TEST PASSED!");
    //    end
    //    else $error   ("Continuos Fetch 0,  ERROR! "     );
    //`endif
    
    #50 
    lagarto_ireq_i     <=  '{default:0};
    //ifill request is sent
    mmu_tresp_i.valid    <=  1'b1;
    mmu_tresp_i.paddr    <= 64'h8000_0000; 

    #50
    mmu_tresp_i.valid  <=  1'b0;
    mmu_tresp_i.paddr  <= 64'h0; 
    //`ifdef FETCH_CACHELINE
        if(icache_resp_o.data == 128'hFFFF_5C5C_2222_5858_2222_5454_2222_5050) begin
            $display ("------");
            $display ($time);
            $display ("Continuos Fetch 1,  TEST PASSED!");
        end
        else $error   ("Continuos Fetch 1,  ERROR! "     );
    //`else
    //    if(icache_resp_o.data == 32'h2222_5050) begin
    //        $display ("------");
    //        $display ($time);
    //        $display ("Continuos Fetch 1,  TEST PASSED!");
    //    end
    //    else $error   ("Continuos Fetch 1,  ERROR! "     );
    //`endif
    end
endtask

task automatic kill_0_test;
    begin
    //It sends a Kill request one clock cycle after a valid request.   
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h84;
    
    #50 
    lagarto_ireq_i.valid   <=  1'b0;  
    lagarto_ireq_i.kill    <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h0;
    
    #50 
    lagarto_ireq_i.kill    <=  1'b0;
    
    #50 
    if (!icache_resp_o.valid && !icache_treq_o.valid && `FSM.state_q == NO_REQ) begin
        $display ("------");
        $display ("kill test 0 PASSED!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $display ("icache_resp_o.valid == %h ", icache_resp_o.valid);
        $display ("icache_treq_o.valid == %h ", icache_treq_o.valid);
        $display ("state_q == %s ", `FSM.state_q);
        $error   ("kill test 0  ERROR! "     );
    end

    end
endtask

task automatic kill_1_test;
    begin
    //It sends a Kill request in a TLB_MISS.   
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h84; 
    #50 
    lagarto_ireq_i.valid   <=  1'b0;  
    lagarto_ireq_i.vaddr   <= 64'h0;
    
    #200
    // Kill is sent.
    lagarto_ireq_i.kill    <=  1'b1;  
    #50 
    lagarto_ireq_i.kill    <=  1'b0;

    #200
    // PTW finished walk.
    mmu_tresp_i.valid   <=  1'b1;
    ifill_resp_i.sent   <=  1'b1; 
    #50 
    mmu_tresp_i.valid   <=  1'b0;
    ifill_resp_i.sent   <=  1'b0;
    
    #50 
    if (!icache_resp_o.valid && !icache_treq_o.valid && `FSM.state_q == NO_REQ) begin
        $display ("------");
        $display ("kill test 1 PASSED!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $display ("icache_resp_o.valid == %h ", icache_resp_o.valid);
        $display ("icache_treq_o.valid == %h ", icache_treq_o.valid);
        $display ("state_q == %s ", `FSM.state_q);
        $error   ("kill test 1  ERROR! "     );
    end

    end

endtask

task automatic kill_2_test;
    begin
    //It sends a Kill request in a MISS.   
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h84; 
    #50 
    lagarto_ireq_i.valid   <=  1'b0;  
    lagarto_ireq_i.vaddr   <= 64'h0;
    mmu_tresp_i.valid      <=  1'b1;
    ifill_resp_i.sent      <=  1'b1; 
    #50 
    mmu_tresp_i.valid   <=  1'b0;
    ifill_resp_i.sent   <=  1'b0;
    
    #200
    // Kill is sent.
    lagarto_ireq_i.kill    <=  1'b1;  
    #50 
    lagarto_ireq_i.kill    <=  1'b0;

    #200
    ifill_resp_i.valid <= 1'b1;
    ifill_resp_i.ack   <= 1'b1;
    ifill_resp_i.data  <= 256'hFFFF_5C5C_2222_5858_2222_5454_2222_5050_2222_4C4C_2222_4848_2222_4444_2222_4040;

    #50
    ifill_resp_i.valid <= 1'b0;
    ifill_resp_i.ack   <= 1'b0;
    ifill_resp_i.data  <= 256'h0;

    
    #50 
    if (!icache_resp_o.valid && !icache_treq_o.valid && `FSM.state_q == NO_REQ) begin
        $display ("------");
        $display ("kill test 2 PASSED!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $display ("icache_resp_o.valid == %h ", icache_resp_o.valid);
        $display ("icache_treq_o.valid == %h ", icache_treq_o.valid);
        $display ("state_q == %s ", `FSM.state_q);
        $error   ("kill test 2  ERROR! "     );
    end
    end
endtask

task automatic kill_3_test;
    begin
    //It sends a Kill request in a Fetch request.   
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.kill    <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h84; 
    #50 
    lagarto_ireq_i.valid   <=  1'b0;  
    lagarto_ireq_i.vaddr   <= 64'h0;
    lagarto_ireq_i.kill    <=  1'b0;  
    
    #50 
    if (!icache_resp_o.valid && !icache_treq_o.valid && `FSM.state_q == NO_REQ) begin
        $display ("------");
        $display ("kill test 3 PASSED!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $display ("icache_resp_o.valid == %h ", icache_resp_o.valid);
        $display ("icache_treq_o.valid == %h ", icache_treq_o.valid);
        $display ("state_q == %s ", `FSM.state_q);
        $error   ("kill test 3  ERROR! "     );
    end
    end
endtask

task automatic flush_0_test;
begin
    //It sends a Flush request one clock cycle after a valid request.   
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h84;
    
    #50 
    lagarto_ireq_i.valid   <=  1'b0;  
    lagarto_ireq_i.vaddr   <= 64'h0;
    flush_i                <=  1'b1;
    mmu_tresp_i.valid      <=  1'b1;
    mmu_tresp_i.paddr      <= 64'h8000_0000; 
    
    #50 
    flush_i                <=  1'b0;
    mmu_tresp_i.valid      <=  1'b0;
    mmu_tresp_i.paddr      <= 64'h0; 
    if (icache_resp_o.valid) begin
        $error   ("a valid response ... ERROR! ");
    end 
    
    #100 
    if (!icache_resp_o.valid && !icache_treq_o.valid && `FSM.state_q == FLUSH) begin
        $display ("------");
        $display ("FLUSH test 0 PASSED!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $display ("icache_resp_o.valid == %h ", icache_resp_o.valid);
        $display ("icache_treq_o.valid == %h ", icache_treq_o.valid);
        $display ("state_q == %s ", `FSM.state_q);
        $error   ("FLUSH test 0  ERROR! "     );
    end
    
    #6350 //- The time needed to flush the valid bits.
    if (`FSM.flush_done_i == 1'b1) begin
        $display ("------");
        $display ("FLUSH done!!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $error   ("FLUSH not done... ERROR! "     );
    end
    
end
endtask

task automatic flush_1_test;
begin
    //It sends a Flush request in a TLB_MISS.   
    #200
    lagarto_ireq_i.valid   <=  1'b1;  
    lagarto_ireq_i.vaddr   <= 64'h84;
    
    #50 
    lagarto_ireq_i.valid   <=  1'b0;  
    lagarto_ireq_i.vaddr   <= 64'h0;
    flush_i                <=  1'b0;
    
    #200 
    flush_i                <=  1'b1;
    #50
    flush_i                <=  1'b0;
    
    #200
    mmu_tresp_i.valid      <=  1'b1;
    #50
    mmu_tresp_i.valid      <=  1'b0;
    
    if (icache_resp_o.valid) begin
        $error   ("a valid response ... ERROR! ");
    end 
    
    #100 
    if (!icache_resp_o.valid && !icache_treq_o.valid && `FSM.state_q == FLUSH) begin
        $display ("------");
        $display ("FLUSH test 1 PASSED!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $display ("icache_resp_o.valid == %h ", icache_resp_o.valid);
        $display ("icache_treq_o.valid == %h ", icache_treq_o.valid);
        $display ("state_q == %s ", `FSM.state_q);
        $error   ("FLUSH test 0  ERROR! "     );
    end
    
    #6350 //- The time needed to flush the valid bits.
    if (`FSM.flush_done_i == 1'b1) begin
        $display ("------");
        $display ("FLUSH done!!");
        $display ("------");
    end  
    else begin 
        $display ("------");
        $error   ("FLUSH not done... ERROR! "     );
    end
    
end
endtask

endmodule


