// this is a 2:1 mux

module mux_2_1 #(
    parameter DATA_WIDTH = 4
)(
    input  wire                  sel,
    input  wire [DATA_WIDTH-1:0] a,
    input  wire [DATA_WIDTH-1:0] b,
    output reg  [DATA_WIDTH-1:0] q
);

    always @(*) begin
        if (sel == 1'b1) begin
            q = b;
        end else begin
            q = a;
        end
    end

endmodule
