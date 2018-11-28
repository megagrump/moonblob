-- Blob.lua example: parse binary data with raw i/o functions
-- This example shows how to use Blob.lua to parse arbitrary binary files
-- run with luajit <path to moon> file.moon
package.moonpath = "#{package.moonpath};../?.moon"
BlobReader = require('BlobReader')
import format from string

file = assert(io.open('smile.png'))
blob = BlobReader(file\read('*all'), '>') -- PNG uses big endian byte order
file\close!

-- parse png header
magic1, magic2 = blob\u32!, blob\u32!
assert(magic1 == 0x89504e47, "Invalid PNG or damaged file")
assert(magic2 == 0x0d0a1a0a, "Invalid PNG or damaged file")

at_end = false
-- read chunks
while not at_end and blob\position! < blob\size! do
	length = blob\u32!
	type = blob\raw(4)

	switch type
		when 'IHDR'
			print("Image width: #{blob\u32!} pixels")
			print("Image height: #{blob\u32!} pixels")
			print("Bit depth: #{blob\u8!} bpp")
			blob\skip(4) -- skip rest of chunk
		when 'pHYs'
			print("#{blob\u32!} pixels per unit, X axis")
			print("#{blob\u32!} pixels per unit, Y axis")
			print("Unit specifier: #{blob\u8! == 1 and 'meter' or 'unknown'}")
		when 'iTXt'
			data = blob\raw(length)
			sep = data\find('\0')
			print(format("%s: %s", data\sub(1, sep - 1), data\sub(sep + 5)))
		when 'IEND'
			print("End of image marker")
			at_end = true
		else
			print("Chunk type #{type}, data length #{length}")
			blob\skip(length) -- skip chunk data

	crc = blob\u32!
	print("Chunk CRC: 0x%x"\format(crc))
	print(string.rep("-", 60))
