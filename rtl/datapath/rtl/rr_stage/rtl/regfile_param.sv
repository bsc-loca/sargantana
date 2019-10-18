/* -----------------------------------------------
* Project Name   : DRAC
* File           : regfile.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

import drac_pkg::*;
import riscv_pkg::*;

module regfile_param #(
    parameter int unsigned READ_PORTS  = 2,
    parameter int unsigned WRITE_PORTS = 1,
    // By default we use 64 bit operands
    parameter int unsigned DATA_SIZE   = 64,
    // By default in riscv there are 32 registers 2^5 
    parameter int unsigned RF_WIDTH    = 5
)(
    input logic                                     clk_i,
    input logic                                     rstn_i,
    // read port inputs
    input logic [READ_PORTS-1:0][RF_WIDTH-1:0]      read_addr_i,
    // write port inputs
    input logic [READ_PORTS-1:0][RF_WIDTH-1:0]      write_addr_i,
    input logic [READ_PORTS-1:0][DATA_SIZE-1:0]     write_data_i,
    input logic                                     write_we_i,    
    // read port output
    input logic [READ_PORTS-1:0][DATA_SIZE-1:0]     read_data_o
);

// Register TODO

endmodule