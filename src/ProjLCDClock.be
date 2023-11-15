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
    ULP.gpio_init(32, 1) # data
    ULP.gpio_init(33, 1) #clock
    var c = bytes().fromb64("dWxwAAwA9AAAAAAAGAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAEACAcgEAANDlryxySABAgCcFzBkDBdwbAwVYGwAB3BsAAVgbEACAcuGvjHIBAABoMgCAcggAANABAAWCAABLggEAgHIJAABoIgCAcgkAANAAAdwbAAVYG3EQAEAABdwbAAFYGxchAEAABdwbAAVYG3EQAEAAAVgbBgBAcKAAQIAABdwbqAAAgAAB3BuoAACAAAFYG3EQAEAABVgbcRAAQAABWBsQAMByAQAZg1IAgHIIAADQAQAFggAADYIBAIByCQAAaEIAgHIJAADQkAAAgAAB3BsAAVgbAAAAsA==")
    ULP.load(c)
    ULP.run()

    self.h24()

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

  def swap_nibbles(data, nibbles)
    var res = 0
    for i:0..nibbles-1
      res += self.swap_nibble((data >> i * 4) & 0xF) << i * 4
    end
    return res
  end

  def send(data, nibbles)
    var sw_data = self.swap_nibbles(data, nibbles)
    var dh = sw_data >> 16 & 0xFFFF
    var dl = sw_data & 0xFFFF
    var mh,ml
    if nibbles > 4 # > 2 byte
      mh = 1 << (((nibbles - 4) * 4) - 1)
      ml = 0x8000
    else
      mh = 1 << ((nibbles * 4) - 1)
      dh = dl
      ml = 0
      dl = 0
    end
    ULP.set_mem(5,ml) # mask_lo
    ULP.set_mem(4,dl) # data_lo
    ULP.set_mem(3,mh) # mask_hi
    ULP.set_mem(2,dh) # data_hi (start transmittion)
    # print(f"{self.hour}:{self.min}:{self.sec} {string.hex(data)} -> {string.hex(sw_data)} : {string.hex(dh)}:{string.hex(mh)} {string.hex(dl)}:{string.hex(ml)}")
  end

  def send_cmd(c, data)
    if type(data) == 'int'
      var cs = (data & 0xF) ^ 0xF
      self.send((c<<8) + (data<<4) + cs, 3)
      return
    end
    var nibbles = size(data)
    var payload = 0
    var cs = 0
    var shift = 4
    for n: data
      payload += (n & 0xF) << (nibbles * 4 - shift)
      cs += n & 0xF
      shift += 4
    end
    self.send(((c & 0xf) << (nibbles * 4 + 4)) + (payload << 4) + (cs & 0xF), nibbles + 2)
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

  def h24()
    self.send_cmd(0xc, 0)
  end

  def h12()
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
      elif (self.sec == 5) || (self.sec == 25) || (self.sec == 45)
        if self.showTemp == 1
          self.temp()
          self.showTemp = 0
        end
      elif (self.sec % 10) == 0
        self.set_temp(self.tempMode == 0 ? self.outTemp : self.inTemp)
        self.tempMode ^= 1
      end
    end
  end

  def web_add_main_button()
    webserver.content_send("<p></p><button onclick='la(\"&flip=1\");'>Flip</button>")
    webserver.content_send("<p></p><button onclick='la(\"&24h=1\");'>24H</button>")
    webserver.content_send("<p></p><button onclick='la(\"&temp=1\");'>Temp</button>")
    webserver.content_send("<p></p><button onclick='la(\"&set=1\");'>Set Time</button>")
  end

  def web_sensor()
    if webserver.has_arg("flip")
      self.flip()
    elif webserver.has_arg("temp")
      self.showTemp = 1
    elif webserver.has_arg("24h")
      self.mode ^= 1
      if self.mode == 0 self.h24() else self.h12() end
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