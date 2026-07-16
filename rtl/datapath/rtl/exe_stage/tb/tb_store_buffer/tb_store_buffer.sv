// tb_store_buffer.sv
// Testbench for store_buffer collision detector fix.
//
// Bug: collision detector only checked data_rs1[11:0] (page offset),
// causing false stalls for stores/loads on different physical pages.
//
// Fix: add a pre-check on the upper physical address bits (page number)
// before checking the in-page offset.
//
// Tests:
//  1. FALSE POSITIVE TEST: store at 0x8000_1008, load from 0xC000_0008
//     → same page offset (0x008), different physical pages → NO collision expected.
//  2. TRUE POSITIVE TEST:  store at 0x8000_1008, load from 0x8000_1000
//     → same physical page (0x8000_1xxx), overlapping 8-byte access → COLLISION expected.

`timescale 1ns/1ps

module tb_store_buffer;
    import drac_pkg::*;

    // DUT signals
    logic                clk_i;
    logic                rstn_i;
    logic                write_enable_i;
    rr_exe_mem_instr_t   instruction_i;
    logic                flush_i;
    logic                advance_head_i;
    bus64_t              load_addr_i;
    logic [3:0]          load_size_i;
    rr_exe_mem_instr_t   finish_instr_o;
    logic                empty_o;
    logic                full_o;
    logic                collision_o;

    // DUT instantiation
    store_buffer dut (
        .clk_i          (clk_i),
        .rstn_i         (rstn_i),
        .write_enable_i (write_enable_i),
        .instruction_i  (instruction_i),
        .flush_i        (flush_i),
        .advance_head_i (advance_head_i),
        .load_addr_i    (load_addr_i),
        .load_size_i    (load_size_i),
        .finish_instr_o (finish_instr_o),
        .empty_o        (empty_o),
        .full_o         (full_o),
        .collision_o    (collision_o)
    );

    // Clock: 10ns period
    initial clk_i = 0;
    always #5 clk_i = ~clk_i;

    // Test tracking
    int tests_passed = 0;
    int tests_failed = 0;

    task reset_dut();
        rstn_i        = 0;
        flush_i       = 0;
        advance_head_i= 0;
        write_enable_i= 0;
        instruction_i = '0;
        load_addr_i   = '0;
        load_size_i   = '0;
        @(posedge clk_i); #1;
        rstn_i = 1;
        @(posedge clk_i); #1;
    endtask

    task write_store(input bus64_t store_phys_addr, input logic [3:0] size);
        instruction_i             = '0;
        instruction_i.instr.valid = 1'b1;
        instruction_i.data_rs1    = store_phys_addr;
        instruction_i.instr.mem_size = size;
        write_enable_i            = 1'b1;
        @(posedge clk_i); #1;
        write_enable_i            = 0;
        instruction_i             = '0;
    endtask

    task check_collision(
        input bus64_t   load_phys_addr,
        input logic [3:0] size,
        input logic     expect_collision,
        input string    test_name
    );
        load_addr_i = load_phys_addr;
        load_size_i = size;
        #1; // combinational settling time
        if (collision_o === expect_collision) begin
            $display("PASS: %s  (collision_o=%0b, expected=%0b)", test_name, collision_o, expect_collision);
            tests_passed++;
        end else begin
            $display("FAIL: %s  (collision_o=%0b, expected=%0b)", test_name, collision_o, expect_collision);
            tests_failed++;
        end
    endtask

    initial begin
        $display("=== store_buffer collision detector tests ===");

        // ---------------------------------------------------------------
        // TEST 1: False positive check (different physical pages, same offset)
        //   Store at 0x8000_1008 (page 0x8000_1, offset 0x008)
        //   Load  from 0xC000_0008 (page 0xC000_0, offset 0x008)
        //   → Different pages → should NOT collide
        // ---------------------------------------------------------------
        reset_dut();
        write_store(64'h8000_1008, 4'b0011); // 8-byte store
        check_collision(
            64'hC000_0008,  // load on completely different physical page
            4'b0011,        // 8-byte load
            1'b0,           // expect NO collision
            "Test 1: Different physical pages, same page offset -> NO collision"
        );

        // Flush between tests
        flush_i = 1; @(posedge clk_i); #1; flush_i = 0;

        // ---------------------------------------------------------------
        // TEST 2: True positive check (same physical page, overlapping access)
        //   Store at 0x8000_1008 (8-byte store covers 0x1008-0x100F)
        //   Load  from 0x8000_1008 (8-byte load at same address)
        //   → Same page AND same offset → MUST collide
        // ---------------------------------------------------------------
        reset_dut();
        write_store(64'h8000_1008, 4'b0011); // 8-byte store
        check_collision(
            64'h8000_1008,  // load at identical physical address
            4'b0011,        // 8-byte load
            1'b1,           // expect COLLISION
            "Test 2: Same physical page and same offset -> COLLISION"
        );

        // Flush between tests
        flush_i = 1; @(posedge clk_i); #1; flush_i = 0;

        // ---------------------------------------------------------------
        // TEST 3: Same page offset, many different upper pages - all should be false
        // ---------------------------------------------------------------
        reset_dut();
        write_store(64'h0000_A010, 4'b0010); // 4-byte store at page 0xA, offset 0x010
        check_collision(64'h0001_0010, 4'b0010, 1'b0, "Test 3a: Page 0x1 vs 0xA, same offset -> NO collision");
        check_collision(64'h0002_0010, 4'b0010, 1'b0, "Test 3b: Page 0x2 vs 0xA, same offset -> NO collision");
        check_collision(64'h1000_0010, 4'b0010, 1'b0, "Test 3c: Page 0x10000 vs 0xA, same offset -> NO collision");
        check_collision(64'h0000_A010, 4'b0010, 1'b1, "Test 3d: Exact same address -> COLLISION");

        // ---------------------------------------------------------------
        // SUMMARY
        // ---------------------------------------------------------------
        $display("");
        $display("=== Results: %0d passed, %0d failed ===", tests_passed, tests_failed);
        if (tests_failed == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
