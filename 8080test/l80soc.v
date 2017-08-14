`include "intr_ctrl.v"
`include "light8080.v"
`include "micro_rom.v"
`include "ram_image.v"
`include "uart_rx.v"
`include "uart_tx.v"
`include "spi_master.v"

//---------------------------------------------------------------------------------------
//	Project:			light8080 SOC		WiCores Solutions 
//
//	File name:			l80soc.v 			(February 04, 2012)
//
//	Writer:				Moti Litochevski 
//
//	Description:
//		This file contains the light8080 System On a Chip (SOC). the system includes the 
//		CPU, program and data RAM and a UART interface and a general purpose digital IO. 
//
//	Revision History:
//
//	Rev <revnumber>			<Date>			<owner> 
//		<comment>
// 
//---------------------------------------------------------------------------------------
// 
//	Copyright (C) 2012 Moti Litochevski 
// 
//	This source file may be used and distributed without restriction provided that this 
//	copyright statement is not removed from the file and that any derivative work 
//	contains the original copyright notice and the associated disclaimer.
//
//	THIS SOURCE FILE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES, 
//	INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF MERCHANTIBILITY AND 
//	FITNESS FOR A PARTICULAR PURPOSE. 
// 
//---------------------------------------------------------------------------------------

module l80soc 
(
	clock100, reset,
	txd, rxd, // RS232
	p1dio, p2dio, 
  din, ss, sck, dout, // SPI
	extint, led1, led2
);
//---------------------------------------------------------------------------------------
// module interfaces 
// global signals 
input 			clock100;		// global clock input 
input 			reset;		// global reset input 
// uart serial signals 
output			txd;		// serial data output 
input			rxd;		// serial data input 
// digital IO ports 
// inout	[7:0]	p1dio;		// port 1 digital IO 
// inout	[7:0]	p2dio;		// port 2 digital IO 
output	[7:0]	p1dio;		// port 1 digital IO 
output	[7:0]	p2dio;		// port 2 digital IO 
// external interrupt sources 
input	[3:0]	extint;		// external interrupt sources 
output led1;
output led2;
// SPI
input din;
output reg ss;
output reg sck;
output reg dout;

//---------------------------------------------------------------------------------------
// io space registers addresses 
// uart registers 
`define UDATA_REG			8'h80 		// used for both transmit and receive 
`define UBAUDL_REG			8'h81		// low byte of baud rate register 
`define UBAUDH_REG			8'h82		// low byte of baud rate register 
`define USTAT_REG			8'h83		// uart status register 
// dio port registers 
`define P1_DATA_REG			8'h84		// port 1 data register 
`define P1_DIR_REG			8'h85		// port 1 direction register 
`define P2_DATA_REG			8'h86		// port 2 data register 
`define P2_DIR_REG			8'h87		// port 2 direction register 
// interrupt controller register 
`define INTR_EN_REG			8'h88		// interrupts enable register 

`define SPI_TX_REG   		8'h90		// interrupts enable register 
`define SPI_RX_REG  		8'h90		// interrupts enable register 

//---------------------------------------------------------------------------------------
// internal declarations 
// registered output 

reg	[1:0]		clk_div;	// 2 bit counter
wire			clock;	

assign 	clock 	= clk_div[1];		// 25Mhz clock = 100Mhz divided by 2-bit counter
assign 	led1 	= clk_div[25];		// 25Mhz clock = 100Mhz divided by 2-bit counter

always @ (posedge clock100) begin		// 2-bt counter ++ on each positive edge of 100Mhz clock
	clk_div <= clk_div + 2'b1;
end

// internals 
wire [15:0] cpu_addr;
wire [7:0] cpu_din, cpu_dout, ram_dout, intr_dout;
wire cpu_io, cpu_rd, cpu_wr, cpu_inta, cpu_inte, cpu_intr; 
wire [7:0] txData, rxData;
wire [7:0] spiRxData;
wire txValid, txBusy, rxValid;
// reg [15:0] uartbaud;
reg rxfull, scpu_io;
reg spifull;
reg [7:0] p1reg, p1dir, p2reg, p2dir, io_dout;
reg [3:0] intr_ena;

//---------------------------------------------------------------------------------------
// module implementation 
// light8080 CPU instance 
light8080 cpu 
(  
	.clk(clock), 
	.reset(reset), 
	.addr_out(cpu_addr), 
	.vma(/* nu */), 
	.io(cpu_io), 
	.rd(cpu_rd), 
	.wr(cpu_wr), 
	.fetch(/* nu */), 
	.data_in(cpu_din), 
	.data_out(cpu_dout), 
	.inta(cpu_inta), 
	.inte(cpu_inte), 
	.halt(/* nu */), 
	.intr(cpu_intr) 
);

// cpu data input selection 
assign cpu_din = (cpu_inta) ? intr_dout : (scpu_io) ? io_dout : ram_dout;

// program and data Xilinx RAM memory 
ram_image ram 
(
	.clk(clock), 
	.addr(cpu_addr[11:0]), 
	.we(cpu_wr & ~cpu_io), 
	.din(cpu_dout), 
	.dout(ram_dout) 
);

