module faceBox (
    input wire reset,
    input wire clk_subwin,
    input wire clk_faceBox,
    input wire start_draw,
    input wire [3:0] scale,
    input wire [8:0] x_pos_subwin,
    input wire [7:0] y_pos_subwin,
    input wire subwin_done,
    input wire [15:0] subwin_detection,
    output wire [16:0] img_wraddress,
    output wire [11:0] img_wrdata,
    output wire img_wren,
    output wire done_draw
);

    /* =====================================================
       Internal signals
       ===================================================== */

    wire info_wren;
    wire [36:0] info_wrdata;
    wire [36:0] info_rddata;

    wire [9:0] count_box_in;
    wire count_box_in_en;
    wire count_box_in_reset;

    wire [13:0] count_box_out;

    /* These are driven by the FSM, so they MUST be reg */
    reg count_box_out_en;
    reg count_box_out_reset;

    wire [8:0] count_box_dim;

    /* These are driven by the FSM, so they MUST be reg */
    reg count_box_dim_en;
    reg count_box_dim_reset;

    reg [15:0] detection;
    reg [3:0] scale_s;
    reg [8:0] x_pos_subwin_s;
    reg [7:0] y_pos_subwin_s;

    reg [12:0] x_box;
    reg [11:0] y_box;
    reg [8:0] dim_box;

    reg [16:0] img_wraddress_s;
    reg img_wren_s;

    reg sel_inc_num;
    reg [8:0] inc_num;

    reg [20:0] box_base_address;

    reg img_wraddress_reset;
    reg wraddress_accum_en;

    wire box_detection;

    reg [20:0] mult_temp;
    reg [7:0] mult_temp2;
    reg [12:0] add_temp;

    /* =====================================================
       State machine
       ===================================================== */

    localparam s_RESET                = 4'd0;
    localparam s_setup_info_rdaddress = 4'd1;
    localparam s_buff_setup           = 4'd2;
    localparam s_TOP                  = 4'd3;
    localparam s_RIGHT                = 4'd4;
    localparam s_LEFT                 = 4'd5;
    localparam s_BOTTOM               = 4'd6;
    localparam s_check_box_out_count  = 4'd7;
    localparam s_DONE                 = 4'd8;

    reg [3:0] current_state;
    reg [3:0] next_state;

    /* =====================================================
       Input / buffer write controls
       ===================================================== */

    assign count_box_in_reset = reset;
    assign info_wren = subwin_done;
    assign count_box_in_en = subwin_done;

    /* =====================================================
       Data written into faceBox buffer
       ===================================================== */

    assign info_wrdata = {
        subwin_detection,
        scale,
        x_pos_subwin,
        y_pos_subwin
    };

    /* =====================================================
       Counter for number of boxes received
       ===================================================== */

    counter #(
        .COUNT_WIDTH(10)
    ) box_in_counter (
        .clk(clk_subwin),
        .reset(count_box_in_reset),
        .en(count_box_in_en),
        .count(count_box_in)
    );

    /* =====================================================
       Counter for number of boxes processed
       ===================================================== */

    counter #(
        .COUNT_WIDTH(14)
    ) box_out_counter (
        .clk(clk_faceBox),
        .reset(count_box_out_reset),
        .en(count_box_out_en),
        .count(count_box_out)
    );

    /* =====================================================
       Counter for box dimension
       ===================================================== */

    counter2 #(
        .COUNT_WIDTH(9)
    ) box_dim_counter (
        .clk(clk_faceBox),
        .reset(count_box_dim_reset),
        .en(count_box_dim_en),
        .count(count_box_dim)
    );

    /* =====================================================
       FaceBox RAM
       ===================================================== */

    faceBox_buff faceBox_ram (
        .data(info_wrdata),
        .rdaddress(count_box_out[13:4]),
        .rdclock(clk_faceBox),
        .wraddress(count_box_in),
        .wrclock(clk_subwin),
        .wren(info_wren),
        .q(info_rddata)
    );

    /* =====================================================
       Increment value multiplexer
       ===================================================== */

    always @(*) begin
        if (sel_inc_num == 1'b0)
            inc_num = 9'd1;
        else
            inc_num = 9'd320;
    end

    /* =====================================================
       Image write address accumulator
       ===================================================== */

    always @(posedge clk_faceBox) begin
        if (img_wraddress_reset)
            img_wraddress_s <= box_base_address[16:0];
        else if (wraddress_accum_en)
            img_wraddress_s <= img_wraddress_s + inc_num;
    end

    /* =====================================================
       Decode RAM output
       ===================================================== */

    always @(*) begin
        detection = info_rddata[36:21];
        scale_s = info_rddata[20:17];
        x_pos_subwin_s = info_rddata[16:8];
        y_pos_subwin_s = info_rddata[7:0];
    end

    /* =====================================================
       Current box detection result
       ===================================================== */

    assign box_detection = detection[count_box_out[3:0]];

    /* =====================================================
       Box dimension and address calculations
       ===================================================== */

    always @(*) begin

        /* dim_box = 23 * scale */
        dim_box = 9'd23 * scale_s;

        /* x_box = x_pos_subwin * scale */
        x_box = x_pos_subwin_s * scale_s;

        /* y_box = y_pos_subwin * scale */
        y_box = y_pos_subwin_s * scale_s;

        /* y position multiplied by image width 320 */
        mult_temp = y_box * 9'd320;

        /* subwindow x offset */
        mult_temp2 = count_box_out[3:0] * scale_s;

        /* x position + subwindow offset */
        add_temp = x_box + mult_temp2;

        /* final image buffer base address */
        box_base_address = mult_temp + add_temp;

    end

    /* =====================================================
       State machine flip-flop
       ===================================================== */

    always @(posedge clk_faceBox or posedge reset) begin
        if (reset)
            current_state <= s_RESET;
        else
            current_state <= next_state;
    end

    /* =====================================================
       State machine combinational logic
       ===================================================== */

    always @(*) begin

        /* Default values */

        img_wraddress_reset = 1'b0;
        sel_inc_num = 1'b0;
        img_wren_s = 1'b0;
        wraddress_accum_en = 1'b0;

        count_box_dim_reset = 1'b0;
        count_box_dim_en = 1'b0;

        count_box_out_reset = 1'b0;
        count_box_out_en = 1'b0;

        next_state = s_RESET;

        case (current_state)

            /* =============================================
               RESET STATE
               ============================================= */

            s_RESET: begin

                count_box_out_reset = 1'b1;

                if (start_draw) begin

                    if (count_box_in == 10'd0)
                        next_state = s_DONE;
                    else
                        next_state = s_setup_info_rdaddress;

                end
                else begin

                    next_state = s_RESET;

                end

            end

            /* =============================================
               SETUP READ ADDRESS
               ============================================= */

            s_setup_info_rdaddress: begin

                next_state = s_buff_setup;

            end

            /* =============================================
               BUFFER SETUP
               ============================================= */

            s_buff_setup: begin

                img_wraddress_reset = 1'b1;

                if (box_detection == 1'b0)
                    next_state = s_TOP;
                else
                    next_state = s_check_box_out_count;

            end

            /* =============================================
               DRAW TOP
               ============================================= */

            s_TOP: begin

                img_wren_s = 1'b1;
                sel_inc_num = 1'b0;

                if (count_box_dim < dim_box) begin

                    wraddress_accum_en = 1'b1;
                    count_box_dim_en = 1'b1;

                    next_state = s_TOP;

                end
                else begin

                    count_box_dim_reset = 1'b1;
                    next_state = s_RIGHT;

                end

            end

            /* =============================================
               DRAW RIGHT
               ============================================= */

            s_RIGHT: begin

                img_wren_s = 1'b1;
                sel_inc_num = 1'b1;

                if (count_box_dim < dim_box) begin

                    wraddress_accum_en = 1'b1;
                    count_box_dim_en = 1'b1;

                    next_state = s_RIGHT;

                end
                else begin

                    count_box_dim_reset = 1'b1;
                    img_wraddress_reset = 1'b1;

                    next_state = s_LEFT;

                end

            end

            /* =============================================
               DRAW LEFT
               ============================================= */

            s_LEFT: begin

                img_wren_s = 1'b1;
                sel_inc_num = 1'b1;

                if (count_box_dim < dim_box) begin

                    wraddress_accum_en = 1'b1;
                    count_box_dim_en = 1'b1;

                    next_state = s_LEFT;

                end
                else begin

                    count_box_dim_reset = 1'b1;
                    next_state = s_BOTTOM;

                end

            end

            /* =============================================
               DRAW BOTTOM
               ============================================= */

            s_BOTTOM: begin

                img_wren_s = 1'b1;
                sel_inc_num = 1'b0;

                if (count_box_dim < dim_box) begin

                    wraddress_accum_en = 1'b1;
                    count_box_dim_en = 1'b1;

                    next_state = s_BOTTOM;

                end
                else begin

                    count_box_dim_reset = 1'b1;
                    next_state = s_check_box_out_count;

                end

            end

            /* =============================================
               CHECK BOX COUNT
               ============================================= */

            s_check_box_out_count: begin

                if (count_box_out[13:4] ==
                    (count_box_in - 10'd1)) begin

                    next_state = s_DONE;

                end
                else begin

                    count_box_out_en = 1'b1;
                    count_box_dim_reset = 1'b1;

                    next_state = s_setup_info_rdaddress;

                end

            end

            /* =============================================
               DONE
               ============================================= */

            s_DONE: begin

                next_state = s_RESET;

            end

            /* =============================================
               DEFAULT
               ============================================= */

            default: begin

                next_state = s_RESET;

            end

        endcase

    end

    /* =====================================================
       Output assignments
       ===================================================== */

    assign img_wrdata = 12'b111100000000;

    assign img_wren = img_wren_s;

    assign img_wraddress = img_wraddress_s;

    assign done_draw = (current_state == s_DONE);

endmodule
