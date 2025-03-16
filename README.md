Hacked ASCOT Projection Clock to display time and temperature 

The clock communicates with the projector using 2 wire serial protocol with clock of 1 kHz

Used TXS0108E to adapt ESP32 GPIO outputs to the projector required 1.5v levels and ESP32 DAC as base 1.5v output.

The clock communicates with the projector with a 5 wire cable using following pinout:

1. VDD
2. GND
3. DATA
4. CLOCK
5. P-LED

The display could not be controlled directly. 

I was able to discover three separate types of commands (see examples in the data dir):

- functions: (24h 12h flip temp) (12 bit - 3 nibbles no checksum)
- temperature (28 bit - 6 nibbles + checksum)
- time (32 bit - 7 nibles + checksum)

Once the time is set the projector continues to work on his own. The time is synced once per minute. 

For precise timing the communication is done using the ULP for both clock and data.

Note that ULP is not enabled by default in Tasmota.

MQTT topic could be defined for control commands:

FLIP                       - to flip the display
TEMP 12.34C or TEMP 12.34F - to set temperature
TOGGLE TEMP                - enable or disable temp mode (toggle between temp and time each 5 seconds)


