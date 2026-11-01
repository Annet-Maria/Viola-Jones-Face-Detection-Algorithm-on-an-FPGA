// ==========================================================================
// vga.v - 640x480 @ 60 Hz VGA timing (module VGA)
// --------------------------------------------------------------------------
// From the 25 MHz pixel clock: Hsync/Vsync, Nblank (visible 640x480),
// activeArea (the 320x240 camera image in the top-left corner) and the
// pixel counters hcount/vcount used by the overlays.  Used by: top.v
// ==========================================================================

module VGA (
    input  wire CLK25,
    output wire clkout,
    output reg  Hsync,
    output reg  Vsync,
    output wire Nblank,
    output reg  activeArea,
    output wire Nsync,
    output wire [9:0] hcount,
    output wire [9:0] vcount
);

    reg [9:0] Hcnt = 10'b0000000000;
    reg [9:0] Vcnt = 10'b1000001000;

    wire video;

    localparam integer HM = 799;
    localparam integer HD = 640;
    localparam integer HF = 16;
    localparam integer HB = 48;
    localparam integer HR = 96;

    localparam integer VM = 524;
    localparam integer VD = 480;
    localparam integer VF = 10;
    localparam integer VB = 33;
    localparam integer VR = 2;

    // Horizontal / vertical counters
    always @(posedge CLK25) begin

        if (Hcnt == HM) begin
            Hcnt <= 10'd0;

            if (Vcnt == VM) begin
                Vcnt <= 10'd0;
                activeArea <= 1'b1;
            end
            else begin
                if (Vcnt < 10'd239)
                    activeArea <= 1'b1;

                Vcnt <= Vcnt + 10'd1;
            end
        end
        else begin
            if (Hcnt == 10'd319)
                activeArea <= 1'b0;

            Hcnt <= Hcnt + 10'd1;
        end
    end

    // Horizontal sync
    always @(posedge CLK25) begin
        if ((Hcnt >= 10'd656) &&
            (Hcnt <= 10'd751))
            Hsync <= 1'b0;
        else
            Hsync <= 1'b1;
    end

    // Vertical sync
    always @(posedge CLK25) begin
        if ((Vcnt >= 10'd490) &&
            (Vcnt <= 10'd491))
            Vsync <= 1'b0;
        else
            Vsync <= 1'b1;
    end

    // Video area
    assign video = (Hcnt < HD) && (Vcnt < VD);

    assign Nblank = video;

    // TFT sync control
    assign Nsync = 1'b1;

    assign hcount = Hcnt;
    assign vcount = Vcnt;

    // 25 MHz output clock
    assign clkout = CLK25;

endmodule