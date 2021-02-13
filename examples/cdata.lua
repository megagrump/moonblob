-- How to write custom serialization functions for ctypes
package.path = package.path .. ';../?.lua'
local BlobReader, BlobWriter = require('BlobReader'), require('BlobWriter')
local ffi = require('ffi')

ffi.cdef('typedef struct { double x, y; } teststruct_t;')

local metatype = {
	__index = {
		__typename = 'teststruct_t', -- the typename from the cdef declaration

		__serialize = function(self, writer) -- called when writing data
			return writer:number(self.x):number(self.y)
		end,

		__deserialize = function(ctype, reader) -- called when reading data
			return ctype(reader:number(), reader:number())
		end,
	}
}

local ctype = ffi.metatype(ffi.typeof('teststruct_t'), metatype) -- add serialization functions to teststruct_t
local cdata = ctype(23, 42)

-- write cdata
local serialized = BlobWriter():write(cdata):tostring()

-- read cdata
local deserialized = BlobReader(serialized):read()

print("Deserialized object is of type " .. deserialized.__typename)
print("Input values: ", cdata.x, cdata.y)
print("Output values: ", deserialized.x, deserialized.y)
