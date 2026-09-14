module var_norm_calc (
    input  wire        clk,

    input  wire [19:0] p0,
    input  wire [19:0] p1,
    input  wire [19:0] p2,
    input  wire [19:0] p3,

    input  wire [27:0] ssp0,
    input  wire [27:0] ssp1,
    input  wire [27:0] ssp2,
    input  wire [27:0] ssp3,

    output reg  [21:0] var_norm_factor
);

    // ---------------------------------------------------------
    // Intermediate signals
    // ---------------------------------------------------------

    // p0 + p3, p1 + p2
    wire [20:0] result_add0;
    wire [20:0] result_add1;

    // Difference
    wire [20:0] result_sub0;

    // m^2
    wire [41:0] result_mult0;
    wire [42:0] result_mult0_extend;

    // ssp0 + ssp3, ssp1 + ssp2
    wire [28:0] result_add2;
    wire [28:0] result_add3;

    // Difference
    wire [28:0] result_sub1;

    // sum(x^2)/512
    wire [28:0] result_divide0;
    wire [42:0] result_divide0_extend;

    // m^2 - sum(x^2)/n
    wire [43:0] result_sub2;

    // Square-root output
    wire [21:0] result_sqrt0;

    // ---------------------------------------------------------
    // m = (p0 + p3) - (p1 + p2)
    // ---------------------------------------------------------

    assign result_add0 = {1'b0, p0} + {1'b0, p3};

    assign result_add1 = {1'b0, p1} + {1'b0, p2};

    assign result_sub0 = result_add0 - result_add1;

    // ---------------------------------------------------------
    // m^2
    // ---------------------------------------------------------

    assign result_mult0 = result_sub0 * result_sub0;

    // Always positive, so MSB extension = 0
    assign result_mult0_extend = {1'b0, result_mult0};

    // ---------------------------------------------------------
    // sum(x^2)
    // ---------------------------------------------------------

    assign result_add2 = {1'b0, ssp0} + {1'b0, ssp3};

    assign result_add3 = {1'b0, ssp1} + {1'b0, ssp2};

    assign result_sub1 = result_add2 - result_add3;

    // ---------------------------------------------------------
    // sum(x^2) / n
    //
    // Original VHDL:
    // result_sub1(28 downto 9)
    //
    // This is equivalent to logical right shift by 9.
    // ---------------------------------------------------------

    assign result_divide0 = {9'b0, result_sub1[28:9]};

    // Extend to 43 bits
    assign result_divide0_extend = {14'b0, result_divide0};

    // ---------------------------------------------------------
    // m^2 - sum(x^2)/n
    // ---------------------------------------------------------

    assign result_sub2 =
        $signed(result_mult0_extend) -
        $signed(result_divide0_extend);

    // ---------------------------------------------------------
    // Square root
    //
    // Original uses Altera/Intel megafunction:
    // altsqrt_varianceCalc
    //
    // Replace this with the Verilog-generated megafunction
    // from Quartus.
    // ---------------------------------------------------------

    altsqrt_varianceCalc sqrt0 (
        .clk       (clk),
        .radical   (result_sub2),
        .q         (result_sqrt0),
        .remainder ()
    );

    // ---------------------------------------------------------
    // sqrt mux
    // ---------------------------------------------------------
    //
    // If result_sub2 is negative, output 1.
    // Otherwise output square root.
    //
    // Original checks bit 43.
    //

    always @(*) begin
        if (result_sub2[43] == 1'b0)
            var_norm_factor = result_sqrt0;
        else
            var_norm_factor = 22'd1;
    end

endmodule
