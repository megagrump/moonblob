local ffi = require('ffi')
local band, bnot, shr = bit.band, bit.bnot, bit.rshift
local _native, _byteOrder, _parseByteOrder
local _tags, _getTag, _taggedReaders, _taggedWriters, _packMap, _unpackMap
local BlobWriter
do
  local _class_0
  local _base_0 = {
    setByteOrder = function(self, byteOrder)
      self._orderBytes = _byteOrder[_parseByteOrder(byteOrder)]
      return self
    end,
    write = function(self, value)
      return self:_writeTagged(value)
    end,
    number = function(self, number)
      _native.n = number
      return self:u32(_native.u32[0]):u32(_native.u32[1])
    end,
    bool = function(self, bool)
      return self:u8(bool and 1 or 0)
    end,
    string = function(self, str)
      local length = #str
      return self:vu32(length):raw(str, length)
    end,
    u8 = function(self, u8)
      if self._length + 1 > self._size then
        self:_grow(1)
      end
      self._data[self._length] = u8
      self._length = self._length + 1
      return self
    end,
    s8 = function(self, s8)
      _native.s8[0] = s8
      return self:u8(_native.u8[0])
    end,
    u16 = function(self, u16)
      local len = self._length
      if len + 2 > self._size then
        self:_grow(2)
      end
      local b1, b2 = self:_orderBytes(band(u16, 2 ^ 8 - 1), shr(u16, 8))
      self._data[len], self._data[len + 1] = b1, b2
      self._length = self._length + 2
      return self
    end,
    s16 = function(self, s16)
      _native.s16[0] = s16
      return self:u16(_native.u16[0])
    end,
    u32 = function(self, u32)
      local len = self._length
      if len + 4 > self._size then
        self:_grow(4)
      end
      local w1, w2 = self:_orderBytes(band(u32, 2 ^ 16 - 1), shr(u32, 16))
      local b1, b2 = self:_orderBytes(band(w1, 2 ^ 8 - 1), shr(w1, 8))
      local b3, b4 = self:_orderBytes(band(w2, 2 ^ 8 - 1), shr(w2, 8))
      self._data[len], self._data[len + 1], self._data[len + 2], self._data[len + 3] = b1, b2, b3, b4
      self._length = self._length + 4
      return self
    end,
    s32 = function(self, s32)
      _native.s32[0] = s32
      return self:u32(_native.u32[0])
    end,
    u64 = function(self, u64)
      _native.u64 = u64
      local a, b = self:_orderBytes(_native.u32[0], _native.u32[1])
      return self:u32(a):u32(b)
    end,
    s64 = function(self, s64)
      _native.s64 = s64
      local a, b = self:_orderBytes(_native.u32[0], _native.u32[1])
      return self:u32(a):u32(b)
    end,
    f32 = function(self, f32)
      _native.f[0] = f32
      return self:u32(_native.u32[0])
    end,
    f64 = function(self, f64)
      return self:number(f64)
    end,
    raw = function(self, raw, length)
      length = length or #raw
      local makeRoom = (self._size - self._length) - length
      if makeRoom < 0 then
        self:_grow(math.abs(makeRoom))
      end
      ffi.copy(ffi.cast('char*', self._data + self._length), raw, length)
      self._length = self._length + length
      return self
    end,
    cstring = function(self, str)
      return self:raw(str):u8(0)
    end,
    table = function(self, t)
      return self:_writeTable(t, { })
    end,
    vu32 = function(self, value)
      assert(value < 2 ^ 32, "Exceeded u32 value range")
      for i = 7, 28, 7 do
        local mask, shift = 2 ^ i - 1, i - 7
        if value < 2 ^ i then
          return self:u8(shr(band(value, mask), shift))
        end
        self:u8(shr(band(value, mask), shift) + 0x80)
      end
      return self:u8(shr(band(value, 0xf0000000), 28))
    end,
    vs32 = function(self, value)
      assert(value < 2 ^ 31 and value >= -2 ^ 31, "Exceeded s32 value range")
      _native.s32[0] = value
      return self:vu32(_native.u32[0])
    end,
    pack = function(self, format, ...)
      assert(type(format) == 'string', "Invalid format specifier")
      local data, index, len = {
        ...
      }, 1, nil
      local limit = select('#', ...)
      local _writeRaw
      _writeRaw = function()
        local l = tonumber(table.concat(len))
        assert(l, l or "Invalid string length specification: " .. tostring(table.concat(len)))
        assert(l < 2 ^ 32, "Maximum string length exceeded")
        self:raw(data[index], l)
        index, len = index + 1, nil
      end
      format:gsub('.', function(c)
        if len then
          if tonumber(c) then
            table.insert(len, c)
          else
            assert(index <= limit, "Number of arguments to pack does not match format specifiers")
            _writeRaw()
          end
        end
        if not (len) then
          local writer = _packMap[c]
          assert(writer, writer or "Invalid data type specifier: " .. tostring(c))
          if c == 'c' then
            len = { }
          else
            assert(index <= limit, "Number of arguments to pack does not match format specifiers")
            if writer(self, data[index]) then
              index = index + 1
            end
          end
        end
      end)
      if len then
        _writeRaw()
      end
      return self
    end,
    tostring = function(self)
      return ffi.string(self._data, self._length)
    end,
    length = function(self)
      return self._length
    end,
    size = function(self)
      return self._size
    end,
    vu32size = function(self, value)
      if value < 2 ^ 7 then
        return 1
      end
      if value < 2 ^ 14 then
        return 2
      end
      if value < 2 ^ 21 then
        return 3
      end
      if value < 2 ^ 28 then
        return 4
      end
      return 5
    end,
    vs32size = function(self, value)
      _native.s32[0] = value
      return self:vu32size(_native.u32[0])
    end,
    _allocate = function(self, size)
      local data
      if size > 0 then
        data = ffi.new('uint8_t[?]', size)
        if self._data then
          ffi.copy(data, self._data, self._length)
        end
      end
      self._data, self._size = data, size
      self._length = math.min(size, self._length)
    end,
    _grow = function(self, minimum)
      minimum = minimum or 0
      local newSize = math.max(self._size + minimum, math.floor(math.max(1, self._size * 1.5) + .5))
      return self:_allocate(newSize)
    end,
    _writeTable = function(self, t, stack)
      stack = stack or { }
      local ttype = type(t)
      assert(ttype == 'table', ttype == 'table' or string.format("Invalid type '%s' for BlobWriter:table", ttype))
      assert(not stack[t], "Cycle detected; can't serialize table")
      stack[t] = true
      for key, value in pairs(t) do
        self:_writeTagged(key, stack)
        self:_writeTagged(value, stack)
      end
      stack[t] = nil
      return self:u8(_tags.stop)
    end,
    _writeTagged = function(self, value, stack)
      local tag = _getTag(value)
      assert(tag, tag or string.format("Can't write values of type '%s'", type(value)))
      self:u8(tag)
      return _taggedWriters[tag](self, value, stack)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, byteOrder, size)
      self._length, self._size = 0, 0
      self:setByteOrder(byteOrder)
      return self:_allocate(size or 1024)
    end,
    __base = _base_0,
    __name = "BlobWriter"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  BlobWriter = _class_0
