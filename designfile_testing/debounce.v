// ==========================================================================
// debounce.v - long-press filter for a slide switch
// --------------------------------------------------------------------------
// Output goes high for one clock only after the input has been high for
// 2^24 consecutive clocks (~0.67 s at 25 MHz) and again every 0.67 s while it
// stays high. Used for SW16 (resend camera registers).  Used by: top.v
// ==========================================================================

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