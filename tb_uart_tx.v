`timescale 1ns/1ps
// Self-checking testbench for uart_tx.
// Uses a small CLKS_PER_BIT (10) so the simulation runs fast.
module tb_uart_tx;

    localparam CLKS = 10;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg        tx_start = 1'b0;
    reg  [7:0] tx_data  = 8'd0;
    wire       tx, busy, done;

    integer errors = 0;
    integer i;
    reg [7:0] rx_byte;

    uart_tx #(.CLKS_PER_BIT(CLKS)) dut (
        .clk(clk), .rst(rst), .tx_start(tx_start),
        .tx_data(tx_data), .tx(tx), .busy(busy), .done(done)
    );

    always #5 clk = ~clk;   // 100 MHz clock (10 ns period)

    // Send one byte, then read the tx line like a receiver would and compare
    task send_and_check(input [7:0] data);
    begin
        @(posedge clk);
        tx_data  <= data;
        tx_start <= 1'b1;
        @(posedge clk);
        tx_start <= 1'b0;

        @(negedge tx);                       // start bit begins
        repeat (CLKS/2) @(posedge clk);      // move to the middle of the start bit
        if (tx !== 1'b0) begin
            $display("ERROR: start bit is not 0 at time %0t", $time);
            errors = errors + 1;
        end

        for (i = 0; i < 8; i = i + 1) begin  // sample each data bit in its middle
            repeat (CLKS) @(posedge clk);
            rx_byte[i] = tx;
        end

        repeat (CLKS) @(posedge clk);        // middle of the stop bit
        if (tx !== 1'b1) begin
            $display("ERROR: stop bit is not 1 at time %0t", $time);
            errors = errors + 1;
        end

        if (rx_byte !== data) begin
            $display("FAIL: sent 0x%02h but received 0x%02h at time %0t", data, rx_byte, $time);
            errors = errors + 1;
        end else
            $display("PASS: sent 0x%02h, received 0x%02h", data, rx_byte);

        wait (done);                         // wait until the transmitter finishes
        @(posedge clk);
    end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        rst = 1'b0;
        repeat (2) @(posedge clk);

        send_and_check(8'h41);   // 'A'
        send_and_check(8'h55);   // 01010101
        send_and_check(8'hA3);   // asymmetric pattern, catches bit-order bugs
        send_and_check(8'hFF);
        send_and_check(8'h00);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d error(s)", errors);
        $finish;
    end
endmodule
