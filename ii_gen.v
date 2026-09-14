// The integral image generator converts portions of the original color image to greyscale and then to integral image (ii) and integral image squared (iix2) format 
//   which is then stored in respective integral image buffers in the top level.
// The ii and iix2 buffers share both ii_wraddress and ii_rdaddress since ii and iix2 calculations executed in tandem.
// Each buffer is divided in to upper and lower memeory partitions, so mem_state specifies which partition the ii_gen process operates on.

module ii_gen (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,           // start ii_gen processes, single clock cycle pulse starts process
    input  wire [3:0]  image_scale,
    input  wire [11:0] image_data_i,    // 12 bit color (RGB444) from image_buffer read data (q) output
    input  wire [19:0] ii_data_i,
    input  wire [27:0] iix2_data_i,
    input  wire        mem_state,
    input  wire [8:0]  scaleImg_x_base,
    input  wire [7:0]  scaleImg_y_base,
    output wire [16:0] image_rdaddress,
    output reg  [12:0] ii_address,      // address for ii and iix2 buffers
    output wire        ii_wren,         // wren for ii and iix2 buffers
    output wire [19:0] ii_data_o,
    output wire [27:0] iix2_data_o,
    output wire        done             // asserted logic high once ii_gen process is complete, de-asserted when whole module is reset
);

    // CONSTANTS
    localparam [5:0] II_WIDTH  = 6'd39;
    localparam [5:0] II_HEIGHT = 6'd59;

    // SIGNALS
    wire [7:0]  grey_data;
    wire [15:0] grey_data_square;       // 8bit * 8bit results in 16 bit unsigned

    wire [15:0] temp0;
    wire [15:0] temp1;
    wire [16:0] temp3;
    wire [16:0] scaleImg_address_base;
    wire [16:0] image_address_base;
    wire [20:0] temp_image_address_base;

    reg  [5:0]  x;                      // 39dec max
    reg         x_count_reset;
    reg         x_count_en;

    reg  [5:0]  y;                      // 59dec max
    reg         y_count_reset;
    reg         y_count_en;

    reg         ii_address_sel;
    reg  [12:0] ii_wraddress;
    wire [12:0] ii_rdaddress;
    reg  [16:0] image_rdaddress_s;
    reg         address_accum_reset;
    reg         buffer_we;

    reg         accum_reset;
    reg         accum_en;
    reg  [13:0] ii_data_accum;          // accumulator register out
    reg  [21:0] iix2_data_accum;        // accumulator register out
    wire [13:0] add2;
    wire [21:0] add3;
    wire [19:0] add2_extend;
    wire [27:0] add3_extend;
    wire [19:0] add4;
    wire [27:0] add5;

    reg  [19:0] ii_data_o_s;            // unsigned
    reg  [27:0] iix2_data_o_s;          // unsigned

    reg         done_s;

    // STATE MACHINE ENUMERATION
    localparam [2:0] s_RESET            = 3'd0,
                     s_latch_RAM_read   = 3'd1,
                     s_latch_RAM_write  = 3'd2,
                     s_soft_reset       = 3'd3,
                     s_DONE             = 3'd4;

    reg [2:0] state, next_state;

    // EXTRA VALUE TO INC IMAGE RDADDRESS -- max_img_width*scale-(ii_width-1)*scale
    reg [11:0] lut0_q;

    // PIPELINE CONTROL
    reg pipeline_reset;
    reg pipeline_advance;

    // PIPELINE REGISTERS
    // R0
    reg [5:0]  reg0_x;
    reg [5:0]  reg0_y;
    reg [12:0] reg0_ii_wraddress;
    reg [11:0] reg0_image_data;
    reg [19:0] reg0_ii_data;
    reg [27:0] reg0_iix2_data;
    reg        reg0_accum_reset;
    reg        reg0_accum_en;
    reg        reg0_done;
    // R1
    reg [5:0]  reg1_x;
    reg [5:0]  reg1_y;
    reg [12:0] reg1_ii_wraddress;
    reg [7:0]  reg1_grey_data;
    reg [19:0] reg1_ii_data;
    reg [27:0] reg1_iix2_data;
    reg        reg1_accum_reset;
    reg        reg1_accum_en;
    reg        reg1_done;
    // R2
    reg [5:0]  reg2_x;
    reg [5:0]  reg2_y;
    reg [12:0] reg2_ii_wraddress;
    reg [7:0]  reg2_grey_data;
    reg [15:0] reg2_grey_data_square;
    reg [19:0] reg2_ii_data;
    reg [27:0] reg2_iix2_data;
    reg        reg2_accum_reset;
    reg        reg2_accum_en;
    reg        reg2_done;
    // R3
    reg [5:0]  reg3_x;
    reg [5:0]  reg3_y;
    reg [12:0] reg3_ii_wraddress;
    reg [19:0] reg3_add2_extend;
    reg [27:0] reg3_add3_extend;
    reg [19:0] reg3_add4;
    reg [27:0] reg3_add5;
    reg        reg3_done;

    reg reset_done_reg;
    reg done_reg;

    // x counter; relative to integral image dimensions
    always @(posedge clk or posedge x_count_reset) begin
        if (x_count_reset) begin
            x <= 6'b0;
        end else if (x_count_en) begin
            x <= x + 6'd1;
        end
    end

    // y counter; relative to integral image dimensions
    always @(posedge clk or posedge y_count_reset) begin
        if (y_count_reset) begin
            y <= 6'b0;
        end else if (y_count_en) begin
            y <= y + 6'd1;
        end
    end

    // convert 12bit color (RGB444) to 8bit greyscale data
    RGB2GREY RGB2GREY_inst (
        .Din  (reg0_image_data),
        .Dout (grey_data)
    );

    assign grey_data_square = reg1_grey_data * reg1_grey_data; // 8bit * 8bit ... 16 bit unsigned

    // calculate base address location of integral image relative to scaled image
    assign temp0                   = {scaleImg_y_base, 8'b00000000};
    assign temp1                   = {2'b00, scaleImg_y_base, 6'b000000};
    assign temp3                   = {1'b0, temp0} + {1'b0, temp1};
    assign scaleImg_address_base   = temp3 + {8'b0, scaleImg_x_base};

    // calculate base address location of integral image relative to original image
    assign temp_image_address_base = scaleImg_address_base * image_scale;
    assign image_address_base      = temp_image_address_base[16:0];

    // LUT for image_rdaddress vertical increment
    always @(*) begin
        case (image_scale)
            4'd1:    lut0_q = 12'd282; // 320*1 - (39-1)*1
            4'd2:    lut0_q = 12'd564; // 320*2 - (39-1)*2
            4'd3:    lut0_q = 12'd846; // 320*3 - (39-1)*3
            4'd4:    lut0_q = 12'd1128;
            4'd5:    lut0_q = 12'd1410;
            4'd6:    lut0_q = 12'd1692;
            4'd7:    lut0_q = 12'd1974;
            4'd8:    lut0_q = 12'd2256;
            default: lut0_q = 12'd0;
        endcase
    end

    // image_rdaddress accumulator
    always @(posedge clk) begin
        if (address_accum_reset) begin
            image_rdaddress_s <= image_address_base;
        end else if (x_count_en) begin
            image_rdaddress_s <= image_rdaddress_s + image_scale;
        end else if (y_count_en) begin
            image_rdaddress_s <= image_rdaddress_s + lut0_q;
        end
    end
    assign image_rdaddress = image_rdaddress_s;

    // ii_wraddress accumulator
    always @(posedge clk) begin
        if (address_accum_reset) begin
            if (mem_state == 1'b0) begin
                ii_wraddress <= 13'd0;
            end else begin
                ii_wraddress <= 13'd4096;
            end
        end else if (x_count_en || y_count_en) begin
            ii_wraddress <= ii_wraddress + 13'd1;
        end
    end

    // ii_rdaddress calculation
    assign ii_rdaddress = ii_wraddress - II_WIDTH;

    // address mux
    always @(*) begin
        if (ii_address_sel == 1'b0) begin
            ii_address = ii_rdaddress;
        end else begin
            ii_address = reg3_ii_wraddress;
        end
    end

    // accumulator data path
    assign add2        = reg2_grey_data + ii_data_accum;
    assign add3        = reg2_grey_data_square + iix2_data_accum;
    assign add2_extend = {6'b0, add2};
    assign add3_extend = {6'b0, add3};

    // accumulate ii and iix2 values for a single row at a time
    always @(posedge clk) begin
        if (reg2_accum_reset && pipeline_advance) begin
            ii_data_accum   <= 14'b0;
            iix2_data_accum <= 22'b0;
        end else if (reg2_accum_en && pipeline_advance) begin
            ii_data_accum   <= add2;
            iix2_data_accum <= add3;
        end
    end

    assign add4 = reg2_ii_data + add2;
    assign add5 = reg2_iix2_data + add3;

    // data output mux
    always @(*) begin
        if (reg3_y == 6'b000000) begin
            ii_data_o_s   = reg3_add2_extend;
            iix2_data_o_s = reg3_add3_extend;
        end else begin
            ii_data_o_s   = reg3_add4;
            iix2_data_o_s = reg3_add5;
        end
    end

    // pipeline register updates
    always @(posedge clk or posedge pipeline_reset) begin
        if (pipeline_reset) begin
            reg0_x                <= 6'b0;
            reg0_y                <= 6'b0;
            reg0_ii_wraddress    <= 13'b0;
            reg0_image_data       <= 12'b0;
            reg0_ii_data          <= 20'b0;
            reg0_iix2_data        <= 28'b0;
            reg0_accum_reset      <= 1'b1;
            reg0_accum_en         <= 1'b0;
            reg0_done             <= 1'b0;

            reg1_x                <= 6'b0;
            reg1_y                <= 6'b0;
            reg1_ii_wraddress    <= 13'b0;
            reg1_grey_data        <= 8'b0;
            reg1_ii_data          <= 20'b0;
            reg1_iix2_data        <= 28'b0;
            reg1_accum_reset      <= 1'b1;
            reg1_accum_en         <= 1'b0;
            reg1_done             <= 1'b0;

            reg2_x                <= 6'b0;
            reg2_y                <= 6'b0;
            reg2_ii_wraddress    <= 13'b0;
            reg2_grey_data        <= 8'b0;
            reg2_grey_data_square <= 16'b0;
            reg2_ii_data          <= 20'b0;
            reg2_iix2_data        <= 28'b0;
            reg2_accum_reset      <= 1'b1;
            reg2_accum_en         <= 1'b0;
            reg2_done             <= 1'b0;

            reg3_x                <= 6'b0;
            reg3_y                <= 6'b0;
            reg3_ii_wraddress    <= 13'b0;
            reg3_add2_extend      <= 20'b0;
            reg3_add3_extend      <= 28'b0;
            reg3_add4             <= 20'b0;
            reg3_add5             <= 28'b0;
            reg3_done             <= 1'b0;
        end else if (pipeline_advance) begin
            reg0_x                <= x;
            reg0_y                <= y;
            reg0_ii_wraddress    <= ii_wraddress;
            reg0_image_data       <= image_data_i;
            reg0_ii_data          <= ii_data_i;
            reg0_iix2_data        <= iix2_data_i;
            reg0_accum_reset      <= accum_reset;
            reg0_accum_en         <= accum_en;
            reg0_done             <= done_s;

            reg1_x                <= reg0_x;
            reg1_y                <= reg0_y;
            reg1_ii_wraddress    <= reg0_ii_wraddress;
            reg1_grey_data        <= grey_data;
            reg1_ii_data          <= reg0_ii_data;
            reg1_iix2_data        <= reg0_iix2_data;
            reg1_accum_reset      <= reg0_accum_reset;
            reg1_accum_en         <= reg0_accum_en;
            reg1_done             <= reg0_done;

            reg2_x                <= reg1_x;
            reg2_y                <= reg1_y;
            reg2_ii_wraddress    <= reg1_ii_wraddress;
            reg2_grey_data        <= reg1_grey_data;
            reg2_grey_data_square <= grey_data_square;
            reg2_ii_data          <= reg1_ii_data;
            reg2_iix2_data        <= reg1_iix2_data;
            reg2_accum_reset      <= reg1_accum_reset;
            reg2_accum_en         <= reg1_accum_en;
            reg2_done             <= reg1_done;

            reg3_x                <= reg2_x;
            reg3_y                <= reg2_y;
            reg3_ii_wraddress    <= reg2_ii_wraddress;
            reg3_add2_extend      <= add2_extend;
            reg3_add3_extend      <= add3_extend;
            reg3_add4             <= add4;
            reg3_add5             <= add5;
            reg3_done             <= reg2_done;
        end
    end

    // state machine flip-flop
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= s_RESET;
        end else begin
            state <= next_state;
        end
    end

    // state machine combinational logic
    always @(*) begin
        accum_reset          = 1'b0;
        buffer_we            = 1'b0;
        accum_en             = 1'b0;
        x_count_reset        = 1'b0;
        x_count_en           = 1'b0;
        y_count_reset        = 1'b0;
        y_count_en           = 1'b0;
        done_s               = 1'b0;
        ii_address_sel       = 1'b0;
        address_accum_reset  = 1'b0;
        pipeline_advance     = 1'b0;
        pipeline_reset       = 1'b0;
        reset_done_reg       = 1'b0;
        next_state           = state;

        case (state)
            s_RESET: begin
                accum_reset          = 1'b1;
                address_accum_reset  = 1'b1;
                x_count_reset        = 1'b1;
                y_count_reset        = 1'b1;
                pipeline_reset       = 1'b1;
                reset_done_reg       = 1'b1;
                if (start) begin
                    next_state = s_latch_RAM_read;
                end else begin
                    next_state = s_RESET;
                end
            end

            s_latch_RAM_read: begin
                ii_address_sel = 1'b0;
                next_state     = s_latch_RAM_write;
            end

            s_latch_RAM_write: begin
                pipeline_advance = 1'b1;
                buffer_we        = 1'b1;
                ii_address_sel   = 1'b1;

                if (x == (II_WIDTH - 6'd1)) begin
                    accum_reset = 1'b1;
                    if (y == (II_HEIGHT - 6'd1)) begin
                        done_s     = 1'b1;
                        next_state = s_DONE;
                    end else begin
                        y_count_en = 1'b1;
                        next_state = s_soft_reset;
                    end
                end else begin
                    accum_en   = 1'b1;
                    x_count_en = 1'b1;
                    next_state = s_latch_RAM_read;
                end
            end

            s_soft_reset: begin
                x_count_reset = 1'b1;
                next_state    = s_latch_RAM_read;
            end

            s_DONE: begin
                if (!done_reg) begin
                    ii_address_sel   = 1'b1;
                    pipeline_advance = 1'b1;
                    buffer_we        = 1'b1;
                end
                next_state = s_DONE;
            end

            default: next_state = s_RESET;
        endcase
    end

    // done register
    always @(posedge clk or posedge reset_done_reg) begin
        if (reset_done_reg) begin
            done_reg <= 1'b0;
        end else if (reg3_done) begin
            done_reg <= 1'b1;
        end
    end

    // Output assignments
    assign ii_wren     = buffer_we;
    assign ii_data_o   = ii_data_o_s;
    assign iix2_data_o = iix2_data_o_s;
    assign done        = done_reg;

endmodule