// io space write registers 
always @ (posedge reset or posedge clock) 
begin 
	if (reset) 
	begin 
		// uartbaud <= 16'd12;
		rxfull <= 1'b0;
		spifull <= 1'b0;
		p1reg <= 8'b0;
		p1dir <= 8'b0;
		p2reg <= 8'b0;
		p2dir <= 8'b0;
		intr_ena <= 4'b0;
	end 
	else 
	begin 
		// io space registers 
		if (cpu_wr && cpu_io) 
		begin 
			// if (cpu_addr[7:0] == `UBAUDL_REG)	uartbaud[7:0] <= cpu_dout;
			// if (cpu_addr[7:0] == `UBAUDH_REG)	uartbaud[15:8] <= cpu_dout;
			// if (cpu_addr[7:0] == `P1_DATA_REG)	p1reg <= cpu_dout;
			// if (cpu_addr[7:0] == `P1_DIR_REG)	p1dir <= cpu_dout;
			// if (cpu_addr[7:0] == `P2_DATA_REG)	p2reg <= cpu_dout;
			// if (cpu_addr[7:0] == `P2_DIR_REG)	p2dir <= cpu_dout;
			if (cpu_addr[7:0] == `INTR_EN_REG)	intr_ena <= cpu_dout[3:0];
		end 
		
		// receiver full flag 
		if (rxValid && !rxfull) 
			rxfull <= 1'b1;
		else if (cpu_rd && cpu_io && (cpu_addr[7:0] == `UDATA_REG) && rxfull)
			rxfull <= 1'b0;
	end 
end 
// uart transmit write pulse 
assign txValid = cpu_wr & cpu_io & (cpu_addr[7:0] == `UDATA_REG);
assign spiValid = cpu_wr & cpu_io & (cpu_addr[7:0] == `SPI_TX_REG);

// io space read registers 
always @ (posedge reset or posedge clock) 
begin 
	if (reset) 
	begin 
		io_dout <= 8'b0;
	end 
	else 
	begin 
		// io space read registers 
		if (cpu_io && (cpu_addr[7:0] == `UDATA_REG))
			io_dout <= rxData;
		else if (cpu_io && (cpu_addr[7:0] == `USTAT_REG))
			io_dout <= {3'b0, rxfull, 3'b0, txBusy};
		else if (cpu_io && (cpu_addr[7:0] == `SPI_RX_REG))
			io_dout <= spiRxdata;

//		else if (cpu_io && (cpu_addr[7:0] == `P1_DATA_REG))
//			io_dout <= p1dio;
//		else if (cpu_io && (cpu_addr[7:0] == `P2_DATA_REG))
//			io_dout <= p2dio;
		
		// sampled io control to select cpu data input 
		scpu_io <= cpu_io;
	end 
end 

// interrupt controller 
intr_ctrl intrc 
(
	.clock(clock), 
	.reset(reset),
	.ext_intr(extint), 
	.cpu_intr(cpu_intr), 
	.cpu_inte(cpu_inte), 
	.cpu_inta(cpu_inta), 
	.cpu_rd(cpu_rd), 
	.cpu_inst(intr_dout), 
	.intr_ena(intr_ena) 
);

assign txBusy = ~txDone;

RS232T RS232T(
    .clk(clock), 
    .rst(reset),
    .start(txValid),
    .data(cpu_dout),
    .rdy(txDone),
    .TxD(txd),
);

RS232R RS232R(
    .clk(clock), 
    .rst(reset),
    .rdy(rxValid),
    .done(~rxfull),
    .RxD(rxd),
    .data(rxData)
);

spi_master spi_master(
  .rstb(~reset),
  .clk(clock),
  .mlb(1'b1), // MSB first???
  .start(spiValid),
  .tdat(cpu_dout),
  .cdiv(3), // :32
  .din(din),
  .ss(ss),
  .sck(sck),
  .dout(dout),
  .done(spiFull),
  .rdata(spiRxData)
);

// digital IO ports 
// port 1 
// assign p1dio[0] = p1dir[0] ? p1reg[0] : 1'bz;
// assign p1dio[1] = p1dir[1] ? p1reg[1] : 1'bz;
// assign p1dio[2] = p1dir[2] ? p1reg[2] : 1'bz;
// assign p1dio[3] = p1dir[3] ? p1reg[3] : 1'bz;
// assign p1dio[4] = p1dir[4] ? p1reg[4] : 1'bz;
// assign p1dio[5] = p1dir[5] ? p1reg[5] : 1'bz;
// assign p1dio[6] = p1dir[6] ? p1reg[6] : 1'bz;
// assign p1dio[7] = p1dir[7] ? p1reg[7] : 1'bz;
// port 2 
// assign p2dio[0] = p2dir[0] ? p2reg[0] : 1'bz;
// assign p2dio[1] = p2dir[1] ? p2reg[1] : 1'bz;
// assign p2dio[2] = p2dir[2] ? p2reg[2] : 1'bz;
// assign p2dio[3] = p2dir[3] ? p2reg[3] : 1'bz;
// assign p2dio[4] = p2dir[4] ? p2reg[4] : 1'bz;
// assign p2dio[5] = p2dir[5] ? p2reg[5] : 1'bz;
// assign p2dio[6] = p2dir[6] ? p2reg[6] : 1'bz;
// assign p2dio[7] = p2dir[7] ? p2reg[7] : 1'bz;

endmodule
//---------------------------------------------------------------------------------------
//						Th.. Th.. Th.. Thats all folks !!!
//---------------------------------------------------------------------------------------
