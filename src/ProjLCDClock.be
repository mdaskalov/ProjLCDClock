import ULP
import mqtt
import string
import webserver

class ProjLCDClock

  var hour,min,sec
  var inTemp,outTemp,tempMode
  var showTemp
  var mode

  def init()
    self.hour = 0
    self.min = 0
    self.sec = 0
    self.inTemp = 22
    self.outTemp = 11
    self.tempMode = 0
    self.showTemp = 0
    self.mode = 0

    gpio.pin_mode(25, gpio.DAC)   # output 1.2v on GPIO25
    gpio.dac_voltage(25, 1502)    # set voltage to 1502mV
    ULP.wake_period(0,20000) # update
    ULP.gpio_init(2, 1) # led
    ULP.gpio_init(32, 1) # data
    ULP.gpio_init(33, 1) #clock
    var c = bytes().fromb64("dWxwAAwA9AAAAAAAGAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAEACAcgEAANDlryxySABAgCcFzBkDBdwbAwVYGwAB3BsAAVgbEACAcuGvjHIBAABoMgCAcggAANABAAWCAABLggEAgHIJAABoIgCAcgkAANAAAdwbAAVYG3EQAEAABdwbAAFYGxchAEAABdwbAAVYG3EQAEAAAVgbBgBAcKAAQIAABdwbqAAAgAAB3BuoAACAAAFYG3EQAEAABVgbcRAAQAABWBsQAMByAQAZg1IAgHIIAADQAQAFggAADYIBAIByCQAAaEIAgHIJAADQkAAAgAAB3BsAAVgbAAAAsA==")
    ULP.load(c)
    ULP.run()

    self.set_24h()

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
    var h1 = h / 10
    var h2 = h % 10
    var m1 = m / 10
    var m2 = m % 10
    var s1 = s / 10
    var s2 = s % 10
    self.send_cmd(0xA, [h1, h2, m1, m2, s1, s2])
  end

  def set_temp(t, farenheit)
    var s1 = farenheit == true ? 0xA : 0x5
    var s2 = 0xA # unknown
    var t1 = int(t) / 10
    var t2 = int(t) % 10
    var t3 = int(t * 10) % 10
    self.send_cmd(0xB, [s1, s2, t1, t2, t3])
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
    webserver.content_send("<p></p><button onclick='la(\"&flip=1\");'>Flip</button>")
    webserver.content_send("<p></p><button onclick='la(\"&24h=1\");'>12H / 24H</button>")
    webserver.content_send("<p></p><button onclick='la(\"&temp=1\");'>Temp</button>")
    webserver.content_send("<p></p><button onclick='la(\"&set=1\");'>Set Time</button>")
  end

  def web_sensor()
    if webserver.has_arg("showTemp")
      self.showTemp ^= 1
    elif webserver.has_arg("flip")
      self.flip()
    elif webserver.has_arg("24h")
      self.mode ^= 1
      if self.mode == 0 self.set_24h() else self.set_12h() end
    elif webserver.has_arg("temp")
      self.temp()
    elif webserver.has_arg("set")
      var rtc = tasmota.rtc()['local']
      var now = tasmota.time_dump(rtc)
      if now['year'] != 1970
        self.set_time(now['hour'],now['min'],now['sec'])
      end
    end
  end

end

return ProjLCDClock

# clk.del()
# clk = ProjLCDClock()