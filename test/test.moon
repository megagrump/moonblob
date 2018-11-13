-- run with luajit <path to moon> test.moon
_globals = {}
_globals[k] = v for k, v in pairs(_G)

package.moonpath = "#{package.moonpath};../?.moon"
lu = require('luaunit')
ffi = require('ffi')
BlobReader = require('BlobReader')
BlobWriter = require('BlobWriter')

equals, almost, isTrue, isError = lu.assertEquals, lu.assertAlmostEquals, lu.assertTrue, lu.assertErrorMsgContains

export *

test_Error = ->
	isError('Invalid data type', BlobReader, 1)
	isError('Invalid data type', BlobReader, true)
	isError('Invalid data type', BlobReader, {})
	isError('Invalid data type', BlobReader, ->)

test_Writer_tiny = ->
	b = BlobWriter(nil, 1)
	b\u32(0xbeefc0de)
	isTrue(b\length! <= b\size!)

test_Writer_signed = ->
	for _, endian in ipairs({ '<', '>', '=' })
		w = BlobWriter(endian)
		w\s8(i)\s16(i)\s32(i)\s64(i) for i = -128, 127

		r = BlobReader(w\tostring!, endian)
		for i = -128, 127
			equals(r\s8!, i)
			equals(r\s16!, i)
			equals(r\s32!, i)
			equals(r\s64!, ffi.cast('int64_t', i))

test_CData = ->
	data = ffi.new('uint8_t[256]')
	data[i] = i for i = 0, 255

	blob = BlobWriter(nil, 257)
	blob\raw(data, 256)
	blob\u8(123)

	reader = BlobReader(blob\tostring!)
	equals(reader\u8!, i) for i = 0, 255

	equals(reader\u8!, 123)
	equals(reader\position!, blob\length!)

	data = ffi.cast('uint8_t*', data)
	blob2 = BlobReader(data, nil, 256)
	equals(blob2\size!, 256)
	equals(blob2\u8!, i) for i = 0, 255

test_Formatted = ->
	b0 = BlobWriter!

	with b0
		\write(123)
		\write(true)
		\write(false)
		\write('hello')
		\write({
			num: 1
			sub: { num: 2 }
			[{}]: { tableAsIndex: true }
		})

	b1 = BlobReader(b0\tostring!)
	equals(b1\read!, 123)
	t = b1\read!
	f = b1\read!
	equals(t, true)
	equals(f, false)
	equals(b1\read!, 'hello')
	t = b1\read!
	equals(t.num, 1)
	equals(t.sub.num, 2)

	tableIndexFound = false
	for k, v in pairs(t)
		tableIndexFound = type(k) == 'table' and v.tableAsIndex
		break if tableIndexFound
	isTrue(tableIndexFound)

	deepTable = { inner: { val: 0 } }
	nested = deepTable.inner
	for i = 1, 1000
		nested.inner = { val: i }
		nested = nested.inner
	w = BlobWriter!\table(deepTable)\tostring!
	r = BlobReader(w)\table!

	nested = r.inner
	for i = 0, 1000
		lu.assertEquals(nested.val, i)
		nested = nested.inner

