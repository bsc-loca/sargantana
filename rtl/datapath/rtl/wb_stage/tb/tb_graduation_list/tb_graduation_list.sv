//-----------------------------
// Header
//-----------------------------

/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_graduation_list.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Víctor Soria
* Email(s)       : victor.soria@bsc.es
* References     :
*/

//-----------------------------
// includes
//-----------------------------

`timescale 1 ns / 1 ns

`include "colors.vh"

import riscv_pkg::*;
import drac_pkg::*;

module tb_graduation_list();

//-----------------------------
// Local parameters
//-----------------------------
    parameter VERBOSE         = 1;
    parameter CLK_PERIOD      = 2;
    parameter CLK_HALF_PERIOD = CLK_PERIOD / 2;
    parameter GL_ENTRIES      = 32;

//-----------------------------
// Signals
//-----------------------------
logic                           tb_clk_i;
logic                           tb_rstn_i;
gl_instruction_t                tb_instruction_i;
logic                           tb_read_head_i;
gl_index_t                      tb_instruction_writeback_1_i;
logic                           tb_instruction_writeback_enable_1_i;
gl_instruction_t                tb_instruction_writeback_data_1_i;
gl_index_t                      tb_instruction_writeback_2_i;
logic                           tb_instruction_writeback_enable_2_i;
gl_instruction_t                tb_instruction_writeback_data_2_i;
gl_index_t                      tb_assigned_gl_entry_o;
gl_index_t                      tb_commit_gl_entry_o;
gl_instruction_t                tb_instruction_o;
logic                           tb_full_o;
logic                           tb_empty_o;

logic                           tb_flush_i;
gl_index_t                      tb_flush_index_i;
logic                           tb_flush_commit_i;

//-----------------------------
// Module
//-----------------------------

