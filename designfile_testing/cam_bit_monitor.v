// Diagnostic: one LED per OV7670 data line. An LED is lit when that line was
// seen both high and low during HREF in the last ~0.34 s window (2^23 PCLKs
// at 25 MHz). A dark LED means the line is stuck - check its wire.

module cam_bit_monitor (
    input  wire       pclk,
    input  wire       href,
    input  wire [7:0] d,
    output reg  [7:0] active
);

    reg [22:0] window   = 23'd0;
    reg [7:0]  seen_one  = 8'h00;
    reg [7:0]  seen_zero = 8'h00;

    always @(posedge pclk) begin
        window <= window + 1'b1;

        if (window == 23'd0) begin
            active    <= seen_one & seen_zero;
            seen_one  <= 8'h00;
            seen_zero <= 8'h00;
        end else if (href) begin
            seen_one  <= seen_one  |  d;
            seen_zero <= seen_zero | ~d;
        end
    end

endmodule
