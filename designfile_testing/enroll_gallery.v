// Enrollment gallery in the right half of the 640x480 screen: the 4 person
// slots, each with its 32x32 enrolled photo shown at 2x (64x64), the name from
// person_names.v and "ENROLLED" / "EMPTY". The slot selected for enrollment
// has a yellow border while KEY1 enrollment is pending, white otherwise.
//
// All outputs are valid one clk_vga cycle after hcount/vcount (the template
// RAM read has the same 1-cycle latency).

module enroll_gallery (
    input  wire        clk_vga,
    input  wire [9:0]  hcount,
    input  wire [9:0]  vcount,

    input  wire [3:0]  enrolled,       // async, synchronised here
    input  wire [1:0]  sel_slot,       // async (switches), synchronised here
    input  wire        pending,        // async, synchronised here

    output wire [11:0] tmpl_address,   // template RAM read: slot*1024 + y*32 + x
    input  wire [7:0]  tmpl_data,

    output reg  [11:0] rgb             // 0 = black outside gallery items
);

    localparam [9:0] TX  = 10'd352;    // thumbnail left edge
    localparam [9:0] TY0 = 10'd16;     // first thumbnail top edge
    localparam [9:0] PITCH = 10'd116;  // vertical distance between slots
    localparam [9:0] TS  = 10'd64;     // thumbnail size on screen
    localparam [9:0] LX  = 10'd432;    // text left edge

    reg [3:0] enrolled_s [0:1];
    reg [1:0] sel_s      [0:1];
    reg [1:0] pend_s;
    always @(posedge clk_vga) begin
        enrolled_s[0] <= enrolled;  enrolled_s[1] <= enrolled_s[0];
        sel_s[0]      <= sel_slot;  sel_s[1]      <= sel_s[0];
        pend_s        <= {pend_s[0], pending};
    end

    // which slot band this scanline is in
    reg [1:0] k;
    reg       in_band;
    reg [9:0] ty;
    always @(*) begin
        in_band = 1'b1;
        if      (vcount >= TY0 && vcount < TY0 + PITCH)            begin k = 2'd0; ty = TY0; end
        else if (vcount >= TY0 + PITCH && vcount < TY0 + 2*PITCH)  begin k = 2'd1; ty = TY0 + PITCH; end
        else if (vcount >= TY0 + 2*PITCH && vcount < TY0 + 3*PITCH) begin k = 2'd2; ty = TY0 + 2*PITCH; end
        else if (vcount >= TY0 + 3*PITCH && vcount < TY0 + 4*PITCH) begin k = 2'd3; ty = TY0 + 3*PITCH; end
        else begin k = 2'd0; ty = TY0; in_band = 1'b0; end
    end

    wire [9:0] dx = hcount - TX;
    wire [9:0] dy = vcount - ty;

    wire in_thumb  = in_band && (hcount >= TX) && (hcount < TX + TS) && (vcount >= ty) && (vcount < ty + TS);
    wire in_border = in_band && (hcount >= TX - 10'd3) && (hcount < TX + TS + 10'd3) &&
                     (vcount + 10'd3 >= ty) && (vcount < ty + TS + 10'd3) && !in_thumb;

    assign tmpl_address = {k, dy[5:1], dx[5:1]};

    // text: row 0 = name at ty+20, row 1 = status at ty+36
    wire       in_name = in_band && (hcount >= LX) && (hcount < LX + 10'd96) && (vcount >= ty + 10'd20) && (vcount < ty + 10'd28);
    wire       in_stat = in_band && (hcount >= LX) && (hcount < LX + 10'd96) && (vcount >= ty + 10'd36) && (vcount < ty + 10'd44);
    wire [9:0] tx_off  = hcount - LX;
    wire [3:0] col     = tx_off[6:3];
    wire [2:0] row     = in_name ? (vcount - (ty + 10'd20)) : (vcount - (ty + 10'd36));

    wire [7:0] name_ch;
    person_names u_names (
        .person ({1'b0, k}),
        .index  (col),
        .ascii  (name_ch)
    );

    reg [7:0] stat_ch;
    always @(*) begin
        if (enrolled_s[1][k]) begin
            case (col)
                4'd0: stat_ch = "E"; 4'd1: stat_ch = "N"; 4'd2: stat_ch = "R"; 4'd3: stat_ch = "O";
                4'd4: stat_ch = "L"; 4'd5: stat_ch = "L"; 4'd6: stat_ch = "E"; 4'd7: stat_ch = "D";
                default: stat_ch = " ";
            endcase
        end else begin
            case (col)
                4'd0: stat_ch = "E"; 4'd1: stat_ch = "M"; 4'd2: stat_ch = "P"; 4'd3: stat_ch = "T";
                4'd4: stat_ch = "Y";
                default: stat_ch = " ";
            endcase
        end
    end

    wire [7:0] glyph;
    font8x8 u_font (
        .ascii (in_name ? name_ch : stat_ch),
        .row   (row),
        .bits  (glyph)
    );
    wire text_on = (in_name || in_stat) && glyph[3'd7 - tx_off[2:0]];

    // register everything to line up with the template RAM data
    reg        thumb_r, border_r, text_r, enr_r, sel_r;
    always @(posedge clk_vga) begin
        thumb_r  <= in_thumb;
        border_r <= in_border;
        text_r   <= text_on;
        enr_r    <= enrolled_s[1][k];
        sel_r    <= (k == sel_s[1]);
    end

    always @(*) begin
        if (text_r)
            rgb = 12'hFFF;
        else if (thumb_r)
            rgb = enr_r ? {tmpl_data[7:4], tmpl_data[7:4], tmpl_data[7:4]} : 12'h222;
        else if (border_r && sel_r)
            rgb = pend_s[1] ? 12'hFF0 : 12'hAAA;
        else
            rgb = 12'h000;
    end

endmodule
