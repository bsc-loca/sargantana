// Copyright 2019 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author: Stefan Mach <smach@iis.ee.ethz.ch>
//
// Additional contributions by: Mate Kovac <mate.kovac@fer.hr>
//                              Leon Dragic <leon.dragic@fer.hr>
//
// Change history: 04/02/2020 - Added new divsqrt unit.
//                 12/03/2020 - Added masking functionality.
//                 30/06/2020 - Added forwarding of 3 src registers for inactive element select.
//

`include "registers.svh"

module fpuv_divsqrt_multi #(
  parameter fpuv_pkg::fmt_logic_t   FpFmtConfig  = '1,
  // FPU configuration
  parameter int unsigned            NumPipeRegs = 0,
  parameter fpuv_pkg::pipe_config_t PipeConfig  = fpuv_pkg::AFTER,
  parameter type                    TagType     = logic,
  parameter type                    AuxType     = logic,
  // Do not change
  localparam int unsigned WIDTH       = fpuv_pkg::max_fp_width(FpFmtConfig),
  localparam int unsigned NUM_FORMATS = fpuv_pkg::NUM_FP_FORMATS
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,
  // Input signals
  input  logic [2:0][WIDTH-1:0]       operands_i, // 3 operands, 2 for op, 1 for mask forwarding
  input  logic [NUM_FORMATS-1:0][1:0] is_boxed_i, // 2 operands
  input  fpuv_pkg::roundmode_e        rnd_mode_i,
  input  fpuv_pkg::operation_e        op_i,
  input  fpuv_pkg::fp_format_e        dst_fmt_i,
  input  TagType                      tag_i,
  input  AuxType                      aux_i,
  input  logic                        mask_i,
  input  logic [1:0]                  inactive_sel_i,
  // Input Handshake
  input  logic                        in_valid_i,
  output logic                        in_ready_o,
  input  logic                        flush_i,
  // Output signals
  output logic [WIDTH-1:0]            result_o,
  output fpuv_pkg::status_t           status_o,
  output logic                        extension_bit_o,
  output TagType                      tag_o,
  output AuxType                      aux_o,
  // Output handshake
  output logic                        out_valid_o,
  input  logic                        out_ready_i,
  // Indication of valid data in flight
  output logic                        busy_o
);
// verilator lint_off BLKANDNBLK
  // ----------
  // Constants
  // ----------
   localparam int unsigned DIVSQRT_WIDTH = 64;
  // Pipelines
   localparam NUM_INP_REGS = (PipeConfig == fpuv_pkg::BEFORE)
                           ? NumPipeRegs
                           : (PipeConfig == fpuv_pkg::DISTRIBUTED
                              ? (NumPipeRegs / 2) // Last to get distributed regs
                              : 0); // no regs here otherwise
   localparam NUM_OUT_REGS = (PipeConfig == fpuv_pkg::AFTER || PipeConfig == fpuv_pkg::INSIDE)
                           ? NumPipeRegs
                           : (PipeConfig == fpuv_pkg::DISTRIBUTED
                              ? ((NumPipeRegs + 1) / 2) // First to get distributed regs
                              : 0); // no regs here otherwise

  // ---------------
  // Input pipeline
  // ---------------
    // Selected pipeline output signals as non-arrays
  logic [2:0][WIDTH-1:0] operands_q;
  fpuv_pkg::roundmode_e  rnd_mode_q;
  fpuv_pkg::operation_e  op_q;
  fpuv_pkg::fp_format_e  dst_fmt_q;
  logic                  in_valid_q;
// verilator lint_off BLKANDNBLK
  // Input pipeline signals, index i holds signal after i register stages
  logic                 [0:NUM_INP_REGS][2:0][WIDTH-1:0] inp_pipe_operands_q;
  fpuv_pkg::roundmode_e [0:NUM_INP_REGS]                 inp_pipe_rnd_mode_q;
  fpuv_pkg::operation_e [0:NUM_INP_REGS]                 inp_pipe_op_q;
  fpuv_pkg::fp_format_e [0:NUM_INP_REGS]                 inp_pipe_dst_fmt_q;
  TagType               [0:NUM_INP_REGS]                 inp_pipe_tag_q;
  AuxType               [0:NUM_INP_REGS]                 inp_pipe_aux_q;
  logic                 [0:NUM_INP_REGS]                 inp_pipe_valid_q;
  logic                 [0:NUM_INP_REGS]                 inp_pipe_mask_q;
  logic                 [0:NUM_INP_REGS][1:0]            inp_pipe_inactive_sel_q;
  // Ready signal is combinatorial for all stages
  logic [0:NUM_INP_REGS] inp_pipe_ready;

  // Input stage: First element of pipeline is taken from inputs
  assign inp_pipe_operands_q[0]     = operands_i;
  assign inp_pipe_rnd_mode_q[0]     = rnd_mode_i;
  assign inp_pipe_op_q[0]           = op_i;
  assign inp_pipe_dst_fmt_q[0]      = dst_fmt_i;
  assign inp_pipe_tag_q[0]          = tag_i;
  assign inp_pipe_aux_q[0]          = aux_i;
  assign inp_pipe_valid_q[0]        = in_valid_i;
  assign inp_pipe_mask_q[0]         = mask_i;
  assign inp_pipe_inactive_sel_q[0] = inactive_sel_i;
  // Input stage: Propagate pipeline ready signal to updtream circuitry
  assign in_ready_o = inp_pipe_ready[0];
  // Generate the register stages
  for (genvar i = 0; i < NUM_INP_REGS; i++) begin : gen_input_pipeline
    // Internal register enable for this stage
    logic reg_ena;
    // Determine the ready signal of the current stage - advance the pipeline:
    // 1. if the next stage is ready for our data
    // 2. if the next stage only holds a bubble (not valid) -> we can pop it
    assign inp_pipe_ready[i] = inp_pipe_ready[i+1] | ~inp_pipe_valid_q[i+1];
    // Valid: enabled by ready signal, synchronous clear with the flush signal
    `FFLARNC(inp_pipe_valid_q[i+1], inp_pipe_valid_q[i], inp_pipe_ready[i], flush_i, 1'b0, clk_i, rst_ni)
    // Enable register if pipleine ready and a valid data item is present
    assign reg_ena = inp_pipe_ready[i] & inp_pipe_valid_q[i];
    // Generate the pipeline registers within the stages, use enable-registers
    `FFL(inp_pipe_operands_q[i+1],     inp_pipe_operands_q[i],     reg_ena, '0)
    `FFL(inp_pipe_rnd_mode_q[i+1],     inp_pipe_rnd_mode_q[i],     reg_ena, fpuv_pkg::RNE)
    `FFL(inp_pipe_op_q[i+1],           inp_pipe_op_q[i],           reg_ena, fpuv_pkg::FMADD)
    `FFL(inp_pipe_dst_fmt_q[i+1],      inp_pipe_dst_fmt_q[i],      reg_ena, fpuv_pkg::fp_format_e'(0))
    `FFL(inp_pipe_tag_q[i+1],          inp_pipe_tag_q[i],          reg_ena, TagType'('0))
    `FFL(inp_pipe_aux_q[i+1],          inp_pipe_aux_q[i],          reg_ena, AuxType'('0))
    `FFL(inp_pipe_mask_q[i+1],         inp_pipe_mask_q[i],         reg_ena, '0)
    `FFL(inp_pipe_inactive_sel_q[i+1], inp_pipe_inactive_sel_q[i], reg_ena, '0)
  end
  // Output stage: assign selected pipe outputs to signals for later use
  assign operands_q = inp_pipe_operands_q[NUM_INP_REGS];
  assign rnd_mode_q = inp_pipe_rnd_mode_q[NUM_INP_REGS];
  assign op_q       = inp_pipe_op_q[NUM_INP_REGS];
  assign dst_fmt_q  = inp_pipe_dst_fmt_q[NUM_INP_REGS];
  assign in_valid_q = inp_pipe_valid_q[NUM_INP_REGS];

  // -----------------
  // Input processing
  // -----------------
  logic [2:0][DIVSQRT_WIDTH-1:0] divsqrt_operands; // those are fixed to 64bit
  logic                          input_is_fp8;

  // Translate fp8 format into fp16
  always_comb begin : is_fp8
    // Only if FP8 is enabled
    input_is_fp8 = FpFmtConfig[fpuv_pkg::FP8] & (dst_fmt_q == fpuv_pkg::FP8);

    // If FP8 is supported, map it to an FP16 value
    divsqrt_operands[0] = input_is_fp8 ? operands_q[0] << 8 : operands_q[0];
    divsqrt_operands[1] = input_is_fp8 ? operands_q[1] << 8 : operands_q[1];
    divsqrt_operands[2] = operands_q[2]; //used only for mask forwarding
  end

  // ------------
  // Control FSM
  // ------------
  logic in_ready;               // input handshake with upstream
  logic div_valid, sqrt_valid;  // input signalling with unit
  logic unit_ready, unit_done;  // status signals from unit instance
  logic op_starting;            // high in the cycle a new operation starts
  logic out_valid, out_ready;   // output handshake with downstream
  logic hold_result;            // whether to put result into hold register
  logic data_is_held;           // data in hold register is valid
  logic unit_busy;              // valid data in flight
  // FSM states
  typedef enum logic [1:0] {IDLE, BUSY, HOLD} fsm_state_e;
  fsm_state_e state_q, state_d;

  // Upstream ready comes from sanitization FSM
  assign inp_pipe_ready[NUM_INP_REGS] = in_ready;

  // Valids are gated by the FSM ready. Invalid input ops run a sqrt to not lose illegal instr.
  assign div_valid   = in_valid_q & (op_q == fpuv_pkg::DIV) & in_ready & ~flush_i;
  assign sqrt_valid  = in_valid_q & (op_q != fpuv_pkg::DIV) & in_ready & ~flush_i;
  assign op_starting = div_valid | sqrt_valid;

  // FSM to safely apply and receive data from DIVSQRT unit
  always_comb begin : flag_fsm
    // Default assignments
    in_ready     = 1'b0;
    out_valid    = 1'b0;
    hold_result  = 1'b0;
    data_is_held = 1'b0;
    unit_busy    = 1'b0;
    state_d      = state_q;

    unique case (state_q)
      // Waiting for work
      IDLE: begin
        in_ready = 1'b1; // we're ready
        if (in_valid_q && unit_ready) begin // New work arrives
          state_d = BUSY; // go into processing state
        end
      end
      // Operation in progress
      BUSY: begin
        unit_busy = 1'b1; // data in flight
        // If the unit is done with processing
        if (unit_done) begin
          out_valid = 1'b1; // try to commit result downstream
          // If downstream accepts our result
          if (out_ready) begin
            state_d = IDLE; // we anticipate going back to idling..
            if (in_valid_q && unit_ready) begin // ..unless new work comes in
              in_ready = 1'b1; // we acknowledge the instruction
              state_d  = BUSY; // and stay busy with it
            end
          // Otherwise if downstream is not ready for the result
          end else begin
            hold_result = 1'b1; // activate the hold register
            state_d     = HOLD; // wait for the pipeline to take the data
          end
        end
      end
      // Waiting with valid result for downstream
      HOLD: begin
        unit_busy    = 1'b1; // data in flight
        data_is_held = 1'b1; // data in hold register is valid
        out_valid    = 1'b1; // try to commit result downstream
        // If the result is accepted by downstream
        if (out_ready) begin
          state_d = IDLE; // go back to idle..
          if (in_valid_q && unit_ready) begin // ..unless new work comes in
            in_ready = 1'b1; // acknowledge the new transaction
            state_d  = BUSY; // will be busy with the next instruction
          end
        end
      end
      // fall into idle state otherwise
      default: state_d = IDLE;
    endcase

    // Flushing overrides the other actions
    if (flush_i) begin
      unit_busy = 1'b0; // data is invalidated
      out_valid = 1'b0; // cancel any valid data
      state_d   = IDLE; // go to default state
    end
  end

  // FSM status register (asynch active low reset)
  `FF(state_q, state_d, IDLE)

  // Hold additional information while the operation is in progress
  logic result_is_fp8_q;
  TagType result_tag_q;
  AuxType result_aux_q;

  // Fill the registers everytime a valid operation arrives (load FF, active low asynch rst)
  `FFL(result_is_fp8_q, input_is_fp8,                 op_starting, '0)
  `FFL(result_tag_q,    inp_pipe_tag_q[NUM_INP_REGS], op_starting, '0)
  `FFL(result_aux_q,    inp_pipe_aux_q[NUM_INP_REGS], op_starting, '0)

  // -----------------
  // DIVSQRT instance
  // -----------------
  logic [DIVSQRT_WIDTH-1:0] unit_result;
  logic [WIDTH-1:0]         adjusted_result, held_result_q;
  fpuv_pkg::status_t        unit_status, held_status_q;

  divsqrt_top #(
     .FpFmtConfig ( FpFmtConfig )
  ) i_divsqrt_top (
   .clk_i          ( clk_i               ),
   .rst_ni         ( rst_ni              ),
   .operands_i     ( divsqrt_operands    ),
   .div_start_i    ( div_valid           ),
   .sqrt_start_i   ( sqrt_valid          ),
   .rnd_mode_i     ( rnd_mode_q          ),
   .dst_fmt_i      ( dst_fmt_q           ),
   .kill_i         ( flush_i             ),
   .mask_i         ( inp_pipe_mask_q[NUM_INP_REGS] ),
   .inactive_sel_i ( inp_pipe_inactive_sel_q[NUM_INP_REGS] ),
   .result_o       ( unit_result         ),
   .status_o       ( unit_status         ),
   .in_ready_o     ( unit_ready          ),
   .done_o         ( unit_done           )
  );

  // Adjust result width and fix FP8
  assign adjusted_result = result_is_fp8_q ? unit_result >> 8 : unit_result;

  // The Hold register (load, no reset)
  `FFLNR(held_result_q, adjusted_result, hold_result, clk_i)
  `FFLNR(held_status_q, unit_status,     hold_result, clk_i)

  // --------------
  // Output Select
  // --------------
  logic [WIDTH-1:0]  result_d;
  fpuv_pkg::status_t status_d;
  // Prioritize hold register data
  assign result_d = data_is_held ? held_result_q : adjusted_result;
  assign status_d = data_is_held ? held_status_q : unit_status;

  // ----------------
  // Output Pipeline
  // ----------------
  // verilator lint_off BLKANDNBLK
  // Output pipeline signals, index i holds signal after i register stages
  logic              [0:NUM_OUT_REGS][WIDTH-1:0] out_pipe_result_q;
  fpuv_pkg::status_t [0:NUM_OUT_REGS]            out_pipe_status_q;
  TagType            [0:NUM_OUT_REGS]            out_pipe_tag_q;
  AuxType            [0:NUM_OUT_REGS]            out_pipe_aux_q;
  logic              [0:NUM_OUT_REGS]            out_pipe_valid_q;
  // Ready signal is combinatorial for all stages
  logic [0:NUM_OUT_REGS] out_pipe_ready;

  // Input stage: First element of pipeline is taken from inputs
  assign out_pipe_result_q[0] = result_d;
  assign out_pipe_status_q[0] = status_d;
  assign out_pipe_tag_q[0]    = result_tag_q;
  assign out_pipe_aux_q[0]    = result_aux_q;
  assign out_pipe_valid_q[0]  = out_valid;
  // Input stage: Propagate pipeline ready signal to inside pipe
  assign out_ready = out_pipe_ready[0];
  // Generate the register stages
  for (genvar i = 0; i < NUM_OUT_REGS; i++) begin : gen_output_pipeline
    // Internal register enable for this stage
    logic reg_ena;
    // Determine the ready signal of the current stage - advance the pipeline:
    // 1. if the next stage is ready for our data
    // 2. if the next stage only holds a bubble (not valid) -> we can pop it
    assign out_pipe_ready[i] = out_pipe_ready[i+1] | ~out_pipe_valid_q[i+1];
    // Valid: enabled by ready signal, synchronous clear with the flush signal
    `FFLARNC(out_pipe_valid_q[i+1], out_pipe_valid_q[i], out_pipe_ready[i], flush_i, 1'b0, clk_i, rst_ni)
    // Enable register if pipleine ready and a valid data item is present
    assign reg_ena = out_pipe_ready[i] & out_pipe_valid_q[i];
    // Generate the pipeline registers within the stages, use enable-registers
    `FFL(out_pipe_result_q[i+1], out_pipe_result_q[i], reg_ena, '0)
    `FFL(out_pipe_status_q[i+1], out_pipe_status_q[i], reg_ena, '0)
    `FFL(out_pipe_tag_q[i+1],    out_pipe_tag_q[i],    reg_ena, TagType'('0))
    `FFL(out_pipe_aux_q[i+1],    out_pipe_aux_q[i],    reg_ena, AuxType'('0))
  end
  // Output stage: Ready travels backwards from output side, driven by downstream circuitry
  assign out_pipe_ready[NUM_OUT_REGS] = out_ready_i;
  // Output stage: assign module outputs
  assign result_o        = out_pipe_result_q[NUM_OUT_REGS];
  assign status_o        = out_pipe_status_q[NUM_OUT_REGS];
  assign extension_bit_o = 1'b1; // always NaN-Box result
  assign tag_o           = out_pipe_tag_q[NUM_OUT_REGS];
  assign aux_o           = out_pipe_aux_q[NUM_OUT_REGS];
  assign out_valid_o     = out_pipe_valid_q[NUM_OUT_REGS];
  assign busy_o          = (| {inp_pipe_valid_q, unit_busy, out_pipe_valid_q});
endmodule
