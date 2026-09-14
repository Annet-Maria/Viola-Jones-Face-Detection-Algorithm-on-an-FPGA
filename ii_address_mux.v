module ii_address_mux (
    input  wire [1:0]  sel,
    input  wire [14:0] a,
    input  wire [14:0] b,
    input  wire [14:0] c,
    input  wire [14:0] d,
    output reg  [14:0] q
);

    always @(*) begin
        case (sel)
            2'b00: q = a;
            2'b01: q = b;
            2'b10: q = c;
            2'b11: q = d;
            default: q = 15'b0;
        endcase
    end

endmodule
