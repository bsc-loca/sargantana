`default_nettype none

module register #(
    parameter WIDTH = 64
) (
    input wire clk_i,
    input wire rstn_i,
    input wire load_i,
    input wire [WIDTH-1:0] input_i,
    output reg [WIDTH-1:0] output_o
);
    
    always @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            output_o <= 0;
        end else if (load_i) begin
            output_o <= input_i;
        end else begin
            output_o <= output_o;
        end
    end

endmodule

`default_nettype wire

