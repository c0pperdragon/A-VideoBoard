EESchema Schematic File Version 2
LIBS:power
LIBS:device
LIBS:transistors
LIBS:conn
LIBS:linear
LIBS:regul
LIBS:74xx
LIBS:cmos4000
LIBS:adc-dac
LIBS:memory
LIBS:xilinx
LIBS:microcontrollers
LIBS:dsp
LIBS:microchip
LIBS:analog_switches
LIBS:motorola
LIBS:texas
LIBS:intel
LIBS:audio
LIBS:interface
LIBS:digital-audio
LIBS:philips
LIBS:display
LIBS:cypress
LIBS:siliconi
LIBS:opto
LIBS:atmel
LIBS:contrib
LIBS:valves
LIBS:components
LIBS:atarimod-cache
EELAYER 25 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 1
Title "Atari mod board"
Date ""
Rev "2"
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
Text GLabel 7800 3400 0    51   Input ~ 0
CLK
Text GLabel 8800 3200 2    51   Input ~ 0
RW
Text GLabel 8800 3300 2    51   Input ~ 0
CS
Text GLabel 8100 2700 0    51   Input ~ 0
D3
Text GLabel 8100 2800 0    51   Input ~ 0
D2
Text GLabel 8100 3000 0    51   Input ~ 0
D0
Text GLabel 8100 2900 0    51   Input ~ 0
D1
Text GLabel 8100 3200 0    51   Input ~ 0
AN1
Text GLabel 8100 3100 0    51   Input ~ 0
AN0
Text GLabel 8100 3300 0    51   Input ~ 0
AN2
Text GLabel 8800 3400 2    51   Input ~ 0
HALT
Text GLabel 8800 3100 2    51   Input ~ 0
D7
Text GLabel 8800 3000 2    51   Input ~ 0
D6
Text GLabel 8800 2900 2    51   Input ~ 0
D5
Text GLabel 8100 2600 0    51   Input ~ 0
A0
Text GLabel 8100 2500 0    51   Input ~ 0
A1
Text GLabel 8800 2500 2    51   Input ~ 0
A2
Text GLabel 8800 2600 2    51   Input ~ 0
A3
Text GLabel 8800 2700 2    51   Input ~ 0
A4
Text GLabel 8800 2800 2    51   Input ~ 0
D4
$Comp
L 74HC14D IC1
U 1 1 59608C85
P 5500 800
F 0 "IC1" H 5450 850 60  0000 C CNN
F 1 "74HC14D" H 5550 750 60  0000 C CNN
F 2 "Housings_SOIC:SOIC-14_3.9x8.7mm_Pitch1.27mm" H 5550 800 60  0001 C CNN
F 3 "" H 5550 800 60  0001 C CNN
	1    5500 800 
	1    0    0    -1  
$EndComp
$Comp
L C_Small C4
U 1 1 59609575
P 2950 6850
F 0 "C4" H 2960 6920 50  0000 L CNN
F 1 "100nF" H 2960 6770 50  0000 L CNN
F 2 "Capacitors_SMD:C_0603_HandSoldering" H 2950 6850 50  0001 C CNN
F 3 "" H 2950 6850 50  0000 C CNN
	1    2950 6850
	-1   0    0    1   
$EndComp
$Comp
L 74HC14D IC2
U 1 1 59609BB1
P 5500 2000
F 0 "IC2" H 5450 2050 60  0000 C CNN
F 1 "74HC14D" H 5550 1950 60  0000 C CNN
F 2 "Housings_SOIC:SOIC-14_3.9x8.7mm_Pitch1.27mm" H 5550 2000 60  0001 C CNN
F 3 "" H 5550 2000 60  0001 C CNN
	1    5500 2000
	1    0    0    -1  
