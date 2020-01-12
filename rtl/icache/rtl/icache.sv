//-----------------------------------------------------
// Design Name  : direct_icache
// File Name    : direct_icache.v
// Function     : direct_icache for drac. Parametric direct map cache
// Coders        : GCabo MRodrig
// References   : Computer principles and design in verilog HDL
//-----------------------------------------------------


import drac_pkg::*;
import riscv_pkg::*;

module icache #
    (
        // direct mapping, 2 ̂ 4 blocks,
        parameter integer ADDRESS_SIZE  = 32,//in bites defined=40
        parameter integer CACHE_SIZE  = 2048,// bits cache
        parameter integer MEM_BUS  =    128, // bits to main memory
        parameter integer I_WORD_SIZE = 32,//32
        parameter integer PREFETCH = 0
        )
    (
        input clk, clrn,// clock and reset
        input [ADDRESS_SIZE-1:0] p_a, // cpu address
        input p_strobe,// cpu strobe
        input uncached,// uncached
        input [MEM_BUS-1:0] m_dout, // mem data out to cpu
        input m_ready,// mem ready

        output [I_WORD_SIZE-1:0] p_din,// cpu data from mem, send the whole line
        output p_ready,// ready (to cpu)
        output cache_miss,// cache miss
        output [ADDRESS_SIZE-1:0] m_a,// mem address
        output m_strobe// mem strobe

    );
    //PARAMETERS
    localparam integer N_WORDS_BLOCK  = 4;// words per block or entry
    localparam integer N_BLOCKS  =CACHE_SIZE/(I_WORD_SIZE*N_WORDS_BLOCK); //total of entries or blocks
    localparam integer BYTES_PER_WORD = I_WORD_SIZE/8;
    localparam integer N_BITS_BLOCK = $clog2(N_BLOCKS);
    localparam integer WORD_OFFSET_BITS = $clog2(N_WORDS_BLOCK);
    localparam integer BASE_BIT_BLOCK =WORD_OFFSET_BITS + $clog2(BYTES_PER_WORD);
    localparam integer N_BITS_TAG =ADDRESS_SIZE - N_BITS_BLOCK - WORD_OFFSET_BITS; //total of entries or blocks
    localparam integer BASE_BIT_TAG =N_BITS_BLOCK+WORD_OFFSET_BITS; //total of entries or blocks

    wire [ADDRESS_SIZE-1:0] p_a_next;
    wire prefetch_mode;
    reg [N_BLOCKS-1:0] d_valid;// 1-bit valid RAM]
    reg [N_BITS_TAG-1:0] d_tags [0:N_BLOCKS-1];// ??-bit tag [RAM]
    reg [N_WORDS_BLOCK*I_WORD_SIZE-1:0] d_data [0:N_BLOCKS-1];// 32-bit data [RAM]
    wire [N_BITS_BLOCK-1:0] index = p_a[ (N_BITS_BLOCK-1+BASE_BIT_BLOCK):BASE_BIT_BLOCK];// block index
    wire [N_BITS_TAG-1:0] tag = p_a[ADDRESS_SIZE-1:BASE_BIT_TAG];// address tag
    wire [N_BITS_TAG-1:0] next_tag;
    wire c_write;// cache write
    wire [MEM_BUS-1:0] c_din;// data to cache
    wire [WORD_OFFSET_BITS-1:0] word_offset = p_a[(WORD_OFFSET_BITS-1+WORD_OFFSET_BITS):WORD_OFFSET_BITS];

    logic [N_BITS_TAG-1:0] tagout;
    logic [MEM_BUS-1:0] p_din_in;
    logic [I_WORD_SIZE-1:0] p_din_aux;
    wire [I_WORD_SIZE-1:0] c_dout;

    assign p_a_next = p_a + ( BYTES_PER_WORD*N_WORDS_BLOCK );
    assign next_tag = p_a_next[ADDRESS_SIZE-1:BASE_BIT_TAG];// address tag
    wire [N_BITS_BLOCK-1:0] next_index = p_a_next[ (N_BITS_BLOCK-1+BASE_BIT_BLOCK):BASE_BIT_BLOCK];// block index
    wire [I_WORD_SIZE-1:0] mem_tmp;
    always @ (posedge clk or negedge clrn) begin
        if (!clrn) begin
            d_valid <={N_BLOCKS{1'b0}};// assign all to 0
        end else if (c_write)begin
            if (prefetch_mode) begin
                d_valid[next_index] <= 1'b1;// write valid
                d_data[next_index] <= c_din;// write data
            end else begin
                d_valid[index] <= 1'b1;// write valid
                d_data[index] <= c_din;// write data
            end
        end
    end
    wire valid = d_valid[index]; // read cache valid
    wire cache_hit = p_strobe & valid & (tagout == tag); // cache hit
    assign next_block_valid = d_valid[next_index];

    generate
    genvar i;
        for (i=0; i<N_WORDS_BLOCK; i=i+1) begin
            always @ (posedge clk) begin
                if (m_ready && prefetch_mode && uncached) begin
                    d_tags[next_index][N_BITS_TAG-1:0] <= next_tag;
                end
                if (c_write && word_offset==i) begin
                    d_tags[index][N_BITS_TAG-1:0] <= tag;// write address tag
                end
            end
        end
    endgenerate
    assign p_din_in = cache_hit ? d_data[index] : m_dout; // data from cache or mem

    always_comb begin
        case(word_offset)
            2'b00: begin
                p_din_aux = p_din_in[31:0];
            end
            2'b01: begin
                p_din_aux = p_din_in[63:32];
            end
            2'b10: begin
                p_din_aux = p_din_in[95:64];
            end
            2'b11: begin
                p_din_aux = p_din_in[127:96];
            end
            default: begin
                p_din_aux = 32'h0;
            end
        endcase
    end
    assign tagout = d_tags[index][N_BITS_TAG-1:0]; // read cache tag

    assign p_din = p_din_aux;
    assign prefetch_mode = valid & ~next_block_valid & PREFETCH;
    assign c_dout[I_WORD_SIZE-1:0] = d_data[index][MEM_BUS-1:0]; // read cache data
    assign cache_miss = (p_strobe & (!valid | (tagout != tag))) | prefetch_mode ; // cache miss
    assign m_a = (prefetch_mode) ? p_a_next : p_a;
    assign m_strobe = cache_miss  ; // read on miss
    assign p_ready = cache_hit | cache_miss & m_ready; // data ready
    assign c_write = cache_miss & uncached & m_ready; // write cache
    assign c_din = m_dout; // data from mem

endmodule

