//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_mul_unit.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Rubén Langarita
* Email(s)       : ruben.langarita@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
* -----------------------------------------------
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns
`default_nettype none

`include "colors.vh"

module tb_mul_unit();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
//***DUT parameters***    
    //parameter TB_DATA_WIDTH = 32;
    //parameter TB_WEIGHTS_WIDTH = 7;
    //parameter TB_N_CORES = 1;
    //parameter TB_CORE_EVENTS = 1;

//-----------------------------
// Signals
//-----------------------------
reg tb_clk_i;
reg tb_rstn_i;
logic tb_wb_exception_i;
logic tb_valid_mul;
logic [2:0] tb_funct3_field;
logic tb_int_32;
logic [63:0] tb_source_1;
logic [63:0] tb_source_2;
reg [63:0] tb_mul_result;
reg tb_lock_mul;
reg tb_ready_mul;

//-----------------------------
// Module
//-----------------------------

mul_unit mul_unit_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .kill_mul_i(tb_wb_exception_i),
    .request_i(tb_valid_mul),
    .func3_i(tb_funct3_field),
    .int_32_i(tb_int_32),
    .src1_i(tb_source_1),
    .src2_i(tb_source_2),
    .result_o(tb_mul_result),
    .stall_o(tb_lock_mul)
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
            $display("*** Toggle reset.");
            tb_rstn_i <= 1'b0; 
            #CLK_PERIOD;
            tb_rstn_i <= 1'b1;
            #CLK_PERIOD;
            $display("Done");
        end
    endtask

//***task automatic init_sim***
    task automatic init_sim;
        begin
            $display("*** init_sim");
            tb_clk_i <='{default:1};
            tb_rstn_i<='{default:0};
            tb_wb_exception_i<='{default:0};
            tb_valid_mul<='{default:0};
            tb_funct3_field<='{default:0};
            tb_int_32<='{default:0};
            tb_source_1<='{default:0};
            tb_source_2<='{default:0};
            tb_mul_result<='{default:0};
            tb_lock_mul<='{default:0};
            tb_ready_mul<='{default:0};
            $display("Done");
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("mul_unit.vcd");
            $dumpvars(0,mul_unit_inst);
        end
    endtask

    task automatic tick();
        begin
            //$display("*** tick");
            #CLK_PERIOD;
        end
    endtask

//ReadCheck: assert (data === correct_data)
//               else $error("memory read error");
//  Igt10: assert (I > 10)
//           else $warning("I is less than or equal to 10");

    task automatic set_srcs;
        input int unsigned src1;
        input int unsigned src2;
        begin
            $display("*** set_srcs: %d * %d",src1,src2);
            tb_source_1  <= src1;
            tb_source_2  <= src2;
            tb_valid_mul <= 1;
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing 
    task automatic test_sim_1;
        output int tmp;
        begin
            int tmp = 0;
            $random(10);
            for(int i = 0; i < 1000; i++) begin
                int unsigned src1 = $urandom();
                int unsigned src2 = $urandom();
                set_srcs(src1,src2);
                tick();
                tick();
                if (tb_mul_result != (src1*src2)) begin
                    tmp = 1;
                    `START_RED_PRINT
                    $error("Result incorrect %d * %d = %d",src1,src2,(src1*src2));
                    `END_COLOR_PRINT
                end
            end
        end
    endtask
    

//***task automatic test_sim***
    task automatic test_sim;
        begin
	    int tmp;
            $display("*** test_sim");
            test_sim_1(tmp);
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


//***init_sim***
//The tasks that compose my testbench are executed here, feel free to add more tasks.
    initial begin
        init_sim();
        init_dump();
        reset_dut();
        test_sim();
        $finish;
    end


endmodule
`default_nettype wire