$EndComp
$Comp
L C_Small C3
U 1 1 59609BD6
P 2600 6850
F 0 "C3" H 2610 6920 50  0000 L CNN
F 1 "100nF" H 2610 6770 50  0000 L CNN
F 2 "Capacitors_SMD:C_0603_HandSoldering" H 2600 6850 50  0001 C CNN
F 3 "" H 2600 6850 50  0000 C CNN
	1    2600 6850
	-1   0    0    1   
$EndComp
$Comp
L C_Small C6
U 1 1 5960A791
P 3650 6850
F 0 "C6" H 3660 6920 50  0000 L CNN
F 1 "100nF" H 3660 6770 50  0000 L CNN
F 2 "Capacitors_SMD:C_0603_HandSoldering" H 3650 6850 50  0001 C CNN
F 3 "" H 3650 6850 50  0000 C CNN
	1    3650 6850
	-1   0    0    1   
$EndComp
$Comp
L 74HC14D IC4
U 1 1 5960B79A
P 5500 4250
F 0 "IC4" H 5450 4300 60  0000 C CNN
F 1 "74HC14D" H 5550 4200 60  0000 C CNN
F 2 "Housings_SOIC:SOIC-14_3.9x8.7mm_Pitch1.27mm" H 5550 4250 60  0001 C CNN
F 3 "" H 5550 4250 60  0001 C CNN
	1    5500 4250
	1    0    0    -1  
$EndComp
$Comp
L C_Small C5
U 1 1 5960B7AE
P 3300 6850
F 0 "C5" H 3310 6920 50  0000 L CNN
F 1 "100nF" H 3310 6770 50  0000 L CNN
F 2 "Capacitors_SMD:C_0603_HandSoldering" H 3300 6850 50  0001 C CNN
F 3 "" H 3300 6850 50  0000 C CNN
	1    3300 6850
	-1   0    0    1   
$EndComp
$Comp
L 74HC14D IC3
U 1 1 5960A76D
P 5500 3150
F 0 "IC3" H 5450 3200 60  0000 C CNN
F 1 "74HC14D" H 5550 3100 60  0000 C CNN
F 2 "Housings_SOIC:SOIC-14_3.9x8.7mm_Pitch1.27mm" H 5550 3150 60  0001 C CNN
F 3 "" H 5550 3150 60  0001 C CNN
	1    5500 3150
	1    0    0    -1  
$EndComp
$Comp
L APE8865N-33-HF-3 U2
U 1 1 5960D9B8
P 1700 6550
F 0 "U2" H 1400 6800 50  0000 C CNN
F 1 "APE8865N-33-HF-3" H 1700 6750 50  0000 C CNN
F 2 "TO_SOT_Packages_SMD:SOT-23" H 1700 6650 50  0000 C CIN
F 3 "" H 1700 6550 50  0000 C CNN
	1    1700 6550
	1    0    0    -1  
$EndComp
$Comp
L +3.3V #PWR01
U 1 1 5960DAF2
P 2250 6500
F 0 "#PWR01" H 2250 6350 50  0001 C CNN
F 1 "+3.3V" H 2250 6640 50  0000 C CNN
F 2 "" H 2250 6500 50  0000 C CNN
F 3 "" H 2250 6500 50  0000 C CNN
	1    2250 6500
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR02
U 1 1 5960DB92
P 1700 7250
F 0 "#PWR02" H 1700 7000 50  0001 C CNN
F 1 "GND" H 1700 7100 50  0000 C CNN
F 2 "" H 1700 7250 50  0000 C CNN
F 3 "" H 1700 7250 50  0000 C CNN
	1    1700 7250
	1    0    0    -1  
$EndComp
$Comp
L C_Small C1
U 1 1 5960DC33
P 1100 6750
F 0 "C1" H 1110 6820 50  0000 L CNN
F 1 "10uF" H 1110 6670 50  0000 L CNN
F 2 "Capacitors_SMD:C_0805_HandSoldering" H 1100 6750 50  0001 C CNN
F 3 "" H 1100 6750 50  0000 C CNN
	1    1100 6750
	1    0    0    -1  
