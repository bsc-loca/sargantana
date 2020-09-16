//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_debug_ring.sv
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
    parameter N2000_CLK_PERIOD = CLK_PERIOD*2000;

//-----------------------------
// Signals
//-----------------------------

    // test name to be shown at every stage
    reg [64*8:0] tb_test_name;

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
    

    logic [127:0] tb_line_o;

    bus64_t tb_dmem_resp_data_i;
    logic tb_dmem_resp_valid_i;

    logic tb_dmem_req_valid_o;
    logic [4:0] tb_dmem_req_cmd_o;
    addr_t  tb_dmem_req_addr_o;
    logic [3:0] tb_dmem_op_type_o;
    bus64_t tb_dmem_req_data_o;

    // Debug signals
    debug_in_t debug_in;
    debug_out_t debug_out;

    logic dmem_ordered;

    

        
    assign IO_FETCH_PC=debug_out.pc_fetch;
    assign IO_DEC_PC=debug_out.pc_dec;
    assign IO_RR_PC=debug_out.pc_rr;
    assign IO_EXE_PC=debug_out.pc_exe;
    assign IO_WB_PC=debug_out.pc_wb;
    assign IO_WB_PC_VALID=debug_out.wb_valid;
    assign IO_WB_ADDR=debug_out.wb_reg_addr;
    assign IO_WB_WE=debug_out.wb_reg_we;
    assign IO_REG_READ_DATA=debug_out.reg_read_data;

    assign tb_icache_rdata_i = tb_line_o;
    assign tb_icache_rvaddr_i = {tb_icache_vpn_i,tb_icache_idx_o};

    assign tb_csr_rw_rdata = (tb_csr_rw_addr == 12'hf10) ? 64'h0 : 64'hf123456776543210;
    assign tb_csr_replay = 1'b0;
    assign tb_csr_stall = 1'b0;
    assign tb_csr_exception_i = 1'b0;
    assign tb_csr_eret = 1'b0;
    assign tb_csr_evec = 40'h0;
    assign tb_csr_interrupt = 1'b0;
    assign tb_csr_interrupt_cause = 64'b0;

    addrPC_t dcache_addr;

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
        .DMEM_ORDERED(dmem_ordered),

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
        // Output Debug 
        .IO_FETCH_PC(debug_out.pc_fetch),
        .IO_DEC_PC(debug_out.pc_dec),
        .IO_RR_PC(debug_out.pc_rr),
        .IO_EXE_PC(debug_out.pc_exe),
        .IO_WB_PC(debug_out.pc_wb),
        .IO_WB_PC_VALID(debug_out.wb_valid),
        .IO_WB_ADDR(debug_out.wb_reg_addr),
        .IO_WB_WE(debug_out.wb_reg_we),
        .IO_WB_BITS_ADDR(dcache_addr),
        .IO_REG_READ_DATA(debug_out.reg_read_data),
        // Input Debug
        .debug_halt_i(debug_in.halt_valid),
        .IO_FETCH_PC_VALUE(debug_in.change_pc_addr[39:0]),
        .IO_FETCH_PC_UPDATE(debug_in.change_pc_valid),
        .IO_REG_READ(debug_in.reg_read_valid),
        .IO_REG_ADDR(debug_in.reg_read_write_addr),
        .IO_REG_WRITE(debug_in.reg_write_valid),
        .IO_REG_WRITE_DATA(debug_in.reg_write_data),
        // Input PMU
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
            debug_in<='{default:0};
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

    task automatic half_tick();
        begin
            //$display("*** tick");
            #CLK_HALF_PERIOD;
        end
    endtask

    task automatic check_out;
        input int test;
        input int status;
        begin
            if (status >= 1) begin
                `START_RED_PRINT
                        $display("TEST %d FAILED.",test);
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST %d PASSED.",test);
                `END_COLOR_PRINT
            end
        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            tb_test_name = "test_0_advance_100_cycles";
            // Advance simulation 100 cycles
            for (int i = 0; i < 100; i++) begin
                tick();
            end
            // Check PC's no stall
            test_sim1(tmp);
            check_out(1,tmp);
            // Check WB no stall 
            test_sim2(tmp);
            check_out(2,tmp);
            // Make a stall and Read-write register
            test_sim3(tmp);
            check_out(3,tmp);
            // Change PC
            test_sim4(tmp);
            check_out(4,tmp);
        end
    endtask

    //Check PC
    task automatic test_sim1;
        output int tmp;
        begin
            tmp = 0;
            $display("*** test_sim1");
            tb_test_name = "test_1_check_PC";
            half_tick();
            if (debug_out.pc_fetch != 40'h0310) begin
                `START_RED_PRINT
                    $error("EXPECTING DIFFERENT FETCH PC, expecting %d, got %d", 
                    40'h0310,
                    debug_out.pc_fetch);
                `END_COLOR_PRINT
                tmp+=1;
            end
            if (debug_out.pc_dec != 40'h0) begin
                `START_RED_PRINT
                    $error("EXPECTING DIFFERENT DEC PC, expecting %d, got %d", 
                    0,
                    debug_out.pc_dec);
                `END_COLOR_PRINT
                tmp+=1;
            end
            if (debug_out.pc_rr != 40'h030C) begin
                `START_RED_PRINT
                    $error("EXPECTING DIFFERENT RR PC, expecting %d, got %d", 
                    40'h030C,
                    debug_out.pc_rr);
                `END_COLOR_PRINT
                tmp+=1;
            end
            if (debug_out.pc_exe != 40'h0308) begin
                `START_RED_PRINT
                    $error("EXPECTING DIFFERENT EXE PC, expecting %d, got %d", 
                    40'h0308,
                    debug_out.pc_exe);
                `END_COLOR_PRINT
                tmp+=1;
            end
            if (debug_out.pc_wb != 40'h0304) begin
                `START_RED_PRINT
                    $error("EXPECTING ADD WB not valid, expecting %d, got %d", 
                    40'h0304,
                    debug_out.pc_wb);
                `END_COLOR_PRINT
                tmp+=1;
            end
            half_tick();
            tick();
        end
    endtask

    //Check WB
    task automatic test_sim2;
        output int tmp;
        begin
            tmp = 0;
            $display("*** test_sim2");
            tb_test_name = "test_2_check_WB";
            tick();
            if (debug_out.wb_valid != 1) begin
                `START_RED_PRINT
                    $error("WB not Valid, expecting %d, got %d", 
                    1,
                    debug_out.wb_valid);
                `END_COLOR_PRINT
                tmp+=1;
            end

            if (debug_out.wb_reg_addr != 2) begin
                `START_RED_PRINT
                    $error("WB Writing register not valid, expecting %d, got %d", 
                    2,
                    debug_out.wb_reg_addr);
                `END_COLOR_PRINT
                tmp+=1;
            end


            if (debug_out.wb_reg_we != 1) begin
                `START_RED_PRINT
                    $error("WB Write enable not valid, expecting %d, got %d", 
                    1,
                    debug_out.wb_reg_we);
                `END_COLOR_PRINT
                tmp+=1;
            end
            if (dcache_addr != 0'h0) begin
                `START_RED_PRINT
                    $error("WB dcache addr not valid, expecting %d, got %d", 
                    0'h0,
                    dcache_addr);
                `END_COLOR_PRINT
                tmp+=1;
            end
            tick();
        end
    endtask

    task automatic test_sim3;
        output int tmp;
        begin
            tmp = 0;
            $display("*** test_sim3");
            tb_test_name = "test_3_register_file";
            // Insert stall
            debug_in.halt_valid=1'b1;
            // Waiting for the halt
            for (int i = 0; i < 5; i++) begin
                tick();
            end

            // Write 1 to register 1 
            debug_in.reg_write_valid=1'b1;
            debug_in.reg_read_write_addr=5;
            debug_in.reg_write_data=5;
            tick();
            half_tick(); // to see the write it is required to wait for half a cycle more..
            debug_in.reg_write_valid=1'b0;
            half_tick();
            // Check old Write has been succesfull         
            debug_in.reg_read_valid=1'b1;
            tick();
            debug_in.reg_read_valid=1'b0;
            if (debug_out.reg_read_data != 5) begin
                `START_RED_PRINT
                    $error("Incorrect Read data  expecting %d, got %d", 
                    5,
                    debug_out.reg_read_data);
                `END_COLOR_PRINT
                tmp+=1;
            end
            tick();
        end
    endtask

    task automatic test_sim4;
        output int tmp;
        begin
            tmp = 0;
            $display("*** test_sim4");
            tb_test_name = "test_4_change_PC";
            tick();
            // Change PC
            debug_in.change_pc_valid=1'b1;
            debug_in.change_pc_addr=1234;
            tick();
            half_tick();
            if (debug_out.pc_fetch != 1234) begin
                `START_RED_PRINT
                    $error("PC CHANGE DEBUG NOT VALID expecting %d, got %d", 
                    1234,
                    debug_out.pc_fetch);
                `END_COLOR_PRINT
                tmp+=1;
            end 
            debug_in.change_pc_valid=1'b0;
            half_tick();
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
