all: ripple.hex

ripple.hex: ripple.asm
	avra ripple.asm

check:
	sudo avrdude -c usbtiny -p attiny4313

fuse:
	sudo avrdude -c usbtiny -p attiny4313 -U lfuse:w:0xe4:m -U hfuse:w:0xd9:m -U efuse:w:0xff:m 

burn: ripple.hex
	sudo avrdude -c usbtiny -p attiny4313 -U flash:w:ripple.hex

clean:
	rm -f ripple.hex ripple.cof ripple.eep.hex ripple.obj
