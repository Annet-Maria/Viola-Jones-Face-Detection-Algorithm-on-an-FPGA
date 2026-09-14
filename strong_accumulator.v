module strong_accumulator (
    input  wire        reset, // synchronous reset (per VHDL logic inside rising_edge)
    input  wire        en,
    input  wire        clk,
    input  wire signed [13:0] din,  // 14-bit signed input
    output wire signed [21:0] dout  // 22-bit signed output
);

    reg signed [21:0] dout_reg = 22'sd0; // 22-bit signed register

    // Adder automatically performs sign-extension from 14-bit to 22-bit
    wire signed [21:0] result_adder0 = din + dout_reg;

    // Accumulator register logic
    always @(posedge clk) begin
        if (reset) begin
            dout_reg <= 22'sd0;
        end else if (en) begin
            dout_reg <= result_adder0;
        end
    end

    assign dout = dout_reg;

endmodule
