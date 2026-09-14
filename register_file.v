module register_file #(
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
    output wire [DATA_WIDTH-1:0] q3,
    output wire [DATA_WIDTH-1:0] q4,
    output wire [DATA_WIDTH-1:0] q5,
    output wire [DATA_WIDTH-1:0] q6,
    output wire [DATA_WIDTH-1:0] q7,
    output wire [DATA_WIDTH-1:0] q8,
    output wire [DATA_WIDTH-1:0] q9,
    output wire [DATA_WIDTH-1:0] q10,
    output wire [DATA_WIDTH-1:0] q11
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
    assign q0  = reg_file[0];
    assign q1  = reg_file[1];
    assign q2  = reg_file[2];
    assign q3  = reg_file[3];
    assign q4  = reg_file[4];
    assign q5  = reg_file[5];
    assign q6  = reg_file[6];
    assign q7  = reg_file[7];
    assign q8  = reg_file[8];
    assign q9  = reg_file[9];
    assign q10 = reg_file[10];
    assign q11 = reg_file[11];

endmodule
