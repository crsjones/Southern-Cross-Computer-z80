# Southern Cross GB Cart Adapter

Some bootleg GameBoy cartridges use 4M FLASH chips and 32k SRAM's.
They can be connected directly to the Z80 buses and can be re-flashed using one of the GameBoy  
flashers that are available.

As the cartridge maps across most of the memory map you need to remove the EEPROM and 
RAM from the Southern Cross, you can however connect the EEPROM and RAM socket to the 
undecoded areas of the memory map $8000-$9FFF, $C000- $DFFF and $E000-$FFFF.
You could use both sockets with RAM  with some small modifications to the PCB. 
This will give a total of 24k bytes of RAM in the memory map, with 8k banked as described below.

The Gerbers for the PCB are provided, remember to specify the PCB as 0.8mm thick otherwise the IDC
 connector won't fit over the edge of the PCB.

The information about the cart was supplied to the TEC-1 Z80 Facebook group by Ben Grimmett;
He sells the Flash Cartridges on his website;  https://bennvenn.myshopify.com/

4M FLASH / 32K (NVRAM) SRAM cartridge. MBC5 Mapper.

Memory map:
0x0000-0x3FFF:  16kBytes - fixed to Flash Address 0x0000-0x3FFF

0x4000-0x7FFF:  16kBytes - 4MBytes in 256 banks, swapped by writing to address 0x2000.

0xA000-0xBFFF:    8kBytes - 32kBytes in 8k banks, swapped by writing to 0x4000. 

                 Write protected unless 0x0A written to 0x0000. Protected if any other value is written to that address.



