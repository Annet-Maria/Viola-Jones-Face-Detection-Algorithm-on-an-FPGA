// ==========================================================================
// ov7670_controller.v - OV7670 configuration and clocking
// --------------------------------------------------------------------------
// Generates XCLK (clk / 2 = 25 MHz), keeps the camera out of reset and power
// down, and writes the register list of ov7670_registers.v over SCCB.
// config_finished (LEDR1) goes high when the list is done; resend (SW16)
// writes it again.  Clock: clk_50_camera.  Used by: top.v
// ==========================================================================

// Controller for the OV7670 camera - transfers registers to the 
// camera over an I2C like bus

`timescale 1 ps / 1 ps

module ov7670_controller (
    input  wire  clk,
    input  wire  resend,
    output wire  config_finished,
    output wire  sioc,
    inout  wire  siod,
    output wire  reset,
    output wire  pwdn,
    output wire  xclk
);

    // Internal Signals
    reg        sys_clk = 1'b0;
    wire [15:0] command;
    wire       finished;
    wire       taken;
    wire       send;

    // Device write ID (0x42); see datasheet of camera module
    localparam [7:0] CAMERA_ADDRESS = 8'h42;

    // Continuous Assignments
    assign config_finished = finished;
    assign send            = ~finished;
    assign reset           = 1'b1; // Normal mode
    assign pwdn            = 1'b0; // Power device up
    assign xclk            = sys_clk;

    i2c_sender Inst_i2c_sender (
        .clk      (clk),
        .siod     (siod),
        .sioc     (sioc),
        .taken    (taken),
        .send     (send),
        .id       (CAMERA_ADDRESS),
        .reg_addr (command[15:8]),
        .value    (command[7:0])
    );

    ov7670_registers Inst_ov7670_registers (
        .clk      (clk),
        .advance  (taken),
        .command  (command),
        .finished (finished),
        .resend   (resend)
    );

    // Clock divider process (Divide-by-2 for sys_clk / xclk)
    always @(posedge clk) begin
        sys_clk <= ~sys_clk;
    end

endmodule