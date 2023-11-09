def shift_left(data)
  var carry = 0
  var i = size(data)-1
  while i >= 0
    var b = (data[i] << 1) + carry
    carry = b >> 8
    data[i] = b & 0xFF
    i = i -1
  end
end

def check_empty(data)
  for i: 0..size(data)-1
    if data[i] != 0
      return false
    end
  end
  return true
end
