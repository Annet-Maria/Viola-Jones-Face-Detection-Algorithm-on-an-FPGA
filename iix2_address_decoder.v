module iix2_address_decoder (
    input  wire [1:0]  iix2_reg_index, // 2bit unsigned ... range 0 to 3
    input  wire [5:0]  width_ii,       // 6bit unsigned ... range(0 to 38)
    input  wire [12:0] p_offset,       // 13bit unsigned ... base address of the subwindow (top left corner)
    output reg  [12:0] iix2_address    // 13bit unsigned ... target corner address
);

    // SIGNALS
    wire [10:0] result_mult0; // 11 bit unsigned

    wire [12:0] iix2_address0;
    wire [12:0] iix2_address1;
    wire [12:0] iix2_address2;
    wire [12:0] iix2_address3;

    // Multiplication: 23 * width_ii (5-bit constant * 6-bit input = 11-bit output)
    assign result_mult0 = 5'd23 * width_ii;

    // ------------ ii_address0 --------------
    // top left corner: address = p_offset
    assign iix2_address0 = p_offset;

    // ------------ ii_address1 --------------
    // top right corner: address = p_offset + 23
    assign iix2_address1 = p_offset + 13'd23;

    // ------------ ii_address2 --------------
    // bottom left corner: address = p_offset + width_ii * 23
    assign iix2_address2 = p_offset + result_mult0;

    // ------------ ii_address3 --------------
    // bottom right corner: address = p_offset + width_ii * 23 + 23
    assign iix2_address3 = iix2_address2 + 13'd23;

    // ------------ mux output --------------
    always @(*) begin
        case (iix2_reg_index)
            2'b00:   iix2_address = iix2_address0;
            2'b01:   iix2_address = iix2_address1;
            2'b10:   iix2_address = iix2_address2;
            2'b11:   iix2_address = iix2_address3;
            default: iix2_address = iix2_address0;
        endcase
    end

endmodule