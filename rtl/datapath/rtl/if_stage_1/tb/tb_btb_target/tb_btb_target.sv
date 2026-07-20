`timescale 1ns/1ps

import riscv_pkg::*;
import drac_pkg::*;

module tb_if_stage_btb_target;

    logic                clk_i;
    logic                rstn_i;
    logic                v_mode_i;
    phy_addr_t           reset_addr_i;

    logic                stall_i;
    logic                stall_debug_i;
    cu_if_t              cu_if_i;

    logic                invalidate_icache_i;
    logic                invalidate_buffer_i;
    logic                en_translation_i;
    logic                en_g_translation_i;

    resp_icache_cpu_t    resp_icache_cpu_i;
    addrPC_t             pc_jump_i;
    exe_if_branch_pred_t exe_if_branch_pred_i;
    logic                retry_fetch_i;

    req_cpu_icache_t     req_cpu_icache_o;
    if_1_if_2_stage_t    fetch_o;

    localparam addrPC_t BRANCH_PC   = 64'h0000000080000000;
    localparam addrPC_t TARGET_PC   = 64'h0000000080000100;
    localparam addrPC_t FALLTHROUGH = 64'h0000000080000004;

    if_stage_1 dut (
        .clk_i                   (clk_i),
        .rstn_i                  (rstn_i),
        .v_mode_i                (v_mode_i),
        .reset_addr_i            (reset_addr_i),
        .stall_i                 (stall_i),
        .stall_debug_i           (stall_debug_i),
        .cu_if_i                 (cu_if_i),
        .invalidate_icache_i     (invalidate_icache_i),
        .invalidate_buffer_i     (invalidate_buffer_i),
        .en_translation_i        (en_translation_i),
        .en_g_translation_i      (en_g_translation_i),
        .resp_icache_cpu_i       (resp_icache_cpu_i),
        .pc_jump_i               (pc_jump_i),
        .exe_if_branch_pred_i    (exe_if_branch_pred_i),
        .retry_fetch_i           (retry_fetch_i),
        .req_cpu_icache_o        (req_cpu_icache_o),
        .fetch_o                 (fetch_o)
    );

    initial clk_i = 1'b0;
    always #2 clk_i = ~clk_i;

    task automatic update_branch(
        input logic    taken,
        input addrPC_t resolved_next_pc
    );
        begin
            @(negedge clk_i);

            exe_if_branch_pred_i = '0;

            exe_if_branch_pred_i.pc_execution =
                BRANCH_PC;

            /*
             * Actual next PC:
             *   taken     -> TARGET_PC
             *   not taken -> FALLTHROUGH
             */
            exe_if_branch_pred_i.branch_addr_result_exe =
                resolved_next_pc;

            /*
             * The taken target remains TARGET_PC regardless of
             * whether this particular execution was taken.
             */
            exe_if_branch_pred_i.branch_addr_target_exe =
                TARGET_PC;

            exe_if_branch_pred_i.branch_taken_result_exe =
                taken;

            exe_if_branch_pred_i.is_branch_exe =
                1'b1;

            @(posedge clk_i);
            #1;

            exe_if_branch_pred_i.is_branch_exe =
                1'b0;
        end
    endtask

    initial begin
        rstn_i               = 1'b0;
        v_mode_i             = 1'b0;
        reset_addr_i         = phy_addr_t'(BRANCH_PC);

        stall_i              = 1'b0;
        stall_debug_i        = 1'b0;
        cu_if_i              = '0;

        invalidate_icache_i  = 1'b0;
        invalidate_buffer_i  = 1'b0;
        en_translation_i     = 1'b0;
        en_g_translation_i   = 1'b0;

        resp_icache_cpu_i    = '0;
        pc_jump_i            = '0;
        exe_if_branch_pred_i = '0;
        retry_fetch_i        = 1'b0;

        /*
         * Keep Fetch at the branch PC while training.
         */
        cu_if_i.next_pc = NEXT_PC_SEL_KEEP_PC;

        repeat (2) @(posedge clk_i);

        @(negedge clk_i);
        rstn_i = 1'b1;

        /*
         * Train direction state:
         * 01 -> 10 -> 11 -> 11 (saturated)
         *
         * Store TARGET_PC in the branch-target buffer.
         */
        update_branch(1'b1, TARGET_PC);
        update_branch(1'b1, TARGET_PC);
        update_branch(1'b1, TARGET_PC);

        /*
         * One not-taken outcome changes the direction counter:
         * 11 -> 10
         *
         * The predictor therefore still predicts taken, and its
         * stored target must remain TARGET_PC.
         */
        update_branch(1'b0, FALLTHROUGH);

        @(negedge clk_i);
        cu_if_i.next_pc = NEXT_PC_SEL_BP_OR_PC_4;

        @(posedge clk_i);
        #1;

        $display(
            "Fetch PC after prediction: 0x%h",
            req_cpu_icache_o.vaddr
        );

        if (req_cpu_icache_o.vaddr !==
            TARGET_PC[PHY_VIRT_MAX_ADDR_SIZE-1:0]) begin

            $fatal(
                1,
                "Expected branch target 0x%h, got 0x%h",
                TARGET_PC,
                req_cpu_icache_o.vaddr
            );
        end

        $display(
            "PASS: not-taken execution preserved the BTB target."
        );

        $finish;
    end

endmodule
