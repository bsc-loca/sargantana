`timescale 1ns/1ps

import riscv_pkg::*;
import drac_pkg::*;

module tb_gstage_map_check;

    localparam int CLK_PERIOD = 4;

    localparam phy_addr_t RESET_PC =
        phy_addr_t'(64'h0000000040000000);

    localparam addrPC_t UNMAPPED_PC =
        addrPC_t'(64'h0000000000200000);

    function automatic drac_cfg_t make_test_config();
        drac_cfg_t cfg;

        cfg = DracDefaultConfig;

        cfg.NMappedSections = 1;
        cfg.InitMappedBase = '0;
        cfg.InitMappedEnd = '0;

        cfg.InitMappedBase[0] =
            addr_t'(64'h0000000040000000);

        cfg.InitMappedEnd[0] =
            addr_t'(64'h0000000080000000);

        return cfg;
    endfunction

    localparam drac_cfg_t TEST_CONFIG =
        make_test_config();

    logic clk_i;
    logic rstn_i;
    logic v_mode_i;

    phy_addr_t reset_addr_i;

    logic stall_i;
    logic stall_debug_i;
    cu_if_t cu_if_i;

    logic invalidate_icache_i;
    logic invalidate_buffer_i;

    logic en_translation_i;
    logic en_g_translation_i;

    resp_icache_cpu_t resp_icache_cpu_i;
    addrPC_t pc_jump_i;
    exe_if_branch_pred_t exe_if_branch_pred_i;
    logic retry_fetch_i;

    req_cpu_icache_t req_cpu_icache_o;
    if_1_if_2_stage_t fetch_o;

    int failures;

    if_stage_1 #(
        .DracCfg(TEST_CONFIG)
    ) dut (
        .clk_i                (clk_i),
        .rstn_i               (rstn_i),
        .v_mode_i             (v_mode_i),
        .reset_addr_i         (reset_addr_i),

        .stall_i              (stall_i),
        .stall_debug_i        (stall_debug_i),
        .cu_if_i              (cu_if_i),

        .invalidate_icache_i  (invalidate_icache_i),
        .invalidate_buffer_i  (invalidate_buffer_i),

        .en_translation_i     (en_translation_i),
        .en_g_translation_i   (en_g_translation_i),

        .resp_icache_cpu_i    (resp_icache_cpu_i),
        .pc_jump_i            (pc_jump_i),
        .exe_if_branch_pred_i (exe_if_branch_pred_i),
        .retry_fetch_i        (retry_fetch_i),

        .req_cpu_icache_o     (req_cpu_icache_o),
        .fetch_o              (fetch_o)
    );

    initial begin
        clk_i = 1'b0;
    end

    always #(CLK_PERIOD / 2) begin
        clk_i = ~clk_i;
    end

    task automatic initialize_inputs;
        begin
            rstn_i = 1'b0;
            v_mode_i = 1'b0;
            reset_addr_i = RESET_PC;

            stall_i = 1'b0;
            stall_debug_i = 1'b0;

            cu_if_i = '0;
            cu_if_i.next_pc = NEXT_PC_SEL_KEEP_PC;

            invalidate_icache_i = 1'b0;
            invalidate_buffer_i = 1'b0;

            en_translation_i = 1'b0;
            en_g_translation_i = 1'b0;

            resp_icache_cpu_i = '0;
            pc_jump_i = '0;
            exe_if_branch_pred_i = '0;
            retry_fetch_i = 1'b0;
        end
    endtask

    task automatic reset_dut;
        begin
            rstn_i = 1'b0;

            repeat (2) begin
                @(posedge clk_i);
            end

            @(negedge clk_i);
            rstn_i = 1'b1;

            @(posedge clk_i);
            #1;
        end
    endtask

    task automatic jump_to(
        input addrPC_t address
    );
        begin
            @(negedge clk_i);

            pc_jump_i = address;
            cu_if_i.next_pc = NEXT_PC_SEL_JUMP;

            @(posedge clk_i);
            #1;

            cu_if_i.next_pc = NEXT_PC_SEL_KEEP_PC;
        end
    endtask

    task automatic test_bare_mode_rejects_unmapped;
        begin
            $display("");
            $display(
                "TEST 1: bare mode rejects an unmapped address"
            );

            v_mode_i = 1'b0;
            en_translation_i = 1'b0;
            en_g_translation_i = 1'b0;

            jump_to(UNMAPPED_PC);

            if (req_cpu_icache_o.vaddr !==
                UNMAPPED_PC[PHY_VIRT_MAX_ADDR_SIZE-1:0]) begin

                failures = failures + 1;

                $display(
                    "FAIL: wrong PC: expected=%h actual=%h",
                    UNMAPPED_PC[PHY_VIRT_MAX_ADDR_SIZE-1:0],
                    req_cpu_icache_o.vaddr
                );
            end

            if (req_cpu_icache_o.valid !== 1'b0) begin
                failures = failures + 1;

                $display(
                    "FAIL: bare mode should suppress the fetch, valid=%b",
                    req_cpu_icache_o.valid
                );
            end

            if (fetch_o.ex.valid !== 1'b1) begin
                failures = failures + 1;

                $display(
                    "FAIL: bare mode should raise an exception, valid=%b",
                    fetch_o.ex.valid
                );
            end

            if (fetch_o.ex.cause !== INSTR_ACCESS_FAULT) begin
                failures = failures + 1;

                $display(
                    "FAIL: expected INSTR_ACCESS_FAULT, cause=%h",
                    fetch_o.ex.cause
                );
            end

            if ((req_cpu_icache_o.vaddr ===
                 UNMAPPED_PC[PHY_VIRT_MAX_ADDR_SIZE-1:0]) &&
                (req_cpu_icache_o.valid === 1'b0) &&
                (fetch_o.ex.valid === 1'b1) &&
                (fetch_o.ex.cause === INSTR_ACCESS_FAULT)) begin

                $display(
                    "PASS: bare mode correctly rejected the address"
                );
            end
        end
    endtask

    task automatic test_gstage_mode_forwards_unmapped;
        begin
            $display("");
            $display(
                "TEST 2: G-stage-only mode forwards an unmapped GPA"
            );

            v_mode_i = 1'b1;
            en_translation_i = 1'b0;
            en_g_translation_i = 1'b1;

            jump_to(UNMAPPED_PC);

            if (req_cpu_icache_o.vaddr !==
                UNMAPPED_PC[PHY_VIRT_MAX_ADDR_SIZE-1:0]) begin

                failures = failures + 1;

                $display(
                    "FAIL: wrong PC: expected=%h actual=%h",
                    UNMAPPED_PC[PHY_VIRT_MAX_ADDR_SIZE-1:0],
                    req_cpu_icache_o.vaddr
                );
            end

            if (req_cpu_icache_o.valid !== 1'b1) begin
                failures = failures + 1;

                $display(
                    "FAIL: G-stage-only mode should forward the GPA, valid=%b",
                    req_cpu_icache_o.valid
                );
            end

            if (fetch_o.ex.valid !== 1'b0) begin
                failures = failures + 1;

                $display(
                    "FAIL: G-stage-only mode raised an early exception: valid=%b cause=%h",
                    fetch_o.ex.valid,
                    fetch_o.ex.cause
                );
            end

            if ((req_cpu_icache_o.vaddr ===
                 UNMAPPED_PC[PHY_VIRT_MAX_ADDR_SIZE-1:0]) &&
                (req_cpu_icache_o.valid === 1'b1) &&
                (fetch_o.ex.valid === 1'b0)) begin

                $display(
                    "PASS: G-stage-only mode forwarded the GPA"
                );
            end
        end
    endtask

    initial begin
        failures = 0;

        initialize_inputs();
        reset_dut();

        test_bare_mode_rejects_unmapped();
        test_gstage_mode_forwards_unmapped();

        if (failures == 0) begin
            $display("");
            $display("All tests passed");
            $finish;
        end else begin
            $fatal(1, "%0d test checks failed", failures);
        end
    end

endmodule
