module ii_address_calc (
    input  wire [4:0]  x_pos_point,
    input  wire [4:0]  y_pos_point,
    input  wire [5:0]  width_ii,
    input  wire [12:0] p_offset,
    output wire [12:0] ii_address
);

    wire [10:0] result_mult0;
    wire [12:0] result_add0;

    /*
     * 5-bit x 6-bit = 11-bit
     * result_mult0 = y_pos_point * width_ii
     */
    assign result_mult0 = y_pos_point * width_ii;

    /*
     * 5-bit + 13-bit = 13-bit
     * result_add0 = x_pos_point + p_offset
     */
    assign result_add0 = x_pos_point + p_offset;

    /*
     * 13-bit + 11-bit = 13-bit
     * ii_address = result_add0 + result_mult0
     */
    assign ii_address = result_add0 + result_mult0;

endmodule
