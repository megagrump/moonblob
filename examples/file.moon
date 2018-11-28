-- Blob example: save and load data to/from file
-- run with luajit <path to moon> file.moon
package.moonpath = "#{package.moonpath};../?.moon"
BlobReader, BlobWriter = require('BlobReader'), require('BlobWriter')

projectInfo =
	name:         'moonblob',
	author:       'megagrump@protonmail.com',
	url:          'https://github.com/megagrump/moonblob',
	license:      'MIT',
	magicnumber:  0xbaadc0de,
	tests:        { 'test/test.moon' }

-- serialize the table
tableBlob = BlobWriter!
tableBlob\write(projectInfo)
-- save the table
file = assert(io.open('table.dat', 'wb'))
file\write(tableBlob\tostring!)
file\close()

-- load the table
file = assert(io.open('table.dat', 'rb'))
filedata = file\read('*all')
file\close()
--deserialize table
blob = BlobReader(filedata)
projectTable = blob\read()

-- display loaded table
show = (what) ->
	for k, v in pairs(what)
		if type(v) == 'table'
			print(k .. ":")
			show(v)
		else
			print(string.format("%s = %s", k, v))

show(projectTable)
