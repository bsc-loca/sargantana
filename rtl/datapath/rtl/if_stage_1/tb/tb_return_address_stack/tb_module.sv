/*
 * Copyright 2025 BSC*
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
`default_nettype none

`include "colors.vh"

import drac_pkg::*;

module tb_module();

    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 10;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
    // Must match _NUM_RAS_ENTRIES_ of the DUT
    parameter NUM_RAS_ENTRIES = 16;

    // Input
    reg      tb_clk_i;
    reg      tb_rstn_i;
    addrPC_t tb_pc_execution_i;
    reg      tb_push_i;
    reg      tb_pop_i;

    // Output
    addrPC_t tb_return_address_o;

    // Error counter
    integer errors;

    ////////////////////////////////////////
    // MODULE
    ///////////////////////////////////////

    return_address_stack module_inst (
        .clk_i(tb_clk_i),
        .rstn_i(tb_rstn_i),
        .pc_execution_i(tb_pc_execution_i),
        .push_i(tb_push_i),
        .pop_i(tb_pop_i),
        .return_address_o(tb_return_address_o)
    );

    ////////////////////////////////////////
    // CLOCK
    ///////////////////////////////////////

    initial tb_clk_i = 1'b1;
    always #CLK_HALF_PERIOD tb_clk_i = ~tb_clk_i;

    ////////////////////////////////////////
    // TASKS
    ///////////////////////////////////////

    task automatic reset_dut;
        begin
            $display("*** Toggle reset.");
            tb_rstn_i <= 1'b0;
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            $display("Done");
        end
    endtask

    // Set default values
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_rstn_i         <= 1'b0;
            tb_pc_execution_i <= '{default:0};
            tb_push_i         <= 1'b0;
            tb_pop_i          <= 1'b0;
            errors             = 0;
            $display("Done");
        end
    endtask

    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("tb_module.vcd");
            $dumpvars(0, module_inst);
        end
    endtask

    // Compare the combinational top-of-stack output against an expected value
    task automatic check_top(input addrPC_t expected, input string what);
        begin
            if (tb_return_address_o !== expected) begin
                `START_RED_PRINT
                $display("FAIL: %s: return_address_o = 0x%h, expected 0x%h",
                         what, tb_return_address_o, expected);
                `END_COLOR_PRINT
                errors = errors + 1;
            end else if (VERBOSE) begin
                $display("ok:   %s: return_address_o = 0x%h", what, tb_return_address_o);
            end
        end
    endtask

    // Push a return address onto the stack
    task automatic ras_push(input addrPC_t addr);
        begin
            @(negedge tb_clk_i);
            tb_push_i         <= 1'b1;
            tb_pop_i          <= 1'b0;
            tb_pc_execution_i <= addr;
            @(posedge tb_clk_i);
            #1;
            tb_push_i <= 1'b0;
        end
    endtask

    // Pop the stack and check the value that comes out
    task automatic ras_pop(input addrPC_t expected, input string what);
        begin
            @(negedge tb_clk_i);
            tb_push_i <= 1'b0;
            tb_pop_i  <= 1'b1;
            #1; // settle combinational read of the top entry
            check_top(expected, what);
            @(posedge tb_clk_i);
            #1;
            tb_pop_i <= 1'b0;
        end
    endtask

    // Simultaneous pop-then-push, as issued by the decoder for
    // JALR rd=link, rs1=link, rd!=rs1 (RISC-V RAS hint table).
    // The popped value must be the current top of the stack, and the top
    // entry must be replaced with the new return address.
    task automatic ras_pop_push(input addrPC_t addr, input addrPC_t expected_pop, input string what);
        begin
            @(negedge tb_clk_i);
            tb_push_i         <= 1'b1;
            tb_pop_i          <= 1'b1;
            tb_pc_execution_i <= addr;
            #1;
            check_top(expected_pop, what);
            @(posedge tb_clk_i);
            #1;
            tb_push_i <= 1'b0;
            tb_pop_i  <= 1'b0;
        end
    endtask

    ////////////////////////////////////////
    // TESTS
    ///////////////////////////////////////

    // Basic LIFO order: values pop in reverse push order
    task automatic test_sim_1;
        begin
            $display("*** test_sim_1: basic LIFO order");
            ras_push(64'h0000_0000_8000_0100);
            ras_push(64'h0000_0000_8000_0200);
            ras_push(64'h0000_0000_8000_0300);
            ras_pop(64'h0000_0000_8000_0300, "test 1 pop 1");
            ras_pop(64'h0000_0000_8000_0200, "test 1 pop 2");
            ras_pop(64'h0000_0000_8000_0100, "test 1 pop 3");
            $display("Test 1 END");
        end
    endtask

    // Pop-then-push replaces the top entry (regression for issue #30):
    // stack [A, B], pop-then-push C -> pops B, stack must become [A, C].
    // A subsequent pop must return C, not the stale B.
    task automatic test_sim_2;
        begin
            $display("*** test_sim_2: pop-then-push replaces the top entry");
            ras_push(64'h0000_0000_8000_1000);                                     // A
            ras_push(64'h0000_0000_8000_2000);                                     // B
            ras_pop_push(64'h0000_0000_8000_3000,                                  // C
                         64'h0000_0000_8000_2000, "test 2 pop-then-push pops B");
            ras_pop(64'h0000_0000_8000_3000, "test 2 pop returns C (not stale B)");
            ras_pop(64'h0000_0000_8000_1000, "test 2 pop returns A");
            $display("Test 2 END");
        end
    endtask

    // Chained pop-then-push operations keep replacing the top entry
    task automatic test_sim_3;
        begin
            $display("*** test_sim_3: chained pop-then-push");
            ras_push(64'h0000_0000_8000_4000);                                     // A
            ras_pop_push(64'h0000_0000_8000_5000,                                  // B
                         64'h0000_0000_8000_4000, "test 3 first pop-then-push pops A");
            ras_pop_push(64'h0000_0000_8000_6000,                                  // C
                         64'h0000_0000_8000_5000, "test 3 second pop-then-push pops B");
            ras_pop(64'h0000_0000_8000_6000, "test 3 pop returns C");
            $display("Test 3 END");
        end
    endtask

    // Full-depth push and pop exercises the pointer wrap-around
    task automatic test_sim_4;
        begin
            $display("*** test_sim_4: full-depth LIFO with pointer wrap-around");
            for (int j = 1; j <= NUM_RAS_ENTRIES; j++) begin
                ras_push(64'h0000_0000_9000_0000 + 64'(j << 2));
            end
            for (int j = NUM_RAS_ENTRIES; j >= 1; j--) begin
                ras_pop(64'h0000_0000_9000_0000 + 64'(j << 2), "test 4 pop");
            end
            $display("Test 4 END");
        end
    endtask

    task automatic test_sim;
        begin
            $display("*** test_sim");
            // basic LIFO behavior
            test_sim_1();
            // pop-then-push replaces the top entry (issue #30)
            test_sim_2();
            // chained pop-then-push
            test_sim_3();
            // pointer wrap-around
            test_sim_4();
        end
    endtask

    ////////////////////////////////////////
    // MAIN
    ///////////////////////////////////////

    initial begin
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        if (errors == 0) begin
            `START_GREEN_PRINT
            $display("TEST PASSED");
            `END_COLOR_PRINT
        end else begin
            `START_RED_PRINT
            $display("TEST FAILED, %0d errors", errors);
            `END_COLOR_PRINT
        end
        $finish;
    end

endmodule
`default_nettype wire
