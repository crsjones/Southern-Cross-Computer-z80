# Southern Cross Computer Monitor

The current version of the monitor is 1.8. 
 Source code, listing, binary and INTEL hex files can be found in the SCMonitorV18 folder under the SouthernCrossSBC_Monitor folder.
The Monitor will work on any version of the Southern Cross PCB and on the TEC-1F and also supports a software scanned keyboard
 if the out of production 74C923 keyboard encoder cannot be sourced.

It can be conditionally built for the following boards:

### SC18-SC
This is the version for a Southern Cross with a 74C923 keyboard encoder.
### SC18-SC-SS
This is the version for a Southern Cross with software scanned keyboard mods.
### SC18-TEC-1F
This is the version for the TEC-1F with a 74C923 keyboard encoder.
### SC18-TEC-1F-SS
This is the version for the TEC-1F with software scanned keyboards mods.

The source file was assembled using TASM32. There is an include (SCM18_Include.asm) file that defines all the Monitor variables 
that can be used in your own programs, an short example of its use is also included in the folder (SCMTest.asm)

### SCMonitorV18_ACIA
A version of the 1.8 Monitor has been patched with the ACIA code from the SC-6850_Serial\Code folder to work with the 6850 ACIA
instead of the Bit Bang Serial Port, only the Source file is provided.

### SCNEO
Built with Buffered Interrupt driven serial communication using the SC-SERIAL ACIA Add-on board.

