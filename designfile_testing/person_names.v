// ============================================================
// Names of the enrolled people - EDIT HERE, then recompile.
//
// Slot 0..3 match the enrollment slot selected with SW11..SW10.
// Each name is exactly 12 characters: pad with spaces on the right.
// Allowed characters: A-Z, 0-9, space and - . _ (lower case shows as upper).
// ============================================================

module person_names (
    input  wire [2:0] person,  // 0..3 = enrolled slot, 4..7 = not recognised
    input  wire [3:0] index,   // character position 0..11
    output wire [7:0] ascii
);

    //                         "123456789012"
    localparam [95:0] NAME0 = "ANNET MARIA ";
    localparam [95:0] NAME1 = "ANITA PAUL  ";
    localparam [95:0] NAME2 = "SHAMEER     ";
    localparam [95:0] NAME3 = "NAIDU SIR   ";
    localparam [95:0] NAME_UNKNOWN = "UNKNOWN     ";

    reg [95:0] name;
    always @(*) begin
        case (person)
            3'd0:    name = NAME0;
            3'd1:    name = NAME1;
            3'd2:    name = NAME2;
            3'd3:    name = NAME3;
            default: name = NAME_UNKNOWN;
        endcase
    end

    // first character sits in the top byte of the string literal
    assign ascii = (index < 4'd12) ? name[(4'd11 - index) * 8 +: 8] : 8'h20;

endmodule