$EndComp
$Comp
L C_Small C2
U 1 1 5960E580
P 2200 6750
F 0 "C2" H 2210 6820 50  0000 L CNN
F 1 "10uF" H 2210 6670 50  0000 L CNN
F 2 "Capacitors_SMD:C_0805_HandSoldering" H 2200 6750 50  0001 C CNN
F 3 "" H 2200 6750 50  0000 C CNN
	1    2200 6750
	1    0    0    -1  
$EndComp
Text GLabel 5050 1050 0    51   Input ~ 0
A1
Text GLabel 5050 1250 0    51   Input ~ 0
A0
Text GLabel 5050 2250 0    51   Input ~ 0
D3
Text GLabel 5050 2450 0    51   Input ~ 0
D2
Text GLabel 5050 2650 0    51   Input ~ 0
D1
Text GLabel 5050 3400 0    51   Input ~ 0
D0
Text GLabel 5050 4500 0    51   Input ~ 0
AN0
Text GLabel 5050 4700 0    51   Input ~ 0
AN1
Text GLabel 5050 4900 0    51   Input ~ 0
AN2
Text GLabel 6250 1150 2    51   Input ~ 0
A2
Text GLabel 6250 1350 2    51   Input ~ 0
A3
Text GLabel 6250 1550 2    51   Input ~ 0
A4
Text GLabel 6250 2350 2    51   Input ~ 0
D4
Text GLabel 6250 2550 2    51   Input ~ 0
D5
Text GLabel 6250 2750 2    51   Input ~ 0
D6
Text GLabel 6250 3500 2    51   Input ~ 0
D7
Text GLabel 6250 3700 2    51   Input ~ 0
RW
Text GLabel 6250 3900 2    51   Input ~ 0
CS
Text GLabel 6200 4600 2    51   Input ~ 0
CLK
Text GLabel 6200 4800 2    51   Input ~ 0
HALT
$Comp
L PWR_FLAG #FLG03
U 1 1 596132DF
P 1500 5950
F 0 "#FLG03" H 1500 6045 50  0001 C CNN
F 1 "PWR_FLAG" H 1500 6130 50  0000 C CNN
F 2 "" H 1500 5950 50  0000 C CNN
F 3 "" H 1500 5950 50  0000 C CNN
	1    1500 5950
	1    0    0    -1  
$EndComp
$Comp
L PWR_FLAG #FLG04
U 1 1 596135A4
P 2050 7250
F 0 "#FLG04" H 2050 7345 50  0001 C CNN
F 1 "PWR_FLAG" H 2050 7430 50  0000 C CNN
F 2 "" H 2050 7250 50  0000 C CNN
F 3 "" H 2050 7250 50  0000 C CNN
	1    2050 7250
	-1   0    0    1   
$EndComp
$Comp
L +5V #PWR05
U 1 1 5961413C
P 1100 5950
F 0 "#PWR05" H 1100 5800 50  0001 C CNN
F 1 "+5V" H 1100 6090 50  0000 C CNN
F 2 "" H 1100 5950 50  0000 C CNN
F 3 "" H 1100 5950 50  0000 C CNN
	1    1100 5950
	1    0    0    -1  
$EndComp
$Comp
L CONN_02X10 P2
U 1 1 5A2D6700
P 8450 2950
F 0 "P2" H 8450 3500 50  0000 C CNN
F 1 "CONN_02X10" V 8450 2950 50  0000 C CNN
F 2 "Pin_Headers:Pin_Header_Angled_2x10_Pitch2.54mm" H 8450 1750 50  0001 C CNN
F 3 "" H 8450 1750 50  0000 C CNN
	1    8450 2950
	1    0    0    -1  
$EndComp
$Comp
L R_Small R10
U 1 1 5A2D9629
P 8000 3400
F 0 "R10" H 8030 3420 50  0000 L CNN
F 1 "100" H 8030 3360 50  0000 L CNN
F 2 "Resistors_SMD:R_0805_HandSoldering" H 8000 3400 50  0001 C CNN
F 3 "" H 8000 3400 50  0000 C CNN
	1    8000 3400
	0    1    1    0   
