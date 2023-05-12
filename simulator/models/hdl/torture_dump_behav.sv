import drac_pkg::*;

// Module used to dump information comming from writeback stage
module torture_dump_behav
(
// General input
input	clk, rst,
// Control Input
input	commit_valid_0,
input	reg_wr_valid_0,
input   freg_wr_valid_0,
input   vreg_wr_valid_0,
// Data Input
input [63:0] pc_0, inst_0, reg_dst_0, freg_dst_0, vreg_dst_0,
input [VLEN-1:0] data_0,
// Control Input
input	commit_valid_1,
input	reg_wr_valid_1,
input   freg_wr_valid_1,
input   vreg_wr_valid_1,
// Data Input
input [63:0] pc_1, inst_1, reg_dst_1, freg_dst_1, vreg_dst_1,
input [VLEN-1:0] data_1,
input drac_pkg::sew_t sew,
// Exception Input
input   xcpt,
input [63:0] xcpt_cause,
input [1:0] csr_priv_lvl,
input [63:0] csr_rw_data,
input   csr_xcpt,
input [63:0] csr_xcpt_cause,
input [63:0] csr_tval

);

//typedef struct {
    int data_0_0;
    int data_0_1;
    int data_0_2;
    int data_0_3;
    int data_1_0;
    int data_1_1;
    int data_1_2;
    int data_1_3;
//} dpi_param_t;
    logic [63:0] cycles;

// DPI calls definition
import "DPI-C" function
 void torture_dump (input longint unsigned cycles, input longint unsigned PC, input longint unsigned inst, input longint unsigned dst, input longint unsigned fdst, input longint unsigned vdst,
                    input longint unsigned reg_wr_valid, input longint unsigned freg_wr_valid, input longint unsigned vreg_wr_valid,
                    input int unsigned data0, input int unsigned data1, input int unsigned data2, input int unsigned data3, 
                    input longint unsigned sew, input longint unsigned xcpt, input longint unsigned xcpt_cause, input longint unsigned csr_priv_lvl_next,
                    input longint unsigned csr_rw_data, input longint unsigned csr_xcpt, input longint unsigned csr_xcpt_cause, input longint unsigned csr_tval);
`ifdef VERILATOR
import "DPI-C" function void torture_signature_init(input string binaryFileName);
`else 
import "DPI-C" function void torture_signature_init();
`endif

import "DPI-C" function
 void check_deadlock (input longint unsigned cycles, input longint unsigned PC, input longint unsigned commit_valid);

// we create the behav model to control it
`ifndef VERILATOR
initial begin
  torture_signature_init();
  clear_output();
  cycles <= '0;
end
`endif


always_comb begin
    //for (int i = 0; i<(VLEN/32); ++i) begin
    data_0_0 = data_0[(0*32)+:32];
    data_0_1 = data_0[(1*32)+:32];
    data_0_2 = data_0[(2*32)+:32];
    data_0_3 = data_0[(3*32)+:32];
    data_1_0 = data_1[(0*32)+:32];
    data_1_1 = data_1[(1*32)+:32];
    data_1_2 = data_1[(2*32)+:32];
    data_1_3 = data_1[(3*32)+:32];
    //end
end

// Main always
always @(posedge clk) begin
    cycles <= cycles + 64'h1;
    check_deadlock(cycles, pc_0[39:0], commit_valid_0);
    if(commit_valid_0) begin
        torture_dump(cycles, pc_0[39:0], inst_0, reg_dst_0, freg_dst_0, vreg_dst_0, reg_wr_valid_0, freg_wr_valid_0, vreg_wr_valid_0,
                    data_0_0, data_0_1, data_0_2, data_0_3, sew, xcpt, xcpt_cause, csr_priv_lvl, csr_rw_data, csr_xcpt, csr_xcpt_cause, csr_tval);
    end
    if(commit_valid_1) begin
        torture_dump(cycles, pc_1[39:0], inst_1, reg_dst_1, freg_dst_1, vreg_dst_1, reg_wr_valid_1, freg_wr_valid_1, vreg_wr_valid_1,
                    data_1_0, data_1_1, data_1_2, data_1_3, sew, xcpt, xcpt_cause, csr_priv_lvl, csr_rw_data, csr_xcpt, csr_xcpt_cause, csr_tval);
    end
end

endmodule
