// Crops one face box out of the 320x240 greyscale detection frame and
// resamples it to 32x32 pixels. Each output pixel is the average of 4 samples
// spread half a sample step apart (2x2 area average), which removes most of
// the sensor noise and aliasing of plain nearest-neighbour sampling.
//
// Runs on the detection-buffer read clock (clk_iigen). The request comes from
// the clk_sys domain as a toggle; box/slot inputs must stay stable until the
// done toggle comes back. While active, rd_address drives the image_ram read
// port (ii_gen is idle between detection passes).

module face_crop (
    input  wire        clk,
    input  wire        start_toggle,   // toggles to start a crop
    output reg         done_toggle,    // toggles when the crop is written
    input  wire [9:0]  box_x,
    input  wire [8:0]  box_y,
    input  wire [8:0]  box_size,
    input  wire [1:0]  slot,

    output reg         active,
    output reg  [16:0] rd_address,     // to image_ram read port
    input  wire [7:0]  rd_data,        // image_ram q

    output reg         wr_en,          // to template RAM: slot*1024 + y*32 + x
    output reg  [11:0] wr_address,
    output reg  [7:0]  wr_data
);

    initial begin
        done_toggle = 1'b0;
        active      = 1'b0;
        wr_en       = 1'b0;
    end

    reg [2:0] start_sync = 3'b000;
    always @(posedge clk)
        start_sync <= {start_sync[1:0], start_toggle};
    wire start = start_sync[2] ^ start_sync[1];

    // latched request
    reg [9:0]  x0;
    reg [8:0]  y0, s;
    reg [1:0]  sl;

    // sample counter: output pixel (i, j), sub-sample k (bit0 = +x, bit1 = +y)
    reg        running = 1'b0;
    reg [4:0]  i, j;
    reg [1:0]  k;

    // pipeline: p1 offsets, p2 clamped coordinates, p3 address,
    // p4 RAM address register, p5 RAM data registered, p6 accumulated / written
    reg        v1 = 1'b0, v2 = 1'b0, v3 = 1'b0, v4 = 1'b0, v5 = 1'b0;
    reg [11:0] tag1, tag2, tag3, tag4, tag5;     // {k, j, i}
    reg [7:0]  d5;
    reg [14:0] offx1, offy1;
    reg [8:0]  xs2;
    reg [7:0]  ys2;
    reg [9:0]  acc;

    // half a sample step = s/64, i.e. +s/2 before the /32
    wire [14:0] half = {6'd0, s};
    wire [10:0] xsum = x0 + offx1[14:5];
    wire [9:0]  ysum = y0 + offy1[14:5];

    always @(posedge clk) begin
        // ---- counter ----
        if (start) begin
            x0      <= box_x;
            y0      <= box_y;
            s       <= box_size;
            sl      <= slot;
            i       <= 5'd0;
            j       <= 5'd0;
            k       <= 2'd0;
            running <= 1'b1;
            active  <= 1'b1;
        end else if (running) begin
            k <= k + 2'd1;
            if (k == 2'd3) begin
                i <= i + 5'd1;
                if (i == 5'd31) begin
                    j <= j + 5'd1;
                    if (j == 5'd31)
                        running <= 1'b0;
                end
            end
        end

        // ---- p1: scaled offsets inside the box ----
        v1    <= running;
        tag1  <= {k, j, i};
        offx1 <= i * s + (k[0] ? {1'b0, half[14:1]} : 15'd0);
        offy1 <= j * s + (k[1] ? {1'b0, half[14:1]} : 15'd0);

        // ---- p2: absolute position, clamped to the frame ----
        v2   <= v1;
        tag2 <= tag1;
        xs2  <= (xsum > 11'd319) ? 9'd319 : xsum[8:0];
        ys2  <= (ysum > 10'd239) ? 8'd239 : ysum[7:0];

        // ---- p3: frame address = y*320 + x ----
        v3         <= v2;
        tag3       <= tag2;
        rd_address <= {ys2, 8'd0} + {ys2, 6'd0} + xs2;

        // ---- p4: RAM registers rd_address ----
        v4   <= v3;
        tag4 <= tag3;

        // ---- p5: register the RAM data (its output mux is slow) ----
        v5   <= v4;
        tag5 <= tag4;
        d5   <= rd_data;

        // ---- p6: average the 4 sub-samples, write the pixel ----
        wr_en <= 1'b0;
        if (v5) begin
            if (tag5[11:10] == 2'd0)
                acc <= {2'b00, d5};
            else
                acc <= acc + d5;
            if (tag5[11:10] == 2'd3) begin
                wr_en      <= 1'b1;
                wr_address <= {sl, tag5[9:0]};
                wr_data    <= (acc + d5 + 10'd2) >> 2;
            end
        end

        // ---- finish once the last pixel has been written ----
        if (active && !start && !running && !v1 && !v2 && !v3 && !v4 && !v5 && wr_en) begin
            active      <= 1'b0;
            done_toggle <= ~done_toggle;
        end
    end

endmodule
