// Groups raw Viola-Jones detections into faces (like OpenCV's groupRectangles).
//
// During a detection pass every accepted subwindow arrives as (x, y, size).
// A box joins the first cluster whose leader (first box of the cluster) is
// within 1/4 of the leader's size in x, y and size; otherwise it starts a new
// cluster. When all slots are taken, a new box replaces a single-hit cluster
// (almost always a stray false positive) so small-scale noise found early in
// the scan cannot lock out the larger faces found later. On finalize, clusters with more than min_neighbors members are
// averaged and the 4 largest clusters are published as the face boxes.
//
// Boxes go through a 3-stage pipeline (register input, search, update) for
// timing; faceBox delivers at most one box every 3 cycles, so a search always
// sees the previous box's update.

module face_cluster #(
    parameter N = 32                   // cluster slots
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        clear,          // pulse: start of a detection pass
    input  wire        box_valid,
    input  wire [9:0]  box_x,
    input  wire [8:0]  box_y,
    input  wire [8:0]  box_size,
    input  wire        finalize,       // pulse: all boxes of this pass delivered
    input  wire [2:0]  min_neighbors,  // keep clusters with count > min_neighbors

    output reg  [3:0]  face_valid,
    output reg  [39:0] face_x,         // 4 x 10 bit, face 0 in [9:0]
    output reg  [35:0] face_y,         // 4 x 9 bit
    output reg  [35:0] face_size,      // 4 x 9 bit
    output reg         face_update     // toggles each time the outputs change
);

    // ---------------- cluster storage ----------------
    reg         used [0:N-1];
    reg [9:0]   lx   [0:N-1];
    reg [8:0]   ly   [0:N-1];
    reg [8:0]   ls   [0:N-1];
    reg [17:0]  sx   [0:N-1];
    reg [16:0]  sy   [0:N-1];
    reg [16:0]  ss   [0:N-1];
    reg [7:0]   cnt  [0:N-1];

    // ---------------- stage 1: register the incoming box ----------------
    reg       p1_valid = 1'b0;
    reg [9:0] p1_x;
    reg [8:0] p1_y, p1_s;

    always @(posedge clk) begin
        p1_valid <= box_valid & ~clear;
        p1_x     <= box_x;
        p1_y     <= box_y;
        p1_s     <= box_size;
    end

    // ---------------- stage 2: match search ----------------
    function [9:0] absdiff10;
        input [9:0] a, b;
        absdiff10 = (a > b) ? (a - b) : (b - a);
    endfunction

    reg       match_found, free_found, single_found;
    reg [4:0] match_idx, free_idx, single_idx;
    reg [9:0] tol;
    integer   k;

    always @(*) begin
        match_found = 1'b0;
        match_idx   = 5'd0;
        free_found  = 1'b0;
        free_idx    = 5'd0;
        single_found = 1'b0;
        single_idx   = 5'd0;
        for (k = N-1; k >= 0; k = k - 1) begin
            tol = {3'b000, ls[k][8:2]};
            if (used[k] &&
                absdiff10(p1_x, lx[k]) <= tol &&
                absdiff10({1'b0, p1_y}, {1'b0, ly[k]}) <= tol &&
                absdiff10({1'b0, p1_s}, {1'b0, ls[k]}) <= tol) begin
                match_found = 1'b1;
                match_idx   = k[4:0];
            end
            if (!used[k]) begin
                free_found = 1'b1;
                free_idx   = k[4:0];
            end
            if (used[k] && cnt[k] == 8'd1) begin
                single_found = 1'b1;
                single_idx   = k[4:0];
            end
        end
    end

    reg       p2_valid = 1'b0;
    reg       p2_match, p2_free;
    reg [4:0] p2_match_idx, p2_free_idx;
    reg [9:0] p2_x;
    reg [8:0] p2_y, p2_s;

    always @(posedge clk) begin
        p2_valid     <= p1_valid & ~clear;
        p2_match     <= match_found;
        p2_free      <= free_found | single_found;
        p2_match_idx <= match_idx;
        p2_free_idx  <= free_found ? free_idx : single_idx;
        p2_x         <= p1_x;
        p2_y         <= p1_y;
        p2_s         <= p1_s;
    end

    // finalize waits until the last box has left the pipeline
    reg [2:0] finalize_d = 3'b000;
    always @(posedge clk)
        finalize_d <= {finalize_d[1:0], finalize & ~clear};

    // ---------------- finalize: average, filter, keep 4 largest ----------------
    localparam F_IDLE  = 3'd0,
               F_CHECK = 3'd1,
               F_DIV   = 3'd2,
               F_STORE = 3'd3,
               F_PUB   = 3'd4;

    reg [2:0]  fstate;
    reg [5:0]  fk;            // cluster being finalized
    reg [1:0]  div_sel;       // 0 = x, 1 = y, 2 = size
    reg [4:0]  div_iter;
    reg [17:0] div_q;
    reg [8:0]  div_rem;
    reg [9:0]  avg_x;
    reg [8:0]  avg_y, avg_s;

    reg [3:0]  stg_valid;
    reg [7:0]  stg_cnt  [0:3];
    reg [9:0]  stg_x    [0:3];
    reg [8:0]  stg_y    [0:3];
    reg [8:0]  stg_s    [0:3];

    // restoring division step: {div_rem, div_q} / cnt
    wire [7:0]  divisor  = cnt[fk[4:0]];
    wire [8:0]  rem_sh   = {div_rem[7:0], div_q[17]};
    wire        rem_ge   = (rem_sh >= {1'b0, divisor});
    wire [8:0]  rem_next = rem_ge ? (rem_sh - {1'b0, divisor}) : rem_sh;
    wire [17:0] q_next   = {div_q[16:0], rem_ge};

    // staging slot to (re)use: first empty, else the one with the smallest count
    reg [1:0] slot;
    reg       slot_empty;
    integer   j;
    always @(*) begin
        slot       = 2'd0;
        slot_empty = 1'b0;
        for (j = 3; j >= 0; j = j - 1) begin
            if (!stg_valid[j]) begin
                slot       = j[1:0];
                slot_empty = 1'b1;
            end
        end
        if (!slot_empty) begin
            for (j = 1; j < 4; j = j + 1)
                if (stg_cnt[j] < stg_cnt[slot])
                    slot = j[1:0];
        end
    end

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < N; i = i + 1) used[i] <= 1'b0;
            fstate      <= F_IDLE;
            face_valid  <= 4'b0000;
            face_update <= 1'b0;
            stg_valid   <= 4'b0000;
        end else if (clear) begin
            for (i = 0; i < N; i = i + 1) used[i] <= 1'b0;
            fstate <= F_IDLE;
        end else begin
            // -------- stage 3: accumulate detections --------
            if (p2_valid) begin
                if (p2_match) begin
                    if (cnt[p2_match_idx] != 8'hFF) begin
                        sx[p2_match_idx]  <= sx[p2_match_idx] + p2_x;
                        sy[p2_match_idx]  <= sy[p2_match_idx] + p2_y;
                        ss[p2_match_idx]  <= ss[p2_match_idx] + p2_s;
                        cnt[p2_match_idx] <= cnt[p2_match_idx] + 8'd1;
                    end
                end else if (p2_free) begin
                    used[p2_free_idx] <= 1'b1;
                    lx[p2_free_idx]   <= p2_x;
                    ly[p2_free_idx]   <= p2_y;
                    ls[p2_free_idx]   <= p2_s;
                    sx[p2_free_idx]   <= {8'd0, p2_x};
                    sy[p2_free_idx]   <= {8'd0, p2_y};
                    ss[p2_free_idx]   <= {8'd0, p2_s};
                    cnt[p2_free_idx]  <= 8'd1;
                end
            end

            // -------- finalize --------
            case (fstate)
                F_IDLE: begin
                    if (finalize_d[2]) begin
                        fk        <= 5'd0;
                        stg_valid <= 4'b0000;
                        fstate    <= F_CHECK;
                    end
                end

                F_CHECK: begin
                    if (fk == N) begin
                        fstate <= F_PUB;
                    end else if (used[fk[4:0]] && (cnt[fk[4:0]] > {5'd0, min_neighbors})) begin
                        div_sel  <= 2'd0;
                        div_q    <= sx[fk[4:0]];
                        div_rem  <= 9'd0;
                        div_iter <= 5'd0;
                        fstate   <= F_DIV;
                    end else begin
                        fk <= fk + 6'd1;
                    end
                end

                F_DIV: begin
                    div_rem <= rem_next;
                    div_q   <= q_next;
                    if (div_iter == 5'd17) begin
                        div_iter <= 5'd0;
                        div_rem  <= 9'd0;
                        case (div_sel)
                            2'd0: begin avg_x <= q_next[9:0]; div_q <= {1'b0, sy[fk[4:0]]}; div_sel <= 2'd1; end
                            2'd1: begin avg_y <= q_next[8:0]; div_q <= {1'b0, ss[fk[4:0]]}; div_sel <= 2'd2; end
                            default: begin avg_s <= q_next[8:0]; fstate <= F_STORE; end
                        endcase
                    end else begin
                        div_iter <= div_iter + 5'd1;
                    end
                end

                F_STORE: begin
                    if (slot_empty || (cnt[fk[4:0]] > stg_cnt[slot])) begin
                        stg_valid[slot] <= 1'b1;
                        stg_cnt[slot]   <= cnt[fk[4:0]];
                        stg_x[slot]     <= avg_x;
                        stg_y[slot]     <= avg_y;
                        stg_s[slot]     <= avg_s;
                    end
                    fk     <= fk + 6'd1;
                    fstate <= F_CHECK;
                end

                F_PUB: begin
                    face_valid  <= stg_valid;
                    face_x      <= {stg_x[3], stg_x[2], stg_x[1], stg_x[0]};
                    face_y      <= {stg_y[3], stg_y[2], stg_y[1], stg_y[0]};
                    face_size   <= {stg_s[3], stg_s[2], stg_s[1], stg_s[0]};
                    face_update <= ~face_update;
                    fstate      <= F_IDLE;
                end

                default: fstate <= F_IDLE;
            endcase
        end
    end

endmodule
