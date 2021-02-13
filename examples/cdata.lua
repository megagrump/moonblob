-- How to write custom serialization functions for ctypes
package.path = package.path .. ';../?.lua'
local BlobReader, BlobWriter = require('BlobReader'), require('BlobWriter')
local ffi = require('ffi')

ffi.cdef([[
	typedef struct {
		double x, y;
		const char *name;
	} teststruct_t;
]])

-- LuaJIT's ffi API does not provide a way to retrieve the declared name of ctypes.
-- To enable transparent serialization of cdata (e.g. cdata in tables), additional metadata has to be added
-- to the metatable of the ctype.
local metatype = {
	__index = {
		-- the typename from the cdef declaration
		-- if this identifier is present, the ctype can be automatically serialized
		-- if not present, only BlobWriter:cdata() and BlobReader:cdata() can be used with this type
		__typename = 'teststruct_t',

		-- custom serialization of cdata. called when a cdata object is serialized
		-- this function is only required for ctypes that contain data of unknown size (i.e. pointers)
		__serialize = function(self, writer)
			return writer
				:number(self.x)
				:number(self.y)
				:string(ffi.string(self.name))
		end,

		-- custom deserialization of cdata. called when a cdata object is deserialized
		-- this function is only required for ctypes that have a __serialize function
		__deserialize = function(ctype, reader)
			return ctype(
				reader:number(),
				reader:number(),
				reader:string()
			)
		end,
	}
}

-- add serialization information to teststruct_t
local ctype = ffi.metatype(ffi.typeof('teststruct_t'), metatype)

local cdata = ctype(23, 42, 'test')

-- write cdata
local serialized = BlobWriter():write(cdata):tostring()

-- read cdata
local deserialized = BlobReader(serialized):read()

-- cdata and deserialized should be identical
print("Deserialized object is of type " .. deserialized.__typename)
print("Input values: ", cdata.x, cdata.y, ffi.string(cdata.name))
print("Output values: ", deserialized.x, deserialized.y, ffi.string(deserialized.name))

