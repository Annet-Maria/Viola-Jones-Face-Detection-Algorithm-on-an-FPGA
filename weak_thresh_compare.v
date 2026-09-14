module weak_thresh_compare (
    input  wire [41:0] result_feature,       // 42-bit signed
    input  wire [37:0] var_norm_weak_thresh, // 38-bit signed
    output wire        q
);

    // Sign-extended 42-bit threshold
    wire [41:0] var_norm_weak_thresh_extend;

    // ---------------------------------------------------------
    // Sign extension
    //
    // Original VHDL:
    //   37 downto 0  <= var_norm_weak_thresh
    //   41 downto 38 <= sign bit (bit 37)
    // ---------------------------------------------------------

    assign var_norm_weak_thresh_extend =
        {{4{var_norm_weak_thresh[37]}}, var_norm_weak_thresh};

    // ---------------------------------------------------------
    // Signed comparison:
    //
    // q = 1 when
    // result_feature >= var_norm_weak_thresh_extend
    // ---------------------------------------------------------

    assign q =
        ($signed(result_feature) >=
         $signed(var_norm_weak_thresh_extend));

endmodule
