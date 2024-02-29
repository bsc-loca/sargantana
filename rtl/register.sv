module register #(
    parameter WIDTH = 64
) (
    input logic clk_i,
    input logic rstn_i,
    input logic flush_i,
    input logic load_i,
    input logic [WIDTH-1:0] input_i,
    output logic [WIDTH-1:0] output_o
);
logic [WIDTH-1:0] register_q;
    
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            register_q <= 0;
        end else if (flush_i) begin
            register_q <= 0;
        end else if (load_i) begin
            register_q <= input_i;
        end else begin
            register_q <= register_q;
        end
    end

    assign output_o = register_q;

endmodule

`default_nettype wire

