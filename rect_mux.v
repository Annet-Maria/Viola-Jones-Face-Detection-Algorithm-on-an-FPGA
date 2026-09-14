module rect_mux (
    input  wire [1:0] sel, // 2-bit unsigned select
    input  wire [4:0] a,   // 5-bit unsigned
    input  wire [4:0] b,   // 5-bit unsigned
    input  wire [4:0] c,   // 5-bit unsigned
    output reg  [4:0] q    // 5-bit unsigned
);

    always @(*) begin
        case (sel)
            2'b00:   q = a;
            2'b01:   q = b;
            2'b10:   q = c;
            default: q = 5'b00000;
        endcase
    end

endmodule
