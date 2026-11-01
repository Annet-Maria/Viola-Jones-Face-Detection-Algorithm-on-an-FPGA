// Face recognizer (LBP histograms), runs once after every detection pass.
//
// For each job the face box (inner 3/4: eyes, nose, mouth) is cropped to
// 32x32 grey (face_crop), then two LBP histograms are built per 8x8 cell
// (4x4 cells), each with 10 rotation-invariant uniform bins (lbp_uniform.v):
//   radius 1 : 8 neighbours 1 px away, pixels 1..30
//   radius 2 : 8 neighbours 2 px away, pixels 2..29
// A neighbour counts as brighter only if it exceeds the centre by LBP_TOL.
// Histogram address = cell*20 + bin (r1: bins 0..9, r2: bins 10..19), 320 used.
//
//   enroll job    : sample k (0..3, one per detection pass) is stored as view k
//                   of person <enroll_slot>; the person turns the head a
//                   little between samples so the 4 views differ. The 32x32
//                   crop also goes to the gallery template RAM.
//   recognize job : L1 distance to all 4 views of every enrolled person; the
//                   nearest view counts. 27 crops are searched (x, y and size
//                   at -1/16, 0, +1/16 of the crop) and the best kept, so box
//                   wobble does not matter.
//                   score = 75 + (D_THRESH - distance)/8, clamped to 0..99;
//                   below THRESH (75) the face is UNKNOWN.
//
// D_THRESH and the score scale were calibrated with a bit-exact software
// model on a 40-person face database (4 enrolled + strangers: 95% correct
// name for enrolled people, 85% overall including rejecting strangers).
//
// One start toggle runs the optional enroll job and then a recognize job for
// every valid face; done toggles when all results are ready. All inputs must
// stay stable from start until done.

