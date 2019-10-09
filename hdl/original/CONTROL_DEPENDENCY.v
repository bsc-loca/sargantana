module	CONTROL_DEPENDENCY (
output					    LOCK_PIPELINE
);
// Current version perform memory operations in execution stage and stall
// until it is ready, then the intrucction go to wb stage, means that if there
// are dependencies, it can use the bypass to solve it we dont need to do
// pipeline stall

assign LOCK_PIPELINE = 1'b0;

endmodule

