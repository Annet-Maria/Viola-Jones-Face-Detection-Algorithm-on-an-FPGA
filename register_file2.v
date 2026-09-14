module register_file2 #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 18
)(
    input  wire                  clk,
    input  wire                  write_en,
    input  wire [ADDR_WIDTH-1:0] write_reg_addr,
    input  wire [DATA_WIDTH-1:0] write_data,
    output wire [DATA_WIDTH-1:0] q0,
    output wire [DATA_WIDTH-1:0] q1,
    output wire [DATA_WIDTH-1:0] q2,
    output wire [DATA_WIDTH-1:0] q3
);

    // 2D Array declaration for the register file
    reg [DATA_WIDTH-1:0] reg_file [0:(1<<ADDR_WIDTH)-1];

    // Initialize all registers to 0
    integer i;
    initial begin
        for (i = 0; i < (1 << ADDR_WIDTH); i = i + 1) begin
            reg_file[i] = {DATA_WIDTH{1'b0}};
        end
    end

    // Synchronous write process
    always @(posedge clk) begin
        if (write_en) begin
            reg_file[write_reg_addr] <= write_data;
        end
    end

    // Asynchronous read assignments
    assign q0 = reg_file[0];
    assign q1 = reg_file[1];
    assign q2 = reg_file[2];
    assign q3 = reg_file[3];

endmodule
