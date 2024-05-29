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
     output logic [5:0]      simd_exe_stages_o, 
     output logic            stall_simd_o    // Stall pipeline
 );

localparam int MAX_STAGES = $clog2(VLEN/8) + 1;  // Number of stages based on the minimum SEW
localparam int DIV_STAGES = 32; // number of clocks a DIV/REM instruction takes, it's basically 1 less than the actual 34 clocks
                                // because for 1 clock cycle the number is being registered but not counted


typedef struct packed {
    logic valid;
    `ifdef VERILATOR
    instr_type_t simd_instr_type;
    `endif
} instr_pipe_t;

instr_pipe_t simd_pipe_d [MAX_STAGES:2][MAX_STAGES-2:0];
instr_pipe_t simd_pipe_q [MAX_STAGES:2][MAX_STAGES-2:0];

// This pipeline is taking care of in-flight DIV/REM instructions
// it's seperated from other instructions as DIV/REM is way more time consuming
// than other instructions.
// The behaviour and managment of this pipeline is alike the simd_pipe
// the differences are explained
instr_pipe_t division_pipe_d [DIV_STAGES - 1:0];
instr_pipe_t division_pipe_q [DIV_STAGES - 1:0];


logic [5:0] simd_exe_stages;
logic is_vmul;
logic is_vred;
logic is_vmadd;
logic is_vdiv;

logic stall_simd;

// Truncate function
function [5:0] trunc_stages(input [31:0] val_in);
    trunc_stages = val_in[5:0];
endfunction

function [4:0] trunc_5_bit(input [31:0] val_in);
    trunc_5_bit = val_in[4:0];
endfunction

assign is_vmadd = ((instr_entry_i.instr_type == VMADD)  ||
                   (instr_entry_i.instr_type == VNMSUB) ||
                   (instr_entry_i.instr_type == VMACC)  ||
                   (instr_entry_i.instr_type == VNMSAC) ||
                   (instr_entry_i.instr_type == VWMACC)  ||
                   (instr_entry_i.instr_type == VWMACCU)  ||
                   (instr_entry_i.instr_type == VWMACCUS)  ||
                   (instr_entry_i.instr_type == VWMACCSU)) ? 1'b1 : 1'b0;

assign is_vdiv =  ((instr_entry_i.instr_type == VDIV )  ||
                   (instr_entry_i.instr_type == VDIVU ) ||
                   (instr_entry_i.instr_type == VREM )  ||
                   (instr_entry_i.instr_type == VREMU)) ? 1'b1 : 1'b0;

assign is_vmul = ((instr_entry_i.instr_type == VWMUL)   ||
                (instr_entry_i.instr_type == VWMULU)   ||
                (instr_entry_i.instr_type == VWMULSU)   ||
                (instr_entry_i.instr_type == VMUL)   ||
                (instr_entry_i.instr_type == VMULH)  ||
                (instr_entry_i.instr_type == VMULHU) ||
                (instr_entry_i.instr_type == VMULHSU)) ? 1'b1 : 1'b0;

assign is_vred = ((instr_entry_i.instr_type == VREDSUM)   ||
                (instr_entry_i.instr_type == VREDAND)   ||
                (instr_entry_i.instr_type == VREDOR)    ||
                (instr_entry_i.instr_type == VREDXOR)    ||
                (instr_entry_i.instr_type == VREDMAXU)    ||
                (instr_entry_i.instr_type == VREDMAX)    ||
                (instr_entry_i.instr_type == VREDMINU)    ||
                (instr_entry_i.instr_type == VREDMIN)) ? 1'b1 : 1'b0;

