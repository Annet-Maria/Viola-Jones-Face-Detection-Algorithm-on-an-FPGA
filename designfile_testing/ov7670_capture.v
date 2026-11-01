// ==========================================================================
// ov7670_capture.v - OV7670 pixel capture (640x480 RGB565 -> 320x240)
// --------------------------------------------------------------------------
// Samples D/HREF/VSYNC on the rising PCLK edge (the camera changes them on
// the falling edge). Two bytes form one RGB565 pixel; every other pixel of
// every other line pair is kept, giving 320x240.
//   live_we : every frame -> live_ram (12-bit RGB444 dout) for the VGA image
//   we      : snapshot frames only (capture input latched at VSYNC) ->
//             image_ram (8-bit grey from the full RGB565 bits) for detection
//   busy    : high while a snapshot frame is being written
// Clock: ov7670_pclk.  Used by: top.v
// ==========================================================================

`timescale 1 ps / 1 ps

module ov7670_capture (
    input  wire        pclk,
    input  wire        capture, // receives signal from a button to begin a single frame capture
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    output wire [16:0] addr,
    output wire [11:0] dout,
    output wire [7:0]  grey,    // full-precision luminance of the same pixel (from RGB565)
    output wire        we,      // write strobe on snapshot frames only (detection buffer)
    output wire        live_we, // write strobe on every frame (live display buffer)
    output reg         busy
);

    // Internal Registers
    reg [15:0] d_latch         = 16'h0000;
    reg [17:0] address         = 18'h00000;
    reg [1:0]  line            = 2'b00;
    reg [6:0]  href_last       = 7'b0000000;
    reg        we_reg          = 1'b0;
    reg        live_we_reg     = 1'b0;
    reg        href_hold       = 1'b0;
    reg        latched_vsync   = 1'b0;
    reg        latched_href    = 1'b0;
    reg [7:0]  latched_d       = 8'h00;
    reg        latched_capture = 1'b0;

    // Continuous Assignments
    assign addr = address[16:0];
    assign we      = we_reg;
    assign live_we = live_we_reg;
    assign dout    = {d_latch[15:12], d_latch[10:7], d_latch[4:1]};

    // Y = (77 R + 150 G + 29 B) / 256 using all 5/6/5 bits
    wire [7:0]  r8 = {d_latch[15:11], d_latch[15:13]};
    wire [7:0]  g8 = {d_latch[10:5],  d_latch[10:9]};
    wire [7:0]  b8 = {d_latch[4:0],   d_latch[4:2]};
    wire [15:0] y16 = r8 * 8'd77 + g8 * 8'd150 + b8 * 8'd29;
    assign grey = y16[15:8];

    // Rising Clock Edge Block
    always @(posedge pclk) begin
        if (live_we_reg) begin
            address <= address + 1'b1;
        end

        // Detect the rising edge on href - the start of the scan line
        if (!href_hold && latched_href) begin
            case (line)
                2'b00:   line <= 2'b01;
                2'b01:   line <= 2'b10;
                2'b10:   line <= 2'b11;
                default: line <= 2'b00;
            endcase
        end
        href_hold <= latched_href;

        // Capturing the data from the camera, 12-bit RGB
        if (latched_href) begin
            d_latch <= {d_latch[7:0], latched_d};
        end
        we_reg      <= 1'b0;
        live_we_reg <= 1'b0;

        // Is a new screen about to start (i.e. we have to restart capturing)
        if (latched_vsync) begin
            address         <= 18'h00000;
            href_last       <= 7'b0000000;
            line            <= 2'b00;
            latched_capture <= capture; // latch the capture status during the vsync state
            busy            <= 1'b0;
        end else begin
            if (latched_capture) begin
                busy <= 1'b1;
            end
            
            // If not, set the write enable whenever we need to capture a pixel
            if (href_last[2] == 1'b1) begin
                if (line[1] == 1'b1) begin
                    if (address < (17'd320 * 17'd240)) begin // necessary to prevent overloading memory
                        live_we_reg <= 1'b1;
                        we_reg      <= latched_capture; // detection buffer only on snapshot frames
                    end
                end
                href_last <= 7'b0000000;
            end else begin
                href_last <= {href_last[5:0], latched_href};
            end
        end
    end

    // Input latching on the rising edge: the OV7670 changes D/HREF/VSYNC on the
    // falling edge of PCLK, so sampling on negedge caught bits mid-transition
    // (speckle, lost red MSB in highlights).
    always @(posedge pclk) begin
        latched_d     <= d;
        latched_href  <= href;
        latched_vsync <= vsync;
    end

endmodule