$EndComp
$Comp
L +3.3V #PWR06
U 1 1 5A30002C
P 6000 750
F 0 "#PWR06" H 6000 600 50  0001 C CNN
F 1 "+3.3V" H 6000 890 50  0000 C CNN
F 2 "" H 6000 750 50  0000 C CNN
F 3 "" H 6000 750 50  0000 C CNN
	1    6000 750 
	1    0    0    -1  
$EndComp
$Comp
L +3.3V #PWR07
U 1 1 5A300104
P 6000 1950
F 0 "#PWR07" H 6000 1800 50  0001 C CNN
F 1 "+3.3V" H 6000 2090 50  0000 C CNN
F 2 "" H 6000 1950 50  0000 C CNN
F 3 "" H 6000 1950 50  0000 C CNN
	1    6000 1950
	1    0    0    -1  
$EndComp
$Comp
L +3.3V #PWR08
U 1 1 5A300284
P 6000 3150
F 0 "#PWR08" H 6000 3000 50  0001 C CNN
F 1 "+3.3V" H 6000 3290 50  0000 C CNN
F 2 "" H 6000 3150 50  0000 C CNN
F 3 "" H 6000 3150 50  0000 C CNN
	1    6000 3150
	1    0    0    -1  
$EndComp
$Comp
L +3.3V #PWR09
U 1 1 5A3003A2
P 6000 4250
F 0 "#PWR09" H 6000 4100 50  0001 C CNN
F 1 "+3.3V" H 6000 4390 50  0000 C CNN
F 2 "" H 6000 4250 50  0000 C CNN
F 3 "" H 6000 4250 50  0000 C CNN
	1    6000 4250
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR010
U 1 1 5A300740
P 5100 5150
F 0 "#PWR010" H 5100 4900 50  0001 C CNN
F 1 "GND" H 5100 5000 50  0000 C CNN
F 2 "" H 5100 5150 50  0000 C CNN
F 3 "" H 5100 5150 50  0000 C CNN
	1    5100 5150
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR011
U 1 1 5A300834
P 5050 4050
F 0 "#PWR011" H 5050 3800 50  0001 C CNN
F 1 "GND" H 5050 3900 50  0000 C CNN
F 2 "" H 5050 4050 50  0000 C CNN
F 3 "" H 5050 4050 50  0000 C CNN
	1    5050 4050
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR012
U 1 1 5A3008C6
P 5100 2950
F 0 "#PWR012" H 5100 2700 50  0001 C CNN
F 1 "GND" H 5100 2800 50  0000 C CNN
F 2 "" H 5100 2950 50  0000 C CNN
F 3 "" H 5100 2950 50  0000 C CNN
	1    5100 2950
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR013
U 1 1 5A3009C8
P 5050 1750
F 0 "#PWR013" H 5050 1500 50  0001 C CNN
F 1 "GND" H 5050 1600 50  0000 C CNN
F 2 "" H 5050 1750 50  0000 C CNN
F 3 "" H 5050 1750 50  0000 C CNN
	1    5050 1750
	1    0    0    -1  
$EndComp
$Comp
L CONN_02X20 P1
U 1 1 5A301E2A
P 2950 3000
F 0 "P1" H 2950 4050 50  0000 C CNN
F 1 "CONN_02X20" V 2950 3000 50  0000 C CNN
F 2 "Pin_Headers:Pin_Header_Straight_2x20_Pitch2.54mm" H 2950 2050 50  0001 C CNN
F 3 "" H 2950 2050 50  0000 C CNN
	1    2950 3000
	1    0    0    -1  
$EndComp
$Comp
L GND #PWR014
U 1 1 5A302918
P 2300 2300
F 0 "#PWR014" H 2300 2050 50  0001 C CNN
F 1 "GND" H 2300 2150 50  0000 C CNN
F 2 "" H 2300 2300 50  0000 C CNN
F 3 "" H 2300 2300 50  0000 C CNN
	1    2300 2300
	1    0    0    -1  
