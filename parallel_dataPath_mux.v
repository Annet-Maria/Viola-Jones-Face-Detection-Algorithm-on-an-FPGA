// special mux/shifter for parallel data path control ... assumes that there are 16 downstream subwindow detectors

`timescale 1 ps / 1 ps

module parallel_dataPath_mux #(
    parameter DATA_WIDTH_OUT = 23
)(
    input  wire [3:0]                         sel,
    input  wire [(16*DATA_WIDTH_OUT)-1:0]     a,
    input  wire [(16*DATA_WIDTH_OUT)-1:0]     b,
    output wire [DATA_WIDTH_OUT-1:0]          q0,
    output wire [DATA_WIDTH_OUT-1:0]          q1,
    output wire [DATA_WIDTH_OUT-1:0]          q2,
    output wire [DATA_WIDTH_OUT-1:0]          q3,
    output wire [DATA_WIDTH_OUT-1:0]          q4,
    output wire [DATA_WIDTH_OUT-1:0]          q5,
    output wire [DATA_WIDTH_OUT-1:0]          q6,
    output wire [DATA_WIDTH_OUT-1:0]          q7,
    output wire [DATA_WIDTH_OUT-1:0]          q8,
    output wire [DATA_WIDTH_OUT-1:0]          q9,
    output wire [DATA_WIDTH_OUT-1:0]          q10,
    output wire [DATA_WIDTH_OUT-1:0]          q11,
    output wire [DATA_WIDTH_OUT-1:0]          q12,
    output wire [DATA_WIDTH_OUT-1:0]          q13,
    output wire [DATA_WIDTH_OUT-1:0]          q14,
    output wire [DATA_WIDTH_OUT-1:0]          q15
);

    reg [(16*DATA_WIDTH_OUT)-1:0] path;

    always @(*) begin
        case (sel)
            4'h0: path = a[(16*DATA_WIDTH_OUT)-1:0];
            4'h1: path = {b[(1*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 1*DATA_WIDTH_OUT]};
            4'h2: path = {b[(2*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 2*DATA_WIDTH_OUT]};
            4'h3: path = {b[(3*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 3*DATA_WIDTH_OUT]};
            4'h4: path = {b[(4*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 4*DATA_WIDTH_OUT]};
            4'h5: path = {b[(5*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 5*DATA_WIDTH_OUT]};
            4'h6: path = {b[(6*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 6*DATA_WIDTH_OUT]};
            4'h7: path = {b[(7*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 7*DATA_WIDTH_OUT]};
            4'h8: path = {b[(8*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 8*DATA_WIDTH_OUT]};
            4'h9: path = {b[(9*DATA_WIDTH_OUT)-1:0],  a[(16*DATA_WIDTH_OUT)-1 : 9*DATA_WIDTH_OUT]};
            4'hA: path = {b[(10*DATA_WIDTH_OUT)-1:0], a[(16*DATA_WIDTH_OUT)-1 : 10*DATA_WIDTH_OUT]};
            4'hB: path = {b[(11*DATA_WIDTH_OUT)-1:0], a[(16*DATA_WIDTH_OUT)-1 : 11*DATA_WIDTH_OUT]};
            4'hC: path = {b[(12*DATA_WIDTH_OUT)-1:0], a[(16*DATA_WIDTH_OUT)-1 : 12*DATA_WIDTH_OUT]};
            4'hD: path = {b[(13*DATA_WIDTH_OUT)-1:0], a[(16*DATA_WIDTH_OUT)-1 : 13*DATA_WIDTH_OUT]};
            4'hE: path = {b[(14*DATA_WIDTH_OUT)-1:0], a[(16*DATA_WIDTH_OUT)-1 : 14*DATA_WIDTH_OUT]};
            4'hF: path = {b[(15*DATA_WIDTH_OUT)-1:0], a[(16*DATA_WIDTH_OUT)-1 : 15*DATA_WIDTH_OUT]};
            default: path = {(16*DATA_WIDTH_OUT){1'b0}};
        endcase
    end

    assign q0  = path[(1*DATA_WIDTH_OUT)-1  : 0];
    assign q1  = path[(2*DATA_WIDTH_OUT)-1  : 1*DATA_WIDTH_OUT];
    assign q2  = path[(3*DATA_WIDTH_OUT)-1  : 2*DATA_WIDTH_OUT];
    assign q3  = path[(4*DATA_WIDTH_OUT)-1  : 3*DATA_WIDTH_OUT];
    assign q4  = path[(5*DATA_WIDTH_OUT)-1  : 4*DATA_WIDTH_OUT];
    assign q5  = path[(6*DATA_WIDTH_OUT)-1  : 5*DATA_WIDTH_OUT];
    assign q6  = path[(7*DATA_WIDTH_OUT)-1  : 6*DATA_WIDTH_OUT];
    assign q7  = path[(8*DATA_WIDTH_OUT)-1  : 7*DATA_WIDTH_OUT];
    assign q8  = path[(9*DATA_WIDTH_OUT)-1  : 8*DATA_WIDTH_OUT];
    assign q9  = path[(10*DATA_WIDTH_OUT)-1 : 9*DATA_WIDTH_OUT];
    assign q10 = path[(11*DATA_WIDTH_OUT)-1 : 10*DATA_WIDTH_OUT];
    assign q11 = path[(12*DATA_WIDTH_OUT)-1 : 11*DATA_WIDTH_OUT];
    assign q12 = path[(13*DATA_WIDTH_OUT)-1 : 12*DATA_WIDTH_OUT];
    assign q13 = path[(14*DATA_WIDTH_OUT)-1 : 13*DATA_WIDTH_OUT];
    assign q14 = path[(15*DATA_WIDTH_OUT)-1 : 14*DATA_WIDTH_OUT];
    assign q15 = path[(16*DATA_WIDTH_OUT)-1 : 15*DATA_WIDTH_OUT];

endmodule
