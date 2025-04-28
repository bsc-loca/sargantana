//-----------------------------
// Header
//-----------------------------

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
//`default_nettype none

`include "colors.vh"

import riscv_pkg::*;
import drac_pkg::*;

module tb_decoder();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;

//-----------------------------
// Signals
//-----------------------------
    reg tb_clk_i;
    // test name to be shown at every stage
    reg [64*8:0] tb_test_name;

    if_id_stage_t tb_decode_i;
    instr_entry_t tb_decode_instr_o;
    jal_id_if_t   tb_jal_id_if_o;


//-----------------------------
// Module
//-----------------------------

    decoder decoder_inst(
        .decode_i(tb_decode_i),
        .decode_instr_o(tb_decode_instr_o),
        .jal_id_if_o(tb_jal_id_if_o)
    );

//-----------------------------
// DUT
//-----------------------------


//***clk_gen***
// A single clock source is used in this design.
    initial tb_clk_i = 1;
    always #CLK_HALF_PERIOD tb_clk_i = !tb_clk_i;

    /* //***task automatic reset_dut***
    task automatic reset_dut;
        begin
            $display("*** Toggle reset.");
            //#tb_rstn_i <= 1'b0; 
            #CLK_PERIOD;
            //tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            $display("Done");
        end
    endtask*/

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            // /tb_rstn_i<='{default:0};
            tb_decode_i<='{default:0};
            
            $display("Done");
            
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("tb_decoder.vcd");
            $dumpvars(0,decoder_inst);
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
            //$display("*** half tick");
            #CLK_HALF_PERIOD;
        end
    endtask

    task automatic print;
        input int value;
        begin
            $display("Value: %h ",value);
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

    task automatic checkWENA;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.regfile_we != expectedValue) begin
                `START_RED_PRINT
                    $error("Register W enable differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask 

    task automatic checkValidInst;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.valid != expectedValue) begin
                `START_RED_PRINT
                    $error("Instr valid differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask 

    task automatic checkValidEx;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.ex.valid != expectedValue) begin
                `START_RED_PRINT
                    $error("Exception valid differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask 

    task automatic checkSamePC;
        input  logic[63:0] expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.pc != expectedValue) begin
                `START_RED_PRINT
                    $error("PC differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask 

    task automatic checkIllegalInstr;
        output int differ;
        begin
            if (tb_decode_instr_o.ex.valid != 1'b1 || 
                tb_decode_instr_o.ex.cause != ILLEGAL_INSTR) begin
                `START_RED_PRINT
                    $error("Illegal instr not set correctly");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkRs1;
        input  logic[4:0] expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.rs1 != expectedValue) begin
                `START_RED_PRINT
                    $error("Register RS1 differs expecting %d, got %d",
                            expectedValue,
                            tb_decode_instr_o.rs1);
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkRs2;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.rs2 != expectedValue) begin
                `START_RED_PRINT
                    $error("Register RS2 differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkRd;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.rd != expectedValue) begin
                `START_RED_PRINT
                    $error("Register RD differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkUseImm;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.use_imm != expectedValue) begin
                `START_RED_PRINT
                    $error("Use Immediate differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkUsePC;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.use_pc != expectedValue) begin
                `START_RED_PRINT
                    $error("Use PC differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkImm;
        input  logic[63:0] expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.result != expectedValue) begin
                `START_RED_PRINT
                    $error("Immediate differs, expecting %h, got %h",expectedValue,tb_decode_instr_o.result);
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkOP32;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.op_32 != expectedValue) begin
                `START_RED_PRINT
                    $error("OP32 differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkSignedOP;
        input  int expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.signed_op != expectedValue) begin
                `START_RED_PRINT
                    $error("SignedOP differs");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkExCause;
        input  exception_cause_t expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.ex.cause != expectedValue) begin
                `START_RED_PRINT
                    $error("EX cause differs, expecting %d",expectedValue);
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    

    task automatic checkFU;
        input  logic[2:0] expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.unit != expectedValue) begin
                `START_RED_PRINT
                    $error("Functional Unit differs");
                    print(tb_decode_instr_o.unit);
                    print(expectedValue);
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkInstrType;
        input  logic[6:0] expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.instr_type != expectedValue) begin
                `START_RED_PRINT
                    $error("Instruction type differs");
                    print(tb_decode_instr_o.instr_type);
                    print(expectedValue);
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkMemSize;
        input  logic[2:0] expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.mem_size != expectedValue) begin
                `START_RED_PRINT
                    $error("Mem Size differs, expecting %d, got %d", expectedValue, tb_decode_instr_o.mem_size);
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    task automatic checkCSRFence;
        input  logic expectedValue;
        output int differ;
        begin
            if (tb_decode_instr_o.stall_csr_fence != expectedValue) begin
                `START_RED_PRINT
                    $error("CSR FENCE Valid differs, expecting %d, got %d", 
                    expectedValue,
                    tb_decode_instr_o.stall_csr_fence);
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
        end
    endtask

    

    task automatic checkValidBasic;
        input instr_entry_t InstrEntry;
        output int tmp;
        begin
            int differ;
            tmp=0;
            checkValidInst(InstrEntry.valid,differ);
            tmp=tmp+differ;
            checkSamePC(InstrEntry.pc,differ);
            tmp=tmp+differ;
            checkValidEx(InstrEntry.ex.valid,differ);
            tmp=tmp+differ;

            checkUseImm(InstrEntry.use_imm,differ);
            tmp=tmp+differ;
            checkUsePC(InstrEntry.use_pc,differ);
            tmp=tmp+differ;
            checkOP32(InstrEntry.op_32,differ);
            tmp=tmp+differ;

            tmp=tmp+differ;
            checkWENA(InstrEntry.regfile_we,differ);
            tmp=tmp+differ;
            checkSignedOP(InstrEntry.signed_op,differ);
            tmp=tmp+differ;
            checkCSRFence(InstrEntry.stall_csr_fence,differ);
            tmp=tmp+differ;
        end
    endtask

    task automatic checkBR;
        input instr_entry_t InstrEntry;
        output int tmp;
        begin
            int differ;
            tmp=0;
            
            checkValidBasic(InstrEntry,differ);
            tmp=tmp+differ;

            checkRs1(InstrEntry.rs1,differ);
            tmp=tmp+differ;
            checkRs2(InstrEntry.rs2,differ);
            tmp=tmp+differ;
            //checkRd(InstrEntry.rd,differ);
            //tmp=tmp+differ;

            checkFU(InstrEntry.unit,differ);
            tmp=tmp+differ;

            checkInstrType(InstrEntry.instr_type,differ);
            tmp=tmp+differ;
            checkImm(InstrEntry.result,differ);
            tmp=tmp+differ;
        end
    endtask

    task automatic checkLD;
        input instr_entry_t InstrEntry;
        output int tmp;
        begin
            int differ;
            tmp=0;
            
            checkValidBasic(InstrEntry,differ);
            tmp=tmp+differ;

            checkRs1(InstrEntry.rs1,differ);
            tmp=tmp+differ;
            //checkRs2(InstrEntry.rs2,differ);
            //tmp=tmp+differ;
            checkRd(InstrEntry.rd,differ);
            tmp=tmp+differ;

            checkFU(InstrEntry.unit,differ);
            tmp=tmp+differ;

            checkInstrType(InstrEntry.instr_type,differ);
            tmp=tmp+differ;
            checkImm(InstrEntry.result,differ);
            tmp=tmp+differ;

            checkMemSize(InstrEntry.mem_size,differ);
            tmp=tmp+differ;
            
            differ = (tmp > 0);
        end
    endtask

    task automatic checkST;
        input instr_entry_t InstrEntry;
        output int tmp;
        begin
            int differ;
            tmp=0;
            
            checkValidBasic(InstrEntry,differ);
            tmp=tmp+differ;

            checkRs1(InstrEntry.rs1,differ);
            tmp=tmp+differ;
            checkRs2(InstrEntry.rs2,differ);
            tmp=tmp+differ;
            //checkRd(InstrEntry.rd,differ);
            //tmp=tmp+differ;

            checkFU(InstrEntry.unit,differ);
            tmp=tmp+differ;

            checkInstrType(InstrEntry.instr_type,differ);
            tmp=tmp+differ;
            checkImm(InstrEntry.result,differ);
            tmp=tmp+differ;

            checkMemSize(InstrEntry.mem_size,differ);
            tmp=tmp+differ;
            
            differ = (tmp > 0);
        end
    endtask

    task automatic checkATOMICS;
        input instr_entry_t InstrEntry;
        output int tmp;
        begin
            int differ;
            tmp=0;
            
            checkValidBasic(InstrEntry,differ);
            tmp=tmp+differ;

            checkRs1(InstrEntry.rs1,differ);
            tmp=tmp+differ;
            checkRs2(InstrEntry.rs2,differ);
            tmp=tmp+differ;
            checkRd(InstrEntry.rd,differ);
            tmp=tmp+differ;

            checkFU(InstrEntry.unit,differ);
            tmp=tmp+differ;

            checkInstrType(InstrEntry.instr_type,differ);
            tmp=tmp+differ;

            checkMemSize(InstrEntry.mem_size,differ);
            tmp=tmp+differ;
            
            differ = (tmp > 0);
        end
    endtask

    task automatic checkALU;
        input instr_entry_t InstrEntry;
        input logic imm;
        output int tmp;
        begin
            int differ;
            tmp=0;
            
            checkValidBasic(InstrEntry,differ);
            tmp=tmp+differ;

            checkRs1(InstrEntry.rs1,differ);
            tmp=tmp+differ;
            if (imm) begin
                checkImm(InstrEntry.result,differ);
                tmp=tmp+differ;
            end else begin
                checkRs2(InstrEntry.rs2,differ);
                tmp=tmp+differ;
            end
            
            checkRd(InstrEntry.rd,differ);
            tmp=tmp+differ;

            checkFU(InstrEntry.unit,differ);
            tmp=tmp+differ;

            checkInstrType(InstrEntry.instr_type,differ);
            tmp=tmp+differ;
            //checkMemSize(InstrEntry.mem_size,differ);
            //tmp=tmp+differ;
            
            differ = (tmp > 0);
        end
    endtask

    task automatic checkSYSTEM;
        input instr_entry_t InstrEntry;
        input logic imm;
        output int tmp;
        begin
            int differ;
            tmp=0;
            
            checkValidBasic(InstrEntry,differ);
            tmp=tmp+differ;

            checkInstrType(InstrEntry.instr_type,differ);
            tmp=tmp+differ;
            
            differ = (tmp > 0);
        end
    endtask

    // this test checks the output when the input 
    // instr has an exception 
    task automatic test_sim_0;
        output int tmp;
        begin
            int differ;
            differ=0;
            tmp=0;
            $display("  %0tns:  *** test sim 0: exceptions in ***",$time);
            tb_test_name = "test_0_exception_in";
            
            tick();
            tb_decode_i.pc_inst = 40'h002010;
            tb_decode_i.inst = 32'hfff02013;
            tb_decode_i.valid = 1'b1;
            
            tb_decode_i.ex.cause = ST_AMO_PAGE_FAULT;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 1;

            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;
            half_tick();
            tmp=tmp+differ;
            checkValidEx(1,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(0,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            half_tick();
            //if (tb_req_cpu_icache_o.vaddr != 40'h0080000008 |
            //    tb_fetch_o.valid != 1'b0) begin
            //    tmp=1;
            //    $error("We should have the same addr");
            //end

        end
    endtask

    // test illegal instruction
    // we check the FP OPs
    // more tests can be added
    task automatic test_sim_1;
        output int tmp;
        begin
            int differ;
            logic [31:0] auxInstr;
            differ=0;
            tmp=0;
            $display("  %0tns:   *** test sim 1 illegal instr ***",$time);
            tb_test_name = "test_1_illegal_instr";
            
            tb_decode_i.pc_inst = 40'h002010;
            
            auxInstr = $urandom();

            //tb_decode_i.inst = {24'hffffff,1'b1,OP_FP};
            tb_decode_i.inst = {auxInstr[24:0],OP_FP};
            tb_decode_i.valid = 1'b1;
            
            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;

            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;
            
            half_tick();
            // Check enables
            checkIllegalInstr(differ);
            tmp=tmp+differ;
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(0,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            half_tick();

            // Second mini test
            auxInstr = $urandom();

            //tb_decode_i.inst = {24'hffffff,1'b1,OP_FP};
            tb_decode_i.inst = {auxInstr[24:0],OP_LOAD_FP};
            
            half_tick();
            // Check enables
            checkIllegalInstr(differ);
            tmp=tmp+differ;
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(0,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            half_tick();

             // Third mini test
            auxInstr = $urandom();

            //tb_decode_i.inst = {24'hffffff,1'b1,OP_FP};
            tb_decode_i.inst = {auxInstr[24:0],OP_STORE_FP};
            
            half_tick();
            // Check enables
            checkIllegalInstr(differ);
            tmp=tmp+differ;
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(0,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            half_tick();

        end
    endtask

    // test LUI
    task automatic test_sim_2;
        output int tmp;
        begin
            int differ;
            logic [31:0] auxInstr;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 2 LUI instr ***",$time);
            tb_test_name = "test_2_lui";
            
            tb_decode_i.pc_inst = 40'h002010;
            
            auxInstr = $urandom();

            tb_decode_i.inst = {{25{1'b1}},OP_LUI};
            //tb_decode_i.inst = {auxInstr[24:0],OP_LUI};
            tb_decode_i.valid = 1'b1;
            
            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;

            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;
            
            half_tick();
            
            tmp=tmp+differ;
            checkValidEx(0,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkImm({{52{1'b1}},{12{1'b0}}},differ);
            tmp=tmp+differ; 

            half_tick();

        end
    endtask

    // test LUI
    task automatic test_sim_3;
        output int tmp;
        begin
            int differ;
            logic [31:0] auxInstr;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 3 AUIPC instr ***",$time);
            tb_test_name = "test_3_auipc";
            
            tb_decode_i.pc_inst = 40'h002010;
            
            auxInstr = $urandom();

            tb_decode_i.inst = {{25{1'b1}},OP_AUIPC};
            //tb_decode_i.inst = {auxInstr[24:0],OP_AUIPC};
            tb_decode_i.valid = 1'b1;
            
            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;

            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;
            
            half_tick();
            
            tmp=tmp+differ;
            checkValidEx(0,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkImm({{52{1'b1}},{12{1'b0}}},differ);
            tmp=tmp+differ;

            half_tick();

        end
    endtask

    // test JAL
    task automatic test_sim_4;
        output int tmp;
        begin
            int differ;
            logic [31:0] auxInstr;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 4 JAL instr ***",$time);
            tb_test_name = "test_4_jal_1";

            $display ("Checking jal 1");
            
            tb_decode_i.pc_inst = 40'h002010;
            
            auxInstr = $urandom();
            //  278:	014000ef        jal 28c <test_3+0x18>
            // we are going 5to 28c-278=14
            tb_decode_i.inst = 32'h014000ef;
            tb_decode_i.valid = 1'b1;
            
            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;

            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;
            
            half_tick();
            
            tmp=tmp+differ;
            checkValidEx(0,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkImm(64'h14,differ);
            tmp=tmp+differ;

            half_tick();

            $display ("Checking jal 2");
            tb_test_name = "test_4_jal_2";

            // 2c8:	ffdff06f          	j	2c4 <ecall>
            tb_decode_i.inst = 32'hffdff06f;
            
            half_tick();
            
            tmp=tmp+differ;
            checkValidEx(0,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkImm(64'hFFFFFFFFFFFFFFFC,differ);
            tmp=tmp+differ;

            half_tick();

            $display ("Checking jal 3");
            tb_test_name = "test_4_jal_3";

            // 2c8:	ffdff06f          	j	2c4 <ecall>
            tb_decode_i.inst = 32'hffdff06f;
            
            half_tick();
            
            tmp=tmp+differ;
            checkValidEx(0,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkImm(64'hFFFFFFFFFFFFFFFC,differ);
            tmp=tmp+differ;

            half_tick();

            $display ("Checking jal 4: exception misaligned");
            tb_test_name = "test_4_jal_4";

            // 2c8:	ffdff06f          	j	2c4 <ecall>
            tb_decode_i.inst = 32'hfffff06f;
            
            half_tick();
            
            tmp=tmp+differ;
            if (tb_decode_instr_o.ex.valid != 1'b1 || 
                tb_decode_instr_o.ex.cause != INSTR_ADDR_MISALIGNED) begin
                `START_RED_PRINT
                    $error("Illegal instr not set correctly");
                `END_COLOR_PRINT
                differ=1;
            end else begin
                differ=0;
            end
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkImm(64'hFFFFFFFFFFFFFFFE,differ);
            tmp=tmp+differ;

            half_tick();

        end
    endtask

    // test JALR
    task automatic test_sim_5;
        output int tmp;
        begin
            int differ;
            int array[7] = '{1, 2, 3, 4, 5,6,7};
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 5 JALR instr ***",$time);
            tb_test_name = "test_5_jalr_1";
            
            tb_decode_i.pc_inst = 40'h002010;
            
            $display ("Checking jalr 1");
            //  278:	014000ef        jal 28c <test_3+0x18>
            // we are going 5to 28c-278=14
            tb_decode_i.inst = 32'h000309e7;
            //tb_decode_i.inst = {{25{1'b1}},OP_JAL};
            //tb_decode_i.inst = {auxInstr[24:0],OP_JAL};
            tb_decode_i.valid = 1'b1;
            
            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;

            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;
            
            half_tick();
            
            tmp=tmp+differ;
            checkValidEx(0,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkRs1(tb_decode_i.inst.common.rs1,differ);
            tmp=tmp+differ;
            checkImm({{52{tb_decode_i.inst[31]}},tb_decode_i.inst[31:20]},differ);
            tmp=tmp+differ;

            half_tick();

            $display ("Checking jalr 2");

            tb_test_name = "test_5_jalr_2";

            // 2c8:	ffdff06f          	j	2c4 <ecall>
            tb_decode_i.inst = 32'hffc109e7;
            
            half_tick();
            
            tmp=tmp+differ;
            checkValidEx(0,differ);
            tmp=tmp+differ;
            checkValidInst(1,differ);
            tmp=tmp+differ;
            checkWENA(1,differ);
            tmp=tmp+differ;
            checkSamePC(tb_decode_i.pc_inst,differ);
            tmp=tmp+differ;
            checkRd(tb_decode_i.inst.common.rd,differ);
            tmp=tmp+differ;
            checkImm({{52{tb_decode_i.inst[31]}},tb_decode_i.inst[31:20]},differ);
            tmp=tmp+differ;

            half_tick();

            tb_test_name = "test_5_jalr_3";

            // Check that func3 except 000 gets
            // exceptions 

            tb_decode_i.inst = 32'hffc109e7;

            $display ("Checking func3 space in JALR");
            for (int i = 0; i < $size(array); i++) begin
                $display ("Checking func3: %0d", array[i]);
                tb_decode_i.inst.itype.func3=array[i];
                half_tick();
                tmp=tmp+differ;
                checkValidInst(1,differ);
                tmp=tmp+differ;
                checkWENA(1,differ);
                tmp=tmp+differ;
                checkSamePC(tb_decode_i.pc_inst,differ);
                tmp=tmp+differ;
                checkRd(tb_decode_i.inst.common.rd,differ);
                tmp=tmp+differ;
                checkImm({{52{tb_decode_i.inst[31]}},tb_decode_i.inst[31:20]},differ);
                tmp=tmp+differ;
                checkIllegalInstr(differ);
                tmp=tmp+differ;
                half_tick();
            end
        end
    endtask

    // test BRANCH
    task automatic test_sim_6;
        output int tmp;
        begin
            int differ;
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 6 BRANCH instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002010;
            tb_decode_i.inst = 32'h04208063;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002010;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            expected_out.rs2 = tb_decode_i.inst.common.rs2;
            //expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b1;
            expected_out.use_pc = 1'b1;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_BRANCH;
            expected_out.regfile_we = 1'b0;
            expected_out.instr_type = BEQ;
            expected_out.result = 'h40;
            expected_out.signed_op = 1'b0;
            expected_out.result = 'h40;
            
            // Test BEQ
            $display ("Checking branch 1: BEQ");
            tb_test_name = "test_6_branch_beq";
            tb_decode_i.inst.btype.func3 = F3_BEQ;
            half_tick();
            
            checkBR(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test BNE
            $display ("Checking branch 2: BNE");
            tb_test_name = "test_6_branch_bne";
            tb_decode_i.inst.btype.func3 = F3_BNE;
            expected_out.instr_type = BNE;
            half_tick();

            checkBR(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test BLT
            $display ("Checking branch 3: BLT");
            tb_test_name = "test_6_branch_blt";
            tb_decode_i.inst.btype.func3 = F3_BLT;
            expected_out.instr_type = BLT;
            half_tick();

            checkBR(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test BGE
            $display ("Checking branch 4: BGE");
            tb_test_name = "test_6_branch_bge";
            tb_decode_i.inst.btype.func3 = F3_BGE;
            expected_out.instr_type = BGE;
            half_tick();

            checkBR(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test BGE
            $display ("Checking branch 5: BLTU");
            tb_test_name = "test_6_branch_bltu";
            tb_decode_i.inst.btype.func3 = F3_BLTU;
            expected_out.instr_type = BLTU;
            half_tick();

            checkBR(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test BGE
            $display ("Checking branch 6: BGEU");
            tb_test_name = "test_6_branch_bgeu";
            tb_decode_i.inst.btype.func3 = F3_BGEU;
            expected_out.instr_type = BGEU;
            half_tick();

            checkBR(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test if OP ==  010 and 011
            // we get illegal instruction
            $display ("Checking branch 7: OP 010");
            tb_test_name = "test_6_branch_010_exc";
            tb_decode_i.inst.btype.func3 = 3'b010;
            half_tick();
            checkIllegalInstr(differ);
            tmp=tmp+differ;           

            half_tick();

            $display ("Checking branch 8: OP 011");
            tb_test_name = "test_6_branch_011_exc";
            tb_decode_i.inst.btype.func3 = 3'b011;
            half_tick();
            checkIllegalInstr(differ);
            tmp=tmp+differ;           

            half_tick();

        end
    endtask

    // test LOAD
    task automatic test_sim_7;
        output int tmp;
        begin
            int differ;
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 7 LOAD instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002010;
            tb_decode_i.inst = 32'h0000b183;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002010;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            //expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b1;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_MEM;
            expected_out.regfile_we = 1'b1;
            expected_out.instr_type = BEQ;
            expected_out.result = 'h00;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;
            
            
            // Test LB
            $display ("Checking load 1: LB");
            tb_test_name = "test_7_load_lb";
            tb_decode_i.inst.itype.func3 = F3_LB;
            expected_out.instr_type = LB;
            expected_out.mem_size = F3_LB;
            half_tick();
            
            checkLD(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test LH
            $display ("Checking load 2: LH");
            tb_test_name = "test_7_load_lh";
            tb_decode_i.inst.itype.func3 = F3_LH;
            expected_out.instr_type = LH;
            expected_out.mem_size = F3_LH;
            half_tick();

            checkLD(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test LW
            $display ("Checking load 3: LW");
            tb_test_name = "test_7_load_lw";
            tb_decode_i.inst.itype.func3 = F3_LW;
            expected_out.instr_type = LW;
            expected_out.mem_size = F3_LW;
            half_tick();

            checkLD(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test LD
            $display ("Checking load 4: LD");
            tb_test_name = "test_7_load_ld";
            tb_decode_i.inst.itype.func3 = F3_LD;
            expected_out.instr_type = LD;
            expected_out.mem_size = F3_LD;
            half_tick();

            checkLD(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test LBU
            $display ("Checking load 5: LBU");
            tb_test_name = "test_7_load_lbu";
            tb_decode_i.inst.itype.func3 = F3_LBU;
            expected_out.instr_type = LBU;
            expected_out.mem_size = F3_LBU;
            half_tick();

            checkLD(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test LHU
            $display ("Checking load 6: LHU");
            tb_test_name = "test_7_load_lhu";
            tb_decode_i.inst.itype.func3 = F3_LHU;
            expected_out.instr_type = LHU;
            expected_out.mem_size = F3_LHU;
            half_tick();

            checkLD(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test LWU
            $display ("Checking load 7: LWU");
            tb_test_name = "test_7_load_lwu";
            tb_decode_i.inst.itype.func3 = F3_LWU;
            expected_out.instr_type = LWU;
            expected_out.mem_size = F3_LWU;
            half_tick();

            checkLD(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test if OP ==  111
            // we get illegal instruction
            $display ("Checking load 7: OP 111");
            tb_test_name = "test_7_load_111_exc";
            tb_decode_i.inst.btype.func3 = 3'b111;
            half_tick();
            checkIllegalInstr(differ);
            tmp=tmp+differ;           

            half_tick();

        end
    endtask

    // test STORE
    task automatic test_sim_8;
        output int tmp;
        begin
            int differ;
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 8 STORE instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002014;
            tb_decode_i.inst = 32'h02113023;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002014;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            expected_out.rs2 = tb_decode_i.inst.common.rs2;
            //expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b1;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_MEM;
            expected_out.regfile_we = 1'b0;
            //expected_out.instr_type = BEQ;
            expected_out.result = 32;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;
            
            
            // Test SB
            $display ("Checking store 1: SB");
            tb_test_name = "test_7_store_sb";
            tb_decode_i.inst.itype.func3 = F3_SB;
            expected_out.instr_type = SB;
            expected_out.mem_size = F3_SB;
            half_tick();
            
            checkLD(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SH
            $display ("Checking store 2: SH");
            tb_test_name = "test_7_store_sh";
            tb_decode_i.inst.itype.func3 = F3_SH;
            expected_out.instr_type = SH;
            expected_out.mem_size = F3_SH;
            half_tick();

            checkST(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SW
            $display ("Checking store 3: SW");
            tb_test_name = "test_7_store_sw";
            tb_decode_i.inst.itype.func3 = F3_SW;
            expected_out.instr_type = SW;
            expected_out.mem_size = F3_SW;
            half_tick();

            checkST(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SD
            $display ("Checking store 4: SD");
            tb_test_name = "test_7_store_sd";
            tb_decode_i.inst.itype.func3 = F3_SD;
            expected_out.instr_type = SD;
            expected_out.mem_size = F3_SD;
            half_tick();

            checkST(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test if OP ==  100
            // we get illegal instruction
            $display ("Checking store 5: OP 100");
            tb_test_name = "test_7_store_111_exc";
            tb_decode_i.inst.btype.func3 = 3'b100;
            half_tick();
            checkIllegalInstr(differ);
            tmp=tmp+differ;           

            half_tick();

            // Test if OP ==  101
            // we get illegal instruction
            $display ("Checking store 6: OP 101");
            tb_test_name = "test_7_store_111_exc";
            tb_decode_i.inst.btype.func3 = 3'b101;
            half_tick();
            checkIllegalInstr(differ);
            tmp=tmp+differ;           

            half_tick();

            // Test if OP ==  110
            // we get illegal instruction
            $display ("Checking store 7: OP 110");
            tb_test_name = "test_7_store_111_exc";
            tb_decode_i.inst.btype.func3 = 3'b110;
            half_tick();
            checkIllegalInstr(differ);
            tmp=tmp+differ;           

            half_tick();

            // Test if OP ==  111
            // we get illegal instruction
            $display ("Checking store 8: OP 111");
            tb_test_name = "test_7_store_111_exc";
            tb_decode_i.inst.btype.func3 = 3'b111;
            half_tick();
            checkIllegalInstr(differ);
            tmp=tmp+differ;           

            half_tick();

        end
    endtask

    // test ALU_I
    task automatic test_sim_9;
        output int tmp;
        begin
            int differ;
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 9 ALU_I instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002018;
            tb_decode_i.inst = 32'h00120213;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002018;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            //expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b1;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_ALU;
            expected_out.regfile_we = 1'b1;
            expected_out.result = 1;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;
            
            
            // Test ADDI
            $display ("Checking alui 1: ADDI");
            tb_test_name = "test_9_alui_addi";
            tb_decode_i.inst.itype.func3 = F3_ADDI;
            expected_out.instr_type = ADD;
            half_tick();
            
            checkALU(expected_out,1,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SLTI
            $display ("Checking alui 2: SLTI");
            tb_test_name = "test_9_alui_slti";
            tb_decode_i.inst.itype.func3 = F3_SLTI;
            expected_out.instr_type = SLT;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SLTIU
            $display ("Checking alui 3: SLTIU");
            tb_test_name = "test_9_alui_sltiu";
            tb_decode_i.inst.itype.func3 = F3_SLTIU;
            expected_out.instr_type = SLTU;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test XORI
            $display ("Checking alui 4: XORI");
            tb_test_name = "test_9_alui_xori";
            tb_decode_i.inst.itype.func3 = F3_XORI;
            expected_out.instr_type = XOR_INST;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test ORI
            $display ("Checking alui 5: ORI");
            tb_test_name = "test_9_alui_ori";
            tb_decode_i.inst.itype.func3 = F3_ORI;
            expected_out.instr_type = OR_INST;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test ANDI
            $display ("Checking alui 6: ANDI");
            tb_test_name = "test_9_alui_andi";
            tb_decode_i.inst.itype.func3 = F3_ANDI;
            expected_out.instr_type = AND_INST;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SLLI
            $display ("Checking alui 7: SLLI");
            tb_test_name = "test_9_alui_slli";
            tb_decode_i.inst.itype.func3 = F3_SLLI;
            expected_out.instr_type = SLL;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SRLScope
            $display ("Checking alui 8: SRLI");
            tb_test_name = "test_9_alui_srli";
            tb_decode_i.inst.itype.func3 = F3_SRLAI;
            tb_decode_i.inst.rtype.func7[31:26] = F7_64_NORMAL[6:1];
            expected_out.instr_type = SRL;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SRA
            $display ("Checking alui 9: SRAI");
            tb_test_name = "test_9_alui_srai";
            tb_decode_i.inst.itype.func3 = F3_SRLAI;
            tb_decode_i.inst.rtype.func7[31:26] = F7_SRAI_SUB_SRA[6:1];
            expected_out.instr_type = SRA;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();
        end
    endtask

    // test ALU
    task automatic test_sim_10;
        output int tmp;
        begin
            int differ;
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 10 ALU instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h00201C;
            tb_decode_i.inst = 32'h000000b3;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h00201C;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b0;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_ALU;
            expected_out.regfile_we = 1'b1;
            //expected_out.result = 1;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;
            
            
            // Test ADD
            $display ("Checking alu  1: ADD");
            tb_test_name = "test_10_alu_add";
            tb_decode_i.inst.rtype.func3 = F3_ADD_SUB;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = ADD;
            half_tick();
            
            checkALU(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SUB
            $display ("Checking alu  2: SUB");
            tb_test_name = "test_10_alu_sub";
            tb_decode_i.inst.rtype.func3 = F3_ADD_SUB;
            tb_decode_i.inst.rtype.func7 = F7_SRAI_SUB_SRA;
            expected_out.instr_type = SUB;
            half_tick();

            checkALU(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SLL
            $display ("Checking alu  3: SLL");
            tb_test_name = "test_10_alu_sll";
            tb_decode_i.inst.rtype.func3 = F3_SLL;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = SLL;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SLT
            $display ("Checking alu  4: SLT");
            tb_test_name = "test_10_alu_slt";
            tb_decode_i.inst.itype.func3 = F3_SLT;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = SLT;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SLTU
            $display ("Checking alu  5: SLTU");
            tb_test_name = "test_10_alu_sltu";
            tb_decode_i.inst.itype.func3 = F3_SLTU;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = SLTU;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test XOR
            $display ("Checking alu  6: XOR");
            tb_test_name = "test_10_alu_xor";
            tb_decode_i.inst.itype.func3 = F3_XOR;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = XOR_INST;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SRL
            $display ("Checking alu  7: SRL");
            tb_test_name = "test_10_alu_slli";
            tb_decode_i.inst.itype.func3 = F3_SRL_SRA;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = SRL;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SRA
            $display ("Checking alu  8: SRA");
            tb_test_name = "test_10_alu_srlai";
            tb_decode_i.inst.itype.func3 = F3_SRL_SRA;
            tb_decode_i.inst.rtype.func7 = F7_SRAI_SUB_SRA;
            expected_out.instr_type = SRA;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test OR
            $display ("Checking alu  9: OR");
            tb_test_name = "test_10_alu_or";
            tb_decode_i.inst.itype.func3 = F3_OR;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = OR_INST;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AND
            $display ("Checking alu 10: AND");
            tb_test_name = "test_10_alu_and";
            tb_decode_i.inst.itype.func3 = F3_AND;
            tb_decode_i.inst.rtype.func7 = F7_NORMAL;
            expected_out.instr_type = AND_INST;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();
        end
    endtask

    // test ALU_I_W
    task automatic test_sim_11;
        output int tmp;
        begin
            int differ;
            int array[5] = '{2,3,4,6,7};
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 11 ALU_I_W instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002020;
            tb_decode_i.inst = 32'h0090819b;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002020;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            //expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b1;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b1;
            expected_out.unit = UNIT_ALU;
            expected_out.regfile_we = 1'b1;
            expected_out.result = 9;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;
            
            
            // Test ADDIW
            $display ("Checking aluiw 1: ADDIW");
            tb_test_name = "test_11_aluiw_addiw";
            tb_decode_i.inst.itype.func3 = F3_64_ADDIW;
            tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = ADDW;
            half_tick();
            
            checkALU(expected_out,1,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SLTIW
            $display ("Checking aluiw 2: SLTIW");
            tb_test_name = "test_11_aluiw_sltiw";
            tb_decode_i.inst.itype.func3 = F3_64_SLLIW;
            tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = SLLW;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SRAIW
            $display ("Checking aluiw 3: SRAIW");
            tb_test_name = "test_11_aluiw_sraiw";
            tb_decode_i.inst.itype.func3 = F3_64_SRLIW_SRAIW;
            tb_decode_i.inst.rtype.func7 = F7_64_SRAIW_SUBW_SRAW;
            expected_out.instr_type = SRAW;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SRLIW
            $display ("Checking aluiw 4: SRLIW");
            tb_test_name = "test_11_aluiw_srliw";
            tb_decode_i.inst.itype.func3 = F3_64_SRLIW_SRAIW;
            tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = SRLW;
            half_tick();

            checkALU(expected_out,1,differ);
            tmp=tmp+differ;

            half_tick();

            // Check that func3 except the ones
            // above get exception 
            $display ("Checking func3 space in ALU_I_W");
            for (int i = 0; i < $size(array); i++) begin
                $display ("Checking func3: %b", array[i][2:0]);
                tb_decode_i.inst.itype.func3=array[i];
                half_tick();
                checkIllegalInstr(differ);
                tmp=tmp+differ;
                half_tick();
            end

            
        end
    endtask

    // test ALU_W
    task automatic test_sim_12;
        output int tmp;
        begin
            int differ;
            int array[5] = '{2,3,4,6,7};
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 12 ALU_W instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002024;
            tb_decode_i.inst = 32'h0020803b;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002024;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b0;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b1;
            expected_out.unit = UNIT_ALU;
            expected_out.regfile_we = 1'b1;
            //expected_out.result = 9;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;
            
            
            // Test ADDW
            $display ("Checking aluw 1: ADDW");
            tb_test_name = "test_12_aluw_addiw";
            tb_decode_i.inst.itype.func3 = F3_64_ADDW_SUBW;
            tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = ADDW;
            half_tick();
            
            checkALU(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SUBW
            $display ("Checking aluw 2: SUBW");
            tb_test_name = "test_12_aluw_sltiw";
            tb_decode_i.inst.itype.func3 = F3_64_ADDW_SUBW;
            tb_decode_i.inst.rtype.func7 = F7_64_SRAIW_SUBW_SRAW;
            expected_out.instr_type = SUBW;
            half_tick();

            checkALU(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SLLW
            $display ("Checking aluw 3: SLLW");
            tb_test_name = "test_12_aluw_sraiw";
            tb_decode_i.inst.itype.func3 = F3_64_SLLW;
            tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = SLLW;
            half_tick();

            checkALU(expected_out,0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SRLW
            $display ("Checking aluw 4: SRLW");
            tb_test_name = "test_12_aluw_srlw";
            tb_decode_i.inst.itype.func3 = F3_64_SRLW_SRAW;
            tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = SRLW;
            half_tick();

            checkALU(expected_out,0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test SRAW
            $display ("Checking aluw 5: SRAW");
            tb_test_name = "test_12_aluw_sraw";
            tb_decode_i.inst.itype.func3 = F3_64_SRLW_SRAW;
            tb_decode_i.inst.rtype.func7 = F7_64_SRAIW_SUBW_SRAW;
            expected_out.instr_type = SRAW;
            half_tick();

            checkALU(expected_out,0,differ);
            tmp=tmp+differ;

            half_tick();

            // Check that func3 except the ones
            // above get exception 
            $display ("Checking func3 space in ALU_W");
            for (int i = 0; i < $size(array); i++) begin
                $display ("Checking func3: %b", array[i][2:0]);
                tb_decode_i.inst.itype.func3=array[i];
                half_tick();
                checkIllegalInstr(differ);
                tmp=tmp+differ;
                half_tick();
            end
        end
    endtask

    // test FENCE
    task automatic test_sim_13;
        output int tmp;
        begin
            int differ;
            int array[6] = '{2,3,4,5,6,7};
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 13 FENCE instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002028;
            tb_decode_i.inst = 32'h0000100f;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002028;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            //expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b0;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_ALU;
            expected_out.regfile_we = 1'b0;
            //expected_out.result = 9;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b1;
            
            
            // Test FENCE
            $display ("Checking FENCE 1: FENCE");
            tb_test_name = "test_13_fence";
            tb_decode_i.inst.itype.func3 = F3_FENCE;
            //tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = FENCE;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test FENCE I
            $display ("Checking FENCE 2: FENCE I");
            tb_test_name = "test_13_fence_i";
            tb_decode_i.inst.itype.func3 = F3_FENCE_I;
            //tb_decode_i.inst.rtype.func7 = F7_64_NORMAL;
            expected_out.instr_type = FENCE_I;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Check that func3 except the ones
            // above get exception 
            $display ("Checking func3 space in FENCE");
            for (int i = 0; i < $size(array); i++) begin
                $display ("Checking func3: %b", array[i][2:0]);
                tb_decode_i.inst.itype.func3=array[i];
                half_tick();
                checkIllegalInstr(differ);
                tmp=tmp+differ;
                half_tick();
            end
        end
    endtask

    // test SYSTEM
    task automatic test_sim_14;
        output int tmp;
        begin
            int differ;
            int array[1] = '{4};
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 14 SYSTEM instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h00202C;
            tb_decode_i.inst = 32'h00000073;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h00202C;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b1;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_SYSTEM;
            expected_out.regfile_we = 1'b0;
            //expected_out.result = 9;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b1;
            
            
            // Test ECALL
            $display ("Checking SYSTEM  1: ECALL");
            tb_test_name = "test_14_sys_ecall";
            tb_decode_i.inst.rtype.func7 = F7_ECALL_EBREAK_URET;
            tb_decode_i.inst.rtype.func3 = F3_ECALL_EBREAK_ERET;
            tb_decode_i.inst.rtype.rs2 = RS2_ECALL_ERET;
            expected_out.instr_type = ECALL;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test EBREAK
            $display ("Checking SYSTEM  2: EBREAK");
            tb_test_name = "test_14_sys_ebreak";
            tb_decode_i.inst.rtype.func7 = F7_ECALL_EBREAK_URET;
            tb_decode_i.inst.rtype.func3 = F3_ECALL_EBREAK_ERET;
            tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = EBREAK;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test ERET
            $display ("Checking SYSTEM  3: ERET");
            tb_test_name = "test_14_sys_eret";
            tb_decode_i.inst.rtype.func7 = F7_ECALL_EBREAK_URET;
            tb_decode_i.inst.rtype.func3 = F3_ECALL_EBREAK_ERET;
            tb_decode_i.inst.rtype.rs2 = RS2_ECALL_ERET;
            expected_out.instr_type = ECALL;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test WFI
            $display ("Checking SYSTEM  7: WFI");
            tb_test_name = "test_14_sys_wfi";
            tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = 'h0;
            tb_decode_i.inst.rtype.rs2 = RS2_WFI;
            expected_out.instr_type = WFI;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SFENCE VM
            $display ("Checking SYSTEM  8: SFENCE VM");
            tb_test_name = "test_14_sys_sfencevm";
            tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = 'h0;
            tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = SFENCE_VMA;
            expected_out.stall_csr_fence = 1'b1;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            tb_decode_i.inst = 32'h34102ff3;

            // Test CSRRW
            $display ("Checking SYSTEM  9: CSRRW");
            tb_test_name = "test_14_sys_csrrw";
            //tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = F3_CSRRW;
            //tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = CSRRW;
            expected_out.regfile_we = 1'b1;
            expected_out.stall_csr_fence = 1'b1;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test CSRRS
            $display ("Checking SYSTEM 10: CSRRS");
            tb_test_name = "test_14_sys_csrrs";
            //tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = F3_CSRRS;
            //tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = CSRRS;
            expected_out.regfile_we = 1'b1;
            expected_out.stall_csr_fence = 1'b1;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test CSRRC
            $display ("Checking SYSTEM 11: CSRRC");
            tb_test_name = "test_14_sys_csrrc";
            //tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = F3_CSRRC;
            //tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = CSRRC;
            expected_out.regfile_we = 1'b1;
            expected_out.stall_csr_fence = 1'b1;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test CSRRWI
            $display ("Checking SYSTEM 12: CSRRWI");
            tb_test_name = "test_14_sys_csrrwi";
            //tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = F3_CSRRWI;
            //tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = CSRRWI;
            expected_out.regfile_we = 1'b1;
            expected_out.stall_csr_fence = 1'b1;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test CSRRSI
            $display ("Checking SYSTEM 13: CSRRSI");
            tb_test_name = "test_14_sys_csrrsi";
            //tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = F3_CSRRSI;
            //tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = CSRRSI;
            expected_out.regfile_we = 1'b1;
            expected_out.stall_csr_fence = 1'b1;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test CSRRCI
            $display ("Checking SYSTEM 13: CSRRCI");
            tb_test_name = "test_14_sys_csrrci";
            //tb_decode_i.inst.rtype.func7 = F7_SRET_WFI_ERET_SFENCE;
            tb_decode_i.inst.rtype.func3 = F3_CSRRCI;
            //tb_decode_i.inst.rtype.rs2 = RS2_EBREAK_SFENCEVM;
            expected_out.instr_type = CSRRCI;
            expected_out.regfile_we = 1'b1;
            expected_out.stall_csr_fence = 1'b1;
            half_tick();
            
            checkSYSTEM(expected_out,0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Check that func3 except the ones
            // above get exception 
            $display ("Checking func3 space in SYSTEM OPS");
            for (int i = 0; i < $size(array); i++) begin
                $display ("Checking func3: %b", array[i][2:0]);
                tb_decode_i.inst.itype.func3=array[i];
                half_tick();
                checkIllegalInstr(differ);
                tmp=tmp+differ;
                half_tick();
            end
        end
    endtask

    // test ATOMICS
    task automatic test_sim_15;
        output int tmp;
        begin
            int differ;
            int array[6] = '{0,1,4,5,6,7};
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 15 ATOMICS instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002030;
            tb_decode_i.inst = 32'h00b6b72f;
            tb_decode_i.inst.rtype.func3 = F3_ATOMICS;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002030;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            expected_out.rs2 = 'h0;//tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b0;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_MEM;
            expected_out.regfile_we = 1'b1;
            expected_out.instr_type = BEQ;
            expected_out.result = 'h00;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;
            
            
            // Test LRW
            $display ("Checking atomics  1: LR.W");
            tb_test_name = "test_15_load_lrw";
            tb_decode_i.inst.rtype.func7[31:27] = LR_W;
            tb_decode_i.inst.rtype.rs2 = 'h0;
            expected_out.instr_type = AMO_LRW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();
            
            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SCW
            $display ("Checking atomics  2: SC.W");
            tb_test_name = "test_15_load_scw";
            tb_decode_i.inst.rtype.func7[31:27] = SC_W;
            tb_decode_i.inst.rtype.rs2 = 'h0;
            expected_out.instr_type = AMO_SCW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();
            
            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test AMOSWAP
            $display ("Checking atomics  3: AMOSWAP.W");
            tb_test_name = "test_15_load_amoswapw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOSWAP_W;
            expected_out.instr_type = AMO_SWAPW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test AMOADD_W
            $display ("Checking atomics  4: AMOADD.W");
            tb_test_name = "test_15_atomics_amoaddw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOADD_W;
            expected_out.instr_type = AMO_ADDW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOXOR_W
            $display ("Checking atomics  5: AMOXOR.W");
            tb_test_name = "test_15_atomics_amoxorw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOXOR_W;
            expected_out.instr_type = AMO_XORW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOAND_W
            $display ("Checking atomics  6: AMOAND.W");
            tb_test_name = "test_15_atomics_amoandw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOAND_W;
            expected_out.instr_type = AMO_ANDW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOOR_W
            $display ("Checking atomics  7: AMOOR.W");
            tb_test_name = "test_15_atomics_amoorw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOOR_W;
            expected_out.instr_type = AMO_ORW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMIN_W
            $display ("Checking atomics  8: AMOMIN.W");
            tb_test_name = "test_15_atomics_amominw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMIN_W;
            expected_out.instr_type = AMO_MINW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMAX_W
            $display ("Checking atomics  9: AMOMAX.W");
            tb_test_name = "test_15_atomics_amomaxw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMAX_W;
            expected_out.instr_type = AMO_MAXW;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMINU_W
            $display ("Checking atomics 10: AMOMINU.W");
            tb_test_name = "test_15_atomics_amominuw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMINU_W;
            expected_out.instr_type = AMO_MINWU;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMAXU_W
            $display ("Checking atomics 11: AMOMAXU.W");
            tb_test_name = "test_15_atomics_amomaxuw";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMAXU_W;
            expected_out.instr_type = AMO_MAXWU;
            expected_out.mem_size = F3_ATOMICS;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            

            // Now RV64A
            tb_decode_i.inst.rtype.func3 = F3_ATOMICS_64;
            // Test LRD
            $display ("Checking atomics 12: LR.D");
            tb_test_name = "test_15_load_lrd";
            tb_decode_i.inst.rtype.func7[31:27] = LR_D;
            tb_decode_i.inst.rtype.rs2 = 'h0;
            expected_out.instr_type = AMO_LRD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();
            
            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test SCD
            $display ("Checking atomics 13: SC.D");
            tb_test_name = "test_15_load_scd";
            tb_decode_i.inst.rtype.func7[31:27] = SC_D;
            tb_decode_i.inst.rtype.rs2 = 'h0;
            expected_out.instr_type = AMO_SCD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();
            
            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test AMOSDAP
            $display ("Checking atomics 14: AMOSDAP.D");
            tb_test_name = "test_15_load_amosDapd";
            tb_decode_i.inst.rtype.func7[31:27] = AMOSWAP_D;
            expected_out.instr_type = AMO_SWAPD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test AMOADD_D
            $display ("Checking atomics 15: AMOADD.D");
            tb_test_name = "test_15_atomics_amoaddd";
            tb_decode_i.inst.rtype.func7[31:27] = AMOADD_D;
            expected_out.instr_type = AMO_ADDD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOXOR_D
            $display ("Checking atomics 16: AMOXOR.D");
            tb_test_name = "test_15_atomics_amoxord";
            tb_decode_i.inst.rtype.func7[31:27] = AMOXOR_D;
            expected_out.instr_type = AMO_XORD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOAND_D
            $display ("Checking atomics 17: AMOAND.D");
            tb_test_name = "test_15_atomics_amoandd";
            tb_decode_i.inst.rtype.func7[31:27] = AMOAND_D;
            expected_out.instr_type = AMO_ANDD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOOR_D
            $display ("Checking atomics 18: AMOOR.D");
            tb_test_name = "test_15_atomics_amoord";
            tb_decode_i.inst.rtype.func7[31:27] = AMOOR_D;
            expected_out.instr_type = AMO_ORD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMIN_D
            $display ("Checking atomics 19: AMOMIN.D");
            tb_test_name = "test_15_atomics_amomind";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMIN_D;
            expected_out.instr_type = AMO_MIND;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMAX_D
            $display ("Checking atomics 20: AMOMAX.D");
            tb_test_name = "test_15_atomics_amomaxd";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMAX_D;
            expected_out.instr_type = AMO_MAXD;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMINU_D
            $display ("Checking atomics 21: AMOMINU.D");
            tb_test_name = "test_15_atomics_amominud";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMINU_D;
            expected_out.instr_type = AMO_MINDU;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Test AMOMAXU_D
            $display ("Checking atomics 22: AMOMAXU.D");
            tb_test_name = "test_15_atomics_amomaxud";
            tb_decode_i.inst.rtype.func7[31:27] = AMOMAXU_D;
            expected_out.instr_type = AMO_MAXDU;
            expected_out.mem_size = F3_ATOMICS_64;
            half_tick();

            checkATOMICS(expected_out,differ);
            tmp=tmp+differ;

            half_tick();

            // Check that func3 except 010 or 011
            // get exceptions
            $display ("Checking func3 space in ATOMICS OPS");
            for (int i = 0; i < $size(array); i++) begin
                $display ("Checking func3: %b", array[i][2:0]);
                tb_decode_i.inst.itype.func3=array[i];
                half_tick();
                checkIllegalInstr(differ);
                tmp=tmp+differ;
                half_tick();
            end

        end
    endtask

    // test MUL/DIV
    task automatic test_sim_16;
        output int tmp;
        begin
            int differ;
            int array[3] = '{1,2,3};
            instr_entry_t expected_out;
            differ=0;
            tmp=0;
            $display(" %0tns:   *** test sim 16 MUL/DIV instr ***",$time);
            
            tb_decode_i.pc_inst = 40'h002034;
            tb_decode_i.inst = 32'h02208033;
            tb_decode_i.valid = 1'b1;

            tb_decode_i.ex.cause = NONE;
            tb_decode_i.ex.origin = 0;
            tb_decode_i.ex.valid = 0;
            
            tb_decode_i.bpred.decision = PRED_NOT_TAKEN;
            tb_decode_i.bpred.pred_addr = 0;

            // Set expected initial values 
            expected_out.valid = 1'b1;
            expected_out.pc = 40'h002034;
            expected_out.ex.valid = 1'b0;
            expected_out.rs1 = tb_decode_i.inst.common.rs1;
            expected_out.rs2 = tb_decode_i.inst.common.rs2;
            expected_out.rd = tb_decode_i.inst.common.rd;
            expected_out.use_imm = 1'b0;
            expected_out.use_pc = 1'b0;
            expected_out.op_32 = 1'b0;
            expected_out.unit = UNIT_MUL;
            expected_out.regfile_we = 1'b1;
            expected_out.instr_type = MUL;
            expected_out.result = 'h00;
            expected_out.signed_op = 1'b0;
            expected_out.stall_csr_fence = 1'b0;

            // Test MUL
            $display ("Checking mul/divs  1: MUL");
            tb_test_name = "test_16_mul_div_mul";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_MUL;
            expected_out.instr_type = MUL;
            half_tick();
            
            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test MULH
            $display ("Checking mul/divs  2: MULH");
            tb_test_name = "test_16_mul_div_mulh";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_MULH;
            expected_out.instr_type = MULH;
            half_tick();
            
            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test MULHSU
            $display ("Checking mul/divs  3: MULHSU");
            tb_test_name = "test_16_mul_div_mulhsu";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_MULHSU;
            expected_out.instr_type = MULHSU;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Test MULHU
            $display ("Checking mul/divs  4: MULHU");
            tb_test_name = "test_16_mul_div_mulhu";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_MULHU;
            expected_out.instr_type = MULHU;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Change unit
            expected_out.unit = UNIT_DIV;

            // Test DIV
            $display ("Checking mul/divs  5: DIV");
            tb_test_name = "test_16_mul_div_div";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_DIV;
            expected_out.instr_type = DIV;
            expected_out.signed_op = 1'b1;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test DIVU
            $display ("Checking mul/divs  6: DIVU");
            tb_test_name = "test_16_mul_div_divu";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_DIVU;
            expected_out.instr_type = DIVU;
            expected_out.signed_op = 1'b0;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test REM
            $display ("Checking mul/divs  7: REM");
            tb_test_name = "test_16_mul_div_rem";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_REM;
            expected_out.instr_type = REM;
            expected_out.signed_op = 1'b1;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test REMU
            $display ("Checking mul/divs  8: REMU");
            tb_test_name = "test_15_atomics_remu";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_REMU;
            expected_out.instr_type = REMU;
            expected_out.signed_op = 1'b0;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Put OP ALU W
            tb_decode_i.inst.common.opcode = OP_ALU_W;
            expected_out.op_32 = 1'b1;
            // Change unit
            expected_out.unit = UNIT_MUL;

            // Test MULW
            $display ("Checking mul/divs  9: MULW");
            tb_test_name = "test_16_mul_div_mulw";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_MUL;
            expected_out.instr_type = MULW;
            half_tick();
            
            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;
            
            half_tick();

            // Change unit
            expected_out.unit = UNIT_DIV;

            // Test DIVW
            $display ("Checking mul/divs 10: DIVW");
            tb_test_name = "test_16_mul_div_divw";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_DIV;
            expected_out.instr_type = DIVW;
            expected_out.signed_op = 1'b1;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test DIVUW
            $display ("Checking mul/divs 11: DIVUW");
            tb_test_name = "test_16_mul_div_divuw";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_DIVU;
            expected_out.instr_type = DIVUW;
            expected_out.signed_op = 1'b0;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test REMW
            $display ("Checking mul/divs 13: REMW");
            tb_test_name = "test_16_mul_div_remw";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_REM;
            expected_out.instr_type = REMW;
            expected_out.signed_op = 1'b1;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Test REMUW
            $display ("Checking mul/divs 14: REMUW");
            tb_test_name = "test_16_mul_div_remuw";
            tb_decode_i.inst.rtype.func7 = F7_MUL_DIV;
            tb_decode_i.inst.itype.func3 = F3_REMU;
            expected_out.instr_type = REMUW;
            expected_out.signed_op = 1'b0;
            half_tick();

            checkALU(expected_out,1'b0,differ);
            tmp=tmp+differ;

            half_tick();

            // Check that func3 except the ones above
            // get exceptions
            $display ("Checking func3 space in MUL/DIV OPS W");
            for (int i = 0; i < $size(array); i++) begin
                $display ("Checking func3: %b", array[i][2:0]);
                tb_decode_i.inst.itype.func3=array[i];
                half_tick();
                checkIllegalInstr(differ);
                tmp=tmp+differ;
                half_tick();
            end

        end
    endtask

//***task automatic test_sim***
    task automatic test_sim;
        begin
            int tmp;
            // Test 0
            // check exceptions Input
            test_sim_0(tmp);
            check_out(0,tmp);
            //  Test 1 
            // check exception illegal instruction
            test_sim_1(tmp);
            check_out(1,tmp);
            // Test 2
            // LUI instruction
            test_sim_2(tmp);
            check_out(2,tmp);
            // Test 3
            // AUIPC instruction
            test_sim_3(tmp);
            check_out(3,tmp);
            // Test 4
            // JAL instruction
            test_sim_4(tmp);
            check_out(4,tmp);
            // Test 5
            // JALR instruction
            test_sim_5(tmp);
            check_out(5,tmp);
            // Test 6
            // Branch instruction
            test_sim_6(tmp);
            check_out(6,tmp);
            // Test 7
            // Load instruction
            test_sim_7(tmp);
            check_out(7,tmp);
            // Test 8
            // Store instruction
            test_sim_8(tmp);
            check_out(8,tmp);
            // Test 9
            // ALUI instruction
            test_sim_9(tmp);
            check_out(9,tmp);
            // Test 10
            // ALU instruction
            test_sim_10(tmp);
            check_out(10,tmp);
            // Test 11
            // ALU I W instruction
            test_sim_11(tmp);
            check_out(11,tmp);
            // Test 12
            // ALU W instruction
            test_sim_12(tmp);
            check_out(12,tmp);
            // Test 13
            // FENCE instruction
            test_sim_13(tmp);
            check_out(13,tmp);
            // Test 14
            // SYSTEM instruction
            test_sim_14(tmp);
            check_out(14,tmp);
            // Test 15
            // ATOMICS instruction
            test_sim_15(tmp);
            check_out(15,tmp);
            // Test 16
            // MUL/DIV instruction
            test_sim_16(tmp);
            check_out(16,tmp);
            
        end
    endtask

//***init_sim***
//The tasks that compose my testbench are executed here.
    initial begin
        init_sim();
        init_dump();
        //reset_dut();
        test_sim();
        $finish;
    end

endmodule
//`default_nettype wire