$EndComp
NoConn ~ 3200 3950
NoConn ~ 3200 3850
NoConn ~ 3200 3750
NoConn ~ 3200 3650
NoConn ~ 3200 3550
NoConn ~ 2700 3650
NoConn ~ 2700 3550
NoConn ~ 2700 3450
NoConn ~ 2700 3350
NoConn ~ 2700 3250
NoConn ~ 2700 3150
NoConn ~ 2700 3050
NoConn ~ 2700 2950
NoConn ~ 2700 2850
NoConn ~ 2700 2750
$Comp
L +5V #PWR015
U 1 1 5A303009
P 3550 3350
F 0 "#PWR015" H 3550 3200 50  0001 C CNN
F 1 "+5V" H 3550 3490 50  0000 C CNN
F 2 "" H 3550 3350 50  0000 C CNN
F 3 "" H 3550 3350 50  0000 C CNN
	1    3550 3350
	1    0    0    -1  
$EndComp
NoConn ~ 3200 3250
NoConn ~ 3200 2950
Wire Wire Line
	2150 6500 2250 6500
Wire Wire Line
	2200 6650 2200 6500
Connection ~ 2200 6500
Wire Wire Line
	1100 6500 1250 6500
Connection ~ 1100 6500
Wire Wire Line
	1700 6850 1700 7250
Wire Wire Line
	2050 7200 2050 7250
Wire Wire Line
	1100 7200 3650 7200
Connection ~ 1700 7200
Wire Wire Line
	2200 7200 2200 6850
Connection ~ 2050 7200
Wire Wire Line
	1100 6850 1100 7200
Wire Wire Line
	1100 5950 1100 6650
Wire Wire Line
	1500 5950 1500 6100
Wire Wire Line
	1500 6100 1100 6100
Connection ~ 1100 6100
Wire Wire Line
	2200 6500 3650 6500
Wire Wire Line
	2600 6500 2600 6750
Wire Wire Line
	2950 6500 2950 6750
Connection ~ 2600 6500
Wire Wire Line
	3300 6500 3300 6750
Connection ~ 2950 6500
Wire Wire Line
	3650 6500 3650 6750
Connection ~ 3300 6500
Wire Wire Line
	2600 7200 2600 6950
Connection ~ 2200 7200
Wire Wire Line
	2950 7200 2950 6950
Connection ~ 2600 7200
Wire Wire Line
	3300 7200 3300 6950
Connection ~ 2950 7200
Wire Wire Line
	3650 7200 3650 6950
Connection ~ 3300 7200
Wire Wire Line
	5100 2750 5100 2950
Wire Wire Line
	5100 5000 5100 5150
Wire Wire Line
	6000 4400 6000 4250
Wire Wire Line
	6000 3300 6000 3150
Wire Wire Line
	6000 2150 6000 1950
Wire Wire Line
	6000 950  6000 750 
Wire Wire Line
	2700 2250 2300 2250
Wire Wire Line
	2300 2250 2300 2300
Wire Wire Line
	3200 3350 3550 3350
Wire Wire Line
	2700 2050 2650 2050
Wire Wire Line
	2650 2050 2650 1850
Wire Wire Line
	2650 1850 4200 1850
Wire Wire Line
	4200 1850 4200 950 
Wire Wire Line
	4200 950  5100 950 
Wire Wire Line
	3200 2050 4250 2050
Wire Wire Line
	4250 2050 4250 1100
Wire Wire Line
	4250 1100 6100 1100
Wire Wire Line
	6100 1100 6100 1050
Wire Wire Line
	6100 1050 6000 1050
Wire Wire Line
	2700 2150 2650 2150
Wire Wire Line
	2650 2150 2650 2100
Wire Wire Line
	2650 2100 4300 2100
Wire Wire Line
	4300 2100 4300 1150
