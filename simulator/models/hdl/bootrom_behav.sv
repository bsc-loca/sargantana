// See LICENSE for license details.

module bootrom_behav
   (
    input  logic clk, rstn,
    input  logic [23:0] brom_req_address_i,
    input  logic brom_req_valid_i,
    output logic brom_ready_o,
    output logic [31:0] brom_resp_data_o,
    output logic brom_resp_valid_o
    );

    localparam MEM_DATA_WIDTH = 128;
    localparam BRAM_ADDR_WIDTH = 19; // 64 KB
    localparam BRAM_LINE = 2 ** BRAM_ADDR_WIDTH  * 8 / MEM_DATA_WIDTH;
    localparam BRAM_LINE_OFFSET = $clog2(MEM_DATA_WIDTH/8);

    (* ram_style = "block" *) reg [MEM_DATA_WIDTH-1:0] boot_ram [0 : BRAM_LINE-1];
    initial begin
        string bootrom;
        if (!$value$plusargs("bootrom=%s", bootrom)) bootrom = "bootrom.hex";
        $readmemh(bootrom, boot_ram);
    end

    logic [MEM_DATA_WIDTH-1:0] brom_resp_data_block;
    logic [23:0] brom_req_address_d;
    logic [7:0] brom_count;
    logic req_active;

    always_ff @(posedge clk, negedge rstn) begin
        if (~rstn) begin
            brom_count <= 'b0;
            req_active  <= 'b0;
            brom_resp_valid_o <= 'b0;
        end else begin
            if(brom_req_valid_i) begin
                req_active  <= 'b1;
                brom_req_address_d <= brom_req_address_i;
            end 

            if(~req_active) begin
                brom_count <= 'b0;
            end else begin
                brom_count <= brom_count +1;
            end

            if(brom_count == 3) begin
                req_active <= 'b0;
                brom_resp_valid_o <= 'b1;
            end else begin
                brom_resp_valid_o <= 'b0;
            end
        end
    end

    logic ram_clk, ram_rst, ram_en;
    logic [MEM_DATA_WIDTH/8-1:0] ram_we;
    logic [MEM_DATA_WIDTH-1:0] ram_wrdata, ram_rddata;

    always_ff @(posedge clk) begin
        brom_resp_data_block = boot_ram[brom_req_address_d[BRAM_ADDR_WIDTH-1:BRAM_LINE_OFFSET]];
        foreach (ram_we[i])
            if(ram_we[i])
                boot_ram[brom_req_address_d[BRAM_ADDR_WIDTH-1:BRAM_LINE_OFFSET]][i*8 +:8] <= ram_wrdata[i*8 +: 8];
    end

    always_comb begin
        case(brom_req_address_d[3:2])
            2'b00: brom_resp_data_o = brom_resp_data_block[31:0];
            2'b01: brom_resp_data_o = brom_resp_data_block[63:32];
            2'b10: brom_resp_data_o = brom_resp_data_block[95:64];
            2'b11: brom_resp_data_o = brom_resp_data_block[127:96];
            default: brom_resp_data_o = 32'h0;
        endcase
    end

    assign brom_ready_o = ~req_active & rstn;

endmodule // bootrom_behav
