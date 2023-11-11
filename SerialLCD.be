import ULP
import string

class SerialLCD
  def init()
    ULP.wake_period(0,20000) # update
    ULP.gpio_init(32, 1) # data
    ULP.gpio_init(33, 1) #clock
    ULP.set_mem(2, 0x30F) # H24
    ULP.set_mem(3, 0x800)
    var c = bytes().fromb64("dWxwAAwA9AAAAAAAGAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAEACAcgEAANDlryxySABAgCcFzBkDBdwbAwVYGwAB3BsAAVgbEACAcuGvjHIBAABoMgCAcggAANABAAWCAABLggEAgHIJAABoIgCAcgkAANAAAdwbAAVYG3EQAEAABdwbAAFYGxchAEAABdwbAAVYG3EQAEAAAVgbBgBAcKAAQIAABdwbqAAAgAAB3BuoAACAAAFYG3EQAEAABVgbcRAAQAABWBsQAMByAQAZg1IAgHIIAADQAQAFggAADYIBAIByCQAAaEIAgHIJAADQkAAAgAAB3BsAAVgbAAAAsA==")
    ULP.load(c)
    ULP.run()
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
    var cmdn = 0x3
    var cn = self.swap_nibble(c)
    var cs = (c & 0xF) ^ 0xF
    var csn = self.swap_nibble(cs)

    print(string.hex(cmdn),string.hex(cn),string.hex(csn))

    ULP.set_mem(2, (cmdn << 8) + (cn << 4) + csn) # data_hi
    ULP.set_mem(3, 0x800)                         # mask_hi
    ULP.set_mem(4, 0)                             # data_lo
    ULP.set_mem(5, 0)                             # mask_lo
  end

  def set_time(h,m,s)
    var h1 = h / 10
    var h2 = h % 10
    var m1 = m / 10
    var m2 = m % 10
    var s1 = s / 10
    var s2 = s % 10

    var cs = (h1 + h2 + m1 + m2 + s1 + s2) & 0xF

    var cmdn = 0x5
    var h1n = self.swap_nibble(h1)
    var h2n = self.swap_nibble(h2)
    var m1n = self.swap_nibble(m1)
    var m2n = self.swap_nibble(m2)
    var s1n = self.swap_nibble(s1)
    var s2n = self.swap_nibble(s2)
    var csn = self.swap_nibble(cs)

    print(string.hex(cmdn),string.hex(h1n),string.hex(h2n),string.hex(m1n),string.hex(m2n),string.hex(s1n),string.hex(s2n),string.hex(csn))

    ULP.set_mem(2, (cmdn << 12) + (h1n << 8) + (h2n << 4) + m1n) # data_hi
    ULP.set_mem(3, 0x8000)                                       # mask_hi
    ULP.set_mem(4, (m2n << 12) + (s1n << 8) + (s2n << 4) + csn)  # data_lo
    ULP.set_mem(5, 0x8000)                                       # mask_lo
  end

  def set_temp(t)
    var t1 = int(t) / 10
    var t2 = int(t) % 10
    var t3 = int(t * 10) % 10
    var cs = (0xA + 0x5 + t1 + t2 + t3) & 0xF

    var cmdn = 0xD
    var s1n = 0xA
    var s2n = 0x5
    var t1n = self.swap_nibble(t1)
    var t2n = self.swap_nibble(t2)
    var t3n = self.swap_nibble(t3)
    var csn = self.swap_nibble(cs)

    print(string.hex(cmdn),string.hex(s1n),string.hex(s2n),string.hex(t1n),string.hex(t2n),string.hex(t3n),string.hex(csn))

    ULP.set_mem(2, (cmdn << 8) + (s1n << 4) + s2n)               # data_hi
    ULP.set_mem(3, 0x800)                                        # mask_hi
    ULP.set_mem(4, (t1n << 12) + (t2n << 8) + (t3n << 4) + csn)  # data_lo
    ULP.set_mem(5, 0x8000)                                       # mask_lo
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