Wire Wire Line
	4300 1150 5100 1150
Wire Wire Line
	3200 2150 4350 2150
Wire Wire Line
	4350 2150 4350 1300
Wire Wire Line
	4350 1300 6100 1300
Wire Wire Line
	6100 1300 6100 1250
Wire Wire Line
	6100 1250 6000 1250
Wire Wire Line
	2700 2450 2650 2450
Wire Wire Line
	2650 2450 2650 2400
Wire Wire Line
	6100 2300 6100 2250
Wire Wire Line
	6100 2250 6000 2250
Wire Wire Line
	2700 2550 2650 2550
Wire Wire Line
	2650 2550 2650 2500
Wire Wire Line
	6100 2500 6100 2450
Wire Wire Line
	6100 2450 6000 2450
Wire Wire Line
	6100 2700 6100 2650
Wire Wire Line
	6100 2650 6000 2650
Wire Wire Line
	2700 3750 2650 3750
Wire Wire Line
	2650 3750 2650 3800
Wire Wire Line
	2650 3800 4100 3800
Wire Wire Line
	2700 3850 2650 3850
Wire Wire Line
	2650 3850 2650 3900
Wire Wire Line
	2650 3900 4050 3900
Wire Wire Line
	2700 3950 2650 3950
Wire Wire Line
	2650 3950 2650 4000
Wire Wire Line
	2650 4000 4000 4000
Wire Wire Line
	6000 1150 6250 1150
Wire Wire Line
	5050 1050 5100 1050
Wire Wire Line
	5100 1250 5050 1250
Wire Wire Line
	6000 1350 6250 1350
Wire Wire Line
	3200 2250 4450 2250
Wire Wire Line
	4450 2250 4450 1500
Wire Wire Line
	4450 1500 6100 1500
Wire Wire Line
	6100 1500 6100 1450
Wire Wire Line
	6100 1450 6000 1450
Wire Wire Line
	6000 1550 6250 1550
NoConn ~ 5100 1450
Wire Wire Line
	5100 1350 5050 1350
Wire Wire Line
	5050 1350 5050 1750
Wire Wire Line
	5100 1550 5050 1550
Connection ~ 5050 1550
Wire Wire Line
	2650 2350 2700 2350
Wire Wire Line
	2650 2300 4550 2300
Wire Wire Line
	4550 2300 4550 2150
Wire Wire Line
	4550 2150 5100 2150
Wire Wire Line
	3200 2350 4600 2350
Wire Wire Line
	4600 2350 4600 2300
Wire Wire Line
	4600 2300 6100 2300
Wire Wire Line
	2650 2400 4650 2400
Wire Wire Line
	4650 2400 4650 2350
Wire Wire Line
	4650 2350 5100 2350
Wire Wire Line
	3200 2450 4700 2450
Wire Wire Line
	4700 2450 4700 2500
Wire Wire Line
	4700 2500 6100 2500
Wire Wire Line
	2650 2500 4600 2500
Wire Wire Line
	4600 2500 4600 2550
Wire Wire Line
	4600 2550 5100 2550
Wire Wire Line
	3200 2550 4550 2550
Wire Wire Line
	4550 2550 4550 2700
Wire Wire Line
	4550 2700 6100 2700
Wire Wire Line
	2650 2350 2650 2300
Wire Wire Line
	5050 2250 5100 2250
Wire Wire Line
	6000 2350 6250 2350
Wire Wire Line
	5050 2450 5100 2450
Wire Wire Line
	6000 2550 6250 2550
Wire Wire Line
	5050 2650 5100 2650
Wire Wire Line
	6000 2750 6250 2750
Wire Wire Line
	4000 4000 4000 4800
Wire Wire Line
	4000 4800 5100 4800
Wire Wire Line
	4050 3900 4050 4600
Wire Wire Line
	4050 4600 5100 4600
Wire Wire Line
	4100 3800 4100 4400
Wire Wire Line
	4100 4400 5100 4400
