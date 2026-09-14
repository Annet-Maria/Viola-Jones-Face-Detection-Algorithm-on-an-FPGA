module rect_calc (
    input  wire signed [14:0] weight,  // signed input
    input  wire        [19:0] a,       // unsigned input
    input  wire        [19:0] b,       // unsigned input
    input  wire        [19:0] c,       // unsigned input
    input  wire        [19:0] d,       // unsigned input
    output wire signed [36:0] result   // signed result
);

    // Intermediate signals
    wire [20:0] result_add0; // MSb is carry from add0
    wire [20:0] result_add1; // MSb is carry from add1
    wire [20:0] result_sub0;
    wire [21:0] result_sub0_extend;

    // Unsigned addition with 1-bit zero extension for carry
    assign result_add0 = {1'b0, a} + {1'b0, d};
    assign result_add1 = {1'b0, b} + {1'b0, c};

    // Unsigned subtraction
    assign result_sub0 = result_add0 - result_add1;

    // Extend to 22 bits with a leading zero (ensures positive sign in 2's complement)
    assign result_sub0_extend = {1'b0, result_sub0};

    // Signed multiplication: $signed() forces unsigned result_sub0_extend to be treated as positive signed
    assign result = $signed(result_sub0_extend) * weight;

endmodule