end
_native = ffi.new([[	union {
		  int8_t s8[8];
		 uint8_t u8[8];
		 int16_t s16[4];
		uint16_t u16[4];
		 int32_t s32[2];
		uint32_t u32[2];
		   float f[2];
		 int64_t s64;
		uint64_t u64;
		  double n;
	}
]])
_byteOrder = {
  le = function(self, v1, v2)
    return v1, v2
  end,
  be = function(self, v1, v2)
    return v2, v1
  end
}
_tags = {
  stop = 0,
  number = 1,
  string = 2,
  table = 3,
  [true] = 4,
  [false] = 5
}
_taggedWriters = {
  BlobWriter.number,
  BlobWriter.string,
  BlobWriter._writeTable,
  function(self)
    return self
  end,
  function(self)
    return self
  end
}
do
  _packMap = {
    b = BlobWriter.s8,
    B = BlobWriter.u8,
    h = BlobWriter.s16,
    H = BlobWriter.u16,
    l = BlobWriter.s32,
    L = BlobWriter.u32,
    v = BlobWriter.vs32,
    V = BlobWriter.vu32,
    q = BlobWriter.s64,
    Q = BlobWriter.u64,
    f = BlobWriter.f32,
    d = BlobWriter.number,
    n = BlobWriter.number,
    c = BlobWriter.raw,
    s = BlobWriter.string,
    z = BlobWriter.cString,
    t = BlobWriter.table,
    y = BlobWriter.bool,
    ['<'] = function(self)
      return nil, self:setByteOrder('<')
    end,
    ['>'] = function(self)
      return nil, self:setByteOrder('>')
    end,
    ['='] = function(self)
      return nil, self:setByteOrder('=')
    end
  }
end
_parseByteOrder = function(endian)
  local _exp_0 = endian
  if nil == _exp_0 or '=' == _exp_0 or 'host' == _exp_0 then
    endian = ffi.abi('le') and 'le' or 'be'
  elseif '<' == _exp_0 then
    endian = 'le'
  elseif '>' == _exp_0 then
    endian = 'be'
  else
    error("Invalid byteOrder identifier: " .. tostring(endian))
  end
  return endian
end
_getTag = function(value)
  if value == true or value == false then
    return _tags[value]
  end
  return _tags[type(value)]
end
return BlobWriter
