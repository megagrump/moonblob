binser = require('benchmarks.binser')
binser.deserialize(binser.serialize({}))

{
	description: 'binser'

	serialize:
		largeNumArray: binser.serialize
		largeU32Array: binser.serialize
		smallNumArray: binser.serialize
		smallU8Array: binser.serialize
		simpleTable: binser.serialize
		deepTable: binser.serialize

	deserialize:
		largeNumArray: binser.deserialize
		largeU32Array: binser.deserialize
		smallNumArray: binser.deserialize
		smallU8Array: binser.deserialize
		simpleTable: binser.deserialize
		deepTable: binser.deserialize
}
