-- BlobReader example: parse binary data via Blob\unpack
-- This example shows how to use Blob\unpack to parse arbitrary binary files
-- run with luajit <path to moon> file.moon
package.moonpath = "#{package.moonpath};../?.moon"
BlobReader = require('BlobReader')
import format from string

file = assert(io.open('smile.png'))
blob = BlobReader(file\read('*all'))
file\close!

-- parse png header
magic1, magic2 = blob\unpack('>LL') -- PNG has big endian byte order
assert(magic1 == 0x89504e47, "Invalid PNG or damaged file")
assert(magic2 == 0x0d0a1a0a, "Invalid PNG or damaged file")

at_end = false
-- read chunks
while not at_end and blob\position! < blob\size! do
	length, type = blob\unpack('Lc4')

	switch type
		when 'IHDR'
			width, height, bpp = blob\unpack('LLBx4')
			print("Image width: #{width} pixels")
			print("Image height: #{height} pixels")
			print("Bit depth: #{bpp} bpp")
		when 'pHYs'
			ppux, ppuy, units = blob\unpack('LLB')
			print("#{ppux} pixels per unit, X axis")
			print("#{ppuy} pixels per unit, Y axis")
			print("Unit specifier: %s"\format(units == 1 and "meter" or "unknown"))
		when 'iTXt'
			data = blob\unpack("c#{length}")
			sep = data\find('\0')
			print(("%s: %s")\format(data\sub(1, sep - 1), data\sub(sep + 5)))
		when 'IEND'
			print("End of image marker")
			at_end = true
		else
			print("Chunk type #{type}, data length #{length}")
			blob\skip(length) -- skip chunk data

	crc = blob\unpack('L')
	print("Chunk CRC: 0x%x"\format(crc))
	print(string.rep("-", 60))
