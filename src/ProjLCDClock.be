import ULP
import mqtt
import math
import string
import webserver
import persist

class ProjLCDClock

  var secs,temp,tempFarenheit
  var mode_12h
  var topic
  var message
  var showTemp

  def init()
    self.secs = 0
    self.temp = 11
    self.tempFarenheit = false
    self.topic = persist.find("clock_message_topic")
    self.mode_12h = persist.find("clock_12h_mode",false)

    ULP.wake_period(0,20000) # each 20ms
    ULP.set_mem(1,0) # data_lo
    ULP.set_mem(2,0) # mask_lo
    ULP.set_mem(3,0) # data_hi
    ULP.set_mem(4,0) # mask_hi
    ULP.gpio_init(32, 1)
    ULP.gpio_init(33, 1)
    var c = bytes().fromb64("dWxwAAwA9AAAAAAAFAAAgAAAAAAAAAAAAAAAAAAAAABCAIByCAAA0AEABYIAAGWCAQCAcgkAAGgyAIByCQAA0AAB3BsABVgbfBAAQAAF3BsAAVgbFyEAQAAFWBuGEABAAAFYGysAAEC0AACABgBAcHAAQIAABdwbeAAAgAAB3BsBAABAAAFYG1kQAEAABVgbiBAAQAABWBsQAMByAQAZgyIAgHIIAADQAQAFggAAJYIBAIByCQAAaBIAgHIJAADQBgBAcMQAQIAABdwbzAAAgAAB3BsBAABAAAFYGy4QAEAABVgbiBAAQAABWBsQAMByAQBDgwAB3BsAAVgbAAAAsA==")
    ULP.load(c)
    ULP.run()

    gpio.pin_mode(2, gpio.OUTPUT) # used for alerts
    gpio.pin_mode(25, gpio.DAC)   # output 1.2v on GPIO25
    gpio.dac_voltage(25, 1502)    # set voltage to 1502mV

    if self.mode_12h self.set_12h() else self.set_24h() end
    if persist.find("clock_flipped",false)
      tasmota.set_timer(2000, def () self.flip() end)
    end
    if self.topic
      mqtt.subscribe(self.topic, def(topic, idx, msg) self.message = msg end)
    end
    tasmota.add_driver(self)
  end

  def deinit()
    self.del()
  end

  def del()
    tasmota.remove_driver(self)
    if self.topic
      mqtt.unsubscribe(self.topic);
    end
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
    ULP.set_mem(1,dl) # data_lo
    ULP.set_mem(2,ml) # mask_lo
    ULP.set_mem(3,dh) # data_hi
    ULP.set_mem(4,mh) # mask_hi (start)
    # print(f"{string.hex(data)} -> {string.hex(dh)}:{string.hex(mh)} {string.hex(dl)}:{string.hex(ml)}")
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

  def toggle_temp()
    self.send_cmd(0xc, 8 + (self.tempFarenheit ? 1 : 0))
  end

  def show(msg)
    if msg == "FLIP"
      self.flip()
    elif msg == "TOGGLE TEMP"
      self.toggle_temp()
    elif string.find(msg, "TEMP ") == 0
      var temp = string.split(msg, 5)[1]
      self.tempFarenheit = (string.find(temp, "F") > 0)
      self.temp = number(string.replace(temp, self.tempFarenheit ? "F" : "C", ""))
      self.set_temp(self.temp, self.tempFarenheit)
      tasmota.set_timer(100, /-> self.toggle_temp())
      self.showTemp = 6 # show for 6 seconds
    end
  end

  def every_second()
    if self.showTemp
      self.showTemp -= 1
      if self.showTemp == 0
        self.toggle_temp()
        self.showTemp = nil
      end
    elif self.message
      self.show(self.message)
      self.message = nil
    else
      if self.secs >= 60
        var rtc = tasmota.rtc()["local"]
        var now = tasmota.time_dump(rtc)
        self.secs = now["sec"]
        if now["year"] != 1970
          self.set_time(now["hour"],now["min"],self.secs)
        end
      end
    end
    self.secs += 1
  end

  def web_add_main_button()
    webserver.content_send("<p></p><button onclick='la(\"&24h=1\");'>12H / 24H</button>")
    webserver.content_send("<p></p><button onclick='la(\"&flip=1\");'>Flip</button>")
    webserver.content_send("<p></p><button onclick='la(\"&temp=1\");'>Toggle temp</button>")
    webserver.content_send("<p></p><button onclick='la(\"&set=1\");'>Set Time</button>")
  end

  def web_sensor()
    if webserver.has_arg("24h")
      self.mode_12h = !self.mode_12h
      persist.clock_12h_mode = self.mode_12h
      persist.save()
      if self.mode_12h self.set_12h() else self.set_24h() end
    elif webserver.has_arg("flip")
      self.flip()
    elif webserver.has_arg("temp")
      self.toggle_temp()
    elif webserver.has_arg("set")
      var rtc = tasmota.rtc()["local"]
      var now = tasmota.time_dump(rtc)
      if now["year"] != 1970
        self.set_time(now["hour"],now["min"],now["sec"])
      end
    end
  end

end

return ProjLCDClock
