local ffi = require('ffi')
local band = bit.band
local _native, _endian, _parseByteOrder
local _tags, _getTag, _taggedReaders, _unpackMap, _arrayTypeMap
local BlobReader
do
  local _class_0
  local _base_0 = {
    setByteOrder = function(self, byteOrder)
      self._orderBytes = _endian[_parseByteOrder(byteOrder)]
      return self
    end,
    read = function(self)
      local tag, value = self:_readTagged()
      return value
    end,
    number = function(self)
      _native.u32[0], _native.u32[1] = self:u32(), self:u32()
      return _native.n
    end,
    string = function(self)
      local len, ptr = self:vu32(), self._readPtr
      assert(ptr + len - 1 < self._size, "Out of data")
      self._readPtr = ptr + len
      return ffi.string(ffi.cast('uint8_t*', self._data + ptr), len)
    end,
    bool = function(self)
      return self:u8() ~= 0
    end,
    table = function(self)
      local result = { }
      local tag, key = self:_readTagged()
      while tag ~= _tags.stop do
        tag, result[key] = self:_readTagged()
        tag, key = self:_readTagged()
      end
      return result
    end,
    u8 = function(self)
      assert(self._readPtr < self._size, "Out of data")
      local u8 = self._data[self._readPtr]
      self._readPtr = self._readPtr + 1
      return u8
    end,
    s8 = function(self)
      _native.u8[0] = self:u8()
      return _native.s8[0]
    end,
    u16 = function(self)
      local ptr = self._readPtr
      assert(ptr + 1 < self._size, "Out of data")
      self._readPtr = ptr + 2
      return self._orderBytes._16(self._data[ptr], self._data[ptr + 1])
    end,
    s16 = function(self)
      _native.u16[0] = self:u16()
      return _native.s16[0]
    end,
    u32 = function(self)
      local ptr = self._readPtr
      assert(ptr + 3 < self._size, "Out of data")
      self._readPtr = ptr + 4
      return self._orderBytes._32(self._data[ptr], self._data[ptr + 1], self._data[ptr + 2], self._data[ptr + 3])
    end,
    s32 = function(self)
      _native.u32[0] = self:u32()
      return _native.s32[0]
    end,
    u64 = function(self)
      local ptr = self._readPtr
      assert(ptr + 7 < self._size, "Out of data")
      self._readPtr = ptr + 8
      return self._orderBytes._64(self._data[ptr], self._data[ptr + 1], self._data[ptr + 2], self._data[ptr + 3], self._data[ptr + 4], self._data[ptr + 5], self._data[ptr + 6], self._data[ptr + 7])
    end,
    s64 = function(self)
      _native.u64 = self:u64()
      return _native.s64
    end,
    f32 = function(self)
      _native.u32[0] = self:u32()
      return _native.f[0]
    end,
    f64 = function(self)
      return self:number()
    end,
    vu32 = function(self)
      local result = self:u8()
      if band(result, 0x00000080) == 0 then
        return result
      end
      result = band(result, 0x0000007f) + self:u8() * 2 ^ 7
      if band(result, 0x00004000) == 0 then
        return result
      end
      result = band(result, 0x00003fff) + self:u8() * 2 ^ 14
      if band(result, 0x00200000) == 0 then
        return result
      end
      result = band(result, 0x001fffff) + self:u8() * 2 ^ 21
      if band(result, 0x10000000) == 0 then
        return result
      end
      return band(result, 0x0fffffff) + self:u8() * 2 ^ 28
    end,
    vs32 = function(self)
      _native.u32[0] = self:vu32()
      return _native.s32[0]
    end,
    raw = function(self, len)
      local ptr = self._readPtr
      assert(ptr + len - 1 < self._size, "Out of data")
      self._readPtr = ptr + len
      return ffi.string(ffi.cast('uint8_t*', self._data + ptr), len)
    end,
    skip = function(self, len)
      assert(self._readPtr + len - 1 < self._size, "Out of data")
      self._readPtr = self._readPtr + len
      return self
    end,
    cstring = function(self)
      local start = self._readPtr
      while self:u8() > 0 do
        local _ = nil
      end
      local len = self._readPtr - start
      assert(len < 2 ^ 32, "String too long")
      return ffi.string(ffi.cast('uint8_t*', self._data + start), len - 1)
    end,
    array = function(self, valueType, result)
      if result == nil then
        result = { }
      end
      local reader = _arrayTypeMap[valueType]
      assert(reader, reader or "Invalid array type <" .. tostring(valueType))
      local length = self:vu32()
      for i = 1, length do
        result[#result + 1] = reader(self)
      end
      return result
    end,
    unpack = function(self, format)
      assert(type(format) == 'string', "Invalid format specifier")
      local result, len = { }, nil
      local _readRaw
      _readRaw = function()
        local l = tonumber(table.concat(len))
        assert(l, l or "Invalid string length specification: " .. tostring(table.concat(len)))
        assert(l < 2 ^ 32, "Maximum string length exceeded")
        table.insert(result, self:raw(l))
        len = nil
      end
      format:gsub('.', function(c)
        if len then
          if tonumber(c) then
            table.insert(len, c)
          else
            _readRaw()
          end
        end
        if not (len) then
          local parser = _unpackMap[c]
          assert(parser, parser or "Invalid data type specifier: " .. tostring(c))
          if c == 'c' then
            len = { }
          else
            local parsed = parser(self)
            if parsed ~= nil then
              return table.insert(result, parsed)
            end
          end
        end
      end)
      if len then
        _readRaw()
      end
      return unpack(result)
    end,
    size = function(self)
      return self._size
    end,
    rewind = function(self)
      self._readPtr = 0
      return self
    end,
    position = function(self)
      return self._readPtr
    end,
    _allocate = function(self, size)
      local data
      if size > 0 then
        data = ffi.new('uint8_t[?]', size)
      end
      self._data, self._size = data, size
    end,
    _readTagged = function(self)
      local tag = self:u8()
      return tag, tag ~= _tags.stop and _taggedReaders[tag](self)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, data, byteOrder, size)
      local dtype = type(data)
      if dtype == 'string' then
        self:_allocate(#data)
        ffi.copy(self._data, data, #data)
      elseif dtype == 'cdata' then
        self._size = size or ffi.sizeof(data)
        self._data = data
      else
        error("Invalid data type <" .. tostring(dtype) .. ">")
      end
      self._readPtr = 0
      return self:setByteOrder(byteOrder)
    end,
    __base = _base_0,
    __name = "BlobReader"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  BlobReader = _class_0
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
_endian = {
  le = {
    _16 = function(b1, b2)
      _native.u8[0], _native.u8[1] = b1, b2
      return _native.u16[0]
    end,
    _32 = function(b1, b2, b3, b4)
      _native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b1, b2, b3, b4
      return _native.u32[0]
    end,
    _64 = function(b1, b2, b3, b4, b5, b6, b7, b8)
      _native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b1, b2, b3, b4
      _native.u8[4], _native.u8[5], _native.u8[6], _native.u8[7] = b5, b6, b7, b8
      return _native.u64
    end
  },
  be = {
    _16 = function(b1, b2)
      _native.u8[0], _native.u8[1] = b2, b1
      return _native.u16[0]
    end,
    _32 = function(b1, b2, b3, b4)
      _native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b4, b3, b2, b1
      return _native.u32[0]
    end,
    _64 = function(b1, b2, b3, b4, b5, b6, b7, b8)
      _native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b8, b7, b6, b5
      _native.u8[4], _native.u8[5], _native.u8[6], _native.u8[7] = b4, b3, b2, b1
      return _native.u64
    end
  }
}
_tags = {
  stop = 0,
  number = 1,
  string = 2,
  table = 3,
  [true] = 4,
  [false] = 5
}
_taggedReaders = {
  BlobReader.number,
  BlobReader.string,
  BlobReader.table,
  function(self)
    return true
  end,
  function(self)
    return false
  end
}
do
  _arrayTypeMap = {
    s8 = BlobReader.s8,
    u8 = BlobReader.u8,
    s16 = BlobReader.s16,
    u16 = BlobReader.u16,
    s32 = BlobReader.s32,
    u32 = BlobReader.u32,
    s64 = BlobReader.s64,
    u64 = BlobReader.u64,
    vs32 = BlobReader.vs32,
    vu32 = BlobReader.vu32,
    f32 = BlobReader.f32,
    f64 = BlobReader.f64,
    number = BlobReader.number,
    string = BlobReader.string,
    cstring = BlobReader.cstring,
    bool = BlobReader.bool,
    table = BlobReader.table
  }
end
do
  _unpackMap = {
    b = BlobReader.s8,
    B = BlobReader.u8,
    h = BlobReader.s16,
    H = BlobReader.u16,
    l = BlobReader.s32,
    L = BlobReader.u32,
    v = BlobReader.vs32,
    V = BlobReader.vu32,
    q = BlobReader.s64,
    Q = BlobReader.u64,
    f = BlobReader.f32,
    d = BlobReader.number,
    n = BlobReader.number,
    c = BlobReader.raw,
    s = BlobReader.string,
    z = BlobReader.cstring,
    t = BlobReader.table,
    y = BlobReader.bool,
    x = function(self)
      return nil, self:skip(1)
    end,
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
return BlobReader
