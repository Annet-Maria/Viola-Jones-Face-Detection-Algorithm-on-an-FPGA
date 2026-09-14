module subwindow (
    input  wire        reset,            // Reset asserted logic '1' - resets the accumulator
    input  wire        clk,              // Latch strong accumulator
    input  wire        en_strongAccum,   // Enable strong accumulator latch
    input  wire        en_var_norm,
    input  wire signed [13:0] left_tree,         // 14-bit signed
    input  wire signed [13:0] right_tree,        // 14-bit signed
    input  wire signed [12:0] weak_thresh,       // 13-bit signed
    input  wire signed [11:0] strong_thresh,     // 12-bit signed
    input  wire signed [14:0] w0,                // 15-bit signed
    input  wire signed [14:0] w1,                // 15-bit signed
    input  wire signed [14:0] w2,                // 15-bit signed
    input  wire        ii_reg_we,
    input  wire [3:0]  ii_reg_address,
    input  wire [19:0] ii_data,
    input  wire        iix2_reg_we,
    input  wire [1:0]  iix2_reg_index,
    input  wire [27:0] iix2_data,
    output wire        detection         // Assert '1' for detection
);

    // Internal Wires & Registers

    // Register File Output Signals
    wire [19:0] r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11;
    wire [19:0] p0, p1, p2, p3;
    wire [27:0] ssp0, ssp1, ssp2, ssp3;

    // Intermediate Calculation Wires
    wire signed [38:0] result_feature;
    wire signed [21:0] var_norm_factor;
    reg  signed [21:0] var_norm_factor_reg = 22'sd0;
    wire signed [34:0] var_norm_weak_thresh;
    
    wire        tree_mux_sel;
    wire signed [13:0] tree_mux_result;
    reg  signed [21:0] strong_accumulator_result = 22'sd0;
    wire        stage_detection;

    wire signed [26:0] result_mult0;
    wire signed [15:0] result_mult1;

    // Component Instantiations

    // Integral Image Registers (12 registers, 20-bit width)
    register_file #(
        .ADDR_WIDTH(4),
        .DATA_WIDTH(20)
    ) ii_reg (
        .clk            (clk),
        .write_en        (ii_reg_we),
        .write_reg_addr (ii_reg_address),
        .write_data     (ii_data),
        .q0             (r0),  .q1 (r1),  .q2 (r2),  .q3 (r3),
        .q4             (r4),  .q5 (r5),  .q6 (r6),  .q7 (r7),
        .q8             (r8),  .q9 (r9),  .q10(r10), .q11(r11)
    );

    // Integral Image Corner Registers for Variance Normalization
    register_file2 #(
        .ADDR_WIDTH(2),
        .DATA_WIDTH(20)
    ) ii_corner_reg (
        .clk            (clk),
        .write_en        (iix2_reg_we),
        .write_reg_addr (iix2_reg_index),
        .write_data     (ii_data),
        .q0             (p0),  .q1(p1),   .q2(p2),   .q3(p3)
    );

    // Integral Image Squared Corner Registers
    register_file2 #(
        .ADDR_WIDTH(2),
        .DATA_WIDTH(28)
    ) iix2_corner_reg (
        .clk            (clk),
        .write_en        (iix2_reg_we),
        .write_reg_addr (iix2_reg_index),
        .write_data     (iix2_data),
        .q0             (ssp0), .q1(ssp1), .q2(ssp2), .q3(ssp3)
    );

    // Feature Calculator
    feature_calc feature_calc0 (
        .w0             (w0),             .w1 (w1),   .w2 (w2),
        .r0             (r0),             .r1 (r1),   .r2 (r2),   .r3 (r3),
        .r4             (r4),             .r5 (r5),   .r6 (r6),   .r7 (r7),
        .r8             (r8),             .r9 (r9),   .r10(r10),  .r11(r11),
        .result_feature (result_feature)
    );

    // Variance Normalization Calculator
    var_norm_calc var_norm_calc0 (
        .clk             (clk),
        .p0              (p0),   .p1  (p1),   .p2  (p2),   .p3  (p3),
        .ssp0            (ssp0), .ssp1(ssp1), .ssp2(ssp2), .ssp3(ssp3),
        .var_norm_factor (var_norm_factor)
    );

    // Sequential & Combinational Logic

    // Variance Normalization Factor Register
    always @(posedge clk) begin
        if (en_var_norm) begin
            var_norm_factor_reg <= var_norm_factor;
        end
    end

    // Scaled Weak Threshold (Signed Multiplication)
    assign var_norm_weak_thresh = weak_thresh * var_norm_factor_reg;

    // Weak Threshold Comparator
    assign tree_mux_sel = (result_feature > var_norm_weak_thresh) ? 1'b1 : 1'b0;

    // Weak Tree Multiplexer
    assign tree_mux_result = (tree_mux_sel) ? right_tree : left_tree;

    // Strong Accumulator Register
    always @(posedge clk) begin
        if (reset) begin
            strong_accumulator_result <= 22'sd0;
        end else if (en_strongAccum) begin
            strong_accumulator_result <= strong_accumulator_result + tree_mux_result;
        end
    end

    // Strong Threshold Scaling Multiplications
    assign result_mult0 = strong_accumulator_result * 5'sd6;
    assign result_mult1 = strong_thresh * 4'sd7;

    // Strong Threshold Comparator
    assign stage_detection = (result_mult0 > result_mult1) ? 1'b1 : 1'b0;

    // Output Assignment
    assign detection = stage_detection;

endmodule
