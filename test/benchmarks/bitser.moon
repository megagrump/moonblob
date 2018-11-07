bitser = require('bitser')

{
	description: 'bitser'

	serialize:
		largeNumberArray: bitser.dumps
		largeU32Array: bitser.dumps
		smallNumberArray: bitser.dumps
		smallU8Array: bitser.dumps
		simpleTable: bitser.dumps
		deepTable: bitser.dumps

	deserialize:
		largeNumberArray: bitser.loads
		largeU32Array: bitser.loads
		smallNumberArray: bitser.loads
		smallU8Array: bitser.loads
		simpleTable: bitser.loads
		deepTable: bitser.loads
}
