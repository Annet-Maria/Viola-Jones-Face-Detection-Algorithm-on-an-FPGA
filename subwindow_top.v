module subwindow_top (
    input              reset,
    input              clk_sys,
    input              start,
    input              mem_state,

    input  [5:0]        x_pos_subwin0,
    input  [5:0]        y_pos_subwin0,

    input  [639:0]      ii_rddata,       // 16*20*2
    input  [895:0]      iix2_rddata,     // 16*28*2

    output [8:0]        ii_rdaddress,
    output [8:0]        iix2_rdaddress,

    output [15:0]       fail_out,
    output             done
);

    //==========================================================
    // CONSTANTS
    //==========================================================

    localparam [5:0] II_WIDTH  = 6'd39;
    localparam [5:0] II_HEIGHT = 6'd59;

    //==========================================================
    // CLOCKS
    //==========================================================

    wire clk;
    wire clk_memRead;

    assign clk        = clk_sys;
    assign clk_memRead = clk_sys;

    //==========================================================
    // COUNTERS
    //==========================================================

    wire [4:0]  strongStage_count;
    wire [11:0] weakNode_count;
    wire [7:0]  weak_count;

    wire [7:0]  weak_stage_num;

    reg ii_reg_index_count_en;
    reg ii_reg_index_count_reset;

    reg iix2_reg_index_count_en;
    reg iix2_reg_index_count_reset;

    reg weakNode_count_en;
    reg weakNode_count_reset;

    reg weak_count_en;
    reg weak_count_reset;

    reg strongStage_count_en;
    reg strongStage_count_reset;

    wire [3:0] ii_reg_index;
    wire [1:0] iix2_reg_index;


    counter #(
        .COUNT_WIDTH(4)
    ) ii_reg_index_counter (
        .clk   (clk),
        .reset (ii_reg_index_count_reset),
        .en    (ii_reg_index_count_en),
        .count (ii_reg_index)
    );


    counter #(
        .COUNT_WIDTH(2)
    ) iix2_reg_index_counter (
        .clk   (clk),
        .reset (iix2_reg_index_count_reset),
        .en    (iix2_reg_index_count_en),
        .count (iix2_reg_index)
    );


    counter #(
        .COUNT_WIDTH(12)
    ) weakNode_counter (
        .clk   (clk),
        .reset (weakNode_count_reset),
        .en    (weakNode_count_en),
        .count (weakNode_count)
    );


    counter #(
        .COUNT_WIDTH(8)
    ) weak_counter (
        .clk   (clk),
        .reset (weak_count_reset),
        .en    (weak_count_en),
        .count (weak_count)
    );


    counter #(
        .COUNT_WIDTH(5)
    ) strongStage_counter (
        .clk   (clk),
        .reset (strongStage_count_reset),
        .en    (strongStage_count_en),
        .count (strongStage_count)
    );


    //==========================================================
    // ROM DATA
    //==========================================================

    wire [11:0] strong_thresh;

    wire [13:0] left_tree;
    wire [13:0] right_tree;
    wire [12:0] weak_thresh;

    wire [14:0] weight_rect0;
    wire [14:0] weight_rect1;
    wire [14:0] weight_rect2;

    wire [4:0] x_rect0;
    wire [4:0] x_rect1;
    wire [4:0] x_rect2;

    wire [4:0] y_rect0;
    wire [4:0] y_rect1;
    wire [4:0] y_rect2;

    wire [4:0] w_rect0;
    wire [4:0] w_rect1;
    wire [4:0] w_rect2;

    wire [4:0] h_rect0;
    wire [4:0] h_rect1;
    wire [4:0] h_rect2;


    //==========================================================
    // STRONG THRESHOLD ROM
    //==========================================================

    ram #(
        .ADDR_WIDTH(5),
        .DATA_WIDTH(12),
        .MAX_PRELOAD_ADDRESS(24),
        .MEM_FILE_NAME("strongThresh.txt"),
        .MIF_FILE_NAME("strongThresh.mif")
    ) strongThresh_rom (
        .data      (12'b0),
        .rdaddress(strongStage_count),
        .rdclock  (clk_memRead),
        .wraddress(5'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (strong_thresh)
    );


    //==========================================================
    // WEAK STAGE NUMBER ROM
    //==========================================================

    ram #(
        .ADDR_WIDTH(5),
        .DATA_WIDTH(8),
        .MAX_PRELOAD_ADDRESS(24),
        .MEM_FILE_NAME("weakStageNum.txt"),
        .MIF_FILE_NAME("weakStageNum.mif")
    ) weakStageNum_rom (
        .data      (8'b0),
        .rdaddress(strongStage_count),
        .rdclock  (clk_memRead),
        .wraddress(5'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (weak_stage_num)
    );


    //==========================================================
    // WEAK NODE ROMs
    //==========================================================

    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(15),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("weight0.txt"),
        .MIF_FILE_NAME("weight0.mif")
    ) weight0_rom (
        .data      (15'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (weight_rect0)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(15),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("weight1.txt"),
        .MIF_FILE_NAME("weight1.mif")
    ) weight1_rom (
        .data      (15'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (weight_rect1)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(15),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("weight2.txt"),
        .MIF_FILE_NAME("weight2.mif")
    ) weight2_rom (
        .data      (15'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (weight_rect2)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("x_rect0.txt"),
        .MIF_FILE_NAME("x_rect0.mif")
    ) x_rect0_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (x_rect0)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("x_rect1.txt"),
        .MIF_FILE_NAME("x_rect1.mif")
    ) x_rect1_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (x_rect1)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("x_rect2.txt"),
        .MIF_FILE_NAME("x_rect2.mif")
    ) x_rect2_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (x_rect2)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("y_rect0.txt"),
        .MIF_FILE_NAME("y_rect0.mif")
    ) y_rect0_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (y_rect0)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("y_rect1.txt"),
        .MIF_FILE_NAME("y_rect1.mif")
    ) y_rect1_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (y_rect1)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("y_rect2.txt"),
        .MIF_FILE_NAME("y_rect2.mif")
    ) y_rect2_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (y_rect2)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("w_rect0.txt"),
        .MIF_FILE_NAME("w_rect0.mif")
    ) w_rect0_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (w_rect0)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("w_rect1.txt"),
        .MIF_FILE_NAME("w_rect1.mif")
    ) w_rect1_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (w_rect1)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("w_rect2.txt"),
        .MIF_FILE_NAME("w_rect2.mif")
    ) w_rect2_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (w_rect2)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("h_rect0.txt"),
        .MIF_FILE_NAME("h_rect0.mif")
    ) h_rect0_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (h_rect0)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("h_rect1.txt"),
        .MIF_FILE_NAME("h_rect1.mif")
    ) h_rect1_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (h_rect1)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(5),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("h_rect2.txt"),
        .MIF_FILE_NAME("h_rect2.mif")
    ) h_rect2_rom (
        .data      (5'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (h_rect2)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(14),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("left_tree.txt"),
        .MIF_FILE_NAME("left_tree.mif")
    ) left_tree_rom (
        .data      (14'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (left_tree)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(14),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("right_tree.txt"),
        .MIF_FILE_NAME("right_tree.mif")
    ) right_tree_rom (
        .data      (14'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (right_tree)
    );


    ram #(
        .ADDR_WIDTH(12),
        .DATA_WIDTH(13),
        .MAX_PRELOAD_ADDRESS(2912),
        .MEM_FILE_NAME("weakThresh.txt"),
        .MIF_FILE_NAME("weakThresh.mif")
    ) weakThresh_rom (
        .data      (13'b0),
        .rdaddress(weakNode_count),
        .rdclock  (clk_memRead),
        .wraddress(12'b0),
        .wrclock  (clk),
        .we       (1'b0),
        .re       (1'b1),
        .q        (weak_thresh)
    );


    //==========================================================
    // ADDRESS GENERATION
    //==========================================================

    wire [12:0] p_offset0;
    wire [12:0] ii_address0;
    wire [12:0] iix2_address0;
    wire [12:0] ii_address_mux0;

    pixel_offset pixel_offset0 (
        .mem_state    (mem_state),
        .x_pos_subwin (x_pos_subwin0),
        .y_pos_subwin (y_pos_subwin0),
        .width_ii     (II_WIDTH),
        .p_offset     (p_offset0)
    );


    ii_address_decoder ii_address_decoder0 (
        .ii_reg_index (ii_reg_index),
        .width_ii     (II_WIDTH),
        .p_offset     (p_offset0),

        .x_rect0      (x_rect0),
        .x_rect1      (x_rect1),
        .x_rect2      (x_rect2),

        .y_rect0      (y_rect0),
        .y_rect1      (y_rect1),
        .y_rect2      (y_rect2),

        .w_rect0      (w_rect0),
        .w_rect1      (w_rect1),
        .w_rect2      (w_rect2),

        .h_rect0      (h_rect0),
        .h_rect1      (h_rect1),
        .h_rect2      (h_rect2),

        .ii_address   (ii_address0)
    );


    iix2_address_decoder iix2_address_decoder0 (
        .iix2_reg_index(iix2_reg_index),
        .width_ii     (II_WIDTH),
        .p_offset     (p_offset0),
        .iix2_address (iix2_address0)
    );


    //==========================================================
    // II ADDRESS MUX
    //==========================================================

    reg ii_rdaddress_mux_sel;

    assign ii_address_mux0 =
            ii_rdaddress_mux_sel ? iix2_address0 : ii_address0;


    assign ii_rdaddress   = ii_address_mux0[12:4];
    assign iix2_rdaddress = iix2_address0[12:4];


    //==========================================================
    // DATA MUX
    //==========================================================

    wire [319:0] ii_data_a;
    wire [319:0] ii_data_b;

    wire [447:0] iix2_data_a;
    wire [447:0] iix2_data_b;

    assign ii_data_a   = ii_rddata[319:0];
    assign ii_data_b   = ii_rddata[639:320];

    assign iix2_data_a = iix2_rddata[447:0];
    assign iix2_data_b = iix2_rddata[895:448];


    wire [19:0] ii_data [0:15];
    wire [27:0] iix2_data [0:15];


    parallel_dataPath_mux #(
        .DATA_WIDTH_OUT(20)
    ) ii_data_mux (
        .sel(ii_address_mux0[3:0]),
        .a(ii_data_a),
        .b(ii_data_b),

        .q0(ii_data[0]),
        .q1(ii_data[1]),
        .q2(ii_data[2]),
        .q3(ii_data[3]),
        .q4(ii_data[4]),
        .q5(ii_data[5]),
        .q6(ii_data[6]),
        .q7(ii_data[7]),
        .q8(ii_data[8]),
        .q9(ii_data[9]),
        .q10(ii_data[10]),
        .q11(ii_data[11]),
        .q12(ii_data[12]),
        .q13(ii_data[13]),
        .q14(ii_data[14]),
        .q15(ii_data[15])
    );


    parallel_dataPath_mux #(
        .DATA_WIDTH_OUT(28)
    ) iix2_data_mux (
        .sel(iix2_address0[3:0]),
        .a(iix2_data_a),
        .b(iix2_data_b),

        .q0(iix2_data[0]),
        .q1(iix2_data[1]),
        .q2(iix2_data[2]),
        .q3(iix2_data[3]),
        .q4(iix2_data[4]),
        .q5(iix2_data[5]),
        .q6(iix2_data[6]),
        .q7(iix2_data[7]),
        .q8(iix2_data[8]),
        .q9(iix2_data[9]),
        .q10(iix2_data[10]),
        .q11(iix2_data[11]),
        .q12(iix2_data[12]),
        .q13(iix2_data[13]),
        .q14(iix2_data[14]),
        .q15(iix2_data[15])
    );


    //==========================================================
    // CONTROL SIGNALS
    //==========================================================

    reg en_var_norm0;
    reg subwindow_reset;
    reg en_strongAccum0;

    reg ii_reg_we0;
    reg iix2_reg_we0;

    reg iix2_regLoad_DONE;
    reg iix2_regLoad_DONE_latch;
    reg iix2_regLoad_DONE_reset;

    reg fail_reg_latch;
    reg fail_reg_reset;

    reg cascade_done;


    //==========================================================
    // FAILURE REGISTER
    //==========================================================

    reg [15:0] fail_reg;
    wire [15:0] face_detected_s;

    always @(posedge clk or posedge fail_reg_reset) begin
        if (fail_reg_reset)
            fail_reg <= 16'b0;
        else if (fail_reg_latch)
            fail_reg <= fail_reg | (~face_detected_s);
    end

    assign fail_out = fail_reg;


    //==========================================================
    // IIX2 LOAD DONE REGISTER
    //==========================================================

    always @(posedge clk or posedge iix2_regLoad_DONE_reset) begin
        if (iix2_regLoad_DONE_reset)
            iix2_regLoad_DONE <= 1'b0;
        else if (iix2_regLoad_DONE_latch)
            iix2_regLoad_DONE <= 1'b1;
    end


    //==========================================================
    // FSM
    //==========================================================

    localparam [3:0]
        S_RESET             = 4'd0,
        S_LATCH_ROM        = 4'd1,
        S_LATCH_RAM_ADDR   = 4'd2,
        S_LATCH_IIX2_REG   = 4'd3,
        S_LATCH_II_REG     = 4'd4,
        S_LATCH_STRONG_ACC = 4'd5,
        S_STRONG_COMPARE   = 4'd6,
        S_FLAG_DONE        = 4'd7,
        S_DONE             = 4'd8;

    reg [3:0] current_state;
    reg [3:0] next_state;


    //==========================================================
    // FSM STATE REGISTER
    //==========================================================

    always @(posedge clk or posedge reset) begin
        if (reset)
            current_state <= S_RESET;
        else
            current_state <= next_state;
    end


    //==========================================================
    // FSM COMBINATIONAL LOGIC
    //==========================================================

    always @(*) begin

        // Default values
        en_var_norm0                = 1'b0;
        subwindow_reset             = 1'b0;
        en_strongAccum0             = 1'b0;

        ii_reg_we0                  = 1'b0;
        ii_reg_index_count_en       = 1'b0;
        ii_reg_index_count_reset    = 1'b0;

        iix2_reg_we0                = 1'b0;
        iix2_reg_index_count_en     = 1'b0;
        iix2_reg_index_count_reset  = 1'b0;

        weakNode_count_en           = 1'b0;
        weakNode_count_reset        = 1'b0;

        weak_count_en               = 1'b0;
        weak_count_reset            = 1'b0;

        strongStage_count_en        = 1'b0;
        strongStage_count_reset     = 1'b0;

        ii_rdaddress_mux_sel        = 1'b0;

        cascade_done                = 1'b0;

        fail_reg_latch              = 1'b0;
        fail_reg_reset              = 1'b0;

        iix2_regLoad_DONE_latch     = 1'b0;
        iix2_regLoad_DONE_reset     = 1'b0;

        next_state                  = S_RESET;


        case (current_state)

            //==================================================
            // RESET
            //==================================================

            S_RESET: begin

                subwindow_reset            = 1'b1;

                ii_reg_index_count_reset   = 1'b1;
                iix2_reg_index_count_reset = 1'b1;

                weakNode_count_reset       = 1'b1;
                weak_count_reset            = 1'b1;
                strongStage_count_reset     = 1'b1;

                fail_reg_reset              = 1'b1;
                iix2_regLoad_DONE_reset     = 1'b1;

                if (start)
                    next_state = S_LATCH_ROM;
                else
                    next_state = S_RESET;

            end


            //==================================================
            // LOAD ROM PARAMETERS
            //==================================================

            S_LATCH_ROM: begin
                next_state = S_LATCH_RAM_ADDR;
            end


            //==================================================
            // SETUP RAM ADDRESS
            //==================================================

            S_LATCH_RAM_ADDR: begin

                if (!iix2_regLoad_DONE) begin
                    ii_rdaddress_mux_sel = 1'b1;
                    next_state = S_LATCH_IIX2_REG;
                end
                else begin
                    next_state = S_LATCH_II_REG;
                end

            end


            //==================================================
            // LOAD IIX2 / CORNER REGISTERS
            //==================================================

            S_LATCH_IIX2_REG: begin

                ii_rdaddress_mux_sel = 1'b1;
                iix2_reg_we0 = 1'b1;

                if (iix2_reg_index == 2'd3) begin

                    en_var_norm0            = 1'b1;
                    iix2_regLoad_DONE_latch = 1'b1;

                    next_state = S_LATCH_RAM_ADDR;

                end
                else begin

                    iix2_reg_index_count_en = 1'b1;

                    next_state = S_LATCH_RAM_ADDR;

                end

            end


            //==================================================
            // LOAD II RECTANGLE REGISTERS
            //==================================================

            S_LATCH_II_REG: begin

                en_var_norm0 = 1'b1;
                ii_reg_we0   = 1'b1;

                if (ii_reg_index == 4'd11) begin

                    next_state = S_LATCH_STRONG_ACC;

                end
                else begin

                    ii_reg_index_count_en = 1'b1;

                    next_state = S_LATCH_RAM_ADDR;

                end

            end


            //==================================================
            // LATCH STRONG ACCUMULATOR
            //==================================================

            S_LATCH_STRONG_ACC: begin

                en_strongAccum0          = 1'b1;
                ii_reg_index_count_reset = 1'b1;

                if (weak_count <
                    (weak_stage_num - 12'd1)) begin

                    weakNode_count_en = 1'b1;
                    weak_count_en     = 1'b1;

                    next_state = S_LATCH_ROM;

                end
                else begin

                    next_state = S_STRONG_COMPARE;

                end

            end


            //==================================================
            // STRONG STAGE COMPARISON
            //==================================================

            S_STRONG_COMPARE: begin

                if (weakNode_count < 12'd2911) begin

                    weakNode_count_en = 1'b1;

                    subwindow_reset = 1'b1;

                    fail_reg_latch = 1'b1;

                    weak_count_reset = 1'b1;

                    strongStage_count_en = 1'b1;

                    next_state = S_LATCH_ROM;

                end
                else begin

                    fail_reg_latch = 1'b1;

                    next_state = S_FLAG_DONE;

                end

            end


            //==================================================
            // DONE FLAG
            //==================================================

            S_FLAG_DONE: begin

                cascade_done = 1'b1;

                next_state = S_DONE;

            end


            //==================================================
            // WAIT FOR RESET
            //==================================================

            S_DONE: begin

                next_state = S_DONE;

            end


            default: begin
                next_state = S_RESET;
            end

        endcase

    end


    //==========================================================
    // 16 PARALLEL SUBWINDOWS
    //==========================================================

    genvar i;

    generate
        for (i = 0; i < 16; i = i + 1) begin : SUBWINDOWS

            subwindow subwindow_inst (
                .reset          (subwindow_reset),
                .clk            (clk),

                .en_strongAccum (en_strongAccum0),
                .en_var_norm    (en_var_norm0),

                .left_tree      (left_tree),
                .right_tree     (right_tree),

                .weak_thresh    (weak_thresh),
                .strong_thresh  (strong_thresh),

                .w0             (weight_rect0),
                .w1             (weight_rect1),
                .w2             (weight_rect2),

                .ii_reg_we      (ii_reg_we0),
                .ii_reg_address (ii_reg_index),
                .ii_data        (ii_data[i]),

                .iix2_reg_we    (iix2_reg_we0),
                .iix2_reg_index (iix2_reg_index),
                .iix2_data      (iix2_data[i]),

                .detection      (face_detected_s[i])
            );

        end
    endgenerate


    //==========================================================
    // DONE OUTPUT
    //==========================================================

    assign done = cascade_done;

endmodule

