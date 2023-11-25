import ULP
import mqtt
import math
import string
import webserver
import persist

class ProjLCDClock

  var hour,min,sec
  var inTemp,outTemp,tempMode
  var showTemp
  var mode_12h

  def init()
    self.hour = 0
    self.min = 0
    self.sec = 0
    self.inTemp = 22
    self.outTemp = 11
    self.tempMode = 0
    self.showTemp = persist.find('clock_show_temp',0)
    self.mode_12h = persist.find('clock_12h_mode',0)

    gpio.pin_mode(25, gpio.DAC)   # output 1.2v on GPIO25
    gpio.dac_voltage(25, 1502)    # set voltage to 1502mV
    ULP.wake_period(0,20000) # update
    ULP.gpio_init(2, 1) # led
    ULP.gpio_init(32, 1) # data
    ULP.gpio_init(33, 1) # clock
    var c = bytes().fromb64("dWxwAAwA9AAAAAAAGAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAEACAcgEAANDlryxySABAgCcFzBkDBdwbAwVYGwAB3BsAAVgbEACAcuGvjHIBAABoMgCAcggAANABAAWCAABLggEAgHIJAABoIgCAcgkAANAAAdwbAAVYG3wQAEAABdwbAAFYGxchAEAABVgbhhAAQAABWBsHAABABgBAcKAAQIAABdwbqAAAgAAB3BuoAACAAAFYG1kQAEAABVgbhhAAQAABWBsQAMByAQAZg1IAgHIIAADQAQAFggAADYIBAIByCQAAaEIAgHIJAADQkAAAgAAB3BsAAVgbAAAAsA==")
    ULP.load(c)
    ULP.run()

    if self.mode_12h == 0 self.set_24h() else self.set_12h() end

    mqtt.subscribe('nodered/message', /topic, idx, msg -> self.set_message(msg))
    tasmota.add_driver(self)
  end

  def deinit()
    self.del()
  end

  def del()
    tasmota.remove_driver(self)
    mqtt.unsubscribe('nodered/message');
  end

  def swap_nibble(n)
    return ((n & 1) << 3) | ((n & 2) << 1) | ((n & 4) >> 1) | ((n & 8) >> 3) & 0xF;
  end

  def send(data, bits)
    var dh = data >> 16 & 0xFFFF
    var dl = data & 0xFFFF
    var mh,ml
    if bits > 16 # >2 bytes
      mh = 1 << (bits - 17)
      ml = 0x8000
    else
      mh = 1 << (bits - 1)
      dh = dl
      ml = 0
      dl = 0
    end
    ULP.set_mem(5,ml) # mask_lo
    ULP.set_mem(4,dl) # data_lo
    ULP.set_mem(3,mh) # mask_hi
    ULP.set_mem(2,dh) # data_hi (start transmittion)
    # print(f"{self.hour}:{self.min}:{self.sec} {string.hex(data)} -> {string.hex(dh)}:{string.hex(mh)} {string.hex(dl)}:{string.hex(ml)}")
  end

  def send_cmd(cmd, data)
    if type(data) == 'int'
      var cs = (data & 0xF) ^ 0xF
      self.send((self.swap_nibble(cmd)<<8) + (self.swap_nibble(data)<<4) + self.swap_nibble(cs), 12)
      return
    end
    var payload = self.swap_nibble(cmd)
    var cs = 0
    for n: data
      payload = (payload << 4) + self.swap_nibble(n)
      cs += n & 0xF
    end
    self.send((payload << 4) + self.swap_nibble(cs & 0xF), size(data)*4 + 8)
  end

  def set_time(h, m, s)
    var h1 = h / 10 + (self.mode_12h ? 8 : 0)
    var h2 = h % 10
    var m1 = m / 10
    var m2 = m % 10
    var s1 = s / 10
    var s2 = s % 10
    self.send_cmd(0xA, [h1, h2, m1, m2, s1, s2])
  end

  def set_temp(t, farenheit)
    var cf = farenheit ? 0xA : 0x5
    var t1 = int(math.abs(t) / 100) % 10
    var t2 = int(math.abs(t) / 10) % 10
    var t3 = int(math.abs(t) / 1) % 10
    var t4 = int(math.abs(t) * 10) % 10
    if t1 != 1 || !farenheit
      t1 = 0xA # SP
    end
    if t < (farenheit ? 0 : -9.9)
      t2 = 0xC # LL
    elif t >= (farenheit ? 200 : 70)
      t2 = 0xB # HH
    elif t < 0
      t2 = 0xD # -
    elif t2 == 0
      t2 = farenheit && t < 10 ? 0 : 0xA # SP
    end
    self.send_cmd(0xB, [cf, t1, t2, t3, t4])
  end

  def set_24h()
    self.send_cmd(0xc, 0)
  end

  def set_12h()
    self.send_cmd(0xc, 2)
  end

  def flip()
    self.send_cmd(0xc, 4)
  end

  def temp()
    self.send_cmd(0xc, 8)
  end

  def set_message(txt)
    var lines = string.split(txt,'\n');
    if size(lines) > 1
      var l1 = lines[0]
      var sub = string.split(lines[1],'°')
      if l1 == "In:"
        self.inTemp = number(sub[0])
      elif l1 == "Out:"
        self.outTemp = number(sub[0])
      end
    end
  end

  def every_second()
    var rtc = tasmota.rtc()['local']
    var now = tasmota.time_dump(rtc)
    if now['year'] != 1970
      self.hour = now['hour']
      self.min = now['min']
      self.sec = now['sec']
      if (self.sec == 5) || (self.sec == 25) || (self.sec == 45)
        self.set_time(self.hour,self.min,self.sec)
      elif self.showTemp == 1
        if (self.sec % 4) == 0
          self.temp()
        elif ((self.sec + 2) % 4) == 0
          self.set_temp(self.tempMode == 0 ? self.outTemp : self.inTemp)
          self.tempMode ^= 1
        end
      end
    end
  end

  def web_add_main_button()
    webserver.content_send("<p></p><button onclick='la(\"&showTemp=1\");'>Toggle showTemp</button>")
    webserver.content_send("<p></p><button onclick='la(\"&24h=1\");'>12H / 24H</button>")
    webserver.content_send("<p></p><button onclick='la(\"&flip=1\");'>Flip</button>")
    webserver.content_send("<p></p><button onclick='la(\"&temp=1\");'>Temp</button>")
    webserver.content_send("<p></p><button onclick='la(\"&set=1\");'>Set Time</button>")
  end

  def web_sensor()
    if webserver.has_arg("showTemp")
      self.showTemp ^= 1
      persist.clock_show_temp = self.showTemp
      persist.save()
    elif webserver.has_arg("24h")
      self.mode_12h ^= 1
      persist.clock_12h_mode = self.mode_12h
      persist.save()
      if self.mode_12h == 0 self.set_24h() else self.set_12h() end
    elif webserver.has_arg("flip")
      self.flip()
    elif webserver.has_arg("temp")
      self.temp()
    elif webserver.has_arg("set")
      var rtc = tasmota.rtc()['local']
      var now = tasmota.time_dump(rtc)
      if now['year'] != 1970
        self.set_time(now['hour'],now['min'],now['sec'])
      end
    end
    webserver.content_send(string.format("{s}inTemp{m}%0.1f{e}",self.inTemp))
    webserver.content_send(string.format("{s}outTemp{m}%0.1f{e}",self.outTemp))
    webserver.content_send(string.format("{s}ShowTemp{m}%s{e}",self.showTemp == 1 ? "On":"Off"))
    webserver.content_send(string.format("{s}12h mode{m}%s{e}",self.mode_12h == 1 ? "On":"Off"))
  end

end

return ProjLCDClock

# clk.del()
# clk = ProjLCDClock()