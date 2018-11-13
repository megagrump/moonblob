BlobWriter, BlobReader = require('BlobWriter'), require('BlobReader')
writer, reader = BlobWriter!, BlobReader('')
reader\reset(writer\table({})\tostring!)\table!

{
	description: 'Blob'

	serialize:
		largeNumArray: (data) -> writer\clear!\array('number', data)\tostring!
		largeU32Array: (data) -> writer\clear!\array('u32', data)\tostring!
		smallNumArray: (data) -> writer\clear!\array('number', data)\tostring!
		smallU8Array: (data) -> writer\clear!\array('u8', data)\tostring!
		simpleTable: (data) -> writer\clear!\table(data)\tostring!
		deepTable: (data) -> writer\clear!\table(data)\tostring!

	deserialize:
		largeNumArray: (data) -> reader\reset(data)\array('number')
		largeU32Array: (data) -> reader\reset(data)\array('u32')
		smallNumArray: (data) -> reader\reset(data)\array('number')
		smallU8Array: (data) -> reader\reset(data)\array('u8')
		simpleTable: (data) -> reader\reset(data)\table!
		deepTable: (data) -> reader\reset(data)\table!
}
