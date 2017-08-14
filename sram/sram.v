`default_nettype none

module clk_divn #(
    parameter WIDTH = 3,
    parameter N = 5)
    (clk,reset, clk_out);
 
    input clk;
    input reset;
    output clk_out;
 
    reg [WIDTH-1:0] pos_count, neg_count;
    wire [WIDTH-1:0] r_nxt;
 
    always @(posedge clk)
    if (reset)
    pos_count <=0;
    else if (pos_count ==N-1) pos_count <= 0;
    else pos_count<= pos_count +1;
 
    always @(negedge clk)
    if (reset)
    neg_count <=0;
    else  if (neg_count ==N-1) neg_count <= 0;
    else neg_count<= neg_count +1; 
 
    assign clk_out = ((pos_count > (N>>1)) | (neg_count > (N>>1))); 
endmodule

`default_nettype none
module sram (
    input wire reset,
    // 50ns max for data read/write. at 12MHz, each clock cycle is 83ns, so write in 1 cycle
	input wire clk,
    input wire write,
    input wire read,
    input wire [15:0] data_write,       // the data to write
    output wire [15:0] data_read,       // the data that's been read
    input wire [17:0] address,          // address to write to
    output wire ready,                  // high when ready for next operation
    output wire data_pins_out_en,       // when to switch between in and out on data pins

    // SRAM pins
    output wire [17:0] address_pins,    // address pins of the SRAM
    input  wire [15:0] data_pins_in,
    output wire [15:0] data_pins_out,
    output wire OE,                     // output enable - low to enable
    output wire WE,                     // write enable - low to enable
    output wire CS                      // chip select - low to enable
);

    localparam STATE_IDLE = 0;
    localparam STATE_WRITE = 1;
    localparam STATE_WRITE_SETUP = 4;
    localparam STATE_READ_SETUP = 2;
    localparam STATE_READ = 3;

    reg output_enable;
    reg write_enable;
    reg chip_select;

    reg [4:0] state;
    reg [15:0] data_read_reg;
    reg [15:0] data_write_reg;

    assign data_pins_out_en = (state == STATE_WRITE) ? 1 : 0; // turn on output pins when writing data
    assign address_pins = address;
    assign data_pins_out = data_write_reg;
    assign data_read = data_read_reg;
    assign OE = output_enable;
    assign WE = write_enable;
    assign CS = chip_select;

    assign ready = (!reset && state == STATE_IDLE) ? 1 : 0; 

    initial begin
        state <= STATE_IDLE;
        output_enable <= 1;
        chip_select <= 1;
        write_enable <= 1;
    end

	always@(posedge clk) begin
        if( reset == 1 ) begin
            state <= STATE_IDLE;
            output_enable <= 1;
            chip_select <= 1;
            write_enable <= 1;
        end
        else begin
            case(state)
                STATE_IDLE: begin
                    output_enable <= 1;
                    chip_select <= 1;
                    write_enable <= 1;
                    if(write) state <= STATE_WRITE_SETUP;
                    else if(read) state <= STATE_READ_SETUP;
                end
                STATE_WRITE_SETUP: begin
                    chip_select <= 0;
                    data_write_reg <= data_write;
                    state <= STATE_WRITE;
                end
                STATE_WRITE: begin
                    write_enable <= 0;
                    state <= STATE_IDLE;
                end
                STATE_READ_SETUP: begin
                    output_enable <= 0;
                    chip_select <= 0;
                    state <= STATE_READ;
                end
                STATE_READ: begin
                    data_read_reg <= data_pins_in;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end


endmodule

module top (
	input  clk,
    output [7:0] PMOD,
    output [17:0] ADR,
    inout [15:0] DAT,
    output RAMOE,
    output RAMWE,
    output RAMCS
);

    wire [15:0] data_pins_in;
    wire [15:0] data_pins_out;
    wire data_pins_out_en;
    
    SB_IO #(
        .PIN_TYPE(6'b 1010_01),
    ) sram_data_pins [15:0] (
        .PACKAGE_PIN(DAT),
        .OUTPUT_ENABLE(data_pins_out_en),
        .D_OUT_0(data_pins_out),
        .D_IN_0(data_pins_in),
    );

    reg slow_clk;
    reg [17:0] address;
    wire [15:0] data_read;
    reg [15:0] data_write;
    reg read;
    reg write;
    reg reset;
    reg ready;
    reg [15:0] counter;
    reg read_write;

    initial begin
        read_write <= 0;
        read <= 0;
        write <= 0;
        reset <= 0;
        address <= 0;
        data_write <= 16'hAAAA;
    end

    wire [15:0] data_pins_in;
    wire [15:0] data_pins_out;
    wire set_data_pins;

    assign PMOD = data_read[15:8];
    
    sram sram_test(.clk(clk), .address(address), .data_read(data_read), .data_write(data_write), .write(write), .read(read), .reset(reset), .ready(ready), 
        .data_pins_in(data_pins_in), 
        .data_pins_out(data_pins_out), 
        .data_pins_out_en(data_pins_out_en),
        .address_pins(ADR), 
        .OE(RAMOE), .WE(RAMWE), .CS(RAMCS));

    clk_divn #(.WIDTH(32), .N(1000)) 
        clockdiv_slow(.clk(clk), .clk_out(slow_clk));

    always @(posedge slow_clk) begin
        address <= counter;
        if(read_write) begin
            if(ready) begin
                counter <= counter + 1;
                read <= 1;
            end else
                read <= 0;
        end else begin
            if(ready) begin
                data_write <= counter;
                counter <= counter + 1;
                write <= 1;
            end else
           write <= 0;
        end
        // flip each cycle of the counter
        if(counter == 0)
            read_write <= read_write ? 0 : 1;
    end
endmodule

