bitser = require('benchmarks.bitser')
bitser.loads(bitser.dumps({}))

{
	description: 'bitser'

	serialize:
		largeNumArray: bitser.dumps
		largeU32Array: bitser.dumps
		smallNumArray: bitser.dumps
		smallU8Array: bitser.dumps
		simpleTable: bitser.dumps
		deepTable: bitser.dumps

	deserialize:
		largeNumArray: bitser.loads
		largeU32Array: bitser.loads
		smallNumArray: bitser.loads
		smallU8Array: bitser.loads
		simpleTable: bitser.loads
		deepTable: bitser.loads
}
