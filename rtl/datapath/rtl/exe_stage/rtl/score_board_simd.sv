/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : score_board_simd.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Xavier Carril 
 * Email(s)       : xavier.carril@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */
 import drac_pkg::*;
 import riscv_pkg::*;
 
 module score_board_simd (
     input logic             clk_i,
     input logic             rstn_i,
     input logic             flush_i,
 
     // INPUTS
     input  logic            ready_i,        // Instruction valid and ready to be issued to SIMD unit
     input  instr_entry_t    instr_entry_i,  // Instruction entry
     input  sew_t            sew_i,          // SEW: 00 for 8 bits, 01 for 16 bits, 10 for 32 bits, 11 for 64 bits
 
     // OUTPUTS
     output logic [3:0]      simd_exe_stages_o,
     output logic            stall_simd_o    // Stall pipeline
 );
 
localparam int MAX_STAGES = $clog2(VLEN/8) + 1;  // Number of stages based on the minimum SEW

typedef struct packed {
    logic valid;
    `ifdef VERILATOR
    instr_type_t simd_instr_type;
    `endif
} instr_pipe_t;

instr_pipe_t simd_pipe_d [MAX_STAGES:2][MAX_STAGES-1:0];
instr_pipe_t simd_pipe_q [MAX_STAGES:2][MAX_STAGES-1:0];

logic [3:0] simd_exe_stages;
logic is_vmul;
logic is_vred;

logic stall_simd_d, stall_simd_q;

// Truncate function
function [3:0] trunc_stages(input [31:0] val_in);
    trunc_stages = val_in[3:0];
endfunction

assign is_vmul = ((instr_entry_i.instr_type == VMADD)   ||
                (instr_entry_i.instr_type == VNMSUB)   ||
                (instr_entry_i.instr_type == VMACC)   ||
                (instr_entry_i.instr_type == VNMSAC)   ||
                (instr_entry_i.instr_type == VWMUL)   ||
                (instr_entry_i.instr_type == VWMULU)   ||
                (instr_entry_i.instr_type == VWMULSU)   ||
                (instr_entry_i.instr_type == VMUL)   ||
                (instr_entry_i.instr_type == VMULH)  ||
                (instr_entry_i.instr_type == VMULHU) ||
                (instr_entry_i.instr_type == VMULHSU)) ? 1'b1 : 1'b0;

assign is_vred = ((instr_entry_i.instr_type == VREDSUM)   ||
                (instr_entry_i.instr_type == VREDAND)   ||
                (instr_entry_i.instr_type == VREDOR)    ||
                (instr_entry_i.instr_type == VREDXOR)) ? 1'b1 : 1'b0;

always_comb begin
    if (is_vmul) begin
        simd_exe_stages = (sew_i == SEW_64) ? 4'd3 : 4'd2;
    end 
    else if (is_vred) begin
        case (sew_i)
            SEW_8, SEW_16 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3) + 1);
            SEW_32 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3));
            SEW_64 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3) - 1);
            default : simd_exe_stages = trunc_stages($clog2(VLEN >> 3));
        endcase
    end else begin
        simd_exe_stages = 4'd1;
    end
end

// Cycle instruction management for those instructions that takes more than 1 cycle
/*
* 2 cycle -> |0|1|
* 3 cycle -> |0|1|2|
* 4 cycle -> |0|1|2|3|
...
*/

always_ff @(posedge clk_i, negedge rstn_i) begin
if (~rstn_i) begin
    for (int i=2; i <= MAX_STAGES; i++) begin
        for (int j = 0; j < MAX_STAGES; j++) begin
            simd_pipe_q[i][j] <= '0;
        end
    end
end else begin
    for (int i=2; i <= MAX_STAGES; i++) begin
        for (int j = 0; j < MAX_STAGES; j++) begin
            simd_pipe_q[i][j] <= simd_pipe_d[i][j];
        end
    end
end
end


// Each cycle, each instruction go forward 1 slot
always_comb begin
    for (int i = 2; i <= MAX_STAGES; i++) begin
        for (int j = 0; j < MAX_STAGES; j++) begin
            if (j==0) begin
                if (simd_exe_stages == (trunc_stages(i))) begin
                    simd_pipe_d[i][0].valid = ~stall_simd_q & ready_i & (instr_entry_i.unit == UNIT_SIMD);
                    `ifdef VERILATOR
                    simd_pipe_d[i][0].simd_instr_type = instr_entry_i.instr_type;
                    `endif
                end else begin
                    simd_pipe_d[i][0].valid = 1'b0;
                    `ifdef VERILATOR
                    simd_pipe_d[i][0].simd_instr_type = ADD;
                    `endif
                end
            end else begin
                if (flush_i) begin 
                    simd_pipe_d[i][j].valid = 1'b0;
                    `ifdef VERILATOR
                    simd_pipe_d[i][j].simd_instr_type = ADD;
                    `endif
                end else begin
                    simd_pipe_d[i][j].valid = simd_pipe_q[i][j-1].valid;
                    `ifdef VERILATOR
                    simd_pipe_d[i][j].simd_instr_type = simd_pipe_q[i][j-1].simd_instr_type;
                    `endif
                end
            end
        end
    end
end

// Management to stall the instruction if necessary (we cannot write back more than 1 simd instruction)
logic [MAX_STAGES:0] or_reduction;
always_comb begin
    or_reduction = '0;
    for (int gv_ored = 2; gv_ored <= MAX_STAGES; gv_ored++) begin
        or_reduction[gv_ored] = ($unsigned(trunc_stages(gv_ored)) > $unsigned(simd_exe_stages)) ? 
                                simd_pipe_q[gv_ored][trunc_stages(gv_ored)-simd_exe_stages].valid 
                                : 1'b0;
    end
end

assign stall_simd_d = |or_reduction;

always_ff @(posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        stall_simd_q <= 1'b0;
    end else begin
        stall_simd_q <= stall_simd_d;
    end
end

// Output assignment
assign simd_exe_stages_o = simd_exe_stages;
assign stall_simd_o = stall_simd_q;
 
 
endmodule
 
 