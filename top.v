// ============================================================
// Project: Viola-Jones Face Detection on FPGA
// VHDL -> Verilog conversion of top.vhd
// Original target: Quartus II / DE2-115
// ============================================================

module top (
    input        clk_50,
    input        slide_sw_RESET,
    input        slide_sw_resend_reg_values,
    input        slide_sw_capture_mode,
    input        btn_capture,

    output       LED_config_finished,
    output       LED_dll_locked,

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
    reg        buff_1A_mux_sel;
    reg        buff_1B_mux_sel;

    wire [16:0] address_buff_1A;
    wire [16:0] address_buff_1B;
    wire        clk_buff_1A;
    wire        clk_buff_1B;

    wire [11:0] rddata_buff_1A;
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
        S_FACEBOX            = 4'd10;

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
        buff_1A_mux_sel          = 1'b0;
        buff_1B_mux_sel          = 1'b0;

        subwin_reset_s           = 1'b0;
        subwin_start_s           = 1'b0;

        faceBox_start_s          = 1'b0;
        faceBox_reset_s          = 1'b0;

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
                    buff_1B_mux_sel  = 1'b1;
                    next_state      = S_II_GEN_INIT;
                end
            end

            S_SUBWIN_RESET: begin
                buff_1B_mux_sel = 1'b1;
                subwin_reset_s  = 1'b1;

                if (subwin_any_fail)
                    next_state = S_SUBWIN_RESET;
                else
                    next_state = S_II_GEN_SUBWIN;
            end

            S_II_GEN_SUBWIN_RESET: begin
                buff_1B_mux_sel = 1'b1;
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
                buff_1B_mux_sel = 1'b1;

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
                faceBox_start_s = 1'b1;
                next_state = S_FACEBOX;
            end

            S_FACEBOX: begin
                buff_1A_mux_sel = 1'b1;

                if (faceBox_done_s)
                    next_state = S_RESET;
                else begin
                    faceBox_start_s = 1'b1;
                    next_state = S_FACEBOX;
                end
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
        .we      (image_wren_from_ov7670_capture),
        .busy    (ov7670_capture_busy)
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
        .activeArea (activeArea)
    );

    RGB Inst_RGB (
        .Din    (rddata_buff_1A),
        .Nblank (activeArea),
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
    // Image frame buffer
    // ----------------------------------------------------------
    image_frame_buffer image_ram1 (
        .address_a (address_buff_1A),
        .address_b (address_buff_1B),
        .clock_a   (clk_buff_1A),
        .clock_b   (clk_buff_1B),
        .data_a    (image_wrdata_from_faceBox),
        .data_b    (image_wrdata_from_ov7670_capture),
        .wren_a    (image_wren_from_faceBox),
        .wren_b    (image_wren_from_ov7670_capture),
        .q_a       (rddata_buff_1A),
        .q_b       (rddata_buff_1B)
    );

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
    // Image-buffer clock/address muxes
    // ----------------------------------------------------------
    mux_std_logic clk_buff_1A_mux (
        .sel (buff_1A_mux_sel),
        .a   (clk_25_vga),
        .b   (clk_faceBox),
        .q   (clk_buff_1A)
    );

    mux_std_logic clk_buff_1B_mux (
        .sel (buff_1B_mux_sel),
        .a   (ov7670_pclk),
        .b   (clk_iigen),
        .q   (clk_buff_1B)
    );

    mux_2_1 #(.DATA_WIDTH(17)) address_buff_1A_mux (
        .sel (buff_1A_mux_sel),
        .a   (image_rdaddress_from_addr_gen),
        .b   (image_wraddress_from_faceBox),
        .q   (address_buff_1A)
    );

    mux_2_1 #(.DATA_WIDTH(17)) address_buff_1B_mux (
        .sel (buff_1B_mux_sel),
        .a   (image_wraddress_from_ov7670_capture),
        .b   (image_rdaddress_from_iigen),
        .q   (address_buff_1B)
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
        .done_draw       (faceBox_done_s)
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

