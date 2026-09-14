// megafunction wizard: %ALTPLL%
// GENERATION: STANDARD
// VERSION: WM1.0
// MODULE: altpll 

// ============================================================
// File Name: my_altpll.v
// Megafunction Name(s):
// 			altpll
// Simulation Library Files(s):
// 			altera_mf
// ============================================================

`timescale 1 ps / 1 ps

module my_altpll (
    input  wire areset,
    input  wire inclk0,
    output wire c0,
    output wire c1,
    output wire c2,
    output wire c3,
    output wire locked
);

    wire [4:0] sub_wire0;
    wire [1:0] sub_wire1;

    assign sub_wire1 = {1'b0, inclk0};
    assign c0     = sub_wire0[0];
    assign c1     = sub_wire0[1];
    assign c2     = sub_wire0[2];
    assign c3     = sub_wire0[3];

    altpll altpll_component (
        .areset (areset),
        .inclk  (sub_wire1),
        .clk    (sub_wire0),
        .locked (locked),
        .activeclock (),
        .clkbad (),
        .clkloss (),
        .empty (),
        .enable0 (),
        .enable1 (),
        .extclk (),
        .fbin (1'b1),
        .inclkbad (),
        .pfdena (1'b1),
        .phasedone (),
        .scandataout (),
        .scandone (),
        .sclkout0 (),
        .sclkout1 ()
    );
    defparam
        altpll_component.bandwidth_type = "AUTO",
        altpll_component.clk0_divide_by = 5,
        altpll_component.clk0_duty_cycle = 50,
        altpll_component.clk0_multiply_by = 4,
        altpll_component.clk0_phase_shift = "0",
        altpll_component.clk1_divide_by = 1,
        altpll_component.clk1_duty_cycle = 50,
        altpll_component.clk1_multiply_by = 2,
        altpll_component.clk1_phase_shift = "0",
        altpll_component.clk2_divide_by = 1,
        altpll_component.clk2_duty_cycle = 50,
        altpll_component.clk2_multiply_by = 1,
        altpll_component.clk2_phase_shift = "0",
        altpll_component.clk3_divide_by = 2,
        altpll_component.clk3_duty_cycle = 50,
        altpll_component.clk3_multiply_by = 1,
        altpll_component.clk3_phase_shift = "0",
        altpll_component.compensate_clock = "CLK0",
        altpll_component.inclk0_input_frequency = 20000,
        altpll_component.intended_device_family = "Cyclone IV E",
        altpll_component.lpm_hint = "CBX_MODULE_PREFIX=my_altpll",
        altpll_component.lpm_type = "altpll",
        altpll_component.operation_mode = "NORMAL",
        altpll_component.pll_type = "AUTO",
        altpll_component.port_activeclock = "PORT_UNUSED",
        altpll_component.port_areset = "PORT_USED",
        altpll_component.port_clkbad0 = "PORT_UNUSED",
        altpll_component.port_clkbad1 = "PORT_UNUSED",
        altpll_component.port_clkloss = "PORT_UNUSED",
        altpll_component.port_clkswitch = "PORT_UNUSED",
        altpll_component.port_configupdate = "PORT_UNUSED",
        altpll_component.port_fbin = "PORT_UNUSED",
        altpll_component.port_inclk0 = "PORT_USED",
        altpll_component.port_inclk1 = "PORT_UNUSED",
        altpll_component.port_locked = "PORT_USED",
        altpll_component.port_pfdena = "PORT_UNUSED",
        altpll_component.port_phasecounterselect = "PORT_UNUSED",
        altpll_component.port_phasedone = "PORT_UNUSED",
        altpll_component.port_phasestep = "PORT_UNUSED",
        altpll_component.port_phaseupdown = "PORT_UNUSED",
        altpll_component.port_pllena = "PORT_UNUSED",
        altpll_component.port_scanaclr = "PORT_UNUSED",
        altpll_component.port_scanclk = "PORT_UNUSED",
        altpll_component.port_scanclkena = "PORT_UNUSED",
        altpll_component.port_scandata = "PORT_UNUSED",
        altpll_component.port_scandataout = "PORT_UNUSED",
        altpll_component.port_scandone = "PORT_UNUSED",
        altpll_component.port_scanread = "PORT_UNUSED",
        altpll_component.port_scanwrite = "PORT_UNUSED",
        altpll_component.port_clk0 = "PORT_USED",
        altpll_component.port_clk1 = "PORT_USED",
        altpll_component.port_clk2 = "PORT_USED",
        altpll_component.port_clk3 = "PORT_USED",
        altpll_component.port_clk4 = "PORT_UNUSED",
        altpll_component.port_clk5 = "PORT_UNUSED",
        altpll_component.port_clkena0 = "PORT_UNUSED",
        altpll_component.port_clkena1 = "PORT_UNUSED",
        altpll_component.port_clkena2 = "PORT_UNUSED",
        altpll_component.port_clkena3 = "PORT_UNUSED",
        altpll_component.port_clkena4 = "PORT_UNUSED",
        altpll_component.port_clkena5 = "PORT_UNUSED",
        altpll_component.port_extclk0 = "PORT_UNUSED",
        altpll_component.port_extclk1 = "PORT_UNUSED",
        altpll_component.port_extclk2 = "PORT_UNUSED",
        altpll_component.port_extclk3 = "PORT_UNUSED",
        altpll_component.self_reset_on_loss_lock = "OFF",
        altpll_component.width_clock = 5;

endmodule
