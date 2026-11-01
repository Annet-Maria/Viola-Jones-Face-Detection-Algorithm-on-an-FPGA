// Simple dual-port, dual-clock RAM: port A writes on wrclock, port B reads on
// rdclock (1-cycle read latency, unregistered output). Replaces the
// BIDIR_DUAL_PORT frame buffer so no port ever needs a muxed clock.

module dp_ram #(
    parameter WIDTH     = 12,
    parameter WIDTHAD   = 17,
    parameter NUMWORDS  = 76800,
    parameter INIT_FILE = "UNUSED"
) (
    input  wire               wrclock,
    input  wire               wren,
    input  wire [WIDTHAD-1:0] wraddress,
    input  wire [WIDTH-1:0]   data,
    input  wire               rdclock,
    input  wire [WIDTHAD-1:0] rdaddress,
    output wire [WIDTH-1:0]   q
);

    altsyncram altsyncram_component (
        .address_a      (wraddress),
        .address_b      (rdaddress),
        .clock0         (wrclock),
        .clock1         (rdclock),
        .data_a         (data),
        .wren_a         (wren),
        .q_b            (q),
        .aclr0          (1'b0),
        .aclr1          (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a      (1'b1),
        .byteena_b      (1'b1),
        .clocken0       (1'b1),
        .clocken1       (1'b1),
        .clocken2       (1'b1),
        .clocken3       (1'b1),
        .data_b         ({WIDTH{1'b1}}),
        .eccstatus      (),
        .q_a            (),
        .rden_a         (1'b1),
        .rden_b         (1'b1),
        .wren_b         (1'b0)
    );

    defparam
        altsyncram_component.address_aclr_b         = "NONE",
        altsyncram_component.address_reg_b          = "CLOCK1",
        altsyncram_component.clock_enable_input_a   = "BYPASS",
        altsyncram_component.clock_enable_input_b   = "BYPASS",
        altsyncram_component.clock_enable_output_b  = "BYPASS",
        altsyncram_component.init_file              = INIT_FILE,
        altsyncram_component.intended_device_family = "Cyclone IV E",
        altsyncram_component.lpm_type               = "altsyncram",
        altsyncram_component.numwords_a             = NUMWORDS,
        altsyncram_component.numwords_b             = NUMWORDS,
        altsyncram_component.operation_mode         = "DUAL_PORT",
        altsyncram_component.outdata_aclr_b         = "NONE",
        altsyncram_component.outdata_reg_b          = "UNREGISTERED",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.ram_block_type         = "M9K",
        altsyncram_component.widthad_a              = WIDTHAD,
        altsyncram_component.widthad_b              = WIDTHAD,
        altsyncram_component.width_a                = WIDTH,
        altsyncram_component.width_b                = WIDTH,
        altsyncram_component.width_byteena_a        = 1;

endmodule
