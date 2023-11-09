import string

class SerialLCD
  var PIN_DIO
  var PIN_CLK

  var packet

  def init()
    self.PIN_DIO = 1
    self.PIN_CLK = 2
    self.packet = []
    gpio.pin_mode(self.PIN_DIO, gpio.OUTPUT)
    gpio.pin_mode(self.PIN_CLK, gpio.OUTPUT)
    gpio.digital_write(self.PIN_DIO, 0)
    gpio.digital_write(self.PIN_CLK, 0)
    #tasmota.add_fast_loop(/-> self.fast_loop())
  end

  def deinit()
    self.del()
  end

  def del()
    #tasmota.remove_fast_loop(/-> self.fast_loop())
  end

  def delay(cnt)
    for i:0..cnt
    end
  end

  def start()
    gpio.digital_write(self.PIN_DIO, 0)
    gpio.digital_write(self.PIN_CLK, 1)
    self.delay(90)
    gpio.digital_write(self.PIN_DIO, 1)
    gpio.digital_write(self.PIN_CLK, 0)
    self.delay(500)
    gpio.digital_write(self.PIN_DIO, 1)
    gpio.digital_write(self.PIN_CLK, 1)
    self.delay(210)
    gpio.digital_write(self.PIN_CLK, 0)
  end

  def stop()
    gpio.digital_write(self.PIN_CLK, 0)
    gpio.digital_write(self.PIN_DIO, 0)
  end

  def write_bit(bitval)
    # print(f"{bitval}")
    # return
    gpio.digital_write(self.PIN_DIO, bitval)
    gpio.digital_write(self.PIN_CLK, 0)
    self.delay(210)
    gpio.digital_write(self.PIN_CLK, 1)
    self.delay(225)
    gpio.digital_write(self.PIN_CLK, 0)
  end

  def send_packet()
    if self.packet.size() == 0
      return
    end
    # start
    gpio.digital_write(self.PIN_DIO, 0)
    gpio.digital_write(self.PIN_CLK, 1)
    self.delay(250)
    gpio.digital_write(self.PIN_DIO, 1)
    gpio.digital_write(self.PIN_CLK, 0)
    self.delay(520)
    gpio.digital_write(self.PIN_DIO, 1)
    gpio.digital_write(self.PIN_CLK, 1)
    self.delay(210)
    gpio.digital_write(self.PIN_CLK, 0)
    while self.packet.size() != 0
      var bit = self.packet.pop()
      # print(f"{bit}")
      gpio.digital_write(self.PIN_DIO, bit)
      gpio.digital_write(self.PIN_CLK, 0)
      self.delay(192)
      gpio.digital_write(self.PIN_CLK, 1)
      self.delay(230)
      gpio.digital_write(self.PIN_CLK, 0)
    end
    #stop
    gpio.digital_write(self.PIN_CLK, 0)
    gpio.digital_write(self.PIN_DIO, 0)
  end

  def write(data, bits)
    if bits < 0 || bits >32
      return
    end
    self.packet.clear()
    for bit: 0..bits-1
      var bitval = (1 << bit) & data == 0 ? 0 : 1
      self.packet.push(bitval)
    end
    self.send_packet()
  end

  def h24()
    self.set_cmd(0)
  end

  def h12()
    self.set_cmd(2)
  end

  def flip()
    self.set_cmd(4)
  end

  def temp()
    self.set_cmd(8)
  end

  def set_cmd(c)
    var cn = self.swap_nibble(c)
    var cs = (c & 0xf) ^ 0xf
    var csn = self.swap_nibble(cs)

    print(string.hex(cn),string.hex(csn))

    var cb1 = (c & 0x1) == 0 ? 0 : 1
    var cb2 = (c & 0x2) == 0 ? 0 : 1
    var cb3 = (c & 0x4) == 0 ? 0 : 1
    var cb4 = (c & 0x8) == 0 ? 0 : 1

    var csb1 = (cs & 0x1) == 0 ? 0 : 1
    var csb2 = (cs & 0x2) == 0 ? 0 : 1
    var csb3 = (cs & 0x4) == 0 ? 0 : 1
    var csb4 = (cs & 0x8) == 0 ? 0 : 1

    self.start()
    #cmd
    self.write_bit(0)
    self.write_bit(0)
    self.write_bit(1)
    self.write_bit(1)
    #c
    self.write_bit(cb1)
    self.write_bit(cb2)
    self.write_bit(cb3)
    self.write_bit(cb4)
    #cs
    self.write_bit(csb1)
    self.write_bit(csb2)
    self.write_bit(csb3)
    self.write_bit(csb4)
    self.stop()
  end

  def set_time(h,m,s)
    var h1 = h / 10
    var h2 = h % 10
    var m1 = m / 10
    var m2 = m % 10
    var s1 = s / 10
    var s2 = s % 10

    var cs = (h1 + h2 + m1 + m2 + s1 + s2) & 0xf

    var h1n = self.swap_nibble(h1)
    var h2n = self.swap_nibble(h2)
    var m1n = self.swap_nibble(m1)
    var m2n = self.swap_nibble(m2)
    var s1n = self.swap_nibble(s1)
    var s2n = self.swap_nibble(s2)
    var csn = self.swap_nibble(cs)

    print(string.hex(h1n),string.hex(h2n),string.hex(m1n),string.hex(m2n),string.hex(s1n),string.hex(s2n),string.hex(csn))

    var h1b1 = (h1 & 0x1) == 0 ? 0 : 1
    var h1b2 = (h1 & 0x2) == 0 ? 0 : 1
    var h1b3 = (h1 & 0x4) == 0 ? 0 : 1
    var h1b4 = (h1 & 0x8) == 0 ? 0 : 1

    var h2b1 = (h2 & 0x1) == 0 ? 0 : 1
    var h2b2 = (h2 & 0x2) == 0 ? 0 : 1
    var h2b3 = (h2 & 0x4) == 0 ? 0 : 1
    var h2b4 = (h2 & 0x8) == 0 ? 0 : 1

    var m1b1 = (m1 & 0x1) == 0 ? 0 : 1
    var m1b2 = (m1 & 0x2) == 0 ? 0 : 1
    var m1b3 = (m1 & 0x4) == 0 ? 0 : 1
    var m1b4 = (m1 & 0x8) == 0 ? 0 : 1

    var m2b1 = (m2 & 0x1) == 0 ? 0 : 1
    var m2b2 = (m2 & 0x2) == 0 ? 0 : 1
    var m2b3 = (m2 & 0x4) == 0 ? 0 : 1
    var m2b4 = (m2 & 0x8) == 0 ? 0 : 1

    var s1b1 = (s1 & 0x1) == 0 ? 0 : 1
    var s1b2 = (s1 & 0x2) == 0 ? 0 : 1
    var s1b3 = (s1 & 0x4) == 0 ? 0 : 1
    var s1b4 = (s1 & 0x8) == 0 ? 0 : 1

    var s2b1 = (s2 & 0x1) == 0 ? 0 : 1
    var s2b2 = (s2 & 0x2) == 0 ? 0 : 1
    var s2b3 = (s2 & 0x4) == 0 ? 0 : 1
    var s2b4 = (s2 & 0x8) == 0 ? 0 : 1

    var csb1 = (cs & 0x1) == 0 ? 0 : 1
    var csb2 = (cs & 0x2) == 0 ? 0 : 1
    var csb3 = (cs & 0x4) == 0 ? 0 : 1
    var csb4 = (cs & 0x8) == 0 ? 0 : 1

    self.start()
    #cmd
    self.write_bit(0)
    self.write_bit(1)
    self.write_bit(0)
    self.write_bit(1)
    #h1
    self.write_bit(h1b1)
    self.write_bit(h1b2)
    self.write_bit(h1b3)
    self.write_bit(h1b4)
    #h2
    self.write_bit(h2b1)
    self.write_bit(h2b2)
    self.write_bit(h2b3)
    self.write_bit(h2b4)
    #m1
    self.write_bit(m1b1)
    self.write_bit(m1b2)
    self.write_bit(m1b3)
    self.write_bit(m1b4)
    #m2
    self.write_bit(m2b1)
    self.write_bit(m2b2)
    self.write_bit(m2b3)
    self.write_bit(m2b4)
    #s1
    self.write_bit(s1b1)
    self.write_bit(s1b2)
    self.write_bit(s1b3)
    self.write_bit(s1b4)
    #s2
    self.write_bit(s2b1)
    self.write_bit(s2b2)
    self.write_bit(s2b3)
    self.write_bit(s2b4)
    #cs
    self.write_bit(csb1)
    self.write_bit(csb2)
    self.write_bit(csb3)
    self.write_bit(csb4)
    self.stop()
  end

  def set_temp(t)
    var t1 = int(t) / 10
    var t2 = int(t) % 10
    var t3 = int(t * 10) % 10
    var cs = (0xA + 0x5 + t1 + t2 + t3) & 0xf

    var t1n = self.swap_nibble(t1)
    var t2n = self.swap_nibble(t2)
    var t3n = self.swap_nibble(t3)
    var csn = self.swap_nibble(cs)

    print(string.hex(t1n),string.hex(t2n),string.hex(t3n),string.hex(csn))

    var t1b1 = (t1 & 0x1) == 0 ? 0 : 1
    var t1b2 = (t1 & 0x2) == 0 ? 0 : 1
    var t1b3 = (t1 & 0x4) == 0 ? 0 : 1
    var t1b4 = (t1 & 0x8) == 0 ? 0 : 1

    var t2b1 = (t2 & 0x1) == 0 ? 0 : 1
    var t2b2 = (t2 & 0x2) == 0 ? 0 : 1
    var t2b3 = (t2 & 0x4) == 0 ? 0 : 1
    var t2b4 = (t2 & 0x8) == 0 ? 0 : 1

    var t3b1 = (t3 & 0x1) == 0 ? 0 : 1
    var t3b2 = (t3 & 0x2) == 0 ? 0 : 1
    var t3b3 = (t3 & 0x4) == 0 ? 0 : 1
    var t3b4 = (t3 & 0x8) == 0 ? 0 : 1

    var csb1 = (cs & 0x1) == 0 ? 0 : 1
    var csb2 = (cs & 0x2) == 0 ? 0 : 1
    var csb3 = (cs & 0x4) == 0 ? 0 : 1
    var csb4 = (cs & 0x8) == 0 ? 0 : 1

    self.start()
    #cmd
    self.write_bit(1)
    self.write_bit(1)
    self.write_bit(0)
    self.write_bit(1)
    #c/f
    self.write_bit(1)
    self.write_bit(0)
    self.write_bit(1)
    self.write_bit(0)
    #sign?
    self.write_bit(0)
    self.write_bit(1)
    self.write_bit(0)
    self.write_bit(1)
    #t1
    self.write_bit(t1b1)
    self.write_bit(t1b2)
    self.write_bit(t1b3)
    self.write_bit(t1b4)
    #t2
    self.write_bit(t2b1)
    self.write_bit(t2b2)
    self.write_bit(t2b3)
    self.write_bit(t2b4)
    #t3
    self.write_bit(t3b1)
    self.write_bit(t3b2)
    self.write_bit(t3b3)
    self.write_bit(t3b4)
    #cs
    self.write_bit(csb1)
    self.write_bit(csb2)
    self.write_bit(csb3)
    self.write_bit(csb4)
    self.stop()
  end


  def swap_nibble(n)
    return ((n & 1) << 3) | ((n & 2) << 1) | ((n & 4) >> 1) | ((n & 8) >> 3);
  end

  def every_second()
    var rtc = tasmota.rtc()['local']
    var now = tasmota.time_dump(rtc)
    if now
      self.set_time(now['hour'], now['min'], now['sec'])
    end
  end

end

# return SerialLCD

#s.del()
s = SerialLCD()