Wire Wire Line
	4250 4450 6100 4450
Wire Wire Line
	6100 4450 6100 4500
Wire Wire Line
	6100 4500 6000 4500
Wire Wire Line
	3200 3450 4200 3450
Wire Wire Line
	4200 4650 6100 4650
Wire Wire Line
	6100 4650 6100 4700
Wire Wire Line
	6100 4700 6000 4700
Wire Wire Line
	4200 3450 4200 4650
Wire Wire Line
	4250 3150 4250 4450
Wire Wire Line
	3200 2650 4400 2650
Wire Wire Line
	4400 3450 6100 3450
Wire Wire Line
	6100 3450 6100 3400
Wire Wire Line
	6100 3400 6000 3400
Wire Wire Line
	3200 2750 4350 2750
Wire Wire Line
	4350 3650 6100 3650
Wire Wire Line
	6100 3650 6100 3600
Wire Wire Line
	6100 3600 6000 3600
Wire Wire Line
	3200 2850 4300 2850
Wire Wire Line
	4300 2850 4300 3850
Wire Wire Line
	4300 3850 6100 3850
Wire Wire Line
	6100 3850 6100 3800
Wire Wire Line
	6100 3800 6000 3800
Wire Wire Line
	4350 2750 4350 3650
Wire Wire Line
	4400 2650 4400 3450
Wire Wire Line
	2700 2650 2650 2650
Wire Wire Line
	2650 2650 2650 2600
Wire Wire Line
	2650 2600 4450 2600
Wire Wire Line
	4450 2600 4450 3300
Wire Wire Line
	4450 3300 5100 3300
NoConn ~ 5100 3600
NoConn ~ 5100 3800
Wire Wire Line
	5050 3400 5100 3400
Wire Wire Line
	6000 3500 6250 3500
Wire Wire Line
	6250 3700 6000 3700
Wire Wire Line
	6000 3900 6250 3900
Wire Wire Line
	6000 4600 6200 4600
Wire Wire Line
	6000 4800 6200 4800
Wire Wire Line
	5050 4500 5100 4500
Wire Wire Line
	5050 4700 5100 4700
Wire Wire Line
	5050 4900 5100 4900
NoConn ~ 6000 5000
Wire Wire Line
	5050 3500 5050 4050
Wire Wire Line
	5050 3900 5100 3900
Wire Wire Line
	5050 3700 5100 3700
Connection ~ 5050 3900
Wire Wire Line
	5050 3500 5100 3500
Connection ~ 5050 3700
Wire Wire Line
	5100 5100 6100 5100
Wire Wire Line
	6100 5100 6100 4900
Wire Wire Line
	6100 4900 6000 4900
Connection ~ 5100 5100
Wire Wire Line
	8100 2500 8200 2500
Wire Wire Line
	8100 2600 8200 2600
Wire Wire Line
	8100 2700 8200 2700
Wire Wire Line
	8100 2800 8200 2800
Wire Wire Line
	8100 2900 8200 2900
Wire Wire Line
	8100 3000 8200 3000
Wire Wire Line
	8100 3100 8200 3100
Wire Wire Line
	8100 3200 8200 3200
Wire Wire Line
	8100 3300 8200 3300
Wire Wire Line
	8100 3400 8200 3400
Wire Wire Line
	7800 3400 7900 3400
Wire Wire Line
	8700 3400 8800 3400
Wire Wire Line
	8700 3300 8800 3300
Wire Wire Line
	8700 3200 8800 3200
Wire Wire Line
	8700 3100 8800 3100
Wire Wire Line
	8700 3000 8800 3000
Wire Wire Line
	8700 2900 8800 2900
Wire Wire Line
	8700 2800 8800 2800
Wire Wire Line
	8700 2700 8800 2700
Wire Wire Line
	8700 2600 8800 2600
Wire Wire Line
	8700 2500 8800 2500
Wire Wire Line
	3200 3150 4250 3150
NoConn ~ 3200 3050
$EndSCHEMATC