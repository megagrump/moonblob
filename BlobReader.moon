-- @class BlobReader
ffi = require('ffi')
band, shr = bit.band, bit.rshift

local _native, _endian, _parseByteOrder
local _tags, _getTag, _taggedReaders, _unpackMap, _arrayTypeMap

--- Parses binary data from memory.
class BlobReader
	--- Creates a new BlobReader instance.
	--
	-- @tparam string|cdata data Data with which to populate the blob
	-- @tparam[opt] string byteOrder The byte order of the data
	--
	-- Use `le` or `<` for little endian; `be` or `>` for big endian; `host`, `=` or `nil` to use the
	-- host's native byte order (default)
	-- @tparam[opt] number size When data is of type `cdata`, you need to pass the size manually
	-- @treturn BlobReader A new BlobReader instance.
	-- @usage reader = BlobReader(data)
	-- @usage reader = BlobReader(data, '>')
	-- @usage reader = BlobReader(cdata, nil, 1000)
	new: (data, byteOrder, size) =>
		dtype = type(data)
		if dtype == 'string'
			@_allocate(#data)
			ffi.copy(@_data, data, #data)
		elseif dtype == 'cdata'
			@_size = size or ffi.sizeof(data)
			@_data = data
		else
			error("Invalid data type <#{dtype}>")

		@_readPtr = 0
		@setByteOrder(byteOrder)

	--- Set source data byte order.
	---
	-- @tparam string byteOrder Byte order.
	--
	-- Can be either `le` or `<` for little endian, `be` or `>` for big endian, or `host` or `nil` for native host byte
	-- order.
	-- @treturn BlobReader self
	setByteOrder: (byteOrder) =>
		@_orderBytes = _endian[_parseByteOrder(byteOrder)]
		@

	--- Reads a `string`, a `number`, a `boolean` or a `table` from the input data.
	--
	-- The data must have been written by `BlobWriter:write`.
	-- The type of the value is automatically detected from the input metadata.
	-- @treturn string|number|bool|table The value read from the input data
	-- @see BlobWriter:write
	read: =>
		tag, value = @_readTagged!
		value

	--- Reads a Lua number from the input data.
	--
	-- @treturn number The number read read from the input data
	number: =>
		_native.u32[0], _native.u32[1] = @u32!, @u32!
		_native.n

	--- Reads a string from the input data.
	--
	-- The string must have been written by `BlobWriter:write` or `BlobWriter:string`
	-- @treturn string The string read from the input data
	-- @see BlobWriter:write
	-- @see BlobWriter:string
	string: =>
		len, ptr = @vu32!, @_readPtr
		assert(ptr + len - 1 < @_size, "Out of data")
		@_readPtr = ptr + len
		ffi.string(ffi.cast('uint8_t*', @_data + ptr), len)

	--- Reads a boolean value from the input data.
	--
	-- The data is expected to be 8 bits long, `0 == false`, any other value == `true`
	-- @treturn bool The boolean value read from the input data
	bool: => @u8! ~= 0

	--- Reads a Lua table from the input data.
	--
	-- The table must have been written by BlobWriter.write or BlobWriter.table.
	--
	-- @tparam[opt] table result Table to put values in
	-- @treturn table The table read from the input data
	-- @see BlobWriter:table
	-- @see BlobWriter:write
	table: (result = {}) =>
		tag, key = @_readTagged!
		while tag ~= _tags.stop
			tag, result[key] = @_readTagged!
			tag, key = @_readTagged!
		result

	--- Reads one unsigned 8-bit value from the input data.
	--
	-- @treturn number The unsigned 8-bit value read from the input data
	u8: =>
		assert(@_readPtr < @._size, "Out of data")
		u8 = @_data[@_readPtr]
		@_readPtr += 1
		u8

	--- Reads one signed 8-bit value from the input data.
	--
	-- @treturn number The signed 8-bit value read from the input data
	s8: =>
		_native.u8[0] = @u8!
		_native.s8[0]

	--- Reads one unsigned 16-bit value from the input data.
	--
	-- @treturn number The unsigned 16-bit value read from the input data
	u16: =>
		ptr = @_readPtr
		assert(ptr + 1 < @_size, "Out of data")
		@_readPtr = ptr + 2
		@_orderBytes._16(@_data[ptr], @_data[ptr + 1])

	--- Reads one signed 16 bit value from the input data.
	--
	-- @treturn number The signed 16-bit value read from the input data
	s16: =>
		_native.u16[0] = @u16!
		_native.s16[0]

	--- Reads one unsigned 32 bit value from the input data.
	--
	-- @treturn number The unsigned 32-bit value read from the input data
	u32: =>
		ptr = @_readPtr
		assert(ptr + 3 < @_size, "Out of data")
		@_readPtr = ptr + 4
		@_orderBytes._32(@_data[ptr], @_data[ptr + 1], @_data[ptr + 2], @_data[ptr + 3])

	--- Reads one signed 32 bit value from the input data.
	--
	-- @treturn number The signed 32-bit value read from the input data
	s32: =>
		_native.u32[0] = @u32!
		_native.s32[0]

	--- Reads one unsigned 64 bit value from the input data.
	--
	-- @treturn number The unsigned 64-bit value read from the input data
	u64: =>
		ptr = @_readPtr
		assert(ptr + 7 < @_size, "Out of data")
		@_readPtr = ptr + 8
		@_orderBytes._64(@_data[ptr], @_data[ptr + 1], @_data[ptr + 2], @_data[ptr + 3],
			@_data[ptr + 4], @_data[ptr + 5], @_data[ptr + 6], @_data[ptr + 7])

	--- Reads one signed 64 bit value from the input data.
	--
	-- @treturn number The signed 64-bit value read from the input data
	s64: =>
		_native.u64 = @u64!
		_native.s64

	--- Reads one 32 bit floating point value from the input data.
	--
	-- @treturn number The 32-bit floating point value read from the input data
	f32: =>
		_native.u32[0] = @u32!
		_native.f[0]

	--- Reads one 64 bit floating point value from the input data.
	--
	-- @treturn number The 64-bit floating point value read from the input data
	f64: => @number!

	--- Reads a length-encoded unsigned 32 bit integer value from the input data.
	--
	-- See `BlobWriter:vu32` for more details about this data type.
	-- @treturn number The unsigned 32-bit integer value read from the input data
	-- @see BlobWriter:vu32
	vu32: =>
		result = @u8!
		return result if band(result, 0x00000080) == 0
		result = band(result, 0x0000007f) + @u8! * 2 ^ 7
		return result if band(result, 0x00004000) == 0
		result = band(result, 0x00003fff) + @u8! * 2 ^ 14
		return result  if band(result, 0x00200000) == 0
		result = band(result, 0x001fffff) + @u8! * 2 ^ 21
		return result if band(result, 0x10000000) == 0
		band(result, 0x0fffffff) + @u8! * 2 ^ 28

	--- Reads a length-encoded signed 32 bit integer value from the input data.
	--
	-- See `BlobWriter:vs32` for more details about this data type.
	-- @treturn number The signed 32-bit integer value read from the input data
	-- @see BlobWriter:vs32
	vs32: =>
		result = @u8!
		sign, result = band(result, 1) == 0 and 1 or -1, shr(result, 1)
		return result * sign if band(result, 0x00000040) == 0
		result = band(result, 0x0000003f) + @u8! * 2 ^ 6
		return result * sign if band(result, 0x00002000) == 0
		result = band(result, 0x00001fff) + @u8! * 2 ^ 13
		return result * sign if band(result, 0x00100000) == 0
		result = band(result, 0x000fffff) + @u8! * 2 ^ 20
		return result * sign if band(result, 0x08000000) == 0
		sign * (band(result, 0x07ffffff) + @u8! * 2 ^ 27)

	--- Reads raw binary data from the input data.
	--
	-- @tparam number len The length of the data (in bytes) to read
	-- @treturn string A string with raw data
	raw: (len) =>
		ptr = @_readPtr
		assert(ptr + len - 1 < @_size, "Out of data")
		@_readPtr = ptr + len
		ffi.string(ffi.cast('uint8_t*', @_data + ptr), len)

	--- Skips a number of bytes in the input data.
	--
	-- @tparam number len The number of bytes to skip
	-- @treturn BlobReader self
	skip: (len) =>
		assert(@_readPtr + len - 1 < @_size, "Out of data")
		@_readPtr += len
		@

	--- Reads a zero-terminated string from the input data (up to 2 ^ 32 - 1 bytes).
	--
	-- Keeps reading bytes until a null byte is encountered.
	-- @treturn string The string read from the input data
	cstring: =>
		ptr, start = @_readPtr, @_readPtr
		while ptr < @_size and @_data[ptr] > 0
			ptr += 1
		error("Out of data") if ptr == @_size
		@_readPtr, len = ptr + 1, ptr - start
		assert(len < 2 ^ 32, "String too long")
		ffi.string(ffi.cast('uint8_t*', @_data + start), len)

	--- Reads a sequential table of typed values.
	--
	-- Expects preceding `vu32` encoded array length information, as written by `BlobWriter:array`.
	--
	-- @tparam string valueType Type of the values in the array
	--
	-- Valid types are `s8`, `u8`, `s16`, `u16`, `s32`, `u32`, `vs32`, `vu32`, `s64`, `u64`, `f32`, `f64`,
	-- `number`, `string`, `bool`, `cstring`, and `table`.
	--
	-- @tparam[opt] table result Table to put the values in
	-- @treturn table A sequential table, starting at index 1
	-- @see BlobWriter:array
	array: (valueType, result = {}) =>
		reader = _arrayTypeMap[valueType]
		assert(reader, reader or "Invalid array type <#{valueType}>")
		length = @vu32!
		result[#result + 1] = reader(@) for i = 1, length
		result

	--- Parses data into separate values according to a format string.
	--
	-- @tparam string format Data format specification
	--
	-- See `BlobWriter:pack` for a list of supported identifiers.
	--
	-- Additional format specifiers for unpack:
	--
	-- * `x[n]`: skip `n` bytes of data
	--
	--     `n` defaults to 1 if no length was specified.
	-- @return All values parsed from the input data
	-- @usage byte, float, bool = reader\unpack('x4Bfy') -- skips 4 bytes before actual data
	-- @see BlobWriter:pack
	unpack: (format) =>
		assert(type(format) == 'string', "Invalid format specifier")
		result, len, lenContext = {}, nil, nil

		raw = ->
			l = tonumber(table.concat(len))
			assert(l, l or "Invalid string length specification: #{table.concat(len)}")
			assert(l < 2 ^ 32, "Maximum string length exceeded")
			table.insert(result, @raw(l))
			len = nil

		skip = ->
			@skip(tonumber(table.concat(len)) or 1)
			len = nil

		format\gsub('.', (c) ->
			if len
				if tonumber(c)
					table.insert(len, c)
				else
					lenContext!

			unless len
				parser = _unpackMap[c]
				assert(parser, parser or "Invalid data type specifier: #{c}")
				switch c
					when 'c'
						len, lenContext = {}, raw
					when 'x'
						len, lenContext = {}, skip
					else
						parsed = parser(@)
						table.insert(result, parsed) if parsed ~= nil
		)

		lenContext! if len -- final specifier in format was a length specifier
		unpack(result)

	--- Returns the size of the input data in bytes.
	--
	-- @treturn number Data size in bytes
	size: => @_size

	--- Resets the read position to the beginning of the data.
	--
	-- @treturn BlobReader self
	rewind: =>
		@_readPtr = 0
		@

	--- Returns the current read position as an offset from the start of the input data in bytes.
	--
	-- @treturn number Current read position in bytes
	position: => @_readPtr

	-----------------------------------------------------------------------------

	_allocate: (size) =>
		local data
		data = ffi.new('uint8_t[?]', size) if size > 0
		@_data, @_size = data, size

	_readTagged: =>
		tag = @u8!
		tag, tag ~= _tags.stop and _taggedReaders[tag](@)

_parseByteOrder = (endian) ->
	switch endian
		when nil, '=', 'host'
			endian = ffi.abi('le') and 'le' or 'be'
		when '<'
			endian = 'le'
		when '>'
			endian = 'be'
		else
			error("Invalid byteOrder identifier: #{endian}")
	endian

_getTag = (value) ->
	return _tags[value] if value == true or value == false
	_tags[type(value)]

_native = ffi.new[[
	union {
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
]]

_endian =
	le:
		_16: (b1, b2) ->
			_native.u8[0], _native.u8[1] = b1, b2
			_native.u16[0]

		_32: (b1, b2, b3, b4) ->
			_native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b1, b2, b3, b4
			_native.u32[0]

		_64: (b1, b2, b3, b4, b5, b6, b7, b8) ->
			_native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b1, b2, b3, b4
			_native.u8[4], _native.u8[5], _native.u8[6], _native.u8[7] = b5, b6, b7, b8
			_native.u64

	be:
		_16: (b1, b2) ->
			_native.u8[0], _native.u8[1] = b2, b1
			_native.u16[0]

		_32: (b1, b2, b3, b4) ->
			_native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b4, b3, b2, b1
			_native.u32[0]

		_64: (b1, b2, b3, b4, b5, b6, b7, b8) ->
			_native.u8[0], _native.u8[1], _native.u8[2], _native.u8[3] = b8, b7, b6, b5
			_native.u8[4], _native.u8[5], _native.u8[6], _native.u8[7] = b4, b3, b2, b1
			_native.u64

_tags =
	stop: 0
	number: 1
	string: 2
	table: 3
	[true]: 4
	[false]: 5

_taggedReaders = {
	BlobReader.number
	BlobReader.string
	BlobReader.table
	=> true
	=> false
}

with BlobReader
	_arrayTypeMap =
		s8:      .s8
		u8:      .u8
		s16:     .s16
		u16:     .u16
		s32:     .s32
		u32:     .u32
		s64:     .s64
		u64:     .u64
		vs32:    .vs32
		vu32:    .vu32
		f32:     .f32
		f64:     .f64
		number:  .number
		string:  .string
		cstring: .cstring
		bool:    .bool
		table:   .table

with BlobReader
	_unpackMap =
		b: .s8
		B: .u8
		h: .s16
		H: .u16
		l: .s32
		L: .u32
		v: .vs32
		V: .vu32
		q: .s64
		Q: .u64
		f: .f32
		d: .number
		n: .number
		c: .raw
		s: .string
		z: .cstring
		t: .table
		y: .bool
		x: => nil, @skip(1)
		['<']: => nil, @setByteOrder('<')
		['>']: => nil, @setByteOrder('>')
		['=']: => nil, @setByteOrder('=')

BlobReader
