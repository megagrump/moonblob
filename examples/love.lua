-- example: read and write save data with LÖVE
local BlobReader, BlobWriter = require('BlobReader'), require('BlobWriter')

local function write_save(filename, data)
	local blob = BlobWriter()
	blob:write(data)
	assert(love.filesystem.write(filename, blob:tostring()))
end

local function read_save(filename)
	local filedata = assert(love.filesystem.read(filename))
	local blob = BlobReader(filedata)
	return blob:read()
end

-- write data to LÖVE save directory
write_save('save.dat', {
	example = 'save_data'
})

-- read data from LÖVE save directory
local saveData = read_save('save.dat')
for k, v in pairs(saveData) do
	print(k, v)
end
