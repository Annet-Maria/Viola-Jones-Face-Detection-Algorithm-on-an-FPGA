module counter #(
    parameter COUNT_WIDTH = 4
)(
    input wire clk,
    input wire reset,
    input wire en,
    output reg [COUNT_WIDTH-1:0] count
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            count <= {COUNT_WIDTH{1'b0}};
        else if (en)
            count <= count + 1'b1;
    end

endmodule
