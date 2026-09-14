// Converts 2D pixel coordinates (x, y) and image width to a linear memory offset address.
// Includes a upper/lower memory bank selection bit controlled by mem_state.

`timescale 1 ps / 1 ps

module pixel_offset (
    input  wire        mem_state,
    input  wire [5:0]  x_pos_subwin, // 6-bit unsigned (0 to 38)
    input  wire [5:0]  y_pos_subwin, // 6-bit unsigned (0 to 58)
    input  wire [5:0]  width_ii,     // 6-bit unsigned (0 to 38)
    output wire [12:0] p_offset      // 13-bit unsigned offset address
);

    // Internal Signals
    wire [11:0] result_mult0;
    wire [12:0] p_offset_s;

    // Multiplication of 6-bit y-position and 6-bit width yields a 12-bit result
    assign result_mult0 = y_pos_subwin * width_ii;

    // Bit 12 selects upper/lower memory bank: if mem_state is 1 -> lower (0), else upper (1)
    assign p_offset_s[12]      = ~mem_state;
    assign p_offset_s[11:0]    = result_mult0 + x_pos_subwin;
    
    // Output assignment
    assign p_offset = p_offset_s;

endmodule
