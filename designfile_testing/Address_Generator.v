// ==========================================================================
// Address_Generator.v - VGA read address for the 320x240 live frame
// --------------------------------------------------------------------------
// Counts one pixel per 25 MHz clock while the VGA image area is active
// (enable = activeArea), stops at 76,800 and restarts during vertical sync.
// The address reads live_ram (camera image) and the overlays line up with it.
// Clock: clk_25_vga.  Used by: top.v
// ==========================================================================

module Address_Generator (
    input  wire        rst_i,
    input  wire        CLK25,    // 25 MHz clock
    input  wire        enable,   // Enable signal
    input  wire        vsync,    // Vertical sync signal
    output wire [16:0] address   // Generated address (17 bits)
);

    // Intermediate register signal (equivalent to 'val' in VHDL)
    reg [16:0] val = 17'd0;

    // Continuous assignment to drive the output address
    assign address = val;

    always @(posedge CLK25) begin
        if (rst_i) begin
            val <= 17'd0;
        end else begin
            if (enable) begin
                // 320 * 240 = 76800
                if (val < 17'd76800) begin
                    val <= val + 1'b1;
                end
            end
            
            if (!vsync) begin
                val <= 17'd0;
            end
        end
    end

endmodule
