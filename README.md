# moonblob - binary serialization library

moonblob is a compact LuaJIT library written in moonscript that performs serialization into an efficient binary format. It can be used to parse arbitrary binary data, or to serialize data for efficient storage or transmission.

## How to use

### Lua example

#### Reading data

	BlobReader = require('BlobReader')

	-- Load data from file
	file = io.open('filename.ext', 'rb')
	blob = BlobReader(file:read('*all'))
	file:close!

	-- Parse binary data
	u8 = blob:u8()
	s16 = blob:s16()
	str = blob:cstring()
	float = blob:f32()
	...

	-- Read Lua types
	tbl = blob:table()
	bool = blob:bool() -- 8 bits, 0 == false
	num = blob:number()
	str = blob:string()

#### Writing data

	BlobWriter = require('BlobWriter')

	blob = BlobWriter()

	-- Store binary data
	blob
		:u8(23)
		:number(123.45)
		:f32(23.0)
		:string('string')
		...

	-- Store Lua types
	blob
		:write({ key: 'value', tbl: { 1, 2, 3 } }) -- no cycles allowed!
		:write(23)
		:write(true)
		:write('string')

	-- Write data to file
	file = io.open('filename.ext', 'wb')
	file:write(blob:tostring())
	file:close()


### moonscript example

#### Reading data

	BlobReader = require('BlobReader')

	-- Load data from file
	file = io.open('filename.ext', 'rb')
	blob = BlobReader(file\read('*all'))
	file\close!

	-- Parse binary data
	u8 = blob\u8!
	s16 = blob\s16!
	str = blob\cstring!
	float = blob\f32!
	...

	-- Read Lua types
	tbl = blob\table!
	bool = blob\bool! -- 8 bits, 0 == false
	num = blob\number!
	str = blob\string!

#### Writing data

	BlobWriter = require('BlobWriter')

	-- Create a new Blob for writing
	blob = BlobWriter!

	-- Store binary data
	with blob
		\u8(23)
		\number(123.45)
		\f32(23.0)
		\string('string')
		...

	-- Store Lua types
	with blob
		\write({ key: 'value', tbl: { 1, 2, 3 } }) -- no cycles allowed!
		\write(23)
		\write(true)
		\write('string')

	-- Write data to file
	file = io.open('filename.ext', 'wb')
	file\write(blob\tostring!)
	file\close!

## Documentation

[API documentation](https://megagrump.github.io/moonblob/doc/)

### Reading and writing Lua types

[`BlobReader\read`](https://megagrump.github.io/moonblob/doc/classes/BlobReader.html#read) and [`BlobWriter\write`](https://megagrump.github.io/moonblob/doc/classes/BlobWriter.html#write) can be used to store Lua values along with their type. `BlobReader\read` can only read data that was previously written by `BlobWriter\write`.

These data types are supported by `BlobReader\read` and `BlobWriter\write`:
* `number` (64 bit)
* `string` (up to 2^32-1 bytes)
* `boolean`
* `table`

Type and length information will be added as metadata by the `write` function. Metadata overhead is 1 byte per value written for type information, and between 1 and 5 bytes per string written for length information. Tables can contain `number`, `string`, `boolean`, and `table` as key and value types. An error is being thrown if other types or cyclic nested tables are encountered.

### Low level I/O

A low level interface is provided for handling arbitrary binary data.

	number       -- Lua number (64 bit floating point)
	bool         -- boolean value (8 bits; 0 == false)
	string       -- Lua string
	table        -- Lua table
	s8  / u8     -- signed/unsigned 8 bit integer value
	s16 / u16    -- signed/unsigned 16 bit integer value
	s32 / u32    -- signed/unsigned 32 bit integer value
	s64 / u64    -- signed/unsigned 64 bit integer value
	vs32 / vu32  -- length-encoded signed/unsigned 32 bit value
	f32 / f64    -- 32/64 bit floating point value
	raw          -- raw binary data (length must be specified)
	cstring      -- zero-terminated string
	array        -- sequential table of typed values

To describe the raw data format in a more concise manner, use [`BlobWriter\pack`](https://megagrump.github.io/moonblob/doc/classes/BlobWriter.html#pack) and [`BlobReader\unpack`](https://megagrump.github.io/moonblob/doc/classes/BlobReader.html#unpack). These functions work similar to `string.unpack` and `string.pack` in Lua 5.3, although some details are different (fixed instead of native data sizes; more supported data types; some features are not implemented). See [API documentation](https://megagrump.github.io/moonblob/doc) for details.

### Benchmark results

Source code for benchmarks can be found in the `test` directory.

#### Serialization speed (ops/sec, larger is better)

--- | deepTable | largeNumArray | largeU32Array | simpleTable | smallNumArray | smallU8Array
--- | --- | --- | --- | --- | --- | --- | 
**BlobWriter** | **1,007** | **1,695** | **5,908** | **490,782** | **460,424** | **880,942** | 
**bitser** | 422 | 179 | 191 | 313,985 | 43,573 | 52,559 | 
**binser** | 478 | 32 | 32 | 231,066 | 13,192 | 16,734 | 

#### Deserialization speed (ops/sec, larger is better)

--- | deepTable | largeNumArray | largeU32Array | simpleTable | smallNumArray | smallU8Array
--- | --- | --- | --- | --- | --- | --- | 
**BlobReader** | **2,052** | **555** | **1,103** | **576,510** | **130,497** | **324,381** | 
**bitser** | 1,880 | 300 | 40 | 543,913 | 95,137 | 100,232 | 
**binser** | 1,371 | 83 | 77 | 375,935 | 29,017 | 50,566 | 

#### Serialization size (bytes, smaller is better)

--- | deepTable | largeNumArray | largeU32Array | simpleTable | smallNumArray | smallU8Array
--- | --- | --- | --- | --- | --- | --- | 
**BlobWriter** | 45,808 | 524,291 | **262,147** | 69 | 2,042 | **258** | 
**bitser** | **25,732** | **393,025** | 404,089 | **62** | 1,338 | 571 | 
**binser** | 25,837 | 532,398 | 589,195 | 69 | **1,310** | 415 | 

### Compatibility

Since moonblob uses the ffi library and C data types, it is not compatible with vanilla Lua and can only be used with LuaJIT.

### License

Copyright 2017, 2018 megagrump

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
