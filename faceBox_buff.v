
module faceBox_buff (
    input wire [36:0] data,
    input wire [9:0] rdaddress,
    input wire rdclock,
    input wire [9:0] wraddress,
    input wire wrclock,
    input wire wren,
    output reg [36:0] q
);

    reg [36:0] mem [0:1023];

    always @(posedge wrclock) begin
        if (wren)
            mem[wraddress] <= data;
    end

    always @(posedge rdclock) begin
        q <= mem[rdaddress];
    end

endmodule