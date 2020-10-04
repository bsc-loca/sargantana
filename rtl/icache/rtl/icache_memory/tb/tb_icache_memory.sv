/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : tb_icache_memory.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Neiel I. Leyva Santes. 
 * Email(s)       : neiel.leyva@bsc.es
 * References     : 
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Commit | Description
 *  ******     | Neiel L.  |        | 
 * -----------------------------------------------
 */

import drac_icache_pkg::*;

`timescale 1 ns/ 1 ns
module tb_icache_memory();


//----------------------------------- input signals
logic                    clk_i        ;
logic                    rstn_i       ;
logic [ICACHE_N_WAY-1:0] way_req_i    ;//- Valid request.  
logic                    we_i         ;//- Write enabled.            
logic                    valid_bit_i  ;//- The valid bit to be written.
logic    [WAY_WIDHT-1:0] cline_i      ;//- The cache line to be written.
logic    [TAG_WIDHT-1:0] tag_i        ;//- The tag of the cache line to be written.
logic   [ADDR_WIDHT-1:0] addr_i       ;//- Address to write or read.     
//----------------------------------- output signals
reg   [ICACHE_N_WAY-1:0][TAG_WIDHT-1:0] tag_way_o   ; //- Tags reads
reg   [ICACHE_N_WAY-1:0][WAY_WIDHT-1:0] cline_way_o ; //- Cache lines read. 
reg                  [ICACHE_N_WAY-1:0] valid_bit_o ; //- Validity bits read.


top_memory i1(
    .clk_i       ( clk_i       ),
    .rstn_i      ( rstn_i      ),
    .way_req_i   ( way_req_i   ),
    .we_i        ( we_i        ),
    .valid_bit_i ( valid_bit_i ),
    .cline_i     ( cline_i     ),
    .tag_i       ( tag_i       ),
    .addr_i      ( addr_i      ),          
    .tag_way_o   ( tag_way_o   ), 
    .cline_way_o ( cline_way_o ), 
    .valid_bit_o ( valid_bit_o )  
);

initial clk_i = 1'b1;
always #25 clk_i = ~clk_i;

task automatic reset;
    begin
        rstn_i <= 1'b0; 
        #50;
        rstn_i <= 1'b1;
    end
endtask

task automatic set;
    begin
        clk_i       <='{default:1};
        rstn_i      <='{default:0};
        way_req_i   <='{default:0}; 
        we_i        <='{default:0}; 
        valid_bit_i <='{default:0}; 
        cline_i     <='{default:0}; 
        tag_i       <='{default:0};
        addr_i      <='{default:0};
        $display("Running testbench");
    end
endtask


initial begin
    set();
    reset();
    
    #50
    way_req_i   <= 4'b0001 ;
    we_i        <= 1'b1    ;
    valid_bit_i <= 1'b1    ;
    cline_i     <= 256'h12345;
    tag_i       <= 44'h24;
    addr_i      <= 7'h6;
    
    #50
    way_req_i   <= 4'b0010 ;
    we_i        <= 1'b1    ;
    valid_bit_i <= 1'b1    ;
    cline_i     <= 256'h12345789;
    tag_i       <= 44'h67;
    addr_i      <= 7'h14;
    
    #50
    way_req_i   <= 4'b0001 ;
    we_i        <= 1'b0    ;
    valid_bit_i <= 1'b0    ;
    cline_i     <= 256'h0;
    tag_i       <= 44'h0;
    addr_i      <= 7'h6;
    
    #50
    way_req_i   <= 4'b0010 ;
    we_i        <= 1'b0    ;
    valid_bit_i <= 1'b0    ;
    cline_i     <= 256'h0;
    tag_i       <= 44'h0;
    addr_i      <= 7'h14;
end


endmodule






