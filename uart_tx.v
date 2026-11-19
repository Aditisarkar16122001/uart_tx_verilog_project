// UART transmitter: 8 data bits, no parity, 1 stop bit (8N1)
// CLKS_PER_BIT = clock_frequency / baud_rate
// Example: 100 MHz clock, 115200 baud -> 100000000 / 115200 = 868
module uart_tx #(
    parameter CLKS_PER_BIT = 868
)(
    input  wire       clk,
    input  wire       rst,        // synchronous, active high
    input  wire       tx_start,   // pulse high for 1 clock to send tx_data
    input  wire [7:0] tx_data,
    output reg        tx,         // serial output line (idles high)
    output reg        busy,       // high while a byte is being sent
    output reg        done        // 1-clock pulse when the byte is finished
);

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;   // counts clocks inside one bit
    reg [2:0]  bit_idx;   // which data bit (0 to 7) is being sent
    reg [7:0]  data_reg;  // holds the byte while sending

    always @(posedge clk) begin
        if (rst) begin
            state    <= IDLE;
            tx       <= 1'b1;
            busy     <= 1'b0;
            done     <= 1'b0;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
        end else begin
            done <= 1'b0;  // default: done is only a 1-clock pulse

            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    busy    <= 1'b0;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (tx_start) begin
                        data_reg <= tx_data;   // latch the byte
                        busy     <= 1'b1;
                        state    <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;                // start bit = 0
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= DATA;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                DATA: begin
                    tx <= data_reg[bit_idx];   // LSB first
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= STOP;
                        end else
                            bit_idx <= bit_idx + 1'b1;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                STOP: begin
                    tx <= 1'b1;                // stop bit = 1
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        done    <= 1'b1;
                        busy    <= 1'b0;
                        state   <= IDLE;
                    end else
                        clk_cnt <= clk_cnt + 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
