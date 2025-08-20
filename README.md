Hacked ASCOT Projection Clock to Display Time and Temperature

The clock communicates with the projector using a 2-wire serial protocol with a clock speed of 1 kHz.

Used TXS0108E to adapt ESP32 GPIO outputs to the projector's required 1.5V levels.
For 1.5V bias input, a voltage divider was built using 1.2kΩ to 3.3V and 1kΩ to ground.

The clock communicates with the projector with a 5-wire cable using the following pinout:

```
1. VDD
2. GND
3. DATA
4. CLOCK
5. P-LED
```

The display could not be controlled directly.

I was able to discover three separate types of commands (see examples in the data dir):

- Functions: (24h/12h, flip, temp) (12 bits - 3 nibbles, no checksum)
- Temperature (28 bits - 6 nibbles + checksum)
- Time (32 bits - 7 nibbles + checksum)

Once the time is set, the projector continues to work on its own. The time is synced once per minute.

For precise timing, the communication is done using the ULP for both clock and data.

Note that ULP is not enabled by default in Tasmota.

There are two separate ULP implementations - for ESP32-S3 in C (ulp_riscv/ulp_main.c) and for ESP32 in assembler (ulp_esp32.py - esp32 branch).
To compile the ULP C code, install ESP-IDF as described [here](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/get-started/linux-macos-setup.html) and execute `ulp.sh`, which will output the compiled ULP code and global variables.

An MQTT topic (`clock_message_topic`) could be defined for control commands:

- `FLIP` - to flip the display
- `TIME 2245` - to set time
- `TEMP 12.34C` or `TEMP 12.34F` - to set temperature
- `TOGGLE TEMP` - enable or disable temp mode (toggle between temp and time every 5 seconds)

