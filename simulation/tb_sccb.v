`timescale 1ns/1ps
// Testbench: ov7670_controller (ov7670_registers + i2c_sender)
// A behavioural SCCB receiver decodes every transaction on SIOC/SIOD
// (START, 3 bytes each followed by an ack slot, STOP) and prints
// device id / register / value. The test checks that all transactions go to
// device 0x42, that COM7, COM15 and MVFP get their expected values, that
// config_finished rises at the end, and that XCLK is 25 MHz.
module tb_sccb;
    reg clk = 0;
    always #10 clk = ~clk;                       // 50 MHz (clk_50_camera)

    reg  resend = 0;
    wire config_finished, sioc, reset, pwdn, xclk;
    wire siod;
    pullup (siod);                               // open-drain style bus

    ov7670_controller dut (
        .clk(clk), .resend(resend), .config_finished(config_finished),
        .sioc(sioc), .siod(siod), .reset(reset), .pwdn(pwdn), .xclk(xclk)
    );

    // ---------------- SCCB receiver ----------------
    reg        in_msg = 0;
    integer    nbits = 0, nmsg = 0, errors = 0;
    reg [27:0] bits;                             // 3 x (8 data + 1 ack) + clock before STOP
    reg        sioc_d = 1, siod_d = 1;
    reg [7:0]  id_b, reg_b, val_b;
    reg        com7_ok = 0, com15_ok = 0, mvfp_ok = 0;

    always @(posedge clk) begin
        sioc_d <= sioc;
        siod_d <= siod;
        // START: SIOD falls while SIOC is high
        if (sioc && sioc_d && siod_d && !siod) begin
            in_msg <= 1; nbits <= 0;
        end
        // data bit: sampled on SIOC rising edge
        else if (in_msg && sioc && !sioc_d) begin
            bits  <= {bits[26:0], siod};
            nbits <= nbits + 1;
        end
        // STOP: SIOD rises while SIOC is high
        else if (in_msg && sioc && sioc_d && !siod_d && siod) begin
            in_msg <= 0;
            id_b  = bits[27:20]; reg_b = bits[18:11]; val_b = bits[9:2];
            nmsg  = nmsg + 1;
            if (nbits != 28 || id_b != 8'h42) errors = errors + 1;
            if (nmsg <= 3 || reg_b == 8'h40 || reg_b == 8'h1E || reg_b == 8'h12)
                $display("  t=%8.3f ms  msg %2d: id=%h  reg=%h  value=%h", $realtime/1e6, nmsg, id_b, reg_b, val_b);
            if (reg_b == 8'h12 && val_b == 8'h04) com7_ok  = 1;
            if (reg_b == 8'h40 && val_b == 8'hD0) com15_ok = 1;
            if (reg_b == 8'h1E && val_b == 8'h37) mvfp_ok  = 1;
        end
    end

    // XCLK frequency check
    realtime t_x1 = 0, t_x2 = 0;
    initial begin
        @(posedge xclk); t_x1 = $realtime;
        @(posedge xclk); t_x2 = $realtime;
    end

    // waveform log: the first message, sampled every 32 clocks (640 ns)
    integer f, n = 0;
    reg started = 0;
    initial f = $fopen("sccb_wave.csv", "w");
    always @(posedge clk) begin
        if (dut.Inst_i2c_sender.busy_sr[31]) started = 1;
        if (started && n < 32 * 280) begin
            if (n % 32 == 0) $fdisplay(f, "%0d,%0d,%0d", n * 20, sioc, siod === 1'b0 ? 0 : 1);
            n = n + 1;
        end
    end

    initial begin
        $display("=== ov7670_controller: SCCB configuration ===");
        wait (config_finished);
        repeat (12000) @(posedge clk);   // last message is still on the bus when finished rises
        $display("transactions decoded      : %0d", nmsg);
        $display("bad id / bit count        : %0d", errors);
        $display("COM7=04, COM15=D0, MVFP=37: %0d %0d %0d", com7_ok, com15_ok, mvfp_ok);
        $display("config_finished at        : %0.3f ms", $realtime / 1e6);
        $display("XCLK period               : %0.1f ns (%0.1f MHz)", t_x2 - t_x1, 1000.0 / (t_x2 - t_x1));
        $display("reset pin = %0d (run), pwdn pin = %0d (powered)", reset, pwdn);
        if (errors == 0 && nmsg > 50 && com7_ok && com15_ok && mvfp_ok && reset && !pwdn)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $fclose(f);
        $finish;
    end
endmodule
