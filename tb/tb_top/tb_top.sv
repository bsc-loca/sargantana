//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_datapath.sv
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

//-----------------------------
// Signals
//-----------------------------
    reg     tb_clk_i;
    reg     tb_rstn_i;

    icache_line_t tb_icache_rdata_i;
    addr_t        tb_icache_rvaddr_i;
    logic         tb_icache_valid_i;
    logic 	  tb_icache_done_i;
    icache_vpn_t  tb_icache_vpn_i;

    logic         tb_icache_valid_o;
    icache_idx_t  tb_icache_idx_o;
    icache_vpn_t  tb_icache_vpn_o;

    
    bus64_t     tb_csr_rw_rdata;
    logic       tb_csr_replay;
    logic       tb_csr_stall;
    logic       tb_csr_exception_i;
    logic       tb_csr_eret;
    bus64_t     tb_csr_evec;
    logic       tb_csr_interrupt;
    bus64_t     tb_csr_interrupt_cause;
    
    csr_addr_t  tb_csr_rw_addr;
    logic [2:0] tb_csr_rw_cmd;
    bus64_t     tb_csr_rw_data;
    logic       tb_csr_exception;
    logic       tb_csr_retire;
    bus64_t     tb_csr_xcpt_cause;
    addr_t      tb_csr_pc; 
    

    logic [127:0] tb_line_o;

    bus64_t tb_dmem_resp_data_i;
    logic tb_dmem_resp_valid_i;

    logic tb_dmem_req_valid_o;
    logic [4:0] tb_dmem_req_cmd_o;
    addr_t  tb_dmem_req_addr_o;
    logic [3:0] tb_dmem_op_type_o;
    bus64_t tb_dmem_req_data_o;

    assign tb_icache_rdata_i = tb_line_o;
    assign tb_icache_rvaddr_i = {tb_icache_vpn_i,tb_icache_idx_o};

    assign tb_csr_rw_rdata = (tb_csr_rw_addr == 12'hf10) ? 64'h0 : 64'hf123456776543210;
    assign tb_csr_replay = 1'b0;
    assign tb_csr_stall = 1'b0;
    assign tb_csr_exception_i = 1'b0;
    assign tb_csr_eret = 1'b0;
    assign tb_csr_evec = 64'h0;
    assign tb_csr_interrupt = 1'b0;
    assign tb_csr_interrupt_cause = 64'b0;

//-----------------------------
// Module
//-----------------------------

    top_drac top_drac_inst(
        .CLK(tb_clk_i),
        .RST(tb_rstn_i),
        .SOFT_RST(1'b1),
        .RESET_ADDRESS(40'h200),

        .CSR_RW_RDATA(tb_csr_rw_rdata),
        .CSR_CSR_STALL(tb_csr_stall),
        .CSR_XCPT(tb_csr_exception_i),
        .CSR_ERET(tb_csr_eret),
        .CSR_EVEC(tb_csr_evec),
        .CSR_INTERRUPT(tb_csr_interrupt),
        .CSR_INTERRUPT_CAUSE(tb_csr_interrupt_cause),

	    .ICACHE_RESP_BITS_DATABLOCK(tb_icache_rdata_i),
        .ICACHE_RESP_BITS_VADDR(tb_icache_rvaddr_i),
        .ICACHE_RESP_VALID(tb_icache_done_i),
        .ICACHE_REQ_READY(tb_dmem_resp_valid_i),
        .PTWINVALIDATE(1'b0),
        .TLB_RESP_MISS(1'b0),
        .TLB_RESP_XCPT_IF(1'b0),
        .iptw_resp_valid_i(1'b0),

        .DMEM_REQ_READY(tb_dmem_resp_valid_i),
        .DMEM_RESP_BITS_DATA_SUBW(tb_dmem_resp_data_i),
        .DMEM_RESP_BITS_NACK(1'b0),
        .DMEM_RESP_BITS_REPLAY(1'b0),
        .DMEM_RESP_VALID(1'b1),
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

        .ICACHE_INVALIDATE(),
        .ICACHE_REQ_BITS_IDX(tb_icache_idx_o),
        .ICACHE_REQ_BITS_KILL(),
        .ICACHE_REQ_VALID(tb_icache_valid_o),
        .ICACHE_RESP_READY(),
        .ICACHE_REQ_BITS_VPN(tb_icache_vpn_o),
        .TLB_REQ_BITS_VPN(),
        .TLB_REQ_VALID(),

        .DMEM_REQ_VALID(tb_dmem_req_valid_o),
        .DMEM_OP_TYPE(tb_dmem_op_type_o),
        .DMEM_REQ_CMD(tb_dmem_req_cmd_o),
        .DMEM_REQ_BITS_DATA(tb_dmem_req_data_o),
        .DMEM_REQ_BITS_ADDR(tb_dmem_req_addr_o),
        .DMEM_REQ_BITS_TAG(),
        .DMEM_REQ_INVALIDATE_LR(),
        .DMEM_REQ_BITS_KILL(),
        .IO_FETCH_PC(),
        .IO_DEC_PC(),
        .IO_RR_PC(),
        .IO_EXE_PC(),
        .IO_WB_PC(),
        .IO_WB_PC_VALID(),
        .IO_WB_ADDR(),
        .IO_WB_WE(),
        .IO_WB_BITS_ADDR(),
        .IO_REG_READ_DATA(),
        .io_core_pmu_branch_miss(),
        .io_core_pmu_EXE_STORE(),
        .io_core_pmu_EXE_LOAD(),
        .io_core_pmu_new_instruction()

);


    perfect_memory_hex perfect_memory_hex_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i({tb_icache_vpn_o,tb_icache_idx_o}),
        .valid_i(tb_icache_valid_o),
        .line_o(tb_line_o),
        .ready_o(tb_icache_valid_i),
	    .done_o(tb_icache_done_i),
	    .vpaddr_o(tb_icache_vpn_i)
    );

    perfect_memory_hex_write perfect_memory_hex_write_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .addr_i(tb_dmem_req_addr_o),
        .valid_i(tb_dmem_req_valid_o),
        .wr_ena_i(tb_dmem_req_cmd_o == 5'b00001),
        .wr_data_i(tb_dmem_req_data_o),
        .word_size_i(tb_dmem_op_type_o),
        .line_o(tb_dmem_resp_data_i),
        .ready_o(tb_dmem_resp_valid_i)
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
            //tb_icache_fetch_i.valid<='{default:0};
            //tb_icache_fetch_i.data<='{default:0};
            //tb_icache_fetch_i.ex.valid<={default:0};
	    //tb_icache_fetch_i.instr_addr_misaligned<='{default:0};
            //tb_icache_fetch_i.instr_access_fault<='{default:0};
            //tb_icache_fetch_i.instr_page_fault<='{default:0};
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
                        //$display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        //$display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask


    task automatic test_sim1;
        output int tmp;
        begin
            tmp = 0;
            //$display("*** test_sim1");
            tick();
            

        end
    endtask


//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        string testname;
        string filename;
        integer f;
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        #2000;
        if (top_drac_inst.datapath_inst.rr_stage_inst.registers[28] == 1) begin
            $fwrite(f,"%c[1;34m",27);
            $fwrite(f,"%s TEST PASSED.",testname);
            $fwrite(f,"%c[0m",27);
            $fwrite(f,"\n");
        end else begin
            $fwrite(f,"%c[1;31m",27);
            $fwrite(f,"%s TEST FAILED.",testname);
            $fwrite(f,"%c[0m",27);
            $fwrite(f,"\n");
        end
        $finish;
    end
//assert property (@(posedge tb_clk_i) (tb_fetch_icache_o.vaddr != 'h0740));
//assert property (@(posedge tb_clk_i) (datapath_inst.wb_cu_int.branch_taken == 0 | datapath_inst.exe_to_wb_wb.result_pc != 'h0740));

endmodule
//`default_nettype wire