module face_recognizer (
    input  wire        clk,
    input  wire        start_toggle,
    output reg         done_toggle,

    input  wire [3:0]  face_valid,
    input  wire [39:0] face_x,
    input  wire [35:0] face_y,
    input  wire [35:0] face_size,

    input  wire        enroll_req,
    input  wire [1:0]  enroll_face,     // which face box to enroll
    input  wire [1:0]  enroll_slot,
    input  wire [3:0]  enrolled_mask,   // people already enrolled
    input  wire [1:0]  enroll_sample,   // 0..3 = view being stored

    // detection frame (image_ram) read port
    output wire        active,
    output wire [16:0] rd_address,
    input  wire [7:0]  rd_data,

    // gallery photo write (enroll jobs only)
    output wire        tmpl_wren,
    output wire [11:0] tmpl_wraddress,
    output wire [7:0]  tmpl_wrdata,

    output reg  [11:0] result_person,   // 4 x 3 bit, 4 = unknown
    output reg  [27:0] result_score,    // 4 x 7 bit, 0..99

    // external access to the enrolled histograms (flash load/save) while idle;
    // address = {slot, view, bin(9)}, read data 2 cycles after ext_raddr
    input  wire        ext_en,
    input  wire [12:0] ext_raddr,
    output wire [7:0]  ext_rdata,
    input  wire        ext_we,
    input  wire [12:0] ext_waddr,
    input  wire [7:0]  ext_wdata,

    output wire [3:0]  dbg_state        // current control state (diagnostic LEDs)
);

    localparam [6:0]  THRESH   = 7'd75;     // minimum score for a name
    localparam [11:0] D_THRESH = 12'd774;   // distance that maps to THRESH
    localparam [8:0]  LBP_TOL  = 9'd2;

    initial begin
        done_toggle   = 1'b0;
        result_person = {4{3'd4}};
        result_score  = 28'd0;
    end

    // ---------------- start detection ----------------
    reg [2:0] start_sync = 3'b000;
    always @(posedge clk)
        start_sync <= {start_sync[1:0], start_toggle};
    wire start = start_sync[2] ^ start_sync[1];

    // ---------------- crop engine ----------------
    reg        crop_req = 1'b0;
    wire       crop_ack;
    reg        crop_ack_d = 1'b0;
    reg  [1:0] cur_face;
    reg        enrolling;
    reg  [1:0] slot_r;

    wire        crop_wren;
    wire [11:0] crop_wraddress;
    wire [7:0]  crop_wrdata;

    // inner 3/4 of the detection box, shifted by the search offset (ox, oy)
    reg  [1:0] ox, oy, oz;        // 0 = -step, 1 = centre, 2 = +step (oz: size)
    wire [9:0] cur_x = face_x[cur_face*10 +: 10];
    wire [8:0] cur_y = face_y[cur_face*9 +: 9];
    wire [8:0] cur_s = face_size[cur_face*9 +: 9];
    // stage A (registered): inner box of the selected face
    reg  [9:0] in_x;
    reg  [8:0] in_y, in_s;
    always @(posedge clk) begin
        in_x <= cur_x + {4'd0, cur_s[8:3]};
        in_y <= cur_y + {3'd0, cur_s[8:3]};
        in_s <= cur_s - {2'd0, cur_s[8:2]};
    end
    wire [4:0] step  = in_s[8:4];            // search step: 1/16 of the crop
    // size search keeps the crop centred: smaller crop moves in by step/2
    wire [8:0] crop_s = (oz == 2'd0) ? in_s - {4'd0, step} : (oz == 2'd2) ? in_s + {4'd0, step} : in_s;
    wire [9:0] zx     = (oz == 2'd0) ? in_x + {6'd0, step[4:1]} :
                        (oz == 2'd2) ? ((in_x >= {6'd0, step[4:1]}) ? in_x - {6'd0, step[4:1]} : 10'd0) : in_x;
    wire [8:0] zy     = (oz == 2'd0) ? in_y + {5'd0, step[4:1]} :
                        (oz == 2'd2) ? ((in_y >= {5'd0, step[4:1]}) ? in_y - {5'd0, step[4:1]} : 9'd0) : in_y;
    wire [9:0] crop_x = (ox == 2'd0) ? ((zx >= {5'd0, step}) ? zx - {5'd0, step} : 10'd0) :
                        (ox == 2'd2) ? zx + {5'd0, step} : zx;
    wire [8:0] crop_y = (oy == 2'd0) ? ((zy >= {4'd0, step}) ? zy - {4'd0, step} : 9'd0) :
                        (oy == 2'd2) ? zy + {4'd0, step} : zy;

    // stage B (registered): search offset applied; face_crop samples these 3
    // cycles after the request, i.e. one cycle after they settle
    reg [9:0] crop_x_r;
    reg [8:0] crop_y_r, crop_s_r;
    always @(posedge clk) begin
        crop_x_r <= crop_x;
        crop_y_r <= crop_y;
        crop_s_r <= crop_s;
    end

    face_crop u_crop (
        .clk          (clk),
        .start_toggle (crop_req),
        .done_toggle  (crop_ack),
        .box_x        (crop_x_r),
        .box_y        (crop_y_r),
        .box_size     (crop_s_r),
        .slot         (slot_r),
        .active       (active),
        .rd_address   (rd_address),
        .rd_data      (rd_data),
        .wr_en        (crop_wren),
        .wr_address   (crop_wraddress),
        .wr_data      (crop_wrdata)
    );

    assign tmpl_wren      = crop_wren & enrolling;
    assign tmpl_wraddress = crop_wraddress;
    assign tmpl_wrdata    = crop_wrdata;

    // ---------------- RAMs (2-cycle read latency from the address register) ----------------
    reg  [9:0] cb_raddr;
    wire [7:0] cb_q;
    dp_ram #(.WIDTH(8), .WIDTHAD(10), .NUMWORDS(1024)) crop_buf (
        .wrclock (clk), .wren (crop_wren), .wraddress (crop_wraddress[9:0]), .data (crop_wrdata),
        .rdclock (clk), .rdaddress (cb_raddr), .q (cb_q)
    );

    reg        ph_we = 1'b0;
    reg  [8:0] ph_waddr, ph_raddr;
    reg  [7:0] ph_wdata;
    wire [7:0] ph_q;
    dp_ram #(.WIDTH(8), .WIDTHAD(9), .NUMWORDS(512)) probe_hist (
        .wrclock (clk), .wren (ph_we), .wraddress (ph_waddr), .data (ph_wdata),
        .rdclock (clk), .rdaddress (ph_raddr), .q (ph_q)
    );

    // enrolled histograms: per person 4 views x 512 entries
    reg  [3:0]  eh_we = 4'b0000;
    reg  [10:0] eh_waddr, eh_raddr;
    reg  [7:0]  eh_wdata;
    wire [7:0]  eh_q [0:3];
    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : g_ehist
            dp_ram #(.WIDTH(8), .WIDTHAD(11), .NUMWORDS(2048)) enrolled_hist (
                .wrclock   (clk),
                .wren      (ext_en ? (ext_we && ext_waddr[12:11] == g) : eh_we[g]),
                .wraddress (ext_en ? ext_waddr[10:0] : eh_waddr),
                .data      (ext_en ? ext_wdata : eh_wdata),
                .rdclock   (clk),
                .rdaddress (ext_en ? ext_raddr[10:0] : eh_raddr),
                .q         (eh_q[g])
            );
        end
    endgenerate

    assign ext_rdata = eh_q[ext_raddr[12:11]];

    // ---------------- LBP radius 1 and 2 ----------------
    reg  [7:0] nb [0:16];         // 0 = centre, 1..8 = radius 1, 9..16 = radius 2 (clockwise from top-left)
    reg  [4:0] px, py;            // current pixel, 1..30
    reg        second;            // 0: radius-1 update, 1: radius-2 update
    wire [8:0] cref = {1'b0, nb[0]} + LBP_TOL;
    wire [7:0] code1 = {{1'b0, nb[8]}  >= cref, {1'b0, nb[7]}  >= cref, {1'b0, nb[6]}  >= cref, {1'b0, nb[5]}  >= cref,
                        {1'b0, nb[4]}  >= cref, {1'b0, nb[3]}  >= cref, {1'b0, nb[2]}  >= cref, {1'b0, nb[1]}  >= cref};
    wire [7:0] code2 = {{1'b0, nb[16]} >= cref, {1'b0, nb[15]} >= cref, {1'b0, nb[14]} >= cref, {1'b0, nb[13]} >= cref,
                        {1'b0, nb[12]} >= cref, {1'b0, nb[11]} >= cref, {1'b0, nb[10]} >= cref, {1'b0, nb[9]}  >= cref};
    wire [5:0] bin1, bin2;
    lbp_uniform u_lbp1 (.code (code1), .bin (bin1));
    lbp_uniform u_lbp2 (.code (code2), .bin (bin2));
    wire [3:0] cell_id  = {py[4:3], px[4:3]};
    wire [8:0] cell_base = {1'b0, cell_id, 4'b0000} + {3'b000, cell_id, 2'b00};   // cell*20
    wire       r2_valid = (px >= 5'd2) && (px <= 5'd29) && (py >= 5'd2) && (py <= 5'd29);

    reg  [4:0] rc;                // pixel read counter 0..18
    reg  [4:0] nx, ny;
    always @(*) begin
        case (rc)
            5'd0:    begin nx = px;        ny = py;        end
            5'd1:    begin nx = px - 5'd1; ny = py - 5'd1; end
            5'd2:    begin nx = px;        ny = py - 5'd1; end
            5'd3:    begin nx = px + 5'd1; ny = py - 5'd1; end
            5'd4:    begin nx = px + 5'd1; ny = py;        end
            5'd5:    begin nx = px + 5'd1; ny = py + 5'd1; end
            5'd6:    begin nx = px;        ny = py + 5'd1; end
            5'd7:    begin nx = px - 5'd1; ny = py + 5'd1; end
            5'd8:    begin nx = px - 5'd1; ny = py;        end
            5'd9:    begin nx = px - 5'd2; ny = py - 5'd2; end
            5'd10:   begin nx = px;        ny = py - 5'd2; end
            5'd11:   begin nx = px + 5'd2; ny = py - 5'd2; end
            5'd12:   begin nx = px + 5'd2; ny = py;        end
            5'd13:   begin nx = px + 5'd2; ny = py + 5'd2; end
            5'd14:   begin nx = px;        ny = py + 5'd2; end
            5'd15:   begin nx = px - 5'd2; ny = py + 5'd2; end
            default: begin nx = px - 5'd2; ny = py;        end
        endcase
    end

    // ---------------- comparison ----------------
    reg [11:0] a;                 // counter for clear / copy / compare
    reg [11:0] acc [0:15];        // distance per person*4 + view
    reg [11:0] vmin [0:3];        // nearest view per person (this crop)
    reg [11:0] best_acc [0:3];    // nearest over all search crops
    reg [3:0]  mask;

    function [7:0] absd;
        input [7:0] p, q;
        absd = (p > q) ? (p - q) : (q - p);
    endfunction

    function [11:0] min2;
        input [11:0] p, q;
        min2 = (p < q) ? p : q;
    endfunction

    // score = 75 + (D_THRESH - d)/8, clamped to 0..99
    function [6:0] score_of;
        input [11:0] d;
        reg   [11:0] diff;
        begin
            if (d <= D_THRESH) begin
                diff = (D_THRESH - d) >> 3;
                score_of = (diff >= 12'd24) ? 7'd99 : THRESH + diff[6:0];
            end else begin
                diff = (d - D_THRESH) >> 3;
                score_of = (diff >= 12'd75) ? 7'd0 : THRESH - diff[6:0];
            end
        end
    endfunction

    reg  [6:0]  s0, s1, s2, s3;
    wire [1:0]  b01 = (s1 > s0) ? 2'd1 : 2'd0;
    wire [6:0]  m01 = (s1 > s0) ? s1 : s0;
    wire [1:0]  b23 = (s3 > s2) ? 2'd3 : 2'd2;
    wire [6:0]  m23 = (s3 > s2) ? s3 : s2;
    wire [1:0]  best     = (m23 > m01) ? b23 : b01;
    wire [6:0]  best_sim = (m23 > m01) ? m23 : m01;
    reg  [1:0]  best_r;
    reg  [6:0]  best_sim_r;

    // ---------------- control ----------------
    localparam M_IDLE   = 4'd0,
               M_NEXT   = 4'd1,
               M_CROP   = 4'd2,
               M_READ   = 4'd3,
               M_CODE   = 4'd4,
               M_H1     = 4'd5,
               M_H2     = 4'd6,
               M_COPY   = 4'd7,
               M_CMP    = 4'd8,
               M_VMIN   = 4'd9,
               M_OFF    = 4'd10,
               M_SC1    = 4'd11,
               M_SC2    = 4'd12,
               M_SCORE  = 4'd13,
               M_DONE   = 4'd14;

    reg [3:0] st = M_IDLE;
    assign dbg_state = st;
    reg       enroll_phase;
    reg [2:0] fi;                 // next face to recognize, 0..4
    reg       crop_busy;
    reg [3:0] valid_r;
    reg [1:0] enroll_face_r;
    reg [1:0] view_r;
    reg [1:0] cv;                 // view of the address issued in M_CMP
    reg [1:0] cv_d;               // view of the data arriving (2 cycles later)
    reg [1:0] cv_e, cv_f;         // view following the compare pipeline
    reg [7:0] pq_r;               // registered probe bin
    reg [7:0] eq_r [0:3];         // registered enrolled bins
    reg [7:0] ad_r [0:3];         // registered |probe - enrolled|
    always @(posedge clk)
        cv_d <= cv;

    integer n;
    always @(posedge clk) begin
        ph_we <= 1'b0;
        eh_we <= 4'b0000;
        crop_ack_d <= crop_ack;

        case (st)
            M_IDLE: begin
                if (start) begin
                    valid_r       <= face_valid;
                    enroll_phase  <= enroll_req;
                    enroll_face_r <= enroll_face;
                    slot_r        <= enroll_slot;
                    view_r        <= enroll_sample;
                    // the slot being enrolled only takes part once all 4 views are new
                    mask          <= enroll_req ? ((enrolled_mask & ~(4'b0001 << enroll_slot)) |
                                                   (enroll_sample == 2'd3 ? (4'b0001 << enroll_slot) : 4'b0000))
                                                : enrolled_mask;
                    fi            <= 3'd0;
                    st            <= M_NEXT;
                end
            end

            M_NEXT: begin
                ox <= 2'd1;
                oy <= 2'd1;
                oz <= 2'd1;
                for (n = 0; n < 4; n = n + 1) best_acc[n] <= 12'hFFF;
                if (enroll_phase) begin
                    cur_face  <= enroll_face_r;
                    enrolling <= 1'b1;
                    crop_req  <= ~crop_req;
                    crop_busy <= 1'b1;
                    a         <= 12'd0;
                    st        <= M_CROP;
                end else if (fi == 3'd4) begin
                    st <= M_DONE;
                end else if (!valid_r[fi[1:0]]) begin
                    result_person[fi[1:0]*3 +: 3] <= 3'd4;
                    result_score [fi[1:0]*7 +: 7] <= 7'd0;
                    fi <= fi + 3'd1;
                end else begin
                    ox        <= 2'd0;     // recognition starts the 3x3x3 search at (-1,-1,-1)
                    oy        <= 2'd0;
                    oz        <= 2'd0;
                    cur_face  <= fi[1:0];
                    enrolling <= 1'b0;
                    crop_req  <= ~crop_req;
                    crop_busy <= 1'b1;
                    a         <= 12'd0;
                    st        <= M_CROP;
                end
            end

            // crop the face while clearing the probe histogram
            M_CROP: begin
                if (a < 12'd512) begin
                    ph_we    <= 1'b1;
                    ph_waddr <= a[8:0];
                    ph_wdata <= 8'd0;
                    a        <= a + 12'd1;
                end
                if (crop_ack != crop_ack_d)
                    crop_busy <= 1'b0;
                if (!crop_busy && a == 12'd512) begin
                    px <= 5'd1;
                    py <= 5'd1;
                    rc <= 5'd0;
                    st <= M_READ;
                end
            end

            // read centre + 16 neighbours (data arrives 2 cycles after the address)
            M_READ: begin
                if (rc < 5'd17)
                    cb_raddr <= {ny, nx};
                if (rc >= 5'd2)
                    nb[rc - 5'd2] <= cb_q;
                if (rc == 5'd18) begin
                    second <= 1'b0;
                    st     <= M_CODE;
                end else
                    rc <= rc + 5'd1;
            end

            M_CODE: begin
                ph_raddr <= cell_base + {3'd0, bin1};
                st <= M_H1;
            end

            M_H1: st <= M_H2;

            // read-modify-write of one histogram bin; radius 2 follows radius 1
            M_H2: begin
                ph_we    <= 1'b1;
                ph_waddr <= ph_raddr;
                ph_wdata <= (ph_q == 8'hFF) ? 8'hFF : ph_q + 8'd1;
                if (!second && r2_valid) begin
                    second   <= 1'b1;
                    ph_raddr <= cell_base + 9'd10 + {3'd0, bin2};
                    st       <= M_H1;
                end else begin
                    rc <= 5'd0;
                    if (px == 5'd30) begin
                        px <= 5'd1;
                        if (py == 5'd30) begin
                            a  <= 12'd0;
                            for (n = 0; n < 16; n = n + 1) acc[n] <= 12'd0;
                            st <= enrolling ? M_COPY : M_CMP;
                        end else begin
                            py <= py + 5'd1;
                            st <= M_READ;
                        end
                    end else begin
                        px <= px + 5'd1;
                        st <= M_READ;
                    end
                end
            end

            // store the histogram as view <enroll_sample> of the enrolled person
            M_COPY: begin
                if (a < 12'd512)
                    ph_raddr <= a[8:0];
                if (a >= 12'd2) begin
                    eh_we[slot_r] <= 1'b1;
                    eh_waddr      <= {view_r, a[8:0] - 9'd2};
                    eh_wdata      <= ph_q;
                end
                if (a == 12'd513) begin
                    enroll_phase <= 1'b0;
                    st           <= M_NEXT;
                end else
                    a <= a + 12'd1;
            end

            // L1 distance to all 4 views of all 4 people, pipelined for
            // timing: RAM data (a>=2) -> registered, |p-e| (a>=3), accumulate (a>=4)
            M_CMP: begin
                if (a < 12'd2048) begin
                    ph_raddr <= a[8:0];
                    eh_raddr <= a[10:0];
                end
                cv   <= a[10:9];
                pq_r <= ph_q;
                cv_e <= cv_d;
                cv_f <= cv_e;
                for (n = 0; n < 4; n = n + 1) begin
                    eq_r[n] <= eh_q[n];
                    ad_r[n] <= absd(pq_r, eq_r[n]);
                end
                // explicit 4-bit index {person, view}: a computed n*4+cv_f was
                // narrowed to 2 bits by synthesis and merged all people
                if (a >= 12'd4) begin
                    acc[{2'd0, cv_f}] <= acc[{2'd0, cv_f}] + ad_r[0];
                    acc[{2'd1, cv_f}] <= acc[{2'd1, cv_f}] + ad_r[1];
                    acc[{2'd2, cv_f}] <= acc[{2'd2, cv_f}] + ad_r[2];
                    acc[{2'd3, cv_f}] <= acc[{2'd3, cv_f}] + ad_r[3];
                end
                if (a == 12'd2051)
                    st <= M_VMIN;
                else
                    a <= a + 12'd1;
            end

            // nearest view per person
            M_VMIN: begin
                for (n = 0; n < 4; n = n + 1)
                    vmin[n] <= min2(min2(acc[n*4], acc[n*4+1]), min2(acc[n*4+2], acc[n*4+3]));
                st <= M_OFF;
            end

            // keep the best distance, then try the next search position
            M_OFF: begin
                for (n = 0; n < 4; n = n + 1)
                    if (vmin[n] < best_acc[n]) best_acc[n] <= vmin[n];
                if (ox == 2'd2 && oy == 2'd2 && oz == 2'd2)
                    st <= M_SC1;
                else begin
                    if (ox == 2'd2) begin
                        ox <= 2'd0;
                        if (oy == 2'd2) begin
                            oy <= 2'd0;
                            oz <= oz + 2'd1;
                        end else
                            oy <= oy + 2'd1;
                    end else
                        ox <= ox + 2'd1;
                    crop_req  <= ~crop_req;
                    crop_busy <= 1'b1;
                    a         <= 12'd0;
                    st        <= M_CROP;
                end
            end

            M_SC1: begin
                s0 <= mask[0] ? score_of(best_acc[0]) : 7'd0;
                s1 <= mask[1] ? score_of(best_acc[1]) : 7'd0;
                s2 <= mask[2] ? score_of(best_acc[2]) : 7'd0;
                s3 <= mask[3] ? score_of(best_acc[3]) : 7'd0;
                st <= M_SC2;
            end

            M_SC2: begin
                best_r     <= best;
                best_sim_r <= best_sim;
                st         <= M_SCORE;
            end

            M_SCORE: begin
                if (mask == 4'b0000 || best_sim_r < THRESH)
                    result_person[cur_face*3 +: 3] <= 3'd4;
                else
                    result_person[cur_face*3 +: 3] <= {1'b0, best_r};
                result_score[cur_face*7 +: 7] <= best_sim_r;
                fi <= fi + 3'd1;
                st <= M_NEXT;
            end

            M_DONE: begin
                done_toggle <= ~done_toggle;
                st          <= M_IDLE;
            end

            default: st <= M_IDLE;
        endcase
    end

endmodule
