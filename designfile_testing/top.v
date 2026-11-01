// ==========================================================================
// top.v - Viola-Jones face detection + recognition system (top level)
// --------------------------------------------------------------------------
// Board: Terasic DE2-115 (Cyclone IV EP4CE115F29C7), camera: OV7670 on GPIO.
//
// Data flow
//   OV7670 -> ov7670_capture (RGB565, 640x480 -> 320x240)
//      live_ram  (12-bit colour, written every frame)  -> VGA left half, 30 FPS
//      image_ram (8-bit grey, written on snapshot frames) -> ii_gen
//   ii_gen -> integral images (ii/iix2 buffers) -> subwindow_top (16 parallel
//   Haar-cascade lanes) -> faceBox (raw hits) -> face_cluster (grouped faces)
//   -> face_recognizer (LBP match against enrolled people) -> box_overlay
//   (green boxes + name/score labels).  Enrolled photos are shown by
//   enroll_gallery (VGA right half) and kept in flash by flash_store.
//
// Clocks (my_altpll from the 50 MHz board clock)
//   clk_sys     40 MHz : main FSM, cascade, faceBox, face_cluster
//   clk_iigen  100 MHz : ii_gen, image_ram read, face_recognizer, flash_store
//   clk_50_camera 50 MHz: camera I2C controller (XCLK = 25 MHz)
//   clk_25_vga  25 MHz : VGA timing, live_ram read, overlays
//   ov7670_pclk        : camera pixel clock (capture, RAM writes)
//   Every RAM has one write clock and one read clock (dp_ram): no clock muxes.
//
// Main FSM (one detection pass)
//   RESET -> CAPTURE_START/CAPTURE (snapshot into image_ram) -> for each of 8
//   scales: NEWSCALE_RESET, II_GEN_INIT, II_GEN_SUBWIN(_RESET), SUBWIN_RESET
//   -> SCALE -> FACEBOX_START/FACEBOX (replay hits into face_cluster) -> POST
//   (wait for grouped faces and idle flash) -> ENROLL (run the recognizer,
//   storing an enrollment view first when KEY1 armed it) -> RESET.
//
// User controls / indicators: see USER_MANUAL.md next to the project folder.
//   SW17 reset, SW16 resend camera registers, SW15 capture mode (0 = continuous),
//   SW14 test image, SW13 overlay, SW11..10 enrollment slot, SW2..0 min group
//   size, KEY0 capture, KEY1 enroll, KEY3 forget everyone.
//   LEDR0 PLL lock, LEDR1 camera configured, LEDR2 pass done (toggles),
//   LEDR3 raw hits seen, LEDR4 enrollment pending, LEDR5 flash busy,
//   LEDR6..9 main FSM state, LEDR10..13 recognizer state, LEDG0..7 camera
//   data lines toggling.
//
// Originally a VHDL design (WPI E50), converted to Verilog and extended.
// ==========================================================================

