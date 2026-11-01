// Draws up to 4 face boxes as 2-pixel outlines over the 320x240 video, each
// with a text label (name from person_names.v and, when score_valid, a "NN%"
// match score) on a black strip just above the box (below it when the box
// touches the top edge).
//
// Box/label registers come from the clk_sys domain; they are copied into the
// VGA domain only during vertical sync after face_update toggles, so nothing
// changes in the middle of a frame.

module box_overlay (
    input  wire        clk_vga,
    input  wire        vga_vsync,      // active low
    input  wire [9:0]  hcount,
    input  wire [9:0]  vcount,

    input  wire [3:0]  face_valid,
    input  wire [39:0] face_x,
    input  wire [35:0] face_y,
    input  wire [35:0] face_size,
    input  wire [11:0] face_person,    // 4 x 3 bit: 0..3 enrolled slot, 4..7 unknown
    input  wire [27:0] face_score,     // 4 x 7 bit match score 0..99
    input  wire        score_valid,    // show the "NN%" part of the labels
    input  wire        face_update,

    output reg         pixel,          // box outline
    output reg         text_fg,        // label character pixel
    output reg         text_bg         // label background strip
);

    localparam [9:0] LABEL_H = 10'd8;

    // ---------------- clock-domain crossing ----------------
    reg [2:0]  update_sync = 3'b000;
    reg [3:0]  valid_v     = 4'b0000;
    reg [39:0] x_v;
    reg [35:0] y_v;
    reg [35:0] s_v;
    reg [11:0] p_v;
    reg [27:0] sc_v;
    reg        scv_v       = 1'b0;
    reg        pending     = 1'b0;

    always @(posedge clk_vga) begin
        update_sync <= {update_sync[1:0], face_update};
        if (update_sync[2] != update_sync[1])
            pending <= 1'b1;

        if (pending && !vga_vsync) begin
            valid_v <= face_valid;
            x_v     <= face_x;
            y_v     <= face_y;
            s_v     <= face_size;
            p_v     <= face_person;
            sc_v    <= face_score;
            scv_v   <= score_valid;
            pending <= 1'b0;
        end
    end

    // outline test for one box: on the 2-pixel border of [x0, x0+s] x [y0, y0+s]
    function on_box;
        input [9:0] h, v;
        input [9:0] x0;
        input [8:0] y0, s;
        reg   [10:0] x1, y1;
        reg          in_x, in_y, edge_x, edge_y;
        begin
            x1     = x0 + s;
            y1     = y0 + s;
            in_x   = (h >= x0) && (h <= x1);
            in_y   = (v >= y0) && (v <= y1);
            edge_x = (h <= x0 + 10'd1) || (h + 10'd1 >= x1);
            edge_y = (v <= y0 + 10'd1) || (v + 10'd1 >= y1);
            on_box = in_x && in_y && (edge_x || edge_y);
        end
    endfunction

    // ---------------- per-box label logic ----------------
    wire [3:0] box_hit, lbl_fg, lbl_bg;

    genvar b;
    generate
        for (b = 0; b < 4; b = b + 1) begin : g_box
            wire [9:0] bx = x_v[b*10 +: 10];
            wire [8:0] by = y_v[b*9 +: 9];
            wire [8:0] bs = s_v[b*9 +: 9];
            wire [2:0] bp = p_v[b*3 +: 3];
            wire [6:0] sc = sc_v[b*7 +: 7];

            // label strip: above the box, or below it if there is no room
            wire [9:0] ly = (by >= 9'd10) ? ({1'b0, by} - 10'd10) : ({1'b0, by} + {1'b0, bs} + 10'd3);
            wire [9:0] lw = scv_v ? 10'd128 : 10'd96;   // 16 or 12 characters
            wire       in_lbl = valid_v[b] &&
                                (hcount >= bx) && (hcount < bx + lw) &&
                                (vcount >= ly) && (vcount < ly + LABEL_H);
            wire [9:0] dx  = hcount - bx;
            wire [9:0] dy  = vcount - ly;
            wire [3:0] col = dx[6:3];

            wire [7:0] name_ch;
            person_names u_names (
                .person (bp),
                .index  (col),
                .ascii  (name_ch)
            );

            wire [6:0] score  = (sc > 7'd99) ? 7'd99 : sc;
            wire [3:0] tens   = score / 7'd10;
            wire [3:0] ones   = score - tens * 7'd10;

            reg [7:0] ch;
            always @(*) begin
                case (col)
                    4'd12:   ch = 8'h20;
                    4'd13:   ch = 8'h30 + tens;
                    4'd14:   ch = 8'h30 + ones;
                    4'd15:   ch = 8'h25;          // '%'
                    default: ch = name_ch;
                endcase
            end

            wire [7:0] glyph;
            font8x8 u_font (
                .ascii (ch),
                .row   (dy[2:0]),
                .bits  (glyph)
            );

            assign lbl_bg[b]  = in_lbl;
            assign lbl_fg[b]  = in_lbl && glyph[3'd7 - dx[2:0]];
            assign box_hit[b] = valid_v[b] && on_box(hcount, vcount, bx, by, bs);
        end
    endgenerate

    always @(posedge clk_vga) begin
        pixel   <= |box_hit;
        text_fg <= |lbl_fg;
        text_bg <= |lbl_bg;
    end

endmodule
