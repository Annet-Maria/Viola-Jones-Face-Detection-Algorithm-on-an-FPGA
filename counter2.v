// counter2.v
module counter2 #(
    parameter COUNT_WIDTH = 4
)(
    input  wire clk,
    input  wire reset,
    input  wire en,
    output reg  [COUNT_WIDTH-1:0] count
);

    reg [COUNT_WIDTH-1:0] num;

    always @(posedge clk) begin
        if (reset) begin
            num <= {COUNT_WIDTH{1'b0}};
        end else if (en) begin
            num <= num + 1'b1;
        end
    end

    always @(*) begin
        count = num;
    end

endmodule

