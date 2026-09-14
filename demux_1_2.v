module demux_1_2 #(
    parameter DATA_WIDTH = 4
)(
    input wire sel,
    input wire [DATA_WIDTH-1:0] a,
    output reg [DATA_WIDTH-1:0] q0,
    output reg [DATA_WIDTH-1:0] q1
);

    always @(*) begin
        if (sel == 1'b1) begin
            q0 = {DATA_WIDTH{1'b0}};
            q1 = a;
        end
        else begin
            q0 = a;
            q1 = {DATA_WIDTH{1'b0}};
        end
    end

endmodule
