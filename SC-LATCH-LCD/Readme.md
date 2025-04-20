# Southern Cross LCD

Using a latch is a common way to connect to a LCD.
The schematic shows how to hook up a 2 line 16 character LCD (1602) to an eight bit latch.
You can hook it up to the SC I/O port at the top of the board or use IC1 to replace the multiplexed 7 segment display.

The code uses the same routines as the monitor uses for the seven segment display but outputs to the LCD instead, also sending the displayed
string out the serial port.
 
The code is a work in progress so the backlight control is currently not implemented and there 
are some additional functions needed to conplete the LCD driver.

