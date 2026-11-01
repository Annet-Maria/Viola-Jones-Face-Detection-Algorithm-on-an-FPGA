`timescale 1ns/1ps
// Testbench: flash_store with a behavioural S29GL064N (8-bit mode) model.
//   MODE 0: power-on load from an erased chip (expect nobody enrolled),
//           save 4 slots of known data, dump the flash, then KEY3 erase.
//   MODE 1: power-on load from the dumped flash (expect the same data back).
// The model checks the unlock/erase/program command sequences, only allows
// 1 -> 0 programming, and reports busy status on DQ7 (data polling).

// ---------------- flash model (one 64 KB sector at 0x400000) ----------------
module s29gl_model #(parameter PROG_NS = 1000, ERASE_NS = 200000) (
    input  wire [22:0] A,
    inout  wire [7:0]  DQ,
    input  wire        CE_N, OE_N, WE_N
);
    reg [7:0] mem [0:65535];
    integer   i, cmd_errors = 0, programs = 0, erases = 0;
    reg [2:0] cs = 0;                 // command state
    reg       busy = 0;
    reg [7:0] busy_data;              // byte being programmed (FF for erase)

    wire in_sector = (A[22:16] == 7'h40);
    wire [7:0] rd  = busy ? {~busy_data[7], 7'h00} : (in_sector ? mem[A[15:0]] : 8'hFF);
    assign DQ = (!CE_N && !OE_N && WE_N) ? rd : 8'bzzzzzzzz;

    always @(posedge WE_N) if (!CE_N && !busy) begin
        case (cs)
            0: if (DQ == 8'hF0) cs <= 0;
               else if (A[11:0] == 12'hAAA && DQ == 8'hAA) cs <= 1;
               else begin cmd_errors = cmd_errors + 1; cs <= 0; end
            1: if (A[11:0] == 12'h555 && DQ == 8'h55) cs <= 2; else begin cmd_errors = cmd_errors + 1; cs <= 0; end
            2: if (A[11:0] == 12'hAAA && DQ == 8'hA0) cs <= 3;
               else if (A[11:0] == 12'hAAA && DQ == 8'h80) cs <= 4;
               else begin cmd_errors = cmd_errors + 1; cs <= 0; end
            3: begin                                     // program one byte
                   if (!in_sector) cmd_errors = cmd_errors + 1;
                   else begin
                       mem[A[15:0]] = mem[A[15:0]] & DQ; // flash: only 1 -> 0
                       busy_data = DQ; busy = 1; programs = programs + 1;
                       #(PROG_NS) busy = 0;
                   end
                   cs <= 0;
               end
            4: if (A[11:0] == 12'hAAA && DQ == 8'hAA) cs <= 5; else begin cmd_errors = cmd_errors + 1; cs <= 0; end
            5: if (A[11:0] == 12'h555 && DQ == 8'h55) cs <= 6; else begin cmd_errors = cmd_errors + 1; cs <= 0; end
            6: begin                                     // sector erase
                   if (DQ == 8'h30 && in_sector) begin
                       busy_data = 8'hFF; busy = 1; erases = erases + 1;
                       #(ERASE_NS);
                       for (i = 0; i < 65536; i = i + 1) mem[i] = 8'hFF;
                       busy = 0;
                   end else cmd_errors = cmd_errors + 1;
                   cs <= 0;
               end
        endcase
    end
endmodule

// ---------------- testbench ----------------
module tb_flash;
    parameter MODE = 0;

    reg clk = 0;
    always #5 clk = ~clk;                         // 100 MHz (clk_iigen)

    reg        save_toggle = 0, erase_toggle = 0;
    reg  [3:0] enrolled_mask = 4'b1011;
    wire       busy, loaded_toggle, ram_en, hist_we, photo_we;
    wire [3:0] loaded_mask;
    wire [12:0] ram_raddr, ram_waddr;
    wire [7:0]  ram_wdata;
    wire [22:0] FL_ADDR;
    wire [7:0]  FL_DQ;
    wire FL_CE_N, FL_OE_N, FL_WE_N, FL_RST_N, FL_WP_N;

    // on-chip RAMs of the design (2-cycle read latency like dp_ram in top.v)
    reg [7:0] hist  [0:8191];
    reg [7:0] photo [0:4095];
    reg [12:0] ra1, ra2;
    always @(posedge clk) begin ra1 <= ram_raddr; ra2 <= ra1; end
    wire [7:0] hist_rdata  = hist[ra2];
    wire [7:0] photo_rdata = photo[ra2[11:0]];
    always @(posedge clk) begin
        if (hist_we)  hist[ram_waddr]        <= ram_wdata;
        if (photo_we) photo[ram_waddr[11:0]] <= ram_wdata;
    end

    flash_store dut (
        .clk(clk), .save_toggle(save_toggle), .erase_toggle(erase_toggle),
        .enrolled_mask(enrolled_mask), .busy(busy), .loaded_toggle(loaded_toggle),
        .loaded_mask(loaded_mask), .ram_en(ram_en), .ram_raddr(ram_raddr),
        .hist_rdata(hist_rdata), .photo_rdata(photo_rdata), .hist_we(hist_we),
        .photo_we(photo_we), .ram_waddr(ram_waddr), .ram_wdata(ram_wdata),
        .FL_ADDR(FL_ADDR), .FL_DQ(FL_DQ), .FL_CE_N(FL_CE_N), .FL_OE_N(FL_OE_N),
        .FL_WE_N(FL_WE_N), .FL_RST_N(FL_RST_N), .FL_WP_N(FL_WP_N)
    );

    s29gl_model flash (.A(FL_ADDR), .DQ(FL_DQ), .CE_N(FL_CE_N), .OE_N(FL_OE_N), .WE_N(FL_WE_N));

    function [7:0] hpat; input integer i; hpat = (i * 7 + 3) & 8'hFF; endfunction
    function [7:0] ppat; input integer i; ppat = (i * 13 + 100) & 8'hFF; endfunction

    // waveform log: bus pins during the first programmed byte
    integer f, wcnt = 0;
    reg wlog = 0;
    initial f = $fopen(MODE == 0 ? "flash_wave.csv" : "flash_wave_run2.csv", "w");
    always @(posedge clk) begin
        if (!wlog && dut.st == 5'd9 && MODE == 0) wlog = 1;       // S_PG_CMD
        if (wlog && wcnt < 90) begin
            $fdisplay(f, "%0d,%0d,%0d,%0d,%h,%h", wcnt * 10, FL_CE_N, FL_WE_N, FL_OE_N, FL_ADDR, FL_DQ);
            wcnt = wcnt + 1;
        end
    end

    integer i, errs;
    realtime t0;
    reg t;
    initial begin
        for (i = 0; i < 8192; i = i + 1) hist[i]  = (MODE == 0) ? hpat(i) : 8'h00;
        for (i = 0; i < 4096; i = i + 1) photo[i] = (MODE == 0) ? ppat(i) : 8'h00;
        if (MODE == 0) for (i = 0; i < 65536; i = i + 1) flash.mem[i] = 8'hFF;
        else           $readmemh("flash_after_save.hex", flash.mem);

        if (MODE == 0) $display("=== flash_store, run 1: empty chip -> save -> erase ===");
        else           $display("=== flash_store, run 2: power-on load of the saved data ===");

        // ---- power-on load ----
        #1 t = loaded_toggle;            // after the design's initial values are set
        wait (loaded_toggle != t);
        $display("power-on load finished at %0.3f ms, loaded_mask = %b", $realtime / 1e6, loaded_mask);

        if (MODE == 1) begin
            errs = 0;
            repeat (5) @(posedge clk);
            for (i = 0; i < 8192; i = i + 1) if (hist[i]  !== hpat(i)) errs = errs + 1;
            for (i = 0; i < 4096; i = i + 1) if (photo[i] !== ppat(i)) errs = errs + 1;
            $display("histogram + photo bytes restored : %0d, wrong : %0d", 12288, errs);
            if (loaded_mask == 4'b1011 && errs == 0) $display("RESULT: PASS");
            else                                     $display("RESULT: FAIL");
            $finish;
        end

        if (loaded_mask != 4'b0000) $display("ERROR: an erased chip must load as nobody enrolled");

        // ---- save (as after an enrollment) ----
        wait (!busy);
        t0 = $realtime;
        @(posedge clk) save_toggle = ~save_toggle;
        wait (busy); wait (!busy);
        $display("save finished in %0.2f ms: %0d sector erase, %0d bytes programmed, command errors %0d",
                 ($realtime - t0) / 1e6, flash.erases, flash.programs, flash.cmd_errors);
        errs = 0;
        for (i = 0; i < 8192; i = i + 1) if (flash.mem[16'h1000 + i] !== hpat(i)) errs = errs + 1;
        for (i = 0; i < 4096; i = i + 1) if (flash.mem[16'h3000 + i] !== ppat(i)) errs = errs + 1;
        $display("header in flash : %s %h (\"VJF2\" + mask)", {flash.mem[0], flash.mem[1], flash.mem[2], flash.mem[3]}, flash.mem[4]);
        $display("data bytes in flash wrong : %0d of 12288", errs);
        $writememh("flash_after_save.hex", flash.mem);

        // ---- KEY3 erase ----
        t = loaded_toggle;
        @(posedge clk) erase_toggle = ~erase_toggle;
        wait (loaded_toggle != t); wait (!busy);
        $display("erase (KEY3): loaded_mask = %b, header byte 0 = %h", loaded_mask, flash.mem[0]);

        if (errs == 0 && flash.cmd_errors == 0 && flash.mem[0] == 8'hFF && loaded_mask == 4'b0000)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");
        $fclose(f);
        $finish;
    end
endmodule
