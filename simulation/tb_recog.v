`timescale 1ns/1ps
// Testbench: enroll one face from the test image (4 samples), then recognize
// several boxes and print the similarity score of each.
module tb_recog;
    reg clk = 0;
    always #5 clk = ~clk;

    // image_ram model: address registered on the read clock, data unregistered
    reg [7:0]  img [0:76799];
    wire [16:0] rd_address;
    reg  [16:0] addr_r;
    always @(posedge clk) addr_r <= rd_address;
    wire [7:0] rd_data = img[addr_r];
    initial $readmemh("img.hex", img);

    reg        start_toggle = 0;
    wire       done_toggle;
    reg [3:0]  face_valid = 4'b0001;
    reg [9:0]  bx;  reg [8:0] by, bs;
    reg        enroll_req = 0;
    reg [1:0]  enroll_sample = 0;
    reg [3:0]  enrolled_mask = 0;
    wire [11:0] result_person;
    wire [27:0] result_score;

    face_recognizer dut (
        .clk(clk), .start_toggle(start_toggle), .done_toggle(done_toggle),
        .face_valid(face_valid),
        .face_x({30'd0, bx}), .face_y({27'd0, by}), .face_size({27'd0, bs}),
        .enroll_req(enroll_req), .enroll_face(2'd0), .enroll_slot(2'd0),
        .enrolled_mask(enrolled_mask),
        .enroll_sample(enroll_sample),
        .active(), .rd_address(rd_address), .rd_data(rd_data),
        .tmpl_wren(), .tmpl_wraddress(), .tmpl_wrdata(),
        .result_person(result_person), .result_score(result_score),
        .ext_en(1'b0), .ext_raddr(13'd0), .ext_rdata(), .ext_we(1'b0),
        .ext_waddr(13'd0), .ext_wdata(8'd0)
    );

    // capture the distance used for the score (best_acc is reset afterwards)
    reg [11:0] last_d = 0;
    always @(posedge clk) if (dut.st == 4'd11) last_d <= dut.best_acc[0];

    task run(input [9:0] x, input [8:0] y, input [8:0] s, input en, input [1:0] smp, input [8*24-1:0] label);
        reg d;
        begin
            bx = x; by = y; bs = s; enroll_req = en; enroll_sample = smp;
            d = done_toggle;
            @(posedge clk) start_toggle = ~start_toggle;
            wait (done_toggle != d);
            repeat (5) @(posedge clk);
            $display("%-24s box=(%0d,%0d,%0d)  person=%0d  score=%0d  L1=%0d",
                     label, x, y, s, result_person[2:0], result_score[6:0], last_d);
        end
    endtask

    initial begin
        repeat (20) @(posedge clk);
        // enroll slot 0 from the 48x48 face at (100,100)
        run(100, 100, 48, 1, 0, "enroll sample 0");
        run(100, 100, 48, 1, 1, "enroll sample 1");
        run(100, 100, 48, 1, 2, "enroll sample 2");
        run(100, 100, 48, 1, 3, "enroll sample 3");
        enrolled_mask = 4'b0001;
        run(100, 100, 48, 0, 0, "same box");
        
        run(102, 102, 48, 0, 0, "shift +2,+2");
        run(104, 98, 50, 0, 0, "shift +4,-2 size 50");
        
        run(0, 120, 96, 0, 0, "same person 96px");
        
        run(200, 196, 40, 0, 0, "white background");
        
        $finish;
    end
endmodule