graduation_list module_inst (
    .clk_i(tb_clk_i),
    .rstn_i(tb_rstn_i),
    .instruction_i(tb_instruction_i),
    .read_head_i(tb_read_head_i),
    .instruction_writeback_1_i(tb_instruction_writeback_1_i),
    .instruction_writeback_enable_1_i(tb_instruction_writeback_enable_1_i),
    .instruction_writeback_data_1_i(tb_instruction_writeback_data_1_i),
    .instruction_writeback_2_i(tb_instruction_writeback_2_i),
    .instruction_writeback_enable_2_i(tb_instruction_writeback_enable_2_i),
    .instruction_writeback_data_2_i(tb_instruction_writeback_data_2_i),
    .flush_i(tb_flush_i),
    .flush_index_i(tb_flush_index_i),
    .flush_commit_i(tb_flush_commit_i),
    .assigned_gl_entry_o(tb_assigned_gl_entry_o),
    .instruction_o(tb_instruction_o),
    .commit_gl_entry_o(tb_commit_gl_entry_o),
    .full_o(tb_full_o),
    .empty_o(tb_empty_o)
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
            #CLK_PERIOD;
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
            tb_instruction_i <= '{default: 0};
            tb_read_head_i <= '{default:0};
            tb_instruction_writeback_1_i <= '{default:0};
            tb_instruction_writeback_enable_1_i <= '{default:0};
            tb_instruction_writeback_data_1_i <= '{default:0};
            tb_instruction_writeback_2_i <= '{default:0};
            tb_instruction_writeback_enable_2_i <= '{default:0};
            tb_instruction_writeback_data_2_i <= '{default:0};
            tb_flush_i <= '{default:0};
            tb_flush_index_i <= '{default:0};
            tb_flush_commit_i <= '{default:0};
            $display("Done");
        end
    endtask

//***task automatic init_dump***
//This task dumps the ALL signals of ALL levels of instance dut_example into the test.vcd file
//If you want a subset to modify the parameters of $dumpvars
    task automatic init_dump;
        begin
            $display("*** init_dump");
            $dumpfile("dum_file.vcd");
            $dumpvars(0,module_inst);
        end
    endtask

//***task automatic test_sim***
//This is an empty structure for a test. Remove the TODO label and start writing, several tasks can be used.
    task automatic test_sim;
        begin
            int tmp;
            $display("*** test_sim");
            test_sim_1(tmp); 
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 1 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 1 PASSED.");
                `END_COLOR_PRINT
            end
            test_sim_2(tmp); 
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 2 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 2 PASSED.");
                `END_COLOR_PRINT
            end
            test_sim_3(tmp); 
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 3 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 3 PASSED.");
                `END_COLOR_PRINT
            end
            test_sim_4(tmp); 
            if (tmp >= 1) begin
                `START_RED_PRINT
                        $display("TEST 4 FAILED.");
                `END_COLOR_PRINT
            end else begin
                `START_GREEN_PRINT
                        $display("TEST 4 PASSED.");
                `END_COLOR_PRINT
            end
        end
    endtask

// Test getting a petition that is not valid
// Output should be nothing
    task automatic test_sim_1;
        output int tmp;
        begin
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;
            assert(tb_full_o == 1'b0) else begin tmp++; assert(1 == 0); end
            assert(tb_empty_o == 1'b1) else begin tmp++; assert(1 == 0); end
        end
    endtask

// Test filling the GL with instructions, mark them as executed and read them in order
// Output should be nothing
    task automatic test_sim_2;
        output int tmp;
        begin
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;

            // Now let's fill this with instructions
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_full_o == 0) else begin tmp++; assert(1 == 0); end

                tb_instruction_i = {   
                    1'b1,                   // Valid instruction
                    addrPC_t'(i),           // PC of the instruction
                    instr_type_t'(1),       // Type of instruction
                    reg_t'(1),              // Destination Register
                    reg_t'(1),              // Source register 1
                    reg_csr_addr_t'(0),     // CSR Address
                    exception_t'(0),        // Exceptions
                    bus64_t'(0),            // Exception data or CSR data
                    1'b0,                   // CSR or fence
                    1'b0,                   // Write to register file                    
                    phreg_t'(1),            // Physical register destination to write      
                    phreg_t'(1)             // Old Physical register destination  
                };

                assert(tb_assigned_gl_entry_o == gl_index_t'(i)) else begin tmp++; assert(1 == 0); end
                #CLK_PERIOD;
            end

            assert(tb_full_o == 1) else begin tmp++; assert(1 == 0); end
            
            // Disable writing
            tb_instruction_i.valid = 1'b0;
            #CLK_PERIOD;

            // Enable reading
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;
            
            // We do the assertions one cycle after 
            // We haven't marked it as valid so no instructions should be outputed
            assert(tb_instruction_o.valid == 0) else begin tmp++; assert(1 == 0); end
            
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;
            
            // Mark everything as finished using two ports 
            for(int i = 0; i < GL_ENTRIES; i = i + 2) begin
                tb_instruction_writeback_1_i <= gl_index_t'(i);
                tb_instruction_writeback_enable_1_i <= 1'b1;
                tb_instruction_writeback_data_1_i <= {   
                    1'b1,                   // Valid instruction
                    addrPC_t'(0),           // PC of the instruction
                    instr_type_t'(0),       // Type of instruction
                    reg_t'(0),              // Destination Register
                    reg_t'(0),              // Source register 1
                    reg_csr_addr_t'(0),     // CSR Address
                    exception_t'(0),        // Exceptions
                    bus64_t'(0),            // Exception data or CSR data
                    1'b0,                   // CSR or fence
                    1'b0,                   // Write to register file                    
                    phreg_t'(0),            // Physical register destination to write      
                    phreg_t'(0)             // Old Physical register destination  
                };

                tb_instruction_writeback_2_i <= gl_index_t'(i + 1);
                tb_instruction_writeback_enable_2_i <= 1'b1;
                tb_instruction_writeback_data_2_i <= {   
                    1'b1,                   // Valid instruction
                    addrPC_t'(0),           // PC of the instruction
                    instr_type_t'(0),       // Type of instruction
                    reg_t'(0),              // Destination Register
                    reg_t'(0),              // Source register 1
                    reg_csr_addr_t'(0),   // CSR Address
                    exception_t'(0),        // Exceptions
                    bus64_t'(0),            // Exception data or CSR data
                    1'b0,                   // CSR or fence
                    1'b0,                   // Write to register file                    
                    phreg_t'(0),            // Physical register destination to write      
                    phreg_t'(0)             // Old Physical register destination  
                };
                #CLK_PERIOD;
            end    
            
            tb_instruction_writeback_enable_1_i <= 1'b0;
            tb_instruction_writeback_enable_2_i <= 1'b0;

            // Enable reading
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;

            // We do the assertions one cycle after because we're dealing with flops in instruction_o
            // Recover the instructions. This is a FIFO, so we want to check everything is in the same order.
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_empty_o == 0) else begin tmp++; assert(1 == 0); end
                #CLK_PERIOD;

                assert(tb_instruction_o.valid == 1) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.rd == 1) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.rs1 == 1) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.pc == addrPC_t'(i)) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.csr_addr == reg_csr_addr_t'(0)) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.exception.valid == 0) else begin tmp++; assert(1 == 0); end
                assert(tb_full_o == 0) else begin tmp++; assert(1 == 0); end
            end

            assert(tb_empty_o == 1) else begin tmp++; assert(1 == 0); end
        end
    endtask

// Test filling the GL with instructions, mark them as executed and read them in order
// Output should be nothing
    task automatic test_sim_3;
        output int tmp;
        begin
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;

            // Now let's fill this with instructions
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_full_o == 0) else begin tmp++; assert(1 == 0); end

                tb_instruction_i = {   
                    1'b1,                   // Valid instruction
                    addrPC_t'(i),           // PC of the instruction
                    instr_type_t'(1),       // Type of instruction
                    reg_t'(1),              // Destination Register
                    reg_t'(1),              // Source register 1
                    reg_csr_addr_t'(0),     // CSR Address
                    exception_t'(0),        // Exceptions
                    bus64_t'(0),            // Exception data or CSR data
                    1'b0,                   // CSR or fence
                    1'b0,                   // Write to register file                    
                    phreg_t'(1),            // Physical register destination to write      
                    phreg_t'(1)             // Old Physical register destination  
                };

                assert(tb_assigned_gl_entry_o == gl_index_t'(i)) else begin tmp++; assert(1 == 0); end
                #CLK_PERIOD;
            end

            assert(tb_full_o == 1) else begin tmp++; assert(1 == 0); end
            
            // Disable writing
            tb_instruction_i.valid = 1'b0;
            #CLK_PERIOD;

            // Enable reading
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;
            
            // We do the assertions one cycle after 
            // We haven't marked it as valid so no instructions should be outputed
            assert(tb_instruction_o.valid == 0) else begin tmp++; assert(1 == 0); end
            
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;
            
            // Mark everything as finished using two ports 
            for(int i = 0; i < GL_ENTRIES; i = i + 2) begin
                tb_instruction_writeback_1_i <= gl_index_t'(i);
                tb_instruction_writeback_enable_1_i <= 1'b1;
                tb_instruction_writeback_data_1_i <= {   
                    1'b1,                   // Valid instruction
                    addrPC_t'(0),           // PC of the instruction
                    instr_type_t'(0),       // Type of instruction
                    reg_t'(0),              // Destination Register
                    reg_t'(0),              // Source register 1
                    reg_csr_addr_t'(0),     // CSR Address
                    exception_t'(0),        // Exceptions
                    bus64_t'(0),            // Exception data or CSR data
                    1'b0,                   // CSR or fence
                    1'b0,                   // Write to register file                    
                    phreg_t'(0),            // Physical register destination to write      
                    phreg_t'(0)             // Old Physical register destination  
                };
                tb_instruction_writeback_data_1_i.exception.valid <= 1'b1;
                tb_instruction_writeback_data_1_i.exception.cause <= INSTR_ACCESS_FAULT;
                tb_instruction_writeback_data_1_i.exception.origin <= bus64_t'(i);

                tb_instruction_writeback_2_i <= gl_index_t'(i + 1);
                tb_instruction_writeback_enable_2_i <= 1'b1;
                tb_instruction_writeback_data_2_i <= {   
                    1'b1,                   // Valid instruction
                    addrPC_t'(0),           // PC of the instruction
                    instr_type_t'(0),       // Type of instruction
                    reg_t'(0),              // Destination Register
                    reg_t'(0),              // Source register 1
                    reg_csr_addr_t'(0),     // CSR Address
                    exception_t'(0),        // Exceptions
                    bus64_t'(0),            // Exception data or CSR data
                    1'b0,                   // CSR or fence
                    1'b0,                   // Write to register file                    
                    phreg_t'(0),            // Physical register destination to write      
                    phreg_t'(0)             // Old Physical register destination  
                };
                tb_instruction_writeback_data_2_i.exception.valid <= 1'b1;
                tb_instruction_writeback_data_2_i.exception.cause <= INSTR_ACCESS_FAULT;
                tb_instruction_writeback_data_2_i.exception.origin <= bus64_t'(i+1);
                
                #CLK_PERIOD;
            end    
            
            tb_instruction_writeback_enable_1_i <= 1'b0;
            tb_instruction_writeback_enable_2_i <= 1'b0;

            // Enable reading
            tb_read_head_i <= 1'b1;
            #CLK_PERIOD;

            // We do the assertions one cycle after because we're dealing with flops in instruction_o
            // Recover the instructions. This is a FIFO, so we want to check everything is in the same order.
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_empty_o == 0) else begin tmp++; assert(1 == 0); end
                #CLK_PERIOD;

                assert(tb_instruction_o.valid == 1) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.rd == 1) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.rs1 == 1) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.pc == addrPC_t'(i)) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.csr_addr == reg_csr_addr_t'(0)) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.exception.valid == 1) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.exception.cause == INSTR_ACCESS_FAULT) else begin tmp++; assert(1 == 0); end
                assert(tb_instruction_o.exception.origin == addrPC_t'(i)) else begin tmp++; assert(1 == 0); end
                assert(tb_full_o == 0) else begin tmp++; assert(1 == 0); end
            end

            assert(tb_empty_o == 1) else begin tmp++; assert(1 == 0); end
        end
    endtask
    
    
// Test filling the GL with instructions, mark them as executed and read them in order
// Output should be nothing
    task automatic test_sim_4;
        output int tmp;
        begin
            tb_read_head_i <= 1'b0;
            #CLK_PERIOD;

            // Now let's fill this with instructions
            for(int i = 0; i < GL_ENTRIES; ++i) begin
                assert(tb_full_o == 0) else begin tmp++; assert(1 == 0); end

                tb_instruction_i = {   
                    1'b1,                   // Valid instruction
                    addrPC_t'(i),           // PC of the instruction
                    instr_type_t'(1),       // Type of instruction
                    reg_t'(1),              // Destination Register
                    reg_t'(1),              // Source register 1
                    reg_csr_addr_t'(0),     // CSR Address
                    exception_t'(0),        // Exceptions
                    bus64_t'(0),            // Exception data or CSR data
                    1'b0,                   // CSR or fence
                    1'b0,                   // Write to register file                    
                    phreg_t'(1),            // Physical register destination to write      
                    phreg_t'(1)             // Old Physical register destination  
                };

                assert(tb_assigned_gl_entry_o == gl_index_t'(i)) else begin tmp++; assert(1 == 0); end
                #CLK_PERIOD;
            end

            assert(tb_full_o == 1) else begin tmp++; assert(1 == 0); end
            
            // Disable writing
            tb_instruction_i.valid = 1'b0;
            #CLK_PERIOD;

            tb_flush_commit_i <= 1'b1;
            #CLK_PERIOD;

            tb_flush_commit_i <= 1'b0;
            #CLK_PERIOD;
            
            assert(tb_empty_o == 1) else begin tmp++; assert(1 == 0); end
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
