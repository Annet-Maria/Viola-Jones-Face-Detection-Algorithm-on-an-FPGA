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

    // Sub-module Instantiations (using positional mapping for i2c_sender)
    // Order: clk, send, taken, id, reg, value, siod, sioc
    i2c_sender Inst_i2c_sender (
        clk,
        send,
        taken,
        CAMERA_ADDRESS,
        command[15:8],
        command[7:0],
        siod,
        sioc
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