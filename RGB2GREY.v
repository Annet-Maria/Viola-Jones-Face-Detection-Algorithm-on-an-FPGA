module RGB2GREY (
    input  wire [11:0] Din,   // 12-bit color (RRRR:GGGG:BBBB)
    output wire [7:0]  Dout   // 8-bit greyscale
);

    /*
     * Luminance approximation using Version 2 scaling (full 8-bit duplication prior to shifts):
     * - R component (8-bit) shifted right by 2: {2'b00, R, R[3:2]}
     * - G component (8-bit) shifted right by 1: {1'b0, G, G[3:1]}
     * - B component (8-bit) shifted right by 3: {3'b000, B, B[3]}
     */

    // Extract 4-bit channels
    wire [3:0] R = Din[11:8];
    wire [3:0] G = Din[7:4];
    wire [3:0] B = Din[3:0];

    // Compute weighted color contributions
    wire [7:0] X = {2'b00, R, R[3:2]};
    wire [7:0] Y = {1'b0,  G, G[3:1]};
    wire [7:0] Z = {3'b000, B, B[3]};

    // Greyscale sum: X + Y + Z
    assign Dout = X + Y + Z;

endmodule
