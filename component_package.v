module my_altpll (
    input wire areset,
    input wire inclk0,
    output wire c0,
    output wire c1,
    output wire c2,
    output wire c3,
    output wire locked
);
endmodule


module image_frame_buffer (
    input wire [16:0] address_a,
    input wire [16:0] address_b,
    input wire clock_a,
    input wire clock_b,
    input wire [11:0] data_a,
    input wire [11:0] data_b,
    input wire wren_a,
    input wire wren_b,
    output wire [11:0] q_a,
    output wire [11:0] q_b
);
endmodule


module ii_buffer (
    input wire [12:0] address_a,
    input wire [8:0] address_b,
    input wire clock_a,
    input wire clock_b,
    input wire [19:0] data_a,
    input wire [319:0] data_b,
    input wire wren_a,
    input wire wren_b,
    output wire [19:0] q_a,
    output wire [319:0] q_b
);
endmodule


module iix2_buffer (
    input wire [12:0] address_a,
    input wire [8:0] address_b,
    input wire clock_a,
    input wire clock_b,
    input wire [27:0] data_a,
    input wire [447:0] data_b,
    input wire wren_a,
    input wire wren_b,
    output wire [27:0] q_a,
    output wire [447:0] q_b
);
endmodule


module debounce (
    input wire clk,
    input wire i,
    output wire o
);
endmodule


module ov7670_capture (
    input wire pclk,
    input wire capture,
    input wire vsync,
    input wire href,
    input wire [7:0] d,
    output wire [16:0] addr,
    output wire [11:0] dout,
    output wire we,
    output wire busy
);
endmodule


module ov7670_controller (
    input wire clk,
    input wire resend,
    inout wire siod,
    output wire config_finished,
    output wire sioc,
    output wire reset,
    output wire pwdn,
    output wire xclk
);
endmodule


module Address_Generator (
    input wire rst_i,
    input wire CLK25,
    input wire enable,
    input wire vsync,
    output wire [16:0] address
);
endmodule


module RGB (
    input wire [11:0] Din,
    input wire Nblank,
    output wire [7:0] R,
    output wire [7:0] G,
    output wire [7:0] B
);
endmodule


module VGA (
    input wire CLK25,
    output wire Hsync,
    output wire Vsync,
    output wire Nblank,
    output wire clkout,
    output wire activeArea,
    output wire Nsync
);
endmodule


module ii_gen (
    input wire clk,
    input wire reset,
    input wire start,
    input wire [3:0] image_scale,
    input wire [11:0] image_data_i,
    input wire [19:0] ii_data_i,
    input wire [27:0] iix2_data_i,
    input wire mem_state,
    input wire [8:0] scaleImg_x_base,
    input wire [7:0] scaleImg_y_base,
    output wire [16:0] image_rdaddress,
    output wire [12:0] ii_address,
    output wire ii_wren,
    output wire [19:0] ii_data_o,
    output wire [27:0] iix2_data_o,
    output wire done
);
endmodule


module subwindow_top (
    input wire reset,
    input wire clk_sys,
    input wire start,
    input wire mem_state,
    input wire [5:0] x_pos_subwin0,
    input wire [5:0] y_pos_subwin0,
    input wire [639:0] ii_rddata,
    input wire [895:0] iix2_rddata,
    output wire [8:0] ii_rdaddress,
    output wire [8:0] iix2_rdaddress,
    output wire [15:0] fail_out,
    output wire done
);
endmodule


module faceBox (
    input wire reset,
    input wire clk_subwin,
    input wire clk_faceBox,
    input wire start_draw,
    input wire [3:0] scale,
    input wire [8:0] x_pos_subwin,
    input wire [7:0] y_pos_subwin,
    input wire subwin_done,
    input wire [15:0] subwin_detection,
    output wire [16:0] img_wraddress,
    output wire [11:0] img_wrdata,
    output wire img_wren,
    output wire done_draw
);
endmodule


module counter #(
    parameter COUNT_WIDTH = 4
)(
    input wire clk,
    input wire reset,
    input wire en,
    output wire [COUNT_WIDTH-1:0] count
);
endmodule


module counter2 #(
    parameter COUNT_WIDTH = 4
)(
    input wire clk,
    input wire reset,
    input wire en,
    output wire [COUNT_WIDTH-1:0] count
);
endmodule


module mux_std_logic (
    input wire sel,
    input wire a,
    input wire b,
    output wire q
);
endmodule


module mux_2_1 #(
    parameter DATA_WIDTH = 4
)(
    input wire sel,
    input wire [DATA_WIDTH-1:0] a,
    input wire [DATA_WIDTH-1:0] b,
    output wire [DATA_WIDTH-1:0] q
);
endmodule


module demux_1_2 #(
    parameter DATA_WIDTH = 4
)(
    input wire sel,
    input wire [DATA_WIDTH-1:0] a,
    output wire [DATA_WIDTH-1:0] q0,
    output wire [DATA_WIDTH-1:0] q1
);
endmodule
