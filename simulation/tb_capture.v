`timescale 1ns/1ps
// Testbench: ov7670_capture
// A behavioural OV7670 sends one 640x480 RGB565 frame (2 bytes per PCLK pair,
// HREF per line, VSYNC per frame). The test checks that exactly 76,800 pixels
// are written, in address order 0..76,799, and that every stored pixel is the
// expected camera pixel (x = 2*col+1, line = 4*(row/2)+1+row%2), for both the
// 12-bit colour output and the 8-bit grey output.
module tb_capture;
    reg pclk = 0;
    always #20 pclk = ~pclk;                 // 25 MHz PCLK

    reg        vsync = 0, href = 0, capture = 1;
    reg  [7:0] d = 0;
    wire [16:0] addr;
    wire [11:0] dout;
    wire [7:0]  grey;
    wire        we, live_we, busy;

    ov7670_capture dut (
        .pclk(pclk), .capture(capture), .vsync(vsync), .href(href), .d(d),
        .addr(addr), .dout(dout), .grey(grey), .we(we), .live_we(live_we), .busy(busy)
    );

    // camera pixel value (RGB565) at column x, line y
    function [15:0] pix;
        input [9:0] x; input [8:0] y;
        pix = {x[4:0], y[5:0], x[9:5] ^ y[4:0]};
    endfunction

    function [11:0] rgb444;
        input [15:0] w;
        rgb444 = {w[15:12], w[10:7], w[4:1]};
    endfunction

    function [7:0] grey_of;
        input [15:0] w;
        reg [7:0] r8, g8, b8; reg [15:0] y16;
        begin
            r8 = {w[15:11], w[15:13]}; g8 = {w[10:5], w[10:9]}; b8 = {w[4:0], w[4:2]};
            y16 = r8 * 8'd77 + g8 * 8'd150 + b8 * 8'd29;
            grey_of = y16[15:8];
        end
    endfunction

    // ---------------- camera model ----------------
    integer x, y;
    task send_frame;
        begin
            @(negedge pclk) vsync = 1;
            repeat (3 * 784) @(negedge pclk);
            vsync = 0;
            repeat (17 * 784) @(negedge pclk);          // vertical back porch
            for (y = 0; y < 480; y = y + 1) begin
                for (x = 0; x < 640; x = x + 1) begin
                    @(negedge pclk) begin href = 1; d = pix(x, y) >> 8; end
                    @(negedge pclk) d = pix(x, y);
                end
                @(negedge pclk) begin href = 0; d = 0; end
                repeat (287) @(negedge pclk);              // horizontal blanking
            end
            repeat (10 * 784) @(negedge pclk);
            @(negedge pclk) vsync = 1;                     // start of next frame
            repeat (3 * 784) @(negedge pclk);
            vsync = 0;
        end
    endtask

    // ---------------- checker ----------------
    integer writes = 0, det_writes = 0, errors = 0, col, row, cam_x, cam_y;
    reg [15:0] exp_w;
    always @(posedge pclk) if (live_we) begin
        col   = writes % 320;
        row   = writes / 320;
        cam_x = 2 * col + 1;
        cam_y = 4 * (row / 2) + 1 + (row % 2);
        exp_w = pix(cam_x, cam_y);
        if (addr !== writes[16:0] || dout !== rgb444(exp_w) || grey !== grey_of(exp_w)) begin
            if (errors < 5)
                $display("MISMATCH write %0d: addr=%0d dout=%h (exp %h) grey=%h (exp %h)",
                         writes, addr, dout, rgb444(exp_w), grey, grey_of(exp_w));
            errors = errors + 1;
        end
        if (we) det_writes = det_writes + 1;
        if (writes == 0 || writes == 1 || writes == 319 || writes == 320 || writes == 76799)
            $display("  write %5d  addr=%5d  <- camera pixel (x=%0d, line=%0d)  colour=%h grey=%h",
                     writes, addr, cam_x, cam_y, dout, grey);
        writes = writes + 1;
    end

    // waveform log: first 24 PCLKs of the first kept line (camera line 1)
    integer f, cyc = 0;
    reg logging = 0;
    initial f = $fopen("capture_wave.csv", "w");
    always @(posedge pclk) begin
        if (!logging && dut.line == 2'b10 && href) logging = 1;
        if (logging && cyc < 24) begin
            $fdisplay(f, "%0d,%0d,%0d,%0d,%0d,%0d,%0d", cyc, href, d, dut.href_last[2:0], live_we, addr, dut.d_latch);
            cyc = cyc + 1;
        end
    end

    reg busy_seen = 0;
    // like the main FSM: request a snapshot until the capture reports busy
    always @(posedge pclk) if (busy) begin busy_seen = 1; capture = 0; end

    initial begin
        $display("=== ov7670_capture: one 640x480 RGB565 frame ===");
        send_frame;
        repeat (20) @(posedge pclk);
        $display("pixels written to live_ram  : %0d (expected 76800)", writes);
        $display("pixels written to image_ram : %0d (expected 76800, capture=1)", det_writes);
        $display("busy went high during frame : %0d, busy now : %0d", busy_seen, busy);
        $display("pixel value mismatches      : %0d", errors);
        if (writes == 76800 && det_writes == 76800 && errors == 0 && busy_seen && !busy)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $fclose(f);
        $finish;
    end
endmodule