test_DataTypes = ->
	for _, endian in ipairs({ '<', '>', '=' })
		b1 = BlobWriter(endian)
		for i = 1, 100
			l = b1\length!
			with b1
				\u8(i)
				\s8(-i)
				\u16(i)
				\u16(i * 10)
				\s16(-i)
				\s16((i - 50) * 10)
				\u32(i * 4e7)
				\s32(-i * 4e6)
				\f32(i * 4e7)
				\f32(-i * 4e7)
				\u64(ffi.cast('uint64_t', 2 ^ 32 + i * 4e7))
				\s64(ffi.cast('int64_t', -2 ^ 32 - i * 4e7))
				\bool(i < 50)
				\bool(i > 50)
				\vu32(i * 1e5)
				\vs32(-i * 1e5)

		str = 'hello there'
		b1\string(str)
		b1\raw('raw data here')
		b1\cstring('cstring')
		b1\cstring('')

		bin = b1\tostring!
		equals(#bin, b1\length!)

		b2 = BlobReader(bin, endian)
		equals(b2\size!, b1\length!)

		for i = 1, 100
			equals(b2\u8!, i)
			equals(b2\s8!, -i)
			equals(b2\u16!, i)
			equals(b2\u16!, i * 10)
			equals(b2\s16!, -i)
			equals(b2\s16!, (i - 50) * 10)
			equals(b2\u32!, i * 4e7)
			equals(b2\s32!, -i * 4e6)
			equals(b2\f32!, i * 4e7)
			equals(b2\f32!, -i * 4e7)
			equals(b2\u64!, ffi.cast('uint64_t', 2 ^ 32 + i * 4e7))
			equals(b2\s64!, ffi.cast('int64_t', -2 ^ 32 - i * 4e7))
			equals(b2\bool!, i < 50)
			equals(b2\bool!, i > 50)
			equals(b2\vu32!, i * 1e5)
			equals(b2\vs32!, -i * 1e5)

		equals(b2\string!, str)
		equals(b2\raw(13), 'raw data here')
		equals(b2\cstring!, 'cstring')
		equals(b2\cstring!, '')
		isError('Out of data', b2.u8, b2)

test_Endianess = ->
	posNum = 2^33 + 1234567.89
	negNum = -2^33 - 1234567.89

	for _, item in ipairs({ { e: '<', fn: 'blob.le' }, { e: '>', fn: 'blob.be' } } )
		file = io.open(item.fn, 'rb')
		dat = file\read('*all')
		file\close!
		b3 = BlobReader(dat, item.e)
		equals(b3\u8!, 0)
		equals(b3\s8!, 0)
		equals(b3\u8!, 2 ^ 8 - 1)
		equals(b3\s8!, -(2 ^ 7 - 1))
		equals(b3\u16!, 0)
		equals(b3\s16!, 0)
		equals(b3\u16!, 2 ^ 16 - 1)
		equals(b3\s16!, -(2 ^ 15 - 1))
		equals(b3\u32!, 0)
		equals(b3\s32!, 0)
		equals(b3\u32!, 2 ^ 32 - 1)
		equals(b3\s32!, -(2 ^ 31 - 1))
		equals(b3\u64!, 18446744073709551615ULL)
		equals(b3\s64!, -9223372036854775808LL)
		equals(b3\number!, posNum)
		equals(b3\number!, negNum)
		equals(b3\u32!, 0x12345678)
		equals(b3\string!, 'end')

test_Tables = ->
	ttab =
		num: 12
		boolt: true
		boolf: false
		str: 'hello'
		tab:
			num: 24
			bool: false
			str: 'world'
		x: { 1, 2, nil, 4 }

	b4 = BlobWriter!\table(ttab)

	tab = BlobReader(b4\tostring!)\table!
	equals(tab.num, ttab.num)
	equals(tab.boolt, true)
	equals(tab.boolf, false)
	equals(tab.str, ttab.str)
	equals(tab.tab.num, ttab.tab.num)
	equals(tab.tab.bool, ttab.tab.bool)
	equals(tab.tab.str, ttab.tab.str)
	equals(ttab.x[1], 1)
	equals(ttab.x[2], 2)
	equals(ttab.x[3], nil)
	equals(ttab.x[4], 4)

	cyclic, cyclic2 = {}, {}
	cyclic.boop = { cycle: cyclic2 }
	cyclic2.foo = { cycle: cyclic }
	isError('Cycle', b4.table, b4, cyclic)

test_LargeString = ->
	b4 = BlobWriter!
	longstr = string.rep("x", 2 ^ 18)
	b4\string(longstr)
	equals(BlobReader(b4\tostring!)\string!, longstr)

test_pack_unpack = ->
	w = BlobWriter!\pack('<BHB>L=QvVz', 255, 65535, 0, 2 ^ 32 - 1, 9876543210123ULL, -2 ^ 31, 2 ^ 31, 'cstring')
	B, H, L, Q, v, V, z = BlobReader(w\tostring!)\unpack('<BHx>L=QvVz')
	equals(B, 255)
	equals(H, 65535)
	equals(L, 2 ^ 32 - 1)
	equals(Q, 9876543210123ULL)
	equals(v, -2 ^ 31)
	equals(V, 2 ^ 31)
	equals(z, 'cstring')

test_unpack_skipMultiple = ->
	w = BlobWriter!\s64(123456789)\s32(42)
	l = BlobReader(w\tostring!)\unpack('xxxxxxxxl')
	equals(l, 42)
	l = BlobReader(w\tostring!)\unpack('x8l')
	equals(l, 42)

test_pack = ->
	float, double = 123.45, 981273.12
	for _, endian in ipairs({ '<', '>', '=' })
		blob = BlobWriter(endian)
		blob\pack(endian .. 'bBhHlLVqQfdnc8yystc12',
			-2,
			220,
			-11991,
			12400,
			-2 ^ 18 + 110,
			2 ^ 30 + 1200,
			12345678,
			-123372036854775808LL,
			2846744073709551615ULL,
			float,
			double,
			double,
			'rawtest1',
			false,
			true,
			'test',
			{ a: 3, b: 4 },
			'rawtest12345'
		)

		r = BlobReader(blob\tostring!, endian)
		equals(r\s8!, -2)
		equals(r\u8!, 220)
		equals(r\s16!, -11991)
		equals(r\u16!, 12400)
		equals(r\s32!, -2 ^ 18 + 110)
		equals(r\u32!, 2 ^ 30 + 1200)
		equals(r\vu32!, 12345678)
		equals(r\s64!, -123372036854775808LL)
		equals(r\u64!, 2846744073709551615ULL)
		equals(r\f32!, tonumber(ffi.cast('float', float)))
		equals(r\f64!, double)
		equals(r\number!, double)
		equals(r\raw(8), 'rawtest1')
		equals(r\bool!, false)
		equals(r\bool!, true)
		equals(r\string!, 'test')
		tab = r\table!
		equals(tab.a, 3)
		equals(tab.b, 4)
		equals(r\raw(12), 'rawtest12345')
		isError('Invalid data type', blob.pack, blob, '/')
		isError('Number of arguments', blob.pack, blob, 'b')

test_unpack = ->
	float, double = 123.45, 981273.12
	for _, endian in ipairs({ '<', '>', '=' })
		w = BlobWriter(endian)
		with w
			\s8(-12)
			\u8(200)
			\s16(-1019)
			\u16(4000)
			\s32(-2 ^ 18 + 10)
			\u32(2 ^ 30 + 100)
			\vu32(87654321)
			\s64(-923372036854775808LL)
			\u64(1846744073709551615ULL)
			\u8(0)
			\f32(float)
			\number(double)
			\number(double)
			\raw('rawtest1')
			\bool(false)
			\bool(true)
			\string('test')
			\table({ a: 1, b: 2 })
			\raw('rawtest12345')

		reader = BlobReader(w\tostring!)
		b, B, h, H, l, L, V, q, Q, f, d, n, c8, yf, yt, s, t, c12 = reader\unpack(endian .. 'bBhHlLVqQxfdnc8yystc12')
		equals(b, -12)
		equals(B, 200)
		equals(h, -1019)
		equals(H, 4000)
		equals(l, -2 ^ 18 + 10)
		equals(L, 2 ^ 30 + 100)
		equals(V, 87654321)
		equals(q, -923372036854775808LL)
		equals(Q, 1846744073709551615ULL)
		equals(f, tonumber(ffi.cast('float', 123.45)))
		equals(d, double)
		equals(n, double)
		equals(c8, 'rawtest1')
		equals(yf, false)
		equals(yt, true)
		equals(s, 'test')
		equals(t.a, 1)
		equals(t.b, 2)
		equals(c12, 'rawtest12345')
		isError('Invalid data type', reader.unpack, reader, '/')
		isError('Out of data', reader.skip, reader, 1)


test_VarU32 = ->
	blob = BlobWriter!
	with blob
		equals(\vu32size(0), 1)
		equals(\vu32size(2 ^ 7 - 1), 1)
		equals(\vu32size(2 ^ 7), 2)
		equals(\vu32size(2 ^ 14 - 1), 2)
		equals(\vu32size(2 ^ 14), 3)
		equals(\vu32size(2 ^ 21 - 1), 3)
		equals(\vu32size(2 ^ 21), 4)
		equals(\vu32size(2 ^ 28 - 1), 4)
		equals(\vu32size(2 ^ 28), 5)
		equals(\vu32size(2 ^ 32 - 1), 5)

		\vu32(0)
		\vu32(2 ^ 7)
		\vu32(2 ^ 11)
		\vu32(2 ^ 27)
		\vu32(2 ^ 31)
		\vu32(2 ^ 32 - 1)
		isError('Exceeded', .vu32, blob, 2 ^ 33)

	blob = BlobReader(blob\tostring!)
	with blob
		equals(\vu32!, 0)
		equals(\vu32!, 2 ^ 7)
		equals(\vu32!, 2 ^ 11)
		equals(\vu32!, 2 ^ 27)
		equals(\vu32!, 2 ^ 31)
		equals(\vu32!, 2 ^ 32 - 1)

test_VarS32 = ->
	blob = BlobWriter!
	with blob
		equals(\vs32size(          0), 1)
		equals(\vs32size(       -126), 1)
		equals(\vs32size(        126), 1)
		equals(\vs32size(       -127), 2)
		equals(\vs32size(     -16382), 2)
		equals(\vs32size(        127), 2)
		equals(\vs32size(      16382), 2)
		equals(\vs32size(     -16383), 3)
		equals(\vs32size(      16383), 3)
		equals(\vs32size(   -2097150), 3)
		equals(\vs32size(    2097150), 3)
		equals(\vs32size(   -2097151), 4)
		equals(\vs32size(    2097151), 4)
		equals(\vs32size( -268435454), 4)
		equals(\vs32size(  268435454), 4)
		equals(\vs32size( -268435455), 5)
		equals(\vs32size(  268435455), 5)
		equals(\vs32size(-2147483648), 5)
		equals(\vs32size( 2147483647), 5)

		\vs32(0)
		\vs32(2 ^ 7)
		\vs32(2 ^ 11)
		\vs32(2 ^ 27)
		\vs32(2 ^ 31 - 1)
		\vs32(-2 ^ 7)
		\vs32(-2 ^ 11 + 1)
		\vs32(-2 ^ 27 + 1)
		\vs32(-2 ^ 31)

		isError('Exceeded', .vs32, blob, 2 ^ 31)

	blob = BlobReader(blob\tostring!)
	with blob
		equals(\vs32!, 0)
		equals(\vs32!, 2 ^ 7)
		equals(\vs32!, 2 ^ 11)
		equals(\vs32!, 2 ^ 27)
		equals(\vs32!, 2 ^ 31 - 1)
		equals(\vs32!, -2 ^ 7)
		equals(\vs32!, -2 ^ 11 + 1)
		equals(\vs32!, -2 ^ 27 + 1)
		equals(\vs32!, -2 ^ 31)

test_Reader_ByteOrder = ->
	posNum = 2^33 + 1234567.89
	negNum = -2^33 - 1234567.89

	for _, item in ipairs({ { e: '<', fn: 'blob.le' }, { e: '>', fn: 'blob.be' } } )
		file = io.open(item.fn, 'rb')
		dat = file\read('*all')
		file\close!
		b3 = BlobReader(dat, item.e)
		equals(b3\u8!, 0)
		equals(b3\s8!, 0)
		equals(b3\u8!, 2 ^ 8 - 1)
		equals(b3\s8!, -(2 ^ 7 - 1))
		equals(b3\u16!, 0)
		equals(b3\s16!, 0)
		equals(b3\u16!, 2 ^ 16 - 1)
		equals(b3\s16!, -(2 ^ 15 - 1))
		equals(b3\u32!, 0)
		equals(b3\s32!, 0)
		equals(b3\u32!, 2 ^ 32 - 1)
		equals(b3\s32!, -(2 ^ 31 - 1))
		equals(b3\u64!, 18446744073709551615ULL)
		equals(b3\s64!, -9223372036854775808LL)
		equals(b3\f64!, posNum)
		equals(b3\f64!, negNum)
		equals(b3\u32!, 0x12345678)
		equals(b3\string!, 'end')

test_Reader_unpack = ->
	posNum = 2^33 + 1234567.89
	negNum = -2^33 - 1234567.89

	for _, item in ipairs({ { e: '<', fn: 'blob.le' }, { e: '>', fn: 'blob.be' } } )
		file = io.open(item.fn, 'rb')
		dat = file\read('*all')
		file\close!
		b = BlobReader(dat, item.e)
		b1, b2, b3, b4, w1, w2, w3, w4, d1, d2, d3, d4, q1, q2, n1, n2, d5, s1 = b\unpack('BbBbHhHhLlLlQqddLs')
		equals(b1, 0)
		equals(b2, 0)
		equals(b3, 2 ^ 8 - 1)
		equals(b4, -(2 ^ 7 - 1))
		equals(w1, 0)
		equals(w2, 0)
		equals(w3, 2 ^ 16 - 1)
		equals(w4, -(2 ^ 15 - 1))
		equals(d1, 0)
		equals(d2, 0)
		equals(d3, 2 ^ 32 - 1)
		equals(d4, -(2 ^ 31 - 1))
		equals(q1, 18446744073709551615ULL)
		equals(q2, -9223372036854775808LL)
		equals(n1, posNum)
		equals(n2, negNum)
		equals(d5, 0x12345678)
		equals(s1, 'end')

test_Writer_array = ->
	_testTypeSize = (type, values, valueSize) ->
		b = BlobWriter!
		b\array(type, values)
		equals(b\length!, #values * valueSize + 1)

	size1 = { 's8', 'u8', 'vs32', 'vu32' }
	for i = 1, #size1
		_testTypeSize(size1[i], { 23, 42, 63 }, 1)
	size2 = { 's16', 'u16', 'vs32', 'vu32' }
	for i = 1, #size2
		_testTypeSize(size2[i], { 6623, 6642, 6127 }, 2)
	size4 = { 's32', 'u32', 'f32', 'vs32', 'vu32' }
	for i = 1, #size4
		_testTypeSize(size4[i], { 123456623, 3214564, 5456127 }, 4)
	size8 = { 's64', 'u64', 'f64', 'number' }
	for i = 1, #size8
		_testTypeSize(size8[i], { 0x123456789ab, 0xcf012312345, -1, -438 }, 8)

	_testTypeSize('string', { 'test', '1234' }, 5)
	_testTypeSize('cstring', { 'test2', '12345' }, 6)
	_testTypeSize('bool', { true, false }, 1)

	large = {}
	large[i] = i for i = 1, 2 ^ 20
	res = BlobWriter!\array('u32', large)\tostring!
	equals(#res, 3 + 2 ^ 20 * 4)

	isError('Invalid array', BlobWriter.array, BlobWriter!, 'inv', {})

test_Reader_array = ->
	w = BlobWriter!
	w\array('u8', { 23, 42 })
	w\array('s16', { 23, -42 })
	w\array('u32', { 0x12345678, 0x87654321 })
	w\array('vs32', { -0x12345678, 0x12345678 })
	w\array('s64', { -23, 42 })
	w\array('f32', { 23.1, 42.2 })
	w\array('f64', { 23.23, 42.42 })
	w\array('bool', { true, false })
	w\array('string', { 'hello', 'world' })
	w\array('cstring', { 'hello', 'world' })
	w\array('table', { { hello: 'world', success: true, answer: 23 } })

	r = BlobReader(w\tostring!)
	u8 = r\array('u8')
	equals(#u8, 2)
	equals( u8[1], 23)
	equals( u8[2], 42)

	s16 = r\array('s16')
	equals(#s16, 2)
	equals( s16[1], 23)
	equals( s16[2], -42)

	u32 = r\array('u32')
	equals(#u32, 2)
	equals( u32[1], 0x12345678)
	equals( u32[2], 0x87654321)

	vs32 = r\array('vs32')
	equals(#vs32, 2)
	equals( vs32[1], -0x12345678)
	equals( vs32[2], 0x12345678)

	s64 = r\array('s64')
	equals(#s64, 2)
	equals( s64[1], -23LL)
	equals( s64[2], 42LL)

	f32 = r\array('f32')
	equals(#f32, 2)
	almost( f32[1], 23.1, .01)
	almost( f32[2], 42.2, .01)

	f64 = r\array('f64')
	equals(#f64, 2)
	almost( f64[1], 23.23, .01)
	almost( f64[2], 42.42, .01)

	bool = r\array('bool')
	equals(#bool, 2)
	isTrue(bool[1])
	lu.assertFalse(bool[2])

	str = r\array('string')
	equals(#str, 2)
	equals(str[1], 'hello')
	equals(str[2], 'world')

	cstr = r\array('cstring')
	equals(#cstr, 2)
	equals(cstr[1], 'hello')
	equals(cstr[2], 'world')

	tbl = r\array('table')
	equals(#tbl, 1)
	with tbl[1]
		equals(.hello, 'world')
		isTrue(.success)
		equals(.answer, 23)

	large = {}
	large[i] = i for i = 1, 2 ^ 20
	d = BlobReader(BlobWriter!\array('u32', large)\tostring!)\array('u32')
	equals(#d, 2 ^ 20)
	equals(d[i], i) for i = 1, #d


test_xxxLastCheckGlobals = ->
	for k, v in pairs(_G)
		unless k\match('^test_.*')
			print('\nLEAKED GLOBAL:', k) if _globals[k] == nil
			isTrue(_globals[k] ~= nil)

test_Writer_clear = ->
	b = BlobWriter(nil, 1)
	b\u8(1)
	b\clear!
	equals(b\size!, 1)
	equals(b\length!, 0)

test_table_with_nil = ->
	wt = { 1, 2, nil, 5, 6, nil }
	w = BlobWriter!
	d = w\write(wt)\tostring!

	rt = BlobReader(d)\read!
	equals(wt, rt)

lu.LuaUnit.new!\runSuite!
