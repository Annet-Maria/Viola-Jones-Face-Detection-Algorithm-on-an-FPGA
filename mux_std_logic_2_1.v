// this is a 2:1 mux

module mux_std_logic (
    input  wire sel,
    input  wire a,
    input  wire b,
    output reg  q
);

    always @(*) begin
        if (sel == 1'b1) begin
            q = b;
        end else begin
            q = a;
        end
    end

endmodule
