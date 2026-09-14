// Captures the pixels data of each frame coming from the OV7670 camera and 
// Stores them in block RAM
// The length of href controls how often pixels are captive - (2 downto 0) stores
// one pixel every 4 cycles.
// "line" is used to control how often data is captured. In this case every forth 
// line
// UPDATE: 1/29/2016 : added capture logic
// UPDATE: 1/29/2016 : added logic to write every other pixel in a row for every other row
//        ... this scales the 320x240 pixel input to 160x120 ... QVGA to QQVGA
//        ... OV7670 registers remain the same

`timescale 1 ps / 1 ps

module ov7670_capture (
    input  wire        pclk,
    input  wire        capture, // receives signal from a button to begin a single frame capture
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    output wire [16:0] addr,
    output wire [11:0] dout,
    output wire        we,
    output reg         busy
);

    // Internal Registers
    reg [15:0] d_latch         = 16'h0000;
    reg [17:0] address         = 18'h00000;
    reg [1:0]  line            = 2'b00;
    reg [6:0]  href_last       = 7'b0000000;
    reg        we_reg          = 1'b0;
    reg        href_hold       = 1'b0;
    reg        latched_vsync   = 1'b0;
    reg        latched_href    = 1'b0;
    reg [7:0]  latched_d       = 8'h00;
    reg        latched_capture = 1'b0;

    // Continuous Assignments
    assign addr = address[16:0];
    assign we   = we_reg;
    assign dout = {d_latch[15:12], d_latch[10:7], d_latch[4:1]};

    // Rising Clock Edge Block
    always @(posedge pclk) begin
        if (we_reg) begin
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
        we_reg <= 1'b0;

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
                if (line[1] == 1'b1) begin // added logic to check if the capture register was latched as logic '1'
                    if (latched_capture && (address < (17'd320 * 17'd240))) begin // necessary to prevent overloading memory
                        we_reg <= 1'b1;
                    end
                end
                href_last <= 7'b0000000;
            end else begin
                href_last <= {href_last[5:0], latched_href};
            end
        end
    end

    // Falling Clock Edge Block (Input Latching)
    always @(negedge pclk) begin
        latched_d     <= d;
        latched_href  <= href;
        latched_vsync <= vsync;
    end

endmodule