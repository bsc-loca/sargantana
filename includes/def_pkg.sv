/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the “License”); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File:   ariane_pkg.sv
 * Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
 * Date:   8.4.2017
 *
 * Description: Contains all the necessary defines for Ariane
 *              in one package.
 */

// this is needed to propagate the
// configuration in case Ariane is
// instantiated in OpenPiton

`ifndef DEF_PKG
`define DEF_PKG
package def_pkg;
    

`ifdef PITON_ARIANE
    // Floating-point extensions configuration
    localparam bit RVF = 1'b0; // Is F extension enabled
    localparam bit RVD = 1'b0; // Is D extension enabled
`else
    // Floating-point extensions configuration
    localparam bit RVF = 1'b1; // Is F extension enabled
    localparam bit RVD = 1'b1; // Is D extension enabled
`endif
    localparam bit RVA = 1'b1; // Is A extension enabled
    localparam bit RVV = 1'b1; // Is V extension enabled

    // Transprecision floating-point extensions configuration
    localparam bit XF16    = 1'b0; // Is half-precision float extension (Xf16) enabled
    localparam bit XF16ALT = 1'b0; // Is alternative half-precision float extension (Xf16alt) enabled
    localparam bit XF8     = 1'b0; // Is quarter-precision float extension (Xf8) enabled
    localparam bit XFVEC   = 1'b0; // Is vectorial float extension (Xfvec) enabled

    // Transprecision float unit
    localparam int unsigned LAT_COMP_FP32    = 'd2;
    localparam int unsigned LAT_COMP_FP64    = 'd3;
    localparam int unsigned LAT_COMP_FP16    = 'd1;
    localparam int unsigned LAT_COMP_FP16ALT = 'd1;
    localparam int unsigned LAT_COMP_FP8     = 'd1;
    localparam int unsigned LAT_DIVSQRT      = 'd2;
    localparam int unsigned LAT_NONCOMP      = 'd1;
    localparam int unsigned LAT_CONV         = 'd2;

    // --------------------------------------
    // vvvv Don't change these by hand! vvvv
    localparam bit FP_PRESENT = RVF | RVD | XF16 | XF16ALT | XF8;

    localparam bit V_PRESENT = RVV;

    // Length of widest floating-point format
    localparam FLEN    = RVD     ? 64 : // D ext.
                         RVF     ? 32 : // F ext.
                         XF16    ? 16 : // Xf16 ext.
                         XF16ALT ? 16 : // Xf16alt ext.
                         XF8     ? 8 :  // Xf8 ext.
                         0;             // Unused in case of no FP

    localparam bit NSX = XF16 | XF16ALT | XF8 | XFVEC; // Are non-standard extensions present?

    localparam bit RVFVEC     = RVF     & XFVEC & (FLEN>32); // FP32 vectors available if vectors and larger fmt enabled
    localparam bit XF16VEC    = XF16    & XFVEC & (FLEN>16); // FP16 vectors available if vectors and larger fmt enabled
    localparam bit XF16ALTVEC = XF16ALT & XFVEC & (FLEN>16); // FP16ALT vectors available if vectors and larger fmt enabled
    localparam bit XF8VEC     = XF8     & XFVEC & (FLEN>8);  // FP8 vectors available if vectors and larger fmt enabled

    localparam logic [63:0] ISA_CODE = (RVA <<  0)  // A - Atomic Instructions extension
                                     | (0   <<  2)  // C - Compressed extension
                                     | (RVD <<  3)  // D - Double precsision floating-point extension
                                     | (RVF <<  5)  // F - Single precsision floating-point extension
                                     | (1   <<  8)  // I - RV32I/64I/128I base ISA
                                     | (1   << 12)  // M - Integer Multiply/Divide extension
                                     | (0   << 13)  // N - User level interrupts supported
                                     | (1   << 18)  // S - Supervisor mode implemented
                                     | (1   << 20)  // U - User mode implemented
                                     | (RVV << 21)  // V - Vector Instructions extension
                                     | (NSX << 23)  // X - Non-standard extensions present
                                     | (1   << 63); // RV64


    // enables a commit log which matches spikes commit log format for easier trace comparison
    localparam bit ENABLE_SPIKE_COMMIT_LOG = 1'b1;

    // read mask for SSTATUS over MMSTATUS
    localparam logic [63:0] SMODE_STATUS_READ_MASK = riscv_pkg::SSTATUS_UIE
                                                   | riscv_pkg::SSTATUS_SIE
                                                   | riscv_pkg::SSTATUS_SPIE
                                                   | riscv_pkg::SSTATUS_SPP
                                                   | riscv_pkg::SSTATUS_FS
                                                   | riscv_pkg::SSTATUS_VS
                                                   | riscv_pkg::SSTATUS_XS
                                                   | riscv_pkg::SSTATUS_SUM
                                                   | riscv_pkg::SSTATUS_MXR
                                                   | riscv_pkg::SSTATUS_UPIE
                                                   | riscv_pkg::SSTATUS_SPIE
                                                   | riscv_pkg::SSTATUS_UXL
                                                   | riscv_pkg::SSTATUS64_SD;

    localparam logic [63:0] SMODE_STATUS_WRITE_MASK = riscv_pkg::SSTATUS_SIE
                                                    | riscv_pkg::SSTATUS_SPIE
                                                    | riscv_pkg::SSTATUS_SPP
                                                    | riscv_pkg::SSTATUS_FS
                                                    | riscv_pkg::SSTATUS_VS
                                                    | riscv_pkg::SSTATUS_SUM
                                                    | riscv_pkg::SSTATUS_MXR;
    // exception
    typedef struct packed {
         logic [63:0] cause; // cause of exception
         logic [63:0] tval;  // additional information of causing exception (e.g.: instruction causing it),
                             // address of LD/ST fault
         logic        valid;
    } exception_t;

    localparam logic [3:0] MODE_SV39 = 4'h8;
    localparam logic [3:0] MODE_OFF = 4'h0;

    // Bits required for representation of physical address space as 4K pages
    // (e.g. 27*4K == 39bit address space).
    localparam PPN4K_WIDTH = 38;

    typedef enum int {
        SARGANTANA_CORE,
        LKA_CORE,
        LOX_CORE
    }   core_type_t;

endpackage
`endif
