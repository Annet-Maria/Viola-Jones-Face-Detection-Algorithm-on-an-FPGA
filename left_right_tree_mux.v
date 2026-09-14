module left_right_tree_mux (
    input  wire        sel,       // 1bit unsigned select
    input  wire [13:0] left_val,  // 14bit signed
    input  wire [13:0] right_val, // 14bit signed
    output reg  [13:0] q          // 14bit signed
);

    always @(*) begin
        if (sel == 1'b1) begin
            q = right_val;
        end else begin
            q = left_val;
        end
    end

endmodule
