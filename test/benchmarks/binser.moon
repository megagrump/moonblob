binser = require('binser')

{
	description: 'binser'

	serialize:
		largeNumberArray: binser.serialize
		largeU32Array: binser.serialize
		smallNumberArray: binser.serialize
		smallU8Array: binser.serialize
		simpleTable: binser.serialize
		deepTable: binser.serialize

	deserialize:
		largeNumberArray: binser.deserialize
		largeU32Array: binser.deserialize
		smallNumberArray: binser.deserialize
		smallU8Array: binser.deserialize
		simpleTable: binser.deserialize
		deepTable: binser.deserialize
}
