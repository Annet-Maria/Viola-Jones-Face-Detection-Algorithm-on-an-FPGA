
module debounce (
    input wire clk,
    input wire i,
    output reg o
);

    reg [23:0] c;

    always @(posedge clk) begin
        if (i) begin
            if (c == 24'hFFFFFF)
                o <= 1'b1;
            else
                o <= 1'b0;

            c <= c + 1'b1;
        end
        else begin
            c <= 24'b0;
            o <= 1'b0;
        end
    end

endmodule