import drac_pkg::*;

// Module used to dump information comming from writeback stage
module torture_dump_behav
(
// General input
input	clk, rst,
input logic commit_valid_i [1:0],
input commit_data_t commit_data_i [1:0]
);

    logic [63:0] cycles;

// DPI calls definition
import "DPI-C" function
 void torture_dump (input longint unsigned cycles, input commit_data_t commit_data);
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

// Main always
always @(posedge clk) begin
    cycles <= cycles + 64'h1;
    check_deadlock(cycles, commit_data_i[0].pc[39:0], commit_valid_i[0]);
    for (int i = 0; i < 2; i++) begin
        if (commit_valid_i[i]) begin
            torture_dump(cycles, commit_data_i[i]);
        end
    end
end

endmodule
