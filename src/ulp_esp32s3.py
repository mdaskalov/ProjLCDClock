"""
Projecting LCD clock with exporting ULP code to Tasmotas Berry implementation
"""
from esp32_ulp import src_to_binary
import ubinascii

source = """\
# constants from:
# https://github.com/espressif/esp-idf/blob/v5.0.2/components/soc/esp32s3/include/soc/reg_base.h
#define DR_REG_RTCIO_BASE                       0x60008400

# constants from:
# https://github.com/espressif/esp-idf/blob/v5.0.2/components/soc/esp32s3/include/soc/rtc_io_reg.h
#define RTC_GPIO_OUT_REG          (DR_REG_RTCIO_BASE + 0x0)
#define RTC_GPIO_OUT_DATA_S       10

# constants from:
# https://github.com/espressif/esp-idf/blob/v5.0.2/components/soc/esp32s3/include/soc/rtc_io_channel.h
#define RTCIO_GPIO17_CHANNEL        17   //RTCIO_CHANNEL_17
#define RTCIO_GPIO18_CHANNEL        18   //RTCIO_CHANNEL_18

# When accessed from the RTC module (ULP) GPIOs need to be addressed by their channel number
.set dat, RTCIO_GPIO17_CHANNEL
.set clk, RTCIO_GPIO18_CHANNEL

.text
  jump entry

data_lo: .long 0 # ULP.get_mem(1)
mask_lo: .long 0 # ULP.get_mem(2)
data_hi: .long 0 # ULP.get_mem(3)
mask_hi: .long 0 # ULP.get_mem(4)

.global entry
entry:
  # load mask_hi packet in R0
  move r2, mask_hi
  ld r0, r2, 0

  # stop if mask_hi is zero
  jumpr stop, 0, EQ

  # reset mask_hi
  move r1, 0
  st r1, r2, 0

  # load data_hi packet in R1
  move r2, data_hi
  ld r1, r2, 0

start:
  # 1µs approx 8,687755102 cycles
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 1)
  wait 4220 # 488µs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 1)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  wait 8471 # 2*488µs = 976µs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 1)
  wait 4230 # 488µs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  wait 43
  jump first_bit

data:
  and r2, r1, r0
  jump off, eq

  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 1)
  jump clock_toggle
off:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  wait 1

clock_toggle:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  wait 4185 # 488µs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 1)
  wait 4232 # 488µs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  rsh r0, r0, 1
  jumpr data, 0, GT

  # load mask_lo packet in R0
  move r2, mask_lo
  ld r0, r2, 0

  # stop if mask_lo is zero
  jumpr stop, 0, EQ

  # reset mask_lo
  move r1, 0
  st r1, r2, 0

  # load data_lo packet in R1
  move r2, data_lo
  ld r1, r2, 0

first_bit:
  and r2, r1, r0
  jump first_bit_off, eq

  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 1)
  jump first_bit_clock_toggle

first_bit_off:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  wait 1

first_bit_clock_toggle:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  wait 4142 # 488µs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 1)
  wait 4232 # 488µs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  rsh r0, r0, 1
  jumpr data, 0, GT

stop:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  halt  # go back to sleep until next wakeup period
"""
binary = src_to_binary(source, cpu="esp32s2")

# Export section for Berry
code_b64 = ubinascii.b2a_base64(binary).decode("utf-8")[:-1]

print("# You can paste the following snippet into Tasmotas Berry console:")
print("import ULP")
print("ULP.wake_period(0,1000) # update each 1s")
print("ULP.set_mem(1,0) # data_lo")
print("ULP.set_mem(2,0) # mask_lo")
print("ULP.set_mem(3,0) # data_hi")
print("ULP.set_mem(4,0) # mask_hi")
print("ULP.gpio_init(17, 1)")
print("ULP.gpio_init(18, 1)")
print('var c = bytes().fromb64("' + code_b64 + '")')
print("ULP.load(c)")
print("ULP.run()")
print("# transmit 12:34 (A: 1,2,3,4,0,0) 584C2005 -> 584C:8000 2005:8000")
print("ULP.set_mem(1,0x2005) # data_lo")
print("ULP.set_mem(2,0x8000) # mask_lo")
print("ULP.set_mem(3,0x584C) # data_hi")
print("ULP.set_mem(4,0x8000) # mask_hi (start)")
