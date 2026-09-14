//=============================================================
// ram.v
// Dual-clock RAM with optional memory initialization from file
//=============================================================

`timescale 1ns / 1ps

module ram #(
    // Parameters (generics)
    parameter ADDR_WIDTH           = 10,
    parameter DATA_WIDTH           = 18,
    parameter MAX_PRELOAD_ADDRESS  = 575,
    parameter MEM_FILE_NAME        = "fileName.txt",  // use for simulation ($readmemh)
    parameter MIF_FILE_NAME        = "fileName.mif"   // use for hardware programming (synthesis attribute)
)(
    // Ports
    input  wire [DATA_WIDTH-1:0] data,
    input  wire [ADDR_WIDTH-1:0] rdaddress,
    input  wire                  rdclock,
    input  wire [ADDR_WIDTH-1:0] wraddress,
    input  wire                  wrclock,
    input  wire                  we,
    input  wire                  re,
    output reg  [DATA_WIDTH-1:0] q
);

    //---------------------------------------------------------
    // Memory array
    // Note: The VHDL array is sized 0 to MAX_PRELOAD_ADDRESS,
    // so we keep the same depth for exact equivalence.
    //---------------------------------------------------------
    reg [DATA_WIDTH-1:0] ram_block [0:MAX_PRELOAD_ADDRESS];

    //---------------------------------------------------------
    // Initialization
    //
    // VHDL: impure function init_mem reads the file at
    //       simulation elaboration time. In Verilog, the
    //       equivalent is $readmemh / $readmemb in an initial
    //       block (simulation) and/or a synthesis attribute
    //       (hardware, e.g. Intel Quartus ram_init_file).
    //---------------------------------------------------------

    // Synthesis attribute for hardware programming
    // (equivalent of: attribute ram_init_file of ram_block)
    // For Intel (Altera) Quartus, the attribute is ram_init_file.
    initial begin
        // Uncomment the line below for simulation preload:
        // $readmemh(MEM_FILE_NAME, ram_block);
    end

    // Attach the Quartus RAM initialization attribute
    // synthesizer translate_off
    initial begin
        // Non-synthesizable file preload for simulation,
        // only executed when MEM_FILE_NAME is readable.
        $readmemh(MEM_FILE_NAME, ram_block);
    end
    // synthesizer translate_on

    // Quartus synthesis attribute: initialize RAM from MIF file
    // (equivalent of: attribute ram_init_file of ram_block : signal is MIF_FILE_NAME)
    // In Verilog this is done with an attribute specification:
    (* ram_init_file = MIF_FILE_NAME *) reg [DATA_WIDTH-1:0] ram_block_init;

    // To ensure the attribute binds properly across tool versions,
    // it can also be declared as:
    // altera attribute
    // (For Quartus: ram_init_file works directly on the memory array
    //  when declared with the attribute above, or via .mif assignment
    //  in the Quartus project settings.)

    //---------------------------------------------------------
    // Read address register (kept to match original structure;
    // output register used implicitly through q)
    //---------------------------------------------------------
    reg [ADDR_WIDTH-1:0] read_address_reg = {ADDR_WIDTH{1'b0}};

    //---------------------------------------------------------
    // Main process: dual-clock read/write behavior
    // (equivalent of the VHDL process with rising_edge checks)
    //---------------------------------------------------------
    always @(posedge wrclock) begin
        if (we == 1'b1) begin
            ram_block[wraddress] <= data;
        end
    end

    always @(posedge rdclock) begin
        if (re == 1'b1) begin
            q <= ram_block[rdaddress];
        end
    end

endmodule

