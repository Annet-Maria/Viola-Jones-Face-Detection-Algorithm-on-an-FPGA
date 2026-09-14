module RGB (
    input  wire [11:0] Din,     // Pixel color data (4 bits per channel)
    input  wire        Nblank,  // Display active zone signal (0 = blanking, outputs zero)
    output wire [7:0]  R,       // Red output channel scaled to 8 bits
    output wire [7:0]  G,       // Green output channel scaled to 8 bits
    output wire [7:0]  B        // Blue output channel scaled to 8 bits
);

    // Conditional assignments: replicate 4-bit slice twice to scale to 8 bits when Nblank = 1
    assign R = (Nblank) ? {Din[11:8], Din[11:8]} : 8'h00;
    assign G = (Nblank) ? {Din[7:4],  Din[7:4]}  : 8'h00;
    assign B = (Nblank) ? {Din[3:0],  Din[3:0]}  : 8'h00;

endmodule