module top (
    input        clk_50,
    input        slide_sw_RESET,
    input        slide_sw_resend_reg_values,
    input        slide_sw_capture_mode,
    input        btn_capture,
    input        slide_sw_overlay_en,  // SW13: 1 = draw face boxes over the video
    input        slide_sw_test_image,  // SW14: 1 = freeze both buffers on the built-in test image
    input  [2:0] slide_sw_min_neighbors, // SW2..SW0: keep face clusters with more than this many hits

    output       LED_config_finished,
    output       LED_dll_locked,
    output       LED_pass_done,        // LEDR2: toggles every completed detection pass
    output       LED_hits_seen,        // LEDR3: last pass produced at least one raw hit
    output       LED_enroll_pending,   // LEDR4: KEY1 pressed, waiting for a face to enroll
    input        btn_enroll,           // KEY1 (active low): enroll the largest face into the selected slot
    input  [1:0] slide_sw_enroll_slot, // SW11..SW10: person slot 0..3 for enrollment
    input        btn_forget_all,       // KEY3 (active low): erase all enrolled people (RAM + flash)
    output       LED_flash_busy,       // LEDR5: flash load / save / erase in progress
    output [3:0] LED_fsm_state,        // LEDR9..6: main FSM state (diagnostic)
    output [3:0] LED_recog_state,      // LEDR13..10: recognizer state (diagnostic)

    // on-board parallel flash: keeps enrolled people across power-off
    output [22:0] FL_ADDR,
    inout  [7:0]  FL_DQ,
    output        FL_CE_N,
    output        FL_OE_N,
    output        FL_WE_N,
    output        FL_RST_N,
    output        FL_WP_N,
    output [7:0] LEDG_cam_bits,

    output       vga_hsync,
    output       vga_vsync,
    output [7:0] vga_r,
    output [7:0] vga_g,
    output [7:0] vga_b,
    output       vga_blank_N,
    output       vga_sync_N,
    output       vga_CLK,

    input        ov7670_pclk,
    output       ov7670_xclk,
    input        ov7670_vsync,
    input        ov7670_href,
    input  [7:0] ov7670_data,
    output       ov7670_sioc,
    inout        ov7670_siod,
    output       ov7670_pwdn,
    output       ov7670_reset,

    output       ii_gen_done,
    output       subwin_done,
    output       faceBox_done,
    output       measure_performance
);

    localparam [5:0] II_WIDTH  = 6'd39;
    localparam [5:0] II_HEIGHT = 6'd59;

    // ----------------------------------------------------------
    // Clock signals
    // ----------------------------------------------------------
    wire clk_50_camera;
    wire clk_25_vga;
    wire clk_sys;
    wire clk_iigen;
    wire clk_faceBox;
    wire dll_locked;

    // ----------------------------------------------------------
    // User controls
    // ----------------------------------------------------------
    wire reset;
    wire resend_reg_values;
    wire capture_mode;
    wire capture;

    assign reset        = slide_sw_RESET;
    assign capture_mode = slide_sw_capture_mode;
    assign capture      = ~btn_capture;

    // ----------------------------------------------------------
    // Image frame buffer signals
    // ----------------------------------------------------------


    wire [11:0] rddata_buff_1B;

    wire        wren_buff_2A;
    wire [12:0] address_buff_2A;
    wire [19:0] wrdata_buff_2A;
    wire [19:0] rddata_buff_2A;

    wire [8:0]  address_buff_2B;
    wire [8:0]  address_buff_2B_prime;
    wire [639:0] rddata_buff_2B;

    wire        wren_buff_3A;
    wire [12:0] address_buff_3A;
    wire [27:0] wrdata_buff_3A;
    wire [27:0] rddata_buff_3A;

    wire [8:0]  address_buff_3B;
    wire [8:0]  address_buff_3B_prime;
    wire [895:0] rddata_buff_3B;

    // ----------------------------------------------------------
    // Integral image related
    // ----------------------------------------------------------
    reg         next_mem_state;
    reg         mem_state;

    reg [8:0]   next_ii_gen_x_base;
    reg [7:0]   next_ii_gen_y_base;
    reg [8:0]   ii_gen_x_base;
    reg [7:0]   ii_gen_y_base;

    wire [16:0] image_rdaddress_from_iigen;
    reg         ii_gen_start_s;
    reg         ii_gen_reset_s;
    wire        ii_gen_done_s;

    // ----------------------------------------------------------
    // Subwindow related
    // ----------------------------------------------------------
    wire [15:0] subwin_fail_s;
    wire        subwin_any_fail;
    wire        subwin_all_fail;

    reg [8:0]   next_subwin_x_base;
    reg [7:0]   next_subwin_y_base;
    reg [8:0]   subwin_x_base;
    reg [7:0]   subwin_y_base;

    reg [5:0]   next_subwin_x_base_offset;
    reg [5:0]   next_subwin_y_base_offset;
    reg [5:0]   subwin_x_base_offset;
    reg [5:0]   subwin_y_base_offset;

    wire [8:0]  subwin_x_pos;
    wire [7:0]  subwin_y_pos;

    reg         subwin_start_s;
    wire        subwin_done_s;
    reg         subwin_reset_s;

    // ----------------------------------------------------------
    // RGB / VGA
    // ----------------------------------------------------------
    wire [7:0] red;
    wire [7:0] green;
    wire [7:0] blue;
    wire       activeArea;
    wire       nBlank;
    wire       vsync;

    // ----------------------------------------------------------
    // Camera capture
    // ----------------------------------------------------------
    reg         take_snapshot;
    wire [16:0] image_wraddress_from_ov7670_capture;
    wire [11:0] image_wrdata_from_ov7670_capture;
    wire        image_wren_from_ov7670_capture;
    wire        live_wren_from_ov7670_capture;
    wire [7:0]  grey_from_ov7670_capture;      // full-precision grey for detection/recognition
    wire        ov7670_capture_busy;

    // ----------------------------------------------------------
    // FaceBox
    // ----------------------------------------------------------
    wire [16:0] image_wraddress_from_faceBox;
    wire [11:0] image_wrdata_from_faceBox;
    wire        image_wren_from_faceBox;

    reg         faceBox_start_s;
    wire        faceBox_done_s;
    wire        faceBox_wren;
    reg         faceBox_reset_s;

    // Face boxes: faceBox reports raw hits, face_cluster groups them,
    // box_overlay draws the result on top of the live video
    reg         cluster_clear;
    reg         cluster_finalize;
    wire        overlay_pixel;
    wire        label_fg;
    wire        label_bg;
    wire        box_valid;
    wire [9:0]  box_x;
    wire [8:0]  box_y;
    wire [8:0]  box_size;
    wire [3:0]  face_valid;
    wire [39:0] face_x;
    wire [35:0] face_y;
    wire [35:0] face_size;
    wire        face_update;
    wire [9:0]  vga_hcount;
    wire [9:0]  vga_vcount;

    // Enrollment: KEY1 arms it, the next pass's largest face is cropped to
    // 32x32 grey into template slot SW11..SW10
    reg         crop_start;
    reg         enroll_done;
    reg         enroll_pending = 1'b0;
    reg  [1:0]  enroll_slot    = 2'd0;
    reg  [3:0]  enrolled       = 4'b0000;
    reg         flash_save_req  = 1'b0;   // toggle
    reg         flash_erase_req = 1'b0;   // toggle
    wire        flash_busy;
    wire        flash_loaded;             // toggle
    wire [3:0]  flash_mask;
    reg  [1:0]  flash_busy_sync = 2'b11;
    reg  [2:0]  flash_loaded_sync = 3'b000;
    wire        flash_busy_s = flash_busy_sync[1];
    wire        flash_ram_en;
    wire [12:0] flash_raddr;
    wire [7:0]  flash_hist_rdata;
    wire [7:0]  flash_photo_rdata;
    wire        flash_hist_we;
    wire        flash_photo_we;
    wire [12:0] flash_waddr;
    wire [7:0]  flash_wdata;
    reg         fu_at_finalize = 1'b0;
    reg         crop_req       = 1'b0;
    reg  [2:0]  crop_ack_sync  = 3'b000;
    reg         recog_enroll   = 1'b0;
    reg  [1:0]  enroll_sample  = 2'd0;    // enrollment stores 4 views, one per pass
    wire [11:0] recog_person;
    wire [27:0] recog_score;
    wire [3:0]  recog_dbg_state;
    wire        crop_ack;
    wire        crop_active;
    wire [16:0] crop_rd_address;
    wire        tmpl_wren;
    wire [11:0] tmpl_wraddress;
    wire [7:0]  tmpl_wrdata;
    wire [11:0] tmpl_rdaddress_vga;
    wire [7:0]  tmpl_rddata_vga;
    wire [11:0] gallery_rgb;
    wire        faces_published = (face_update != fu_at_finalize);
    wire        crop_finished   = (crop_ack_sync[2] == crop_req);

    // ----------------------------------------------------------
    // VGA address
    // ----------------------------------------------------------
    wire [16:0] image_rdaddress_from_addr_gen;

    // ----------------------------------------------------------
    // Scale counter
    // ----------------------------------------------------------
    reg [3:0] scale_count;
    reg       scale_count_en;
    reg       scale_count_reset;

    reg [8:0] width_scale_img;
    reg [7:0] height_scale_img;

    // VHDL lookup tables:
    // scale: 1  2  3  4  5  6  7  8
    // width:320,160,107,80,64,54,46,40
    // height:240,120,80,60,48,40,35,30
    always @(*) begin
        case (scale_count)
            4'd1: begin width_scale_img = 9'd320; height_scale_img = 8'd240; end
            4'd2: begin width_scale_img = 9'd160; height_scale_img = 8'd120; end
            4'd3: begin width_scale_img = 9'd107; height_scale_img = 8'd80;  end
            4'd4: begin width_scale_img = 9'd80;  height_scale_img = 8'd60;  end
            4'd5: begin width_scale_img = 9'd64;  height_scale_img = 8'd48;  end
            4'd6: begin width_scale_img = 9'd54;  height_scale_img = 8'd40;  end
            4'd7: begin width_scale_img = 9'd46;  height_scale_img = 8'd35;  end
            4'd8: begin width_scale_img = 9'd40;  height_scale_img = 8'd30;  end
            default: begin width_scale_img = 9'd0; height_scale_img = 8'd0; end
        endcase
    end

    always @(posedge clk_sys or posedge scale_count_reset) begin
        if (scale_count_reset)
            scale_count <= 4'd1;
        else if (scale_count_en)
            scale_count <= scale_count + 4'd1;
    end

    // ----------------------------------------------------------
    // Determine whether any/all subwindows failed
    // ----------------------------------------------------------
    assign subwin_any_fail = |subwin_fail_s;
    assign subwin_all_fail = &subwin_fail_s;

    // ----------------------------------------------------------
    // TOP LEVEL FSM
    // ----------------------------------------------------------
    localparam [3:0]
        S_RESET              = 4'd0,
        S_CAPTURE_START     = 4'd1,
        S_CAPTURE           = 4'd2,
        S_NEWSCALE_RESET    = 4'd3,
        S_II_GEN_INIT       = 4'd4,
        S_SUBWIN_RESET      = 4'd5,
        S_II_GEN_SUBWIN_RESET = 4'd6,
        S_II_GEN_SUBWIN     = 4'd7,
        S_SCALE             = 4'd8,
        S_FACEBOX_START     = 4'd9,
        S_FACEBOX            = 4'd10,
        S_POST               = 4'd11,  // wait for face_cluster to publish the faces
        S_ENROLL             = 4'd12;  // recognizer running (enrolls first when armed)

    reg [3:0] current_state, next_state;

    always @(posedge clk_sys or posedge reset) begin
        if (reset) begin
            current_state          <= S_RESET;
            mem_state              <= 1'b0;
            subwin_x_base_offset   <= 6'd0;
            subwin_y_base_offset   <= 6'd0;
            ii_gen_x_base          <= 9'd0;
            ii_gen_y_base          <= 8'd0;
            subwin_x_base          <= 9'd0;
            subwin_y_base          <= 8'd0;
        end
        else begin
            current_state          <= next_state;
            mem_state              <= next_mem_state;
            subwin_x_base_offset   <= next_subwin_x_base_offset;
            subwin_y_base_offset   <= next_subwin_y_base_offset;
            ii_gen_x_base          <= next_ii_gen_x_base;
            ii_gen_y_base          <= next_ii_gen_y_base;
            subwin_x_base          <= next_subwin_x_base;
            subwin_y_base          <= next_subwin_y_base;
        end
    end

    always @(*) begin

        subwin_reset_s           = 1'b0;
        subwin_start_s           = 1'b0;

        faceBox_start_s          = 1'b0;
        faceBox_reset_s          = 1'b0;

        cluster_clear            = 1'b0;
        cluster_finalize         = 1'b0;
        crop_start               = 1'b0;
        enroll_done              = 1'b0;

        ii_gen_start_s           = 1'b0;
        ii_gen_reset_s            = 1'b0;

        scale_count_reset        = 1'b0;
        scale_count_en           = 1'b0;
        take_snapshot            = 1'b0;

        next_mem_state            = mem_state;

        next_subwin_x_base_offset = subwin_x_base_offset;
        next_subwin_y_base_offset = subwin_y_base_offset;

        next_ii_gen_x_base        = ii_gen_x_base;
        next_ii_gen_y_base        = ii_gen_y_base;

        next_subwin_x_base        = subwin_x_base;
        next_subwin_y_base        = subwin_y_base;

        next_state                = S_RESET;

        case (current_state)

            S_RESET: begin
                subwin_reset_s    = 1'b1;
                faceBox_reset_s   = 1'b1;
                scale_count_reset = 1'b1;
                ii_gen_reset_s    = 1'b1;

                next_mem_state            = 1'b0;
                next_subwin_x_base_offset = 6'd0;
                next_subwin_y_base_offset = 6'd0;
                next_ii_gen_x_base        = 9'd0;
                next_ii_gen_y_base        = 8'd0;
                next_subwin_x_base        = 9'd0;
                next_subwin_y_base        = 8'd0;

                next_state = S_CAPTURE_START;
            end

            S_CAPTURE_START: begin
                if (ov7670_capture_busy) begin
                    next_state = S_CAPTURE;
                end
                else begin
                    if (!capture_mode) begin
                        take_snapshot = 1'b1;
                    end
                    else if (capture) begin
                        take_snapshot = 1'b1;
                    end

                    next_state = S_CAPTURE_START;
                end
            end

            S_CAPTURE: begin
                if (!ov7670_capture_busy)
                    next_state = S_NEWSCALE_RESET;
                else
                    next_state = S_CAPTURE;
            end

            S_NEWSCALE_RESET: begin
                ii_gen_reset_s  = 1'b1;
                subwin_reset_s  = 1'b1;
                next_mem_state  = 1'b0;

                next_subwin_x_base = 9'd0;
                next_subwin_y_base = 8'd0;
                next_ii_gen_x_base = 9'd0;
                next_ii_gen_y_base = 8'd0;

                next_subwin_x_base_offset = 6'd0;
                next_subwin_y_base_offset = 6'd0;

                next_state = S_II_GEN_INIT;
            end

            S_II_GEN_INIT: begin
                if (ii_gen_done_s) begin
                    next_ii_gen_x_base = 9'd0;
                    next_ii_gen_y_base = 8'd36;
                    next_state = S_II_GEN_SUBWIN_RESET;
                end
                else begin
                    ii_gen_start_s  = 1'b1;
                    next_state      = S_II_GEN_INIT;
                end
            end

            S_SUBWIN_RESET: begin
                subwin_reset_s  = 1'b1;

                if (subwin_any_fail)
                    next_state = S_SUBWIN_RESET;
                else
                    next_state = S_II_GEN_SUBWIN;
            end

            S_II_GEN_SUBWIN_RESET: begin
                ii_gen_reset_s  = 1'b1;
                subwin_reset_s  = 1'b1;

                if (subwin_any_fail)
                    next_state = S_II_GEN_SUBWIN_RESET;
                else begin
                    next_mem_state = ~mem_state;
                    next_state = S_II_GEN_SUBWIN;
                end
            end

            S_II_GEN_SUBWIN: begin
                next_subwin_x_base_offset = 6'd0;

                ii_gen_start_s = 1'b1;
                subwin_start_s = 1'b1;

                if (subwin_done_s || subwin_all_fail) begin

                    if ((subwin_y_base_offset < (II_HEIGHT - 6'd24)) &&
                        (subwin_y_base_offset < (height_scale_img - 8'd24))) begin

                        next_subwin_y_base_offset =
                            subwin_y_base_offset + 6'd1;

                        next_state = S_SUBWIN_RESET;
                    end
                    else begin

                        if (ii_gen_done_s) begin
                            next_subwin_y_base_offset = 6'd0;
                            next_subwin_x_base = ii_gen_x_base;
                            next_subwin_y_base = ii_gen_y_base;

                            if (ii_gen_y_base <
                                (height_scale_img - II_HEIGHT)) begin

                                next_ii_gen_y_base =
                                    ii_gen_y_base + 8'd36;

                                next_state = S_II_GEN_SUBWIN_RESET;
                            end
                            else if (ii_gen_x_base <
                                     (width_scale_img - II_WIDTH)) begin

                                next_ii_gen_x_base =
                                    ii_gen_x_base + 9'd16;

                                next_ii_gen_y_base = 8'd0;
                                next_state = S_II_GEN_SUBWIN_RESET;
                            end
                            else begin
                                next_state = S_SCALE;
                            end
                        end
                        else begin
                            next_state = S_II_GEN_SUBWIN;
                        end
                    end
                end
                else begin
                    next_state = S_II_GEN_SUBWIN;
                end
            end

            S_SCALE: begin
                subwin_reset_s = 1'b1;
                ii_gen_reset_s = 1'b1;

                if (scale_count == 4'd8)
                    next_state = S_FACEBOX_START;
                else begin
                    scale_count_en = 1'b1;
                    next_state = S_NEWSCALE_RESET;
                end
            end

            S_FACEBOX_START: begin
                cluster_clear   = 1'b1; // forget the previous pass's clusters
                faceBox_start_s = 1'b1;
                next_state = S_FACEBOX;
            end

            S_FACEBOX: begin

                if (faceBox_done_s) begin
                    cluster_finalize = 1'b1; // group this pass's hits and publish the faces
                    next_state = S_POST;
                end
                else begin
                    faceBox_start_s = 1'b1;
                    next_state = S_FACEBOX;
                end
            end

            S_POST: begin
                if (!faces_published || flash_busy_s)
                    next_state = S_POST;
                else begin
                    crop_start = 1'b1;   // run the recognizer (and enrollment if armed)
                    next_state = S_ENROLL;
                end
            end

            S_ENROLL: begin
                if (crop_finished) begin
                    enroll_done = recog_enroll && (enroll_sample == 2'd3);
                    next_state = S_RESET;
                end
                else
                    next_state = S_ENROLL;
            end

            default:
                next_state = S_RESET;

        endcase
    end

    // ----------------------------------------------------------
    // PLL
    // ----------------------------------------------------------
    my_altpll Inst_four_clocks_pll (
        .areset  (1'b0),
        .inclk0  (clk_50),
        .c0      (clk_sys),
        .c1      (clk_iigen),
        .c2      (clk_50_camera),
        .c3      (clk_25_vga),
        .locked  (dll_locked)
    );

    assign clk_faceBox = clk_sys;
    assign LED_dll_locked = dll_locked;

    // ----------------------------------------------------------
    // Debounce
    // ----------------------------------------------------------
    debounce Inst_debounce_resend (
        .clk (clk_25_vga),
        .i   (slide_sw_resend_reg_values),
        .o   (resend_reg_values)
    );

    // ----------------------------------------------------------
    // OV7670 controller
    // ----------------------------------------------------------
    ov7670_controller Inst_ov7670_controller (
        .clk             (clk_50_camera),
        .resend          (resend_reg_values),
        .config_finished (LED_config_finished),
        .sioc            (ov7670_sioc),
        .siod            (ov7670_siod),
        .reset           (ov7670_reset),
        .pwdn            (ov7670_pwdn),
        .xclk            (ov7670_xclk)
    );

    ov7670_capture Inst_ov7670_capture (
        .pclk    (ov7670_pclk),
        .capture (take_snapshot),
        .vsync   (ov7670_vsync),
        .href    (ov7670_href),
        .d       (ov7670_data),
        .addr    (image_wraddress_from_ov7670_capture),
        .dout    (image_wrdata_from_ov7670_capture),
        .grey    (grey_from_ov7670_capture),
        .we      (image_wren_from_ov7670_capture),
        .live_we (live_wren_from_ov7670_capture),
        .busy    (ov7670_capture_busy)
    );

    // Diagnostic: LEDG[i] lit = camera data line D[i] is toggling
    cam_bit_monitor Inst_cam_bit_monitor (
        .pclk   (ov7670_pclk),
        .href   (ov7670_href),
        .d      (ov7670_data),
        .active (LEDG_cam_bits)
    );

    // ----------------------------------------------------------
    // VGA
    // ----------------------------------------------------------
    Address_Generator Inst_Address_Generator (
        .rst_i   (1'b0),
        .CLK25   (clk_25_vga),
        .enable  (activeArea),
        .vsync   (vsync),
        .address (image_rdaddress_from_addr_gen)
    );

    VGA Inst_VGA (
        .CLK25      (clk_25_vga),
        .clkout     (vga_CLK),
        .Hsync      (vga_hsync),
        .Vsync      (vsync),
        .Nblank     (nBlank),
        .Nsync      (vga_sync_N),
        .hcount     (vga_hcount),
        .vcount     (vga_vcount),
        .activeArea (activeArea)
    );

    // Live video with face boxes drawn in red on top
    wire [11:0] live_pixel;
    wire [11:0] display_pixel =
        !slide_sw_overlay_en ? live_pixel :
        label_fg             ? 12'hFFF :   // label text: white
        label_bg             ? 12'h000 :   // label strip: black
        overlay_pixel        ? 12'h0F0 :   // face box: green
                               live_pixel;

    // left 320x240: camera + overlay; elsewhere: enrollment gallery
    RGB Inst_RGB (
        .Din    (activeArea ? display_pixel : gallery_rgb),
        .Nblank (nBlank),
        .R      (red),
        .G      (green),
        .B      (blue)
    );

    assign vga_r      = red;
    assign vga_g      = green;
    assign vga_b      = blue;
    assign vga_vsync  = vsync;
    assign vga_blank_N = nBlank;

    // ----------------------------------------------------------
    // Frame buffers - each has one write clock and one read clock, so no
    // clock muxing is needed.
    //   live_ram : camera (pclk) every frame -> VGA (25 MHz), 30 FPS video
    //   image_ram: camera (pclk) snapshot frames, 8bit grey -> ii_gen (clk_iigen)
    // ----------------------------------------------------------
    // In test-image mode the camera writes are blocked, so both buffers keep
    // their power-up contents (the face-grid test image) and detection runs on it.
    dp_ram #(.WIDTH(12), .WIDTHAD(17), .NUMWORDS(76800), .INIT_FILE("test_image_rgb444.mif")) live_ram (
        .wrclock   (ov7670_pclk),
        .wren      (live_wren_from_ov7670_capture & ~slide_sw_test_image),
        .wraddress (image_wraddress_from_ov7670_capture),
        .data      (image_wrdata_from_ov7670_capture),
        .rdclock   (clk_25_vga),
        .rdaddress (image_rdaddress_from_addr_gen),
        .q         (live_pixel)
    );

    wire [7:0] grey_rddata;

    dp_ram #(.WIDTH(8), .WIDTHAD(17), .NUMWORDS(76800), .INIT_FILE("test_image_grey8.mif")) image_ram (
        .wrclock   (ov7670_pclk),
        .wren      (image_wren_from_ov7670_capture & ~slide_sw_test_image),
        .wraddress (image_wraddress_from_ov7670_capture),
        .data      (grey_from_ov7670_capture),
        .rdclock   (clk_iigen),
        .rdaddress (crop_active ? crop_rd_address : image_rdaddress_from_iigen),
        .q         (grey_rddata)
    );

    assign rddata_buff_1B = {4'b0000, grey_rddata};


    // ----------------------------------------------------------
    // Integral image buffers
    // ----------------------------------------------------------
    ii_buffer ii_ram1 (
        .address_a (address_buff_2A),
        .address_b (address_buff_2B),
        .clock_a   (clk_iigen),
        .clock_b   (clk_sys),
        .data_a    (wrdata_buff_2A),
        .data_b    (20'd0),
        .wren_a    (wren_buff_2A),
        .wren_b    (1'b0),
        .q_a       (rddata_buff_2A),
        .q_b       (rddata_buff_2B[319:0])
    );

    assign address_buff_2B_prime = address_buff_2B + 9'd1;

    ii_buffer ii_ram2 (
        .address_a (address_buff_2A),
        .address_b (address_buff_2B_prime),
        .clock_a   (clk_iigen),
        .clock_b   (clk_sys),
        .data_a    (wrdata_buff_2A),
        .data_b    (20'd0),
        .wren_a    (wren_buff_2A),
        .wren_b    (1'b0),
        .q_a       (),
        .q_b       (rddata_buff_2B[639:320])
    );

    iix2_buffer iix2_ram1 (
        .address_a (address_buff_3A),
        .address_b (address_buff_3B),
        .clock_a   (clk_iigen),
        .clock_b   (clk_sys),
        .data_a    (wrdata_buff_3A),
        .data_b    (28'd0),
        .wren_a    (wren_buff_3A),
        .wren_b    (1'b0),
        .q_a       (rddata_buff_3A),
        .q_b       (rddata_buff_3B[447:0])
    );

    assign address_buff_3B_prime = address_buff_3B + 9'd1;

    iix2_buffer iix2_ram2 (
        .address_a (address_buff_3A),
        .address_b (address_buff_3B_prime),
        .clock_a   (clk_iigen),
        .clock_b   (clk_sys),
        .data_a    (wrdata_buff_3A),
        .data_b    (28'd0),
        .wren_a    (wren_buff_3A),
        .wren_b    (1'b0),
        .q_a       (),
        .q_b       (rddata_buff_3B[895:448])
    );

    // ----------------------------------------------------------
    // Integral image generator
    // ----------------------------------------------------------
    ii_gen ii_gen_inst (
        .clk             (clk_iigen),
        .reset           (ii_gen_reset_s),
        .start           (ii_gen_start_s),
        .image_data_i    (rddata_buff_1B),
        .image_scale     (scale_count),
        .ii_data_i       (rddata_buff_2A),
        .iix2_data_i     (rddata_buff_3A),
        .mem_state       (mem_state),
        .scaleImg_x_base (ii_gen_x_base),
        .scaleImg_y_base (ii_gen_y_base),
        .image_rdaddress (image_rdaddress_from_iigen),
        .ii_address      (address_buff_2A),
        .ii_wren         (wren_buff_2A),
        .ii_data_o       (wrdata_buff_2A),
        .iix2_data_o     (wrdata_buff_3A),
        .done            (ii_gen_done_s)
    );

    assign address_buff_3A = address_buff_2A;
    assign wren_buff_3A    = wren_buff_2A;

    // ----------------------------------------------------------
    // Parallel subwindow top
    // ----------------------------------------------------------
    subwindow_top subwin_top_inst (
        .reset         (subwin_reset_s),
        .clk_sys       (clk_sys),
        .start         (subwin_start_s),
        .mem_state     (mem_state),
        .x_pos_subwin0 (subwin_x_base_offset),
        .y_pos_subwin0 (subwin_y_base_offset),
        .ii_rddata     (rddata_buff_2B),
        .iix2_rddata   (rddata_buff_3B),
        .ii_rdaddress  (address_buff_2B),
        .iix2_rdaddress(address_buff_3B),
        .fail_out      (subwin_fail_s),
        .done          (subwin_done_s)
    );

    assign subwin_x_pos = subwin_x_base + subwin_x_base_offset;
    assign subwin_y_pos = subwin_y_base + subwin_y_base_offset;

    // ----------------------------------------------------------
    // FaceBox
    // ----------------------------------------------------------
    assign faceBox_wren = subwin_done_s & ~subwin_all_fail;

    faceBox faceBox_inst (
        .reset           (faceBox_reset_s),
        .clk_subwin      (clk_sys),
        .clk_faceBox     (clk_faceBox),
        .start_draw      (faceBox_start_s),
        .scale           (scale_count),
        .x_pos_subwin    (subwin_x_pos),
        .y_pos_subwin    (subwin_y_pos),
        .subwin_done     (faceBox_wren),
        .subwin_detection(subwin_fail_s),
        .img_wraddress   (image_wraddress_from_faceBox),
        .img_wrdata      (image_wrdata_from_faceBox),
        .img_wren        (image_wren_from_faceBox),
        .done_draw       (faceBox_done_s),
        .box_valid       (box_valid),
        .box_x           (box_x),
        .box_y           (box_y),
        .box_size        (box_size)
    );

    face_cluster Inst_face_cluster (
        .clk           (clk_faceBox),
        .reset         (reset),
        .clear         (cluster_clear),
        .box_valid     (box_valid),
        .box_x         (box_x),
        .box_y         (box_y),
        .box_size      (box_size),
        .finalize      (cluster_finalize),
        .min_neighbors (slide_sw_min_neighbors),
        .face_valid    (face_valid),
        .face_x        (face_x),
        .face_y        (face_y),
        .face_size     (face_size),
        .face_update   (face_update)
    );

    // ---------------- enrollment ----------------
    // KEY1: synchronise, detect the press, ignore bounces for ~100 ms
    reg [2:0]  key1_sync = 3'b111;
    reg [21:0] key1_lock = 22'd0;
    reg [2:0]  key3_sync = 3'b111;
    reg [21:0] key3_lock = 22'd0;
    always @(posedge clk_sys) begin
        key1_sync <= {key1_sync[1:0], btn_enroll};
        if (key1_lock != 22'd0)
            key1_lock <= key1_lock - 22'd1;
        else if (key1_sync[2] && !key1_sync[1]) begin   // falling edge = press
            key1_lock <= 22'h3FFFFF;
            if (!enroll_pending) begin
                enroll_pending <= 1'b1;
                enroll_slot    <= slide_sw_enroll_slot;
            end
        end

        if (enroll_done) begin
            enroll_pending        <= 1'b0;
            enrolled[enroll_slot] <= 1'b1;
            flash_save_req        <= ~flash_save_req;   // store it permanently
        end

        // KEY3: forget everyone
        key3_sync <= {key3_sync[1:0], btn_forget_all};
        if (key3_lock != 22'd0)
            key3_lock <= key3_lock - 22'd1;
        else if (key3_sync[2] && !key3_sync[1]) begin
            key3_lock       <= 22'h3FFFFF;
            enrolled        <= 4'b0000;
            enroll_pending  <= 1'b0;
            flash_erase_req <= ~flash_erase_req;
        end

        // people loaded from flash at power-up
        flash_busy_sync   <= {flash_busy_sync[0], flash_busy};
        flash_loaded_sync <= {flash_loaded_sync[1:0], flash_loaded};
        if (flash_loaded_sync[2] != flash_loaded_sync[1])
            enrolled <= flash_mask;
    end

    // largest published face
    wire [8:0] fs0 = face_valid[0] ? face_size[8:0]   : 9'd0;
    wire [8:0] fs1 = face_valid[1] ? face_size[17:9]  : 9'd0;
    wire [8:0] fs2 = face_valid[2] ? face_size[26:18] : 9'd0;
    wire [8:0] fs3 = face_valid[3] ? face_size[35:27] : 9'd0;
    wire [1:0] big01 = (fs1 > fs0) ? 2'd1 : 2'd0;
    wire [8:0] fs01  = (fs1 > fs0) ? fs1 : fs0;
    wire [1:0] big23 = (fs3 > fs2) ? 2'd3 : 2'd2;
    wire [8:0] fs23  = (fs3 > fs2) ? fs3 : fs2;
    wire [1:0] big   = (fs23 > fs01) ? big23 : big01;

    always @(posedge clk_sys) begin
        if (cluster_finalize)
            fu_at_finalize <= face_update;
        if (!enroll_pending)
            enroll_sample <= 2'd0;
        else if (current_state == S_ENROLL && crop_finished && recog_enroll)
            enroll_sample <= enroll_sample + 2'd1;   // one sample per recognizer run
        if (crop_start) begin
            recog_enroll <= enroll_pending && (face_valid != 4'b0000);
            crop_req     <= ~crop_req;
        end
        crop_ack_sync <= {crop_ack_sync[1:0], crop_ack};
    end

    face_recognizer Inst_face_recognizer (
        .clk            (clk_iigen),
        .start_toggle   (crop_req),
        .done_toggle    (crop_ack),
        .face_valid     (face_valid),
        .face_x         (face_x),
        .face_y         (face_y),
        .face_size      (face_size),
        .enroll_req     (recog_enroll),
        .enroll_face    (big),
        .enroll_slot    (enroll_slot),
        .enrolled_mask  (enrolled),
        .enroll_sample  (enroll_sample),
        .active         (crop_active),
        .rd_address     (crop_rd_address),
        .rd_data        (grey_rddata),
        .tmpl_wren      (tmpl_wren),
        .tmpl_wraddress (tmpl_wraddress),
        .tmpl_wrdata    (tmpl_wrdata),
        .result_person  (recog_person),
        .result_score   (recog_score),
        .ext_en         (flash_ram_en),
        .ext_raddr      (flash_raddr),
        .ext_rdata      (flash_hist_rdata),
        .ext_we         (flash_hist_we),
        .ext_waddr      (flash_waddr),
        .ext_wdata      (flash_wdata),
        .dbg_state      (recog_dbg_state)
    );

    // enrolled 32x32 photos, 4 slots
    wire        photo_wren  = flash_ram_en ? flash_photo_we : tmpl_wren;
    wire [11:0] photo_waddr = flash_ram_en ? flash_waddr[11:0] : tmpl_wraddress;
    wire [7:0]  photo_wdata = flash_ram_en ? flash_wdata    : tmpl_wrdata;

    dp_ram #(.WIDTH(8), .WIDTHAD(12), .NUMWORDS(4096)) template_ram (
        .wrclock   (clk_iigen),
        .wren      (photo_wren),
        .wraddress (photo_waddr),
        .data      (photo_wdata),
        .rdclock   (clk_25_vga),
        .rdaddress (tmpl_rdaddress_vga),
        .q         (tmpl_rddata_vga)
    );

    // same photos, read port on clk_iigen for saving them to flash
    dp_ram #(.WIDTH(8), .WIDTHAD(12), .NUMWORDS(4096)) template_shadow (
        .wrclock   (clk_iigen),
        .wren      (photo_wren),
        .wraddress (photo_waddr),
        .data      (photo_wdata),
        .rdclock   (clk_iigen),
        .rdaddress (flash_raddr[11:0]),
        .q         (flash_photo_rdata)
    );

    flash_store Inst_flash_store (
        .clk           (clk_iigen),
        .save_toggle   (flash_save_req),
        .erase_toggle  (flash_erase_req),
        .enrolled_mask (enrolled),
        .busy          (flash_busy),
        .loaded_toggle (flash_loaded),
        .loaded_mask   (flash_mask),
        .ram_en        (flash_ram_en),
        .ram_raddr     (flash_raddr),
        .hist_rdata    (flash_hist_rdata),
        .photo_rdata   (flash_photo_rdata),
        .hist_we       (flash_hist_we),
        .photo_we      (flash_photo_we),
        .ram_waddr     (flash_waddr),
        .ram_wdata     (flash_wdata),
        .FL_ADDR       (FL_ADDR),
        .FL_DQ         (FL_DQ),
        .FL_CE_N       (FL_CE_N),
        .FL_OE_N       (FL_OE_N),
        .FL_WE_N       (FL_WE_N),
        .FL_RST_N      (FL_RST_N),
        .FL_WP_N       (FL_WP_N)
    );

    assign LED_flash_busy = flash_busy;
    assign LED_fsm_state   = current_state;
    assign LED_recog_state = recog_dbg_state;

    enroll_gallery Inst_enroll_gallery (
        .clk_vga      (clk_25_vga),
        .hcount       (vga_hcount),
        .vcount       (vga_vcount),
        .enrolled     (enrolled),
        .sel_slot     (slide_sw_enroll_slot),
        .pending      (enroll_pending),
        .tmpl_address (tmpl_rdaddress_vga),
        .tmpl_data    (tmpl_rddata_vga),
        .rgb          (gallery_rgb)
    );

    assign LED_enroll_pending = enroll_pending;

    // detection status LEDs
    reg hits_this_pass = 1'b0;
    reg hits_last_pass = 1'b0;
    always @(posedge clk_faceBox) begin
        if (cluster_clear)
            hits_this_pass <= 1'b0;
        else if (box_valid)
            hits_this_pass <= 1'b1;
        if (cluster_finalize)
            hits_last_pass <= hits_this_pass;
    end
    assign LED_pass_done = face_update;
    assign LED_hits_seen = hits_last_pass;

    box_overlay Inst_box_overlay (
        .clk_vga     (clk_25_vga),
        .vga_vsync   (vsync),
        .hcount      (vga_hcount),
        .vcount      (vga_vcount),
        .face_valid  (face_valid),
        .face_x      (face_x),
        .face_y      (face_y),
        .face_size   (face_size),
        .face_person (recog_person),
        .face_score  (recog_score),
        .score_valid (1'b1),
        .face_update (crop_ack),        // boxes + names change together once recognition is done
        .pixel       (overlay_pixel),
        .text_fg     (label_fg),
        .text_bg     (label_bg)
    );

    // ----------------------------------------------------------
    // Performance/debug
    // ----------------------------------------------------------
    reg measure_performance_reg;

    always @(posedge clk_faceBox) begin
        if (faceBox_done_s)
            measure_performance_reg <= ~measure_performance_reg;
    end

    assign measure_performance = measure_performance_reg;

    assign ii_gen_done  = ii_gen_done_s;
    assign subwin_done  = subwin_done_s;
    assign faceBox_done = faceBox_done_s;

endmodule

