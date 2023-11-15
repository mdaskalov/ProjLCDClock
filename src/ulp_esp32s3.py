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
#define RTC_IO_TOUCH_PAD2_REG       (DR_REG_RTCIO_BASE + 0x8C)
#define RTC_IO_TOUCH_PAD2_MUX_SEL_M (BIT(19))
#define RTC_GPIO_OUT_REG            (DR_REG_RTCIO_BASE + 0x0)
#define RTC_GPIO_ENABLE_REG         (DR_REG_RTCIO_BASE + 0xC)
#define RTC_GPIO_ENABLE_S           10
#define RTC_GPIO_OUT_DATA_S         10

# constants from:
# https://github.com/espressif/esp-idf/blob/v5.0.2/components/soc/esp32s3/include/soc/rtc_io_channel.h
#define RTCIO_GPIO1_CHANNEL         1   //RTCIO_CHANNEL_1
#define RTCIO_GPIO2_CHANNEL         2   //RTCIO_CHANNEL_2

# When accessed from the RTC module (ULP) GPIOs need to be addressed by their channel number
.set dat, RTCIO_GPIO1_CHANNEL
.set clk, RTCIO_GPIO2_CHANNEL

.set token, 0xcafe  # magic token

.text
  jump entry

magic:   .long 0 # ULP.get_mem(1)
data_hi: .long 0 # ULP.get_mem(2)
mask_hi: .long 0 # ULP.get_mem(3)
data_lo: .long 0 # ULP.get_mem(4)
mask_lo: .long 0 # ULP.get_mem(5)

.global entry
entry:
  # load magic flag
  move r0, magic
  ld r1, r0, 0

  # test if we have initialised already
  sub r1, r1, token
  jump submit, eq  # jump if magic == token (note: "eq" means the last instruction (sub) resulted in 0)

init:
  # connect GPIO to ULP (0: GPIO connected to digital GPIO module, 1: GPIO connected to analog RTC module)
  WRITE_RTC_REG(RTC_IO_TOUCH_PAD2_REG, RTC_IO_TOUCH_PAD2_MUX_SEL_M, 1, 1);

  # GPIO shall be output, not input (this also enables a pull-down by default)
  WRITE_RTC_REG(RTC_GPIO_ENABLE_REG, RTC_GPIO_ENABLE_S + dat, 1, 1)
  WRITE_RTC_REG(RTC_GPIO_ENABLE_REG, RTC_GPIO_ENABLE_S + clk, 1, 1)

  # reset both GPIOs
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)

  # store that we're done with initialisation
  move r0, magic
  move r1, token
  st r1, r0, 0

submit:
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
  # 1us approx 8,687755102 cycles
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 1)
  wait 4209
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 1)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  wait 8471
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 1)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 1)
  wait 4209
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
data:
  and r2, r1, r0
  jump off, eq
on:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 1)
  jump clock_toggle
off:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  jump clock_toggle
clock_toggle:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  wait 4209
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 1)
  wait 4209
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
  jump data

stop:
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + dat, 1, 0)
  WRITE_RTC_REG(RTC_GPIO_OUT_REG, RTC_GPIO_OUT_DATA_S + clk, 1, 0)
  halt  # go back to sleep until next wakeup period
"""
binary = src_to_binary(source, cpu="esp32s2")

# Export section for Berry
code_b64 = ubinascii.b2a_base64(binary).decode('utf-8')[:-1]

print("")
print("#You can paste the following snippet into Tasmotas Berry console:")
print("import ULP")
print("ULP.wake_period(0,1000000) # start")
print("ULP.wake_period(1,490) # short")
print("ULP.wake_period(2,975) # long")
print("ULP.gpio_init(1, 1)")
print("ULP.gpio_init(2, 1)")
print("ULP.set_mem(2, 0x30F)")
print("ULP.set_mem(3, 0x800)")
print("var c = bytes().fromb64(\""+code_b64+"\")")
print("ULP.load(c)")
print("ULP.run()")
