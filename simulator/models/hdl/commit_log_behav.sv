import drac_pkg::*;

// Module used to dump information comming from writeback stage
module commit_log_behav
(
// General input
input	clk, rst,
input logic commit_valid_i [1:0],
input commit_data_t commit_data_i [1:0]
);

    // DPI calls definition
    import "DPI-C" function void commit_log (input commit_data_t commit_data);
    import "DPI-C" function void commit_log_init(input string logfile);

    logic dump_enabled;

// we create the behav model to control it
initial begin
    string logfile;
    if($test$plusargs("commit_log")) begin
        dump_enabled = 1'b1;
        if (!$value$plusargs("commit_log=%s", logfile)) logfile = "signature.txt";
        commit_log_init(logfile);
    end else begin
        dump_enabled = 1'b0;
    end
end

// Main always
always @(posedge clk) begin
    if (dump_enabled) begin
        for (int i = 0; i < 2; i++) begin
            if (commit_valid_i[i]) begin
                commit_log(commit_data_i[i]);
            end
        end
    end
end

endmodule
