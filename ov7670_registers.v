// register settings for the OV7670 camera (partially from OV7670.c
// in the Linux Kernel)
//
// this is tricky; based on my experience, using an OV7670 camera module
// has a LOT to do with how we set/program the camera's registers;
// it seems that the register values here get it right; thanks to the guys
// who managed to dig this up: Mike Field, Christopher Wilson;
// 
// Notes:
// 1) Regarding the finished flag check:
// finished is asserted high ('1') when sreg reaches 16'hFFFF.

`timescale 1 ps / 1 ps

module ov7670_registers (
    input  wire        clk,
    input  wire        resend,
    input  wire        advance,
    output wire [15:0] command,
    output wire        finished
);

    reg [15:0] sreg;
    reg [7:0]  address = 8'h00;

    assign command  = sreg;
    assign finished = (sreg == 16'hFFFF) ? 1'b1 : 1'b0;

    always @(posedge clk) begin
        if (resend) begin
            address <= 8'h00;
        end else if (advance) begin
            address <= address + 1'b1;
        end

        case (address)
            8'h00: sreg <= 16'h1280; // COM7   Reset
            8'h01: sreg <= 16'h1280; // COM7   Reset
            8'h02: sreg <= 16'h1204; // COM7   Size & RGB output
            8'h03: sreg <= 16'h1100; // CLKRC  Prescaler - Fin/(1+1)
            8'h04: sreg <= 16'h0C00; // COM3   Lots of stuff, enable scaling, all others off
            8'h05: sreg <= 16'h3E00; // COM14  PCLK scaling off

            8'h06: sreg <= 16'h8C00; // RGB444 Set RGB format
            8'h07: sreg <= 16'h0400; // COM1   no CCIR601
            8'h08: sreg <= 16'h4010; // COM15  Full 0-255 output, RGB 565
            8'h09: sreg <= 16'h3a04; // TSLB   Set UV ordering,  do not auto-reset window
            8'h0A: sreg <= 16'h1438; // COM9   - AGC Celling
            8'h0B: sreg <= 16'h4f40; // MTX1   - colour conversion matrix
            8'h0C: sreg <= 16'h5034; // MTX2   - colour conversion matrix
            8'h0D: sreg <= 16'h510C; // MTX3   - colour conversion matrix
            8'h0E: sreg <= 16'h5217; // MTX4   - colour conversion matrix
            8'h0F: sreg <= 16'h5329; // MTX5   - colour conversion matrix
            8'h10: sreg <= 16'h5440; // MTX6   - colour conversion matrix
            8'h11: sreg <= 16'h581e; // MTXS   - Matrix sign and auto contrast
            8'h12: sreg <= 16'h3dc0; // COM13  - Turn on GAMMA and UV Auto adjust
            8'h13: sreg <= 16'h1100; // CLKRC  Prescaler - Fin/(1+1)

            8'h14: sreg <= 16'h1711; // HSTART HREF start (high 8 bits)
            8'h15: sreg <= 16'h1861; // HSTOP  HREF stop (high 8 bits)
            8'h16: sreg <= 16'h32A4; // HREF   Edge offset and low 3 bits of HSTART and HSTOP

            8'h17: sreg <= 16'h1903; // VSTART VSYNC start (high 8 bits)
            8'h18: sreg <= 16'h1A7b; // VSTOP  VSYNC stop (high 8 bits)
            8'h19: sreg <= 16'h030a; // VREF   VSYNC low two bits

            8'h1A: sreg <= 16'h0e61; // COM5(0x0E) 0x61
            8'h1B: sreg <= 16'h0f4b; // COM6(0x0F) 0x4B

            8'h1C: sreg <= 16'h1602;
            8'h1D: sreg <= 16'h1e37; // MVFP (0x1E) 0x07  -- FLIP AND MIRROR IMAGE 0x3x

            8'h1E: sreg <= 16'h2102;
            8'h1F: sreg <= 16'h2291;

            8'h20: sreg <= 16'h2907;
            8'h21: sreg <= 16'h330b;

            8'h22: sreg <= 16'h350b;
            8'h23: sreg <= 16'h371d;

            8'h24: sreg <= 16'h3871;
            8'h25: sreg <= 16'h392a;

            8'h26: sreg <= 16'h3c78; // COM12 (0x3C) 0x78
            8'h27: sreg <= 16'h4d40;

            8'h28: sreg <= 16'h4e20;
            8'h29: sreg <= 16'h6900; // GFIX (0x69) 0x00

            8'h2A: sreg <= 16'h6b4a;
            8'h2B: sreg <= 16'h7410;

            8'h2C: sreg <= 16'h8d4f;
            8'h2D: sreg <= 16'h8e00;

            8'h2E: sreg <= 16'h8f00;
            8'h2F: sreg <= 16'h9000;

            8'h30: sreg <= 16'h9100;
            8'h31: sreg <= 16'h9600;

            8'h32: sreg <= 16'h9a00;
            8'h33: sreg <= 16'hb084;

            8'h34: sreg <= 16'hb10c;
            8'h35: sreg <= 16'hb20e;

            8'h36: sreg <= 16'hb382;
            8'h37: sreg <= 16'hb80a;

            default: sreg <= 16'hFFFF;
        endcase
    end

endmodule