// megafunction wizard: %RAM: 2-PORT%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: altsyncram 

// ============================================================
// File Name: iix2_buffer.v
// Megafunction Name(s):
// 			altsyncram
// Simulation Library Files(s):
// 			altera_mf
// ============================================================

`timescale 1 ps / 1 ps

module iix2_buffer (
    input  wire [12:0]  address_a,
    input  wire [8:0]   address_b,
    input  wire         clock_a,
    input  wire         clock_b,
    input  wire [27:0]  data_a,
    input  wire [447:0] data_b,
    input  wire         wren_a,
    input  wire         wren_b,
    output wire [27:0]  q_a,
    output wire [447:0] q_b
);

    altsyncram altsyncram_component (
        .address_a (address_a),
        .address_b (address_b),
        .clock0    (clock_a),
        .clock1    (clock_b),
        .data_a    (data_a),
        .data_b    (data_b),
        .wren_a    (wren_a),
        .wren_b    (wren_b),
        .q_a       (q_a),
        .q_b       (q_b),
        .aclr0     (1'b0),
        .aclr1     (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a (1'b1),
        .byteena_b (1'b1),
        .clocken0  (1'b1),
        .clocken1  (1'b1),
        .clocken2  (1'b1),
        .clocken3  (1'b1),
        .eccstatus (),
        .rden_a    (1'b1),
        .rden_b    (1'b1)
    );
    defparam
        altsyncram_component.address_reg_b = "CLOCK1",
        altsyncram_component.clock_enable_input_a = "BYPASS",
        altsyncram_component.clock_enable_input_b = "BYPASS",
        altsyncram_component.clock_enable_output_a = "BYPASS",
        altsyncram_component.clock_enable_output_b = "BYPASS",
        altsyncram_component.indata_reg_b = "CLOCK1",
        altsyncram_component.intended_device_family = "Cyclone IV E",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = 8192,
        altsyncram_component.numwords_b = 512,
        altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_aclr_b = "NONE",
        altsyncram_component.outdata_reg_a = "UNREGISTERED",
        altsyncram_component.outdata_reg_b = "UNREGISTERED",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
        altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
        altsyncram_component.widthad_a = 13,
        altsyncram_component.widthad_b = 9,
        altsyncram_component.width_a = 28,
        altsyncram_component.width_b = 448,
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.width_byteena_b = 1,
        altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";

endmodule