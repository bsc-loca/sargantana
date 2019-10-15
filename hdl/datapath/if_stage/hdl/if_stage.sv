import defines::*;

module if_stage(
  	input logic clk_i,
  	input logic rst_i,
    
  	input logic stall_i,
  	// which pc to select
    input next_pc_sel_t next_pc_sel_i,
  	// PC comming from commit
    input addr_t pc_commit_i,
    // Request packet coming from Icache
  	input icache_req_out_t icache_req_receive_i,
    // Request packet going from Icache
	output icache_req_in_t icache_req_send_o,
    // fetch data output
  	output fetch_out_t fetch_o
);

addr_t next_pc;
reg_addr_t pc;

always_comb begin
	priority case (next_pc_sel_i)
		NEXT_PC_SEL_PC:
			next_pc = pc;
		NEXT_PC_SEL_PC_4:
			next_pc = pc + 40'h04;
		NEXT_PC_SEL_COMMIT:
			next_pc = pc_commit_i;
	endcase
end

// PC output is the next_pc after a latch
always_ff @(posedge clk_i) begin
	if (rst_i) begin
		pc <= 'h00002000;
	end else begin
		//pc <= next_pc;
		pc <= next_pc;
	end
end

// logic for icache access
assign icache_req_send_o.fetch_valid = 1'b1;
assign icache_req_send_o.fetch_vaddr = pc;

// logic branch predictor

assign fetch_o.pc_inst = pc;
assign fetch_o.inst = 32'b0; // TODO: add logic of getting the block
assign fetch_o.valid = icache_req_receive_i.valid;
assign fetch_o.bpred.decision = PRED_NOT_TAKEN; // TODO: add bpred
assign fetch_o.bpred.pred_addr = 40'b0; // TODO: add bpred 

assign fetch_o.ex.cause = MISALIGNED_FETCH;
assign fetch_o.ex.origin_help = 40'b0;
assign fetch_o.ex.valid = 1'b1;

endmodule