
`default_nettype none
`include "definitions.v"

/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : branch_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */

module branch_unit(
    input wire `ADDR   pc_i,
    input wire [15:0]  control_i,
    input wire `INST   inst_i,

    input wire `DATA   source1_i,
    input wire `DATA   source2_i,

    output wire        branch_valid_o,
    output wire        branch_taken_o,
    output reg `ADDR   branch_target_o,
    output reg `ADDR   branch_result_o,

    output reg [4:0]   write_reg_o,
    output wire `DATA  write_data_o
);

// Declarations
wire `ADDR branch_offset;
wire `ADDR jal_offset;
wire `DATA jalr_offset_aux;
wire `ADDR jalr_offset;
wire [2:0] funct3_field;
wire [4:0] dest_reg;
wire branch;
wire jal;
wire jalr;
wire equal;
wire less;
wire less_u;
reg taken_aux;
wire `ADDR next_pc;

// Calculate offsets and func3
assign branch_offset = {{28{inst_i[31]}},inst_i[7],inst_i[30:25],inst_i[11:8],1'b0};
assign jal_offset = {{20{inst_i[31]}},inst_i[19:12],inst_i[20],inst_i[30:21],1'b0};
assign jalr_offset_aux = source1_i + {{53{inst_i[31]}},inst_i[30:20]};
assign jalr_offset = {jalr_offset_aux[39:1],1'b0};
assign funct3_field = inst_i[14:12];
assign dest_reg = inst_i[11:7];

// Calculate if the inst is a branch, jal or jalr
assign branch = control_i[4];
assign jal = ~control_i[0] & control_i[3] & control_i[5];
assign jalr = (control_i[0] & control_i[3] & control_i[5]) & (funct3_field == 3'b000);

// Calculate all posible conditions
assign equal = source1_i == source2_i;
assign less = $signed(source1_i) < $signed(source2_i);
assign less_u = source1_i < source2_i;

// Calculate if the branch is taken
always@(*) begin
    if (branch) begin
        case (funct3_field)
            3'b000: begin   //branch on equal
                taken_aux = equal;
            end
            3'b001: begin   //branch on not equal
                taken_aux = ~equal;
            end
            3'b100: begin   //branch on less than
                taken_aux = less;
            end
            3'b101: begin   //branch on greater than or equal
                taken_aux = ~less;
            end
            3'b110: begin   //branch if less than unsigned
                taken_aux = less_u;
            end
            3'b111: begin   //branch if greater than or equal unsigned
                taken_aux = ~less_u;
            end
            default: begin
                taken_aux = 0;
            end
        endcase
    end else if (jal | jalr) begin
        taken_aux = 1;
    end else begin
        taken_aux = 0;
    end
end

// Next pc in case there is no branch
assign next_pc = pc_i + 4;

// Branch result
assign branch_valid_o = branch | jal | jalr;
assign branch_taken_o = taken_aux;
assign branch_target_o = branch ? (pc_i + branch_offset) : jal ? (pc_i + jal_offset) : (pc_i + jalr_offset);
assign branch_result_o = taken_aux ? branch_target_o : next_pc;

// Destination register for jal and jalr
assign write_reg_o = (jal | jalr) ? dest_reg : 0;
assign write_data_o = {24'b0,next_pc};

endmodule
`default_nettype wire
