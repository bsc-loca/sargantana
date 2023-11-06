/*
 * Copyright 2023 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
//`default_nettype none

`include "colors.vh"

import drac_pkg::*;

module tb_top();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
    parameter N4000_CLK_PERIOD = CLK_PERIOD*4000;

//-----------------------------
// Signals
//-----------------------------
    reg     tb_clk_i;
    reg     tb_rstn_i;

    
    bus64_t     tb_csr_rw_rdata;
    logic       tb_csr_replay;
    logic       tb_csr_stall;
    logic       tb_csr_exception_i;
    logic       tb_csr_eret;
    addr_t      tb_csr_evec;
    logic       tb_csr_interrupt;
    bus64_t     tb_csr_interrupt_cause;
    
    csr_addr_t  tb_csr_rw_addr;
    logic [2:0] tb_csr_rw_cmd;
    bus64_t     tb_csr_rw_data;
    logic       tb_csr_exception;
    logic       tb_csr_retire;
    bus64_t     tb_csr_xcpt_cause;
    addr_t      tb_csr_pc; 

    phreg_t pr;

    bus_simd_t tb_dmem_resp_data_i;
    logic tb_dmem_resp_valid_i;
    logic [7:0] tb_dmem_resp_tag_i;

    logic tb_dmem_req_ready_i;
    logic tb_dmem_req_valid_o;
    logic [4:0] tb_dmem_req_cmd_o;
    addr_t  tb_dmem_req_addr_o;
    logic [3:0] tb_dmem_op_type_o;
    bus_simd_t tb_dmem_req_data_o;
    logic [7:0] tb_dmem_req_tag_o;
    
    logic [27:0] l1_vpn_request;
    logic l1_vpn_valid;
    
    logic l2_response_valid;
    logic [25:0] l1_request_paddr;
    logic [127:0] l2_response_data;
    logic [1:0] l2_response_seqnum;
    
    
    assign tb_csr_rw_rdata = (tb_csr_rw_addr == 12'h342) ? 64'h0B : 64'h0;
    assign tb_csr_replay = 1'b0;
    assign tb_csr_stall = 1'b0;
    assign tb_csr_exception_i = 1'b0;
    assign tb_csr_eret = 1'b0;
    assign tb_csr_evec = 40'h04;
    assign tb_csr_interrupt = 1'b0;
    assign tb_csr_interrupt_cause = 64'b0;

//-----------------------------
// Module
//-----------------------------

    top_drac top_drac_inst(
        .CLK(tb_clk_i),
        .RST(tb_rstn_i),
        .SOFT_RST(1'b1),
        .RESET_ADDRESS(40'h000),
        .debug_halt_i(1'b0),

        .CSR_RW_RDATA(tb_csr_rw_rdata),
        .CSR_CSR_STALL(tb_csr_stall),
        .CSR_XCPT(tb_csr_exception_i),
        .CSR_ERET(tb_csr_eret),
        .CSR_EVEC(tb_csr_evec),
        .CSR_INTERRUPT(tb_csr_interrupt),
        .CSR_INTERRUPT_CAUSE(tb_csr_interrupt_cause),
        .csr_vpu_data_i(40'h0),

        .PTWINVALIDATE(1'b0),
        .TLB_RESP_MISS(1'b0),
        .TLB_RESP_XCPT_IF(1'b0),
        .iptw_resp_valid_i(1'b0),
        .itlb_resp_ppn_i(l1_vpn_request[19:0]),

        .io_mem_grant_valid(l2_response_valid),         
        .io_mem_grant_bits_data(l2_response_data),     
        .io_mem_grant_bits_addr_beat(l2_response_seqnum),

        .DMEM_REQ_READY(tb_dmem_req_ready_i),
        .DMEM_RESP_BITS_DATA_SUBW(tb_dmem_resp_data_i),
        .DMEM_RESP_BITS_NACK(1'b0),
        .DMEM_RESP_BITS_REPLAY(1'b0),
        .DMEM_RESP_VALID(1'b1),
        .DMEM_RESP_TAG(tb_dmem_resp_tag_i),
        .DMEM_XCPT_MA_ST(1'b0),
        .DMEM_XCPT_MA_LD(1'b0),
        .DMEM_XCPT_PF_ST(1'b0),
        .DMEM_XCPT_PF_LD(1'b0),

        .CSR_RW_ADDR(tb_csr_rw_addr),
        .CSR_RW_CMD(tb_csr_rw_cmd),
        .CSR_RW_WDATA(tb_csr_rw_data),
        .CSR_EXCEPTION(tb_csr_exception),
        .CSR_RETIRE(tb_csr_retire),
        .CSR_CAUSE(tb_csr_xcpt_cause),
        .CSR_PC(tb_csr_pc),

        .TLB_REQ_BITS_VPN(l1_vpn_request),
        .TLB_REQ_VALID(l1_vpn_valid),

        .io_mem_acquire_valid(l1_request_valid),               
        .io_mem_acquire_bits_addr_block(l1_request_paddr),         
        .io_mem_acquire_bits_client_xact_id(), 
        .io_mem_acquire_bits_addr_beat(),      
        .io_mem_acquire_bits_data(),          
        .io_mem_acquire_bits_is_builtin_type(),
        .io_mem_acquire_bits_a_type(),         
        .io_mem_acquire_bits_union(),          
        .io_mem_grant_ready(),                 

        .DMEM_REQ_VALID(tb_dmem_req_valid_o),
        .DMEM_OP_TYPE(tb_dmem_op_type_o),
        .DMEM_REQ_CMD(tb_dmem_req_cmd_o),
        .DMEM_REQ_BITS_DATA(tb_dmem_req_data_o),
        .DMEM_REQ_BITS_ADDR(tb_dmem_req_addr_o),
        .DMEM_REQ_BITS_TAG(tb_dmem_req_tag_o),
        .DMEM_REQ_INVALIDATE_LR(),
        .DMEM_REQ_BITS_KILL(),
        .IO_FETCH_PC_VALUE(),
        .IO_FETCH_PC_UPDATE(),
        .IO_REG_READ(),
        .IO_REG_ADDR(),
        .IO_REG_WRITE(),
        .IO_REG_WRITE_DATA(),
        .IO_REG_READ_DATA(),
        .IO_FETCH_PC(),
        .IO_DEC_PC(),
        .IO_RR_PC(),
        .IO_EXE_PC(),
        .IO_WB_PC(),
        .IO_WB_PC_VALID(),
        .IO_WB_ADDR(),
        .IO_WB_WE(),
        .IO_WB_BITS_ADDR(),
        .io_core_pmu_branch_miss(),
        .io_core_pmu_EXE_STORE(),
        .io_core_pmu_EXE_LOAD(),
        .io_core_pmu_new_instruction()
);


    perfect_memory_hex perfect_memory_hex_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i(l1_request_paddr),
        .valid_i(l1_request_valid),
        .valid_o(l2_response_valid),
        .line_o(l2_response_data),
	    .seq_num_o(l2_response_seqnum)
    );

    perfect_memory_hex_write perfect_memory_hex_write_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i(tb_dmem_req_addr_o),
        .valid_i(tb_dmem_req_valid_o),
        .tag_i(tb_dmem_req_tag_o),
        .wr_ena_i(tb_dmem_req_cmd_o == 5'b00001),
        .wr_data_i(tb_dmem_req_data_o),
        .word_size_i(tb_dmem_op_type_o),
        .line_o(tb_dmem_resp_data_i),
        .ready_o(tb_dmem_req_ready_i),
        .valid_o(tb_dmem_resp_valid_i),
        .tag_o(tb_dmem_resp_tag_i)
    );


//-----------------------------
// DUT
//-----------------------------

    
    //***clk_gen***
    // A single clock source is used in this design.
    initial tb_clk_i = 1;
    always #CLK_HALF_PERIOD tb_clk_i = !tb_clk_i;

    //***task automatic reset_dut***
    task automatic reset_dut;
        begin
            //$display("*** Toggle reset.");
            tb_rstn_i <= 1'b0; 
            #CLK_PERIOD;
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            //$display("Done");
        end
    endtask



    //***task automatic init_sim***
    task automatic init_sim;
        begin
            //$display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};
            //tb_addr_i<='{default:0};
            //$display("Done");
            
        end
    endtask

    //***task automatic init_dump***
    //This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
    //If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            //$display("*** init_dump");
            $dumpfile("dump_file.vcd");
            $dumpvars(0,top_drac_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            //$display("*** test_sim");
            // check req valid 0
            test_sim1(tmp);
            if (tmp == 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

    task automatic test_sim1;
        output int tmp;
        begin
            tmp = 0;
            //$display("*** test_sim1");
            #N4000_CLK_PERIOD;
            pr <= top_drac_inst.datapath_inst.rename_table_inst.commit_table[3];
            #CLK_PERIOD;
            if (top_drac_inst.datapath_inst.regfile_inst.registers[pr] == 1) begin
                //FAIL
                tmp = 0;
            end else begin
                //PASS
                tmp = 1;
            end
        end
    endtask

//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        $finish;
    end


//assert property (@(posedge tb_clk_i) (tb_fetch_icache_o.vaddr != 'h0740));
//assert property (@(posedge tb_clk_i) (datapath_inst.wb_cu_int.branch_taken == 0 | datapath_inst.exe_to_wb_wb.result_pc != 'h0740));

endmodule
//`default_nettype wire
