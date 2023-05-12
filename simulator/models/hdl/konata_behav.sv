// Module used to dump information comming from writeback stage
module konata_dump_behav
(
// General input
input	clk, rst,
// Control Input
input	if1_valid,
input	if2_valid,
input id_valid,
input ir_valid,
input rr_valid,
input exe_valid,
input wb1_valid,
input wb2_valid,
input wb3_valid,
input wb1_fp_valid,
input wb2_fp_valid,
input wb1_simd_valid,
input wb2_simd_valid,
input wb_store_valid,

input if1_stall,
input if2_stall,
input id_stall,
input ir_stall,
input rr_stall,
input exe_stall,

input if1_flush,
input if2_flush,
input id_flush,
input rr_flush,
input ir_flush,
input exe_flush,

input [63:0] if1_id,
input [63:0] if2_id,
input [63:0] id_id,
input [63:0] ir_id,
input [63:0] rr_id,
input [63:0] exe_id,
input [63:0] wb1_id,
input [63:0] wb2_id,
input [63:0] wb3_id,
input [63:0] wb1_fp_id,
input [63:0] wb2_fp_id,
input [63:0] wb1_simd_id,
input [63:0] wb2_simd_id,
input [63:0] wb_srore_id,

// Data Input
input [63:0] id_pc,
input [31:0] id_inst,

input functional_unit_t exe_unit

);

// DPI calls definition
import "DPI-C" function
  void konata_dump (input longint unsigned if1_valid,
                            input longint unsigned if2_valid,
                            input longint unsigned id_valid,
                            input longint unsigned ir_valid,
                            input longint unsigned rr_valid,
                            input longint unsigned exe_valid,
                            input longint unsigned wb1_valid,
                            input longint unsigned wb2_valid,
                            input longint unsigned wb3_valid,
                            input longint unsigned wb1_fp_valid,
                            input longint unsigned wb2_fp_valid,
                            input longint unsigned wb1_simd_valid,
                            input longint unsigned wb2_simd_valid,
                            input longint unsigned wb_store_valid,
                            input longint unsigned if1_stall,
                            input longint unsigned if2_stall,
                            input longint unsigned id_stall,
                            input longint unsigned ir_stall,
                            input longint unsigned rr_stall,
                            input longint unsigned exe_stall,
                            input longint unsigned if1_flush,
                            input longint unsigned if2_flush,
                            input longint unsigned id_flush,
                            input longint unsigned ir_flush,
                            input longint unsigned rr_flush,
                            input longint unsigned exe_flush, 
                            input longint unsigned id_pc,
                            input longint unsigned id_inst,
                            input longint unsigned if1_id,
                            input longint unsigned if2_id,
                            input longint unsigned id_id,
                            input longint unsigned ir_id,
                            input longint unsigned rr_id,
                            input longint unsigned exe_id,
                            input longint unsigned exe_unit,
                            input longint unsigned wb1_id,
                            input longint unsigned wb2_id,
                            input longint unsigned wb3_id,
                            input longint unsigned wb1_fp_id,
                            input longint unsigned wb2_fp_id,
                            input longint unsigned wb1_simd_id,
                            input longint unsigned wb2_simd_id,
                            input longint unsigned wb_srore_id);
                     
                    
import "DPI-C" function void konata_signature_init();

// we create the behav model to control it
initial begin
  `ifndef VERILATOR
  konata_signature_init();
  `endif
end

// Main always
always @(posedge clk) begin
konata_dump(if1_valid, if2_valid, id_valid, rr_valid, ir_valid, exe_valid, 
            wb1_valid, wb2_valid, wb3_valid, wb1_fp_valid, wb2_fp_valid, wb1_simd_valid, wb2_simd_valid, wb_store_valid, if1_stall, if2_stall, id_stall, ir_stall,
            rr_stall, exe_stall, if1_flush, if2_flush, id_flush, ir_flush, rr_flush, exe_flush, id_pc,
            id_inst, if1_id, if2_id, id_id, ir_id, rr_id, exe_id, exe_unit, wb1_id, wb2_id, wb3_id, wb1_fp_id, wb2_fp_id, wb1_simd_id, wb2_simd_id, wb_srore_id);
end

endmodule
