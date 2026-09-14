module feature_calc (
    input  wire [14:0] w0,
    input  wire [14:0] w1,
    input  wire [14:0] w2,

    input  wire [19:0] r0,
    input  wire [19:0] r1,
    input  wire [19:0] r2,
    input  wire [19:0] r3,
    input  wire [19:0] r4,
    input  wire [19:0] r5,
    input  wire [19:0] r6,
    input  wire [19:0] r7,
    input  wire [19:0] r8,
    input  wire [19:0] r9,
    input  wire [19:0] r10,
    input  wire [19:0] r11,

    output wire [38:0] result_feature
);

    wire signed [36:0] result_rect0;
    wire signed [36:0] result_rect1;
    wire signed [36:0] result_rect2;

    wire signed [37:0] result_temp;
    wire signed [37:0] result_rect2_extend;

    /*
     * rect0:
     * w0 * ((r0 + r3) - (r1 + r2))
     */
    rect_calc rect0 (
        .weight(w0),
        .a(r0),
        .b(r1),
        .c(r2),
        .d(r3),
        .result(result_rect0)
    );

    /*
     * rect1:
     * w1 * ((r4 + r7) - (r5 + r6))
     */
    rect_calc rect1 (
        .weight(w1),
        .a(r4),
        .b(r5),
        .c(r6),
        .d(r7),
        .result(result_rect1)
    );

    /*
     * rect2:
     * w2 * ((r8 + r11) - (r9 + r10))
     */
    rect_calc rect2 (
        .weight(w2),
        .a(r8),
        .b(r9),
        .c(r10),
        .d(r11),
        .result(result_rect2)
    );

    /*
     * Sign extend both 37-bit results to 38 bits
     * and add them.
     */
    assign result_temp =
            $signed({result_rect0[36], result_rect0}) +
            $signed({result_rect1[36], result_rect1});

    /*
     * Sign extend result_rect2 from 37 bits to 38 bits.
     */
    assign result_rect2_extend =
            $signed({result_rect2[36], result_rect2});

    /*
     * Final result:
     * result_feature = result_rect0 + result_rect1 + result_rect2
     *
     * Sign extend to 39 bits, matching VHDL.
     */
    assign result_feature =
            $signed({result_rect2_extend[37], result_rect2_extend}) +
            $signed({result_temp[37], result_temp});

endmodule
