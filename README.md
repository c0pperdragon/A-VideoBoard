# A-Video Board

A small FPGA board with a component video interface to directly drive
an analog monitor or TV input.
Its main purpose is to create component video / RGB mods of vintage
home computers and consoles.

It consists of the purest minimum parts necessary to have a multi-purpose
FPGA combined with a simple way to generate a YPbPr signal. After much research
I finally settled on a cheap MAX 10 device in a TQFP-144 package which I can 
solder by hand (barely). The rest of the parts are pretty cheap and quite easy to solder. 

To interface any of the vintage systems to the A-Video Board, level shifters
are necessary to translate the 5 volt to 3.3 volt for the FPGA input pins. These level
shifters need to be implemented in a system specific daughter board that can be stacked
on top of the A-Video board. Any such interface board can probably be implemented in a 
simple single-sided wide-pitch PCB that can be even home-etched with some experience.

Inside this github repository, there are subfolders for each specific vintage system
(starting with the ZX Spectrum) that contains the electronics schematics and layouts and
the appropriate FPGA code and firmware.
