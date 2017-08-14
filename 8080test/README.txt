A small SoC based on the opencores light8080 SoC by Ruiz and Litochevski,
adapted to run on the OlimeCE40HX1K-EVB board.

Currently, this system only implements:
- light8080 CPU core running at 25 MHz
- Transmit-only UART (now 19200 bps, currently some RX artifacts)
- First try at SPI master interface
- Memory as block RAM

The CPU core and SoC are licensed under GPL V3 (see COPYING.txt)

The UART core is now derived from Niklaus Wirth's Oberon Verilog code at
https://github.com/Spirit-of-Oberon/wirth-personal/blob/master/personal/wirth/FPGA-relatedWork/

Current resource consumption:
- 735 / 1280 LUTs
- 12 / 16 BRAMs

Planned extensions: 
- fix UART receive problem
- SRAM interface
- implement UART bootloader
- reduce the number of BRAMs required by restructuring the microcode
  (eliminate jump table) of the 8080 core
- get CP/M 2.2 up and running (adapt CP/M BIOS)
- play ZORK! :-)

Enjoy!

-- Michael Engel (engel@multicores.org)

