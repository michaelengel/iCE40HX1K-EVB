A small SoC based on the opencores light8080 SoC by Ruiz and Litochevski,
adapted to run on the OlimeCE40HX1K-EVB board.

Currently, this system only implements:
- light8080 CPU core running at 25 MHz
- Transmit-only UART (115200 bps)
- Memory as block RAM

The CPU core and SoC are licensed under GPL V3 (see COPYING.txt)

The UART core is derived from example code at
https://www.nandland.com/vhdl/modules/module-uart-serial-port-rs232.html

Planned extensions: 
- UART receive
- SRAM interface
- SPI interface for SD card
- CP/M

Enjoy!

-- Michael Engel (engel@multicores.org)

