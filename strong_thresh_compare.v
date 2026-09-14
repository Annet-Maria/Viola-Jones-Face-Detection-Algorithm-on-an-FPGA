module strong_thresh_compare (
    input  wire signed [21:0] strong_accumulator_result, // 22-bit signed
    input  wire signed [11:0] strong_thresh,             // 12-bit signed
    output wire               q                         // asserts 1 when scaled accumulator > scaled thresh
);

    // Multiplications with signed constant literals
    // 22-bit signed * 5-bit signed constant (6) = 27-bit signed
    wire signed [26:0] result_mult0 = strong_accumulator_result * 5'sd6;

    // 12-bit signed * 4-bit signed constant (7) = 16-bit signed
    wire signed [15:0] result_mult1 = strong_thresh * 4'sd7;

    // Signed comparison
    assign q = (result_mult0 > result_mult1) ? 1'b1 : 1'b0;

endmodule
