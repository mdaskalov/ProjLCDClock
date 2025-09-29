import ULP
import mqtt
import math
import string
import webserver
import persist

class ProjLCDClock
  static BITS_ADDR = 140 # address of "bits" global variable in ulp_main.c
  static DATA_ADDR = 141 # address of "data" global variable in ulp_main.c

  var secs,temp,tempFarenheit
  var topic
  var mode_12h
  var message
  var showTemp

  def init()
    self.secs = 0
    self.temp = 11
    self.tempFarenheit = false
    self.topic = persist.find("clock_message_topic")
    self.mode_12h = persist.find("clock_12h_mode",false)

    ULP.wake_period(0,20000) # each 20ms
    ULP.set_mem(self.BITS_ADDR,0) # bits
    ULP.set_mem(self.DATA_ADDR,0) # data
    ULP.gpio_init(1, 1)
    ULP.gpio_init(2, 1)
    var c = bytes().fromb64("bwBAABcRAAATAcH/7SINKO0qAaDzJwDAMRU+lfMnAMDj7qf+goApZxMHR0AUQ5MHAECzl6cAk/b2P9WPHMOCgAERTsaDJ0AjBs4izCbKSshSxFbCWsBjiAcUtWaThgaQ3EI3DgCANwMIALPnxwHcwqlnk4eHSJhDtwX6//0VM2dnAJjDmEOJaAVpbY+Yw5hDkwoJgDNnFwGYwylnEwcHQRBDE3b2PzNmVgEQwylmEwbGQghCE2VFAAjCkEM3BQAISY6QwwOoBwA3BgDwfRYzeMgAI6AHAdxCs+fHAdzCqWeTh8dIlEOz5mYAlMOUQ+2OlMOUQ7PmFgGUwxRDk/b2P7PmJgEUwylnEwcHQxRDk+ZGABTDmENJj5jDmENxj5jDgyQAI73MKWQTBIRAHEADK0AjCUWT9/c/s+dXARzA5TUJZRMFtSD5NQVF8T0cQBFlEwVlTZP39z+z5ycBHMBdPQlF0TUJZRMF9SNtNRxA/RST9/c/s+cnARzAY9EEBKlnk4eHQJhDhWYThgaAE3f3P1GPmMOYQxN39z9Vj5jDIygAIiMqACLyQGJE0kRCSbJJIkqSSgJLAUUFYYKAs1ebAIWLncMFRYU1HEAJZRMFVRyT9/c/s+cnARzALT0JRaE1CWUTBRUlUbccQJP39z+z51cBHMDRv6Fnk4dHEJhDtwbA/f0WdY+Yw4KAoWeTh0cQmEO3RsD//RZ1j7fGDwBVj5jDmEO3BkACVY+YwwGg")
    ULP.load(c)
    ULP.run()

    gpio.pin_mode(2, gpio.OUTPUT) # used for alerts

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
    var cur = ULP.get_mem(self.DATA_ADDR)
    if cur != 0
      tasmota.delay(50) # wait to complete (data == 0)
    end
    ULP.set_mem(self.BITS_ADDR, bits)
    ULP.set_mem(self.DATA_ADDR, data)
    # print(f"{string.hex(data)} ({bits})")
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
    elif string.find(msg, "TEMP ") == 0 # TEMP ###.#C TEMP ###.#F
      var temp = string.split(msg, 5)[1]
      self.tempFarenheit = (string.find(temp, "F") > 0)
      self.temp = number(string.replace(temp, self.tempFarenheit ? "F" : "C", ""))
      self.set_temp(self.temp, self.tempFarenheit)
      tasmota.set_timer(100, /-> self.toggle_temp())
      self.showTemp = 6 # show for 6 seconds
    elif string.find(msg, "TIME ") == 0 # TIME HHMM
      var time = number(string.split(msg, 5)[1])
      var hh = time / 100 % 100
      var mm = time  % 100
      self.set_time(hh, mm, 0)
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
