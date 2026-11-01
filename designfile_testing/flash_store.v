// Keeps the enrolled people in the DE2-115 parallel NOR flash (8 MB, used in
// 8-bit mode) so they survive power-off.
//
// Flash layout, one 64 KB sector at BASE (byte addresses):
//   BASE + 0x0000 : "VJF2" magic, then the enrolled mask (written last)
//   BASE + 0x1000 : LBP histograms, 4 slots x 4 views x 512 bytes (8 KB)
//   BASE + 0x3000 : 32x32 gallery photos, 4 slots x 1024 bytes
//
//   load  : once after power-up; copies histograms + photos into the RAMs and
//           reports the enrolled mask (0 if the sector holds no valid data)
//   save  : erase the sector, program histograms, photos, then the header
//   erase : erase the sector only (forget everyone)
//
// Runs on clk (100 MHz); bus timings are counted in clk cycles and are well
// inside the S29GL064N limits (70-90 ns access, 35 ns write pulse).

module flash_store #(
    parameter [22:0] BASE = 23'h400000
) (
    input  wire        clk,
    input  wire        save_toggle,    // request: store enrolled_mask + RAM contents
    input  wire        erase_toggle,   // request: forget everyone
    input  wire [3:0]  enrolled_mask,  // sampled when a save starts

    output reg         busy,           // load / save / erase in progress
    output reg         loaded_toggle,  // toggles when a load (or erase) finished
    output reg  [3:0]  loaded_mask,    // valid after loaded_toggle

    // RAM access: hist = recognizer enrolled histograms, photo = gallery photos
    // hist address = {slot, view, bin}, photo address = slot*1024 + pixel;
    // reads have 2 cycles latency
    output reg         ram_en,         // flash_store owns the RAM ports
    output reg  [12:0] ram_raddr,
    input  wire [7:0]  hist_rdata,
    input  wire [7:0]  photo_rdata,
    output reg         hist_we,
    output reg         photo_we,
    output reg  [12:0] ram_waddr,
    output reg  [7:0]  ram_wdata,

    // flash pins
    output reg  [22:0] FL_ADDR,
    inout  wire [7:0]  FL_DQ,
    output reg         FL_CE_N,
    output reg         FL_OE_N,
    output reg         FL_WE_N,
    output wire        FL_RST_N,
    output wire        FL_WP_N
);

    assign FL_RST_N = 1'b1;
    assign FL_WP_N  = 1'b1;

    reg       dq_oe = 1'b0;
    reg [7:0] dq_out;
    assign FL_DQ = dq_oe ? dq_out : 8'bzzzzzzzz;

    initial begin
        busy          = 1'b1;
        loaded_toggle = 1'b0;
        loaded_mask   = 4'b0000;
        ram_en        = 1'b0;
        hist_we       = 1'b0;
        photo_we      = 1'b0;
        FL_CE_N       = 1'b1;
        FL_OE_N       = 1'b1;
        FL_WE_N       = 1'b1;
        FL_ADDR       = 23'd0;
    end

    // ---------------- request detection ----------------
    reg [2:0] save_sync  = 3'b000;
    reg [2:0] erase_sync = 3'b000;
    always @(posedge clk) begin
        save_sync  <= {save_sync[1:0],  save_toggle};
        erase_sync <= {erase_sync[1:0], erase_toggle};
    end
    reg save_req = 1'b0, erase_req = 1'b0;   // set by edges, cleared when served

    // ---------------- single bus cycle ----------------
    // bus_go with bus_write/bus_addr/bus_data; bus_done pulses when finished,
    // bus_rdata holds the byte read.
    reg        bus_go = 1'b0, bus_write;
    reg [22:0] bus_addr;
    reg [7:0]  bus_data, bus_rdata;
    reg        bus_done = 1'b0;
    reg [4:0]  bt = 5'd0;
    reg        bus_active = 1'b0;

    always @(posedge clk) begin
        bus_done <= 1'b0;
        if (!bus_active) begin
            if (bus_go) begin
                bus_active <= 1'b1;
                bt         <= 5'd0;
                FL_ADDR    <= bus_addr;
                dq_out     <= bus_data;
                dq_oe      <= bus_write;
                FL_CE_N    <= 1'b0;
                FL_OE_N    <= bus_write;     // reads: output enable now
            end
        end else begin
            bt <= bt + 5'd1;
            if (bus_write) begin
                // 20 ns setup, 60 ns WE# low, 20 ns hold
                if (bt == 5'd1)  FL_WE_N <= 1'b0;
                if (bt == 5'd7)  FL_WE_N <= 1'b1;
                if (bt == 5'd9)  begin FL_CE_N <= 1'b1; dq_oe <= 1'b0; end
                if (bt == 5'd11) begin bus_active <= 1'b0; bus_done <= 1'b1; end
            end else begin
                // 120 ns access time, then release
                if (bt == 5'd12) begin bus_rdata <= FL_DQ; FL_OE_N <= 1'b1; FL_CE_N <= 1'b1; end
                if (bt == 5'd14) begin bus_active <= 1'b0; bus_done <= 1'b1; end
            end
        end
    end

    // ---------------- command sequencer ----------------
    localparam [22:0] A_AAA = 23'h000AAA, A_555 = 23'h000555;

    localparam S_BOOT       = 5'd0,
               S_IDLE       = 5'd1,
               S_RESETCMD   = 5'd2,
               S_LD_MAGIC   = 5'd3,
               S_LD_DATA    = 5'd4,
               S_LD_DONE    = 5'd5,
               S_ER_CMD     = 5'd6,
               S_ER_POLL    = 5'd7,
               S_PG_FETCH   = 5'd8,
               S_PG_CMD     = 5'd9,
               S_PG_POLL    = 5'd10,
               S_PG_NEXT    = 5'd11,
               S_FINISH     = 5'd12,
               S_WAITBUS    = 5'd13;

    reg [4:0]  st = S_BOOT, ret;
    reg [19:0] boot_cnt = 20'd0;
    reg [2:0]  step;
    reg [13:0] idx;             // 0..8191 histograms, 8192..12287 photos, 12288..12292 header
    reg [7:0]  magic [0:4];
    reg [7:0]  pg_data;
    reg [22:0] pg_addr;
    reg [21:0] poll_cnt;
    reg        is_save;
    reg [3:0]  save_mask;
    reg [1:0]  fetch_wait;

    localparam [13:0] N_HIST = 14'd8192, N_DATA = 14'd12288;

    // address of program/load byte idx: data first, header after N_DATA
    function [22:0] data_addr;
        input [13:0] i;
        data_addr = (i < N_DATA) ? (BASE + 23'h001000 + {9'd0, i}) : (BASE + {9'd0, i - N_DATA});
    endfunction

    // RAM address of data byte idx (histogram or photo)
    function [12:0] ram_addr;
        input [13:0] i;
        ram_addr = (i < N_HIST) ? i[12:0] : {1'b0, i[11:0]};   // photos: i - 8192
    endfunction

    // issue one bus cycle and come back to state r
    task bus;
        input        w;
        input [22:0] ad;
        input [7:0]  da;
        input [4:0]  r;
        begin
            bus_go    <= 1'b1;
            bus_write <= w;
            bus_addr  <= ad;
            bus_data  <= da;
            ret       <= r;
            st        <= S_WAITBUS;
        end
    endtask

    integer m;
    always @(posedge clk) begin
        bus_go   <= 1'b0;
        hist_we  <= 1'b0;
        photo_we <= 1'b0;

        if (save_sync[2]  != save_sync[1])  save_req  <= 1'b1;
        if (erase_sync[2] != erase_sync[1]) erase_req <= 1'b1;

        case (st)
            // wait ~10 ms after configuration before touching the flash
            S_BOOT: begin
                boot_cnt <= boot_cnt + 20'd1;
                if (boot_cnt == 20'hFFFFF) begin
                    step <= 3'd0;
                    idx  <= 14'd0;
                    bus(1'b1, A_AAA, 8'hF0, S_LD_MAGIC);   // reset to read mode
                end
            end

            S_WAITBUS: begin
                if (bus_done)
                    st <= ret;
            end

            // ---------- load ----------
            S_LD_MAGIC: begin
                // read the 5 header bytes ("VJF1" + mask), step counts them
                if (step != 3'd0)
                    magic[step - 3'd1] <= bus_rdata;
                if (step == 3'd5)
                    st <= S_LD_DONE;
                else begin
                    step <= step + 3'd1;
                    bus(1'b0, BASE + {20'd0, step}, 8'h00, S_LD_MAGIC);
                end
            end

            S_LD_DONE: begin
                if (magic[0] == "V" && magic[1] == "J" && magic[2] == "F" && magic[3] == "2") begin
                    loaded_mask <= magic[4][3:0];
                    ram_en      <= 1'b1;
                    idx         <= 14'd0;
                    bus(1'b0, data_addr(14'd0), 8'h00, S_LD_DATA);
                end else begin
                    loaded_mask   <= 4'b0000;
                    loaded_toggle <= ~loaded_toggle;
                    st            <= S_IDLE;
                end
            end

            S_LD_DATA: begin
                ram_waddr <= ram_addr(idx);
                ram_wdata <= bus_rdata;
                hist_we   <= (idx <  N_HIST);
                photo_we  <= (idx >= N_HIST);
                if (idx == N_DATA - 14'd1) begin
                    ram_en        <= 1'b0;
                    loaded_toggle <= ~loaded_toggle;
                    st            <= S_IDLE;
                end else begin
                    idx <= idx + 14'd1;
                    bus(1'b0, data_addr(idx + 14'd1), 8'h00, S_LD_DATA);
                end
            end

            // ---------- idle ----------
            S_IDLE: begin
                busy <= 1'b0;
                if (erase_req || save_req) begin
                    busy      <= 1'b1;
                    is_save   <= save_req & ~erase_req;
                    save_mask <= enrolled_mask;
                    erase_req <= 1'b0;
                    save_req  <= 1'b0;
                    step      <= 3'd0;
                    st        <= S_ER_CMD;
                end
            end

            // ---------- sector erase: AA 55 80 AA 55 30 ----------
            S_ER_CMD: begin
                step <= step + 3'd1;
                case (step)
                    3'd0: bus(1'b1, A_AAA, 8'hAA, S_ER_CMD);
                    3'd1: bus(1'b1, A_555, 8'h55, S_ER_CMD);
                    3'd2: bus(1'b1, A_AAA, 8'h80, S_ER_CMD);
                    3'd3: bus(1'b1, A_AAA, 8'hAA, S_ER_CMD);
                    3'd4: bus(1'b1, A_555, 8'h55, S_ER_CMD);
                    3'd5: begin poll_cnt <= 22'd0; bus(1'b1, BASE, 8'h30, S_ER_POLL); end
                    default: st <= S_ER_POLL;
                endcase
            end

            // DQ7 reads 1 once the erase is complete (timeout ~6 s)
            S_ER_POLL: begin
                if (step == 3'd6) begin
                    step <= 3'd7;
                    bus(1'b0, BASE, 8'h00, S_ER_POLL);
                end else if (bus_rdata[7] || poll_cnt == 22'h3FFFFF) begin
                    if (is_save) begin
                        idx        <= 14'd0;
                        ram_en     <= 1'b1;
                        st         <= S_PG_FETCH;
                        fetch_wait <= 2'd0;
                    end else
                        st <= S_FINISH;
                end else begin
                    poll_cnt <= poll_cnt + 22'd1;
                    bus(1'b0, BASE, 8'h00, S_ER_POLL);
                end
            end

            // ---------- program idx = 0..12292 ----------
            S_PG_FETCH: begin
                ram_raddr  <= ram_addr(idx);
                fetch_wait <= fetch_wait + 2'd1;
                if (fetch_wait == 2'd3) begin
                    case (idx)
                        N_DATA:          pg_data <= "V";
                        N_DATA + 14'd1:  pg_data <= "J";
                        N_DATA + 14'd2:  pg_data <= "F";
                        N_DATA + 14'd3:  pg_data <= "2";
                        N_DATA + 14'd4:  pg_data <= {4'd0, save_mask};
                        default:         pg_data <= (idx < N_HIST) ? hist_rdata : photo_rdata;
                    endcase
                    pg_addr <= data_addr(idx);
                    step    <= 3'd0;
                    st      <= S_PG_CMD;
                end
            end

            // AA 55 A0 then the data byte (skipped for erased value FF)
            S_PG_CMD: begin
                step <= step + 3'd1;
                if (pg_data == 8'hFF)
                    st <= S_PG_NEXT;
                else case (step)
                    3'd0: bus(1'b1, A_AAA, 8'hAA, S_PG_CMD);
                    3'd1: bus(1'b1, A_555, 8'h55, S_PG_CMD);
                    3'd2: bus(1'b1, A_AAA, 8'hA0, S_PG_CMD);
                    3'd3: begin poll_cnt <= 22'd0; bus(1'b1, pg_addr, pg_data, S_PG_POLL); end
                    default: st <= S_PG_POLL;
                endcase
            end

            // DQ7 shows the true data bit once programming is complete
            S_PG_POLL: begin
                if (step == 3'd4) begin
                    step <= 3'd5;
                    bus(1'b0, pg_addr, 8'h00, S_PG_POLL);
                end else if (bus_rdata[7] == pg_data[7] || poll_cnt == 22'h00FFFF)
                    st <= S_PG_NEXT;
                else begin
                    poll_cnt <= poll_cnt + 22'd1;
                    bus(1'b0, pg_addr, 8'h00, S_PG_POLL);
                end
            end

            S_PG_NEXT: begin
                if (idx == N_DATA + 14'd4) begin
                    ram_en <= 1'b0;
                    st     <= S_FINISH;
                end else begin
                    idx        <= idx + 14'd1;
                    fetch_wait <= 2'd0;
                    st         <= S_PG_FETCH;
                end
            end

            S_FINISH: begin
                if (!is_save) begin
                    loaded_mask   <= 4'b0000;
                    loaded_toggle <= ~loaded_toggle;
                end
                bus(1'b1, A_AAA, 8'hF0, S_IDLE);   // back to read mode
            end

            default: st <= S_IDLE;
        endcase
    end

endmodule
