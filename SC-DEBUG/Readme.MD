# SC-DEBUG Single Stepper 
This board uses Bit 7 of the Refresh register to control single stepping hardware.
When Bit 7 of the Refresh register is set, an interrupt will occur at the end of each instruction
allowing the softrware to display the contents of the registers.
Additionally the contents of the Interrupt register are also latched and can be used as a 
debugging aid.