always_comb begin
    if (is_vmul) begin
        simd_exe_stages = (sew_i == SEW_64) ? 6'd3 : 6'd2;
    end 
    else if (is_vmadd) begin
        simd_exe_stages = (sew_i == SEW_64) ? 6'd4 : 6'd3;
    end 
    else if (is_vred) begin
        case (sew_i)
            SEW_8, SEW_16 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3) + 1);
            SEW_32 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3));
            SEW_64 : simd_exe_stages = trunc_stages($clog2(VLEN >> 3) - 1);
            default : simd_exe_stages = trunc_stages($clog2(VLEN >> 3));
        endcase
    end else if(is_vdiv) begin
        simd_exe_stages = 6'd32;                     
    end else begin
        simd_exe_stages = 6'd1;
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
            for (int j = 0; j < (MAX_STAGES-1); j++) begin
                simd_pipe_q[i][j] <= '0;
            end
        end
        for (int i = 0; i < DIV_STAGES; i++) begin
            division_pipe_q[i] <= '0;
        end
    end else begin
        for (int i=2; i <= MAX_STAGES; i++) begin
            for (int j = 0; j < (MAX_STAGES-1); j++) begin
                simd_pipe_q[i][j] <= simd_pipe_d[i][j];
            end
        end
        for (int i = 0; i < DIV_STAGES; i++) begin
                division_pipe_q[i] <= division_pipe_d[i];
        end
    end
end


// Each cycle, each instruction go forward 1 slot
always_comb begin
    for (int i = 2; i <= MAX_STAGES; i++) begin
        for (int j = 0; j < (MAX_STAGES-1); j++) begin
            if (flush_i) begin
                simd_pipe_d[i][j].valid = 1'b0;
                `ifdef VERILATOR
                simd_pipe_d[i][j].simd_instr_type = ADD;
                `endif
            end else if (j==0) begin
                if (simd_exe_stages == (trunc_stages(i))) begin
                    simd_pipe_d[i][0].valid = ~stall_simd & ready_i & (instr_entry_i.unit == UNIT_SIMD);
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
                simd_pipe_d[i][j].valid = simd_pipe_q[i][j-1].valid;
                `ifdef VERILATOR
                simd_pipe_d[i][j].simd_instr_type = simd_pipe_q[i][j-1].simd_instr_type;
                `endif
            end
        end
    end


    for (int j = 0; j < DIV_STAGES; j++) begin
        if (j==0) begin
            if(is_vdiv) begin
                division_pipe_d[0].valid = ~stall_simd & ready_i & (instr_entry_i.unit == UNIT_SIMD);
                `ifdef VERILATOR
                division_pipe_d[0].simd_instr_type = instr_entry_i.instr_type;
                `endif
            end
            else begin
                division_pipe_d[0].valid = 1'b0;
                `ifdef VERILATOR
                division_pipe_d[0].simd_instr_type = ADD;
                `endif
            end
        end else begin
            division_pipe_d[j].valid = division_pipe_q[j-1].valid;
            `ifdef VERILATOR
            division_pipe_d[j].simd_instr_type = division_pipe_q[j-1].simd_instr_type;
            `endif
                 
        end
    end
end

// Management to stall the instruction if necessary (we cannot write back more than 1 simd instruction)
always_comb begin
    stall_simd = 1'b0;
    for (int i = 2; (i <= MAX_STAGES) && (!stall_simd); i++) begin
        if ( ($unsigned(trunc_stages(i)) > $unsigned(simd_exe_stages)) && (simd_pipe_q[i][trunc_stages(i)-simd_exe_stages-1].valid) ) begin
            stall_simd = 1'b1;
        end
    end
    // unlike the normal pipeline in Division pipeline the very last index has to be
    // checked
    if(division_pipe_q[trunc_5_bit(DIV_STAGES - simd_exe_stages)].valid) begin
        stall_simd = 1'b1;
    end
    // Since the DIV/REM pipeline is circular and not linear (the same hardware is used in every clock) a new
    // DIV/REM instruction can not be issued while the previous one is still in flight, the check below does this.
    if (is_vdiv && (!stall_simd)) begin
        for (int i = 0; ((i < (DIV_STAGES - 1)) && (!stall_simd)); i++) begin
            if(division_pipe_q[i].valid) begin
                stall_simd = 1'b1;
            end
        end 
    end
end

// Output assignment
assign simd_exe_stages_o = simd_exe_stages;
assign stall_simd_o = stall_simd;
 
 
endmodule
 
 