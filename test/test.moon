-- run with luajit <path to moon> test.moon
_globals = {}
_globals[k] = v for k, v in pairs(_G)

package.moonpath = "#{package.moonpath];../?.moon"
lu = require('luaunit')
ffi = require('ffi')
BlobReader = require('BlobReader')
BlobWriter = require('BlobWriter')

export *

test_Error = ->
	lu.assertErrorMsgContains('Invalid data type', BlobReader, 1)
	lu.assertErrorMsgContains('Invalid data type', BlobReader, true)
	lu.assertErrorMsgContains('Invalid data type', BlobReader, {})
	lu.assertErrorMsgContains('Invalid data type', BlobReader, ->)

test_Writer_tiny = ->
	b = BlobWriter(nil, 1)
	b\u32(0xbeefc0de)
	lu.assertTrue(b\length! <= b\size!)

test_Writer_signed = ->
	for _, endian in ipairs({ '<', '>', '=' })
		w = BlobWriter(endian)
		w\s8(i)\s16(i)\s32(i)\s64(i) for i = -128, 127

		r = BlobReader(w\tostring!, endian)
		for i = -128, 127
			lu.assertEquals(r\s8!, i)
			lu.assertEquals(r\s16!, i)
			lu.assertEquals(r\s32!, i)
			lu.assertEquals(r\s64!, ffi.cast('int64_t', i))

test_CData = ->
	data = ffi.new('uint8_t[256]')
	data[i] = i for i = 0, 255

	blob = BlobWriter(nil, 257)
	blob\raw(data, 256)
	blob\u8(123)

	reader = BlobReader(blob\tostring!)
	lu.assertEquals(reader\u8!, i) for i = 0, 255

	lu.assertEquals(reader\u8!, 123)
	lu.assertEquals(reader\position!, blob\length!)

	data = ffi.cast('uint8_t*', data)
	blob2 = BlobReader(data, nil, 256)
	lu.assertEquals(blob2\size!, 256)
	lu.assertEquals(blob2\u8!, i) for i = 0, 255

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
		})

	b1 = BlobReader(b0\tostring!)
	lu.assertEquals(b1\read!, 123)
	t = b1\read!
	f = b1\read!
	lu.assertEquals(t, true)
	lu.assertEquals(f, false)
	lu.assertEquals(b1\read!, 'hello')
	t = b1\read!
	lu.assertEquals(t.num, 1)
	lu.assertEquals(t.sub.num, 2)

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
		lu.assertEquals(#bin, b1\length!)

		b2 = BlobReader(bin, endian)
		lu.assertEquals(b2\size!, b1\length!)

		for i = 1, 100
			lu.assertEquals(b2\u8!, i)
			lu.assertEquals(b2\s8!, -i)
			lu.assertEquals(b2\u16!, i)
			lu.assertEquals(b2\u16!, i * 10)
			lu.assertEquals(b2\s16!, -i)
			lu.assertEquals(b2\s16!, (i - 50) * 10)
			lu.assertEquals(b2\u32!, i * 4e7)
			lu.assertEquals(b2\s32!, -i * 4e6)
			lu.assertEquals(b2\f32!, i * 4e7)
			lu.assertEquals(b2\f32!, -i * 4e7)
			lu.assertEquals(b2\u64!, ffi.cast('uint64_t', 2 ^ 32 + i * 4e7))
			lu.assertEquals(b2\s64!, ffi.cast('int64_t', -2 ^ 32 - i * 4e7))
			lu.assertEquals(b2\bool!, i < 50)
			lu.assertEquals(b2\bool!, i > 50)
			lu.assertEquals(b2\vu32!, i * 1e5)
			lu.assertEquals(b2\vs32!, -i * 1e5)

		lu.assertEquals(b2\string!, str)
		lu.assertEquals(b2\raw(13), 'raw data here')
		lu.assertEquals(b2\cstring!, 'cstring')
		lu.assertEquals(b2\cstring!, '')
		lu.assertErrorMsgContains('Out of data', b2.u8, b2)

test_Endianess = ->
	posNum = 2^33 + 1234567.89
	negNum = -2^33 - 1234567.89

	for _, item in ipairs({ { e: '<', fn: 'blob.le' }, { e: '>', fn: 'blob.be' } } )
		file = io.open(item.fn, 'rb')
		dat = file\read('*all')
		file\close!
		b3 = BlobReader(dat, item.e)
		lu.assertEquals(b3\u8!, 0)
		lu.assertEquals(b3\s8!, 0)
		lu.assertEquals(b3\u8!, 2 ^ 8 - 1)
		lu.assertEquals(b3\s8!, -(2 ^ 7 - 1))
		lu.assertEquals(b3\u16!, 0)
		lu.assertEquals(b3\s16!, 0)
		lu.assertEquals(b3\u16!, 2 ^ 16 - 1)
		lu.assertEquals(b3\s16!, -(2 ^ 15 - 1))
		lu.assertEquals(b3\u32!, 0)
		lu.assertEquals(b3\s32!, 0)
		lu.assertEquals(b3\u32!, 2 ^ 32 - 1)
		lu.assertEquals(b3\s32!, -(2 ^ 31 - 1))
		lu.assertEquals(b3\u64!, 18446744073709551615ULL)
		lu.assertEquals(b3\s64!, -9223372036854775808LL)
		lu.assertEquals(b3\number!, posNum)
		lu.assertEquals(b3\number!, negNum)
		lu.assertEquals(b3\u32!, 0x12345678)
		lu.assertEquals(b3\string!, 'end')

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
	lu.assertEquals(tab.num, ttab.num)
	lu.assertEquals(tab.boolt, true)
	lu.assertEquals(tab.boolf, false)
	lu.assertEquals(tab.str, ttab.str)
	lu.assertEquals(tab.tab.num, ttab.tab.num)
	lu.assertEquals(tab.tab.bool, ttab.tab.bool)
	lu.assertEquals(tab.tab.str, ttab.tab.str)
	lu.assertEquals(ttab.x[1], 1)
	lu.assertEquals(ttab.x[2], 2)
	lu.assertEquals(ttab.x[3], nil)
	lu.assertEquals(ttab.x[4], 4)

	cyclic, cyclic2 = {}, {}
	cyclic.boop = { cycle: cyclic2 }
	cyclic2.foo = { cycle: cyclic }
	lu.assertErrorMsgContains('Cycle', b4.table, b4, cyclic)

test_LargeString = ->
	b4 = BlobWriter!
	longstr = string.rep("x", 2 ^ 18)
	b4\string(longstr)
	lu.assertEquals(BlobReader(b4\tostring!)\string!, longstr)

test_pack_unpack = ->
	w = BlobWriter!\pack('<BHB>L=QvV', 255, 65535, 0, 2 ^ 32 - 1, 9876543210123ULL, -2 ^ 31, 2 ^ 31)
	B, H, L, Q, v, V = BlobReader(w\tostring!)\unpack('<BHx>L=QvV')
	lu.assertEquals(B, 255)
	lu.assertEquals(H, 65535)
	lu.assertEquals(L, 2 ^ 32 - 1)
	lu.assertEquals(Q, 9876543210123ULL)
	lu.assertEquals(v, -2 ^ 31)
	lu.assertEquals(V, 2 ^ 31)

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
		lu.assertEquals(r\s8!, -2)
		lu.assertEquals(r\u8!, 220)
		lu.assertEquals(r\s16!, -11991)
		lu.assertEquals(r\u16!, 12400)
		lu.assertEquals(r\s32!, -2 ^ 18 + 110)
		lu.assertEquals(r\u32!, 2 ^ 30 + 1200)
		lu.assertEquals(r\vu32!, 12345678)
		lu.assertEquals(r\s64!, -123372036854775808LL)
		lu.assertEquals(r\u64!, 2846744073709551615ULL)
		lu.assertEquals(r\f32!, tonumber(ffi.cast('float', float)))
		lu.assertEquals(r\f64!, double)
		lu.assertEquals(r\number!, double)
		lu.assertEquals(r\raw(8), 'rawtest1')
		lu.assertEquals(r\bool!, false)
		lu.assertEquals(r\bool!, true)
		lu.assertEquals(r\string!, 'test')
		tab = r\table!
		lu.assertEquals(tab.a, 3)
		lu.assertEquals(tab.b, 4)
		lu.assertEquals(r\raw(12), 'rawtest12345')
		lu.assertErrorMsgContains('Invalid data type', blob.pack, blob, '/')
		lu.assertErrorMsgContains('Number of arguments', blob.pack, blob, 'b')

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
		lu.assertEquals(b, -12)
		lu.assertEquals(B, 200)
		lu.assertEquals(h, -1019)
		lu.assertEquals(H, 4000)
		lu.assertEquals(l, -2 ^ 18 + 10)
		lu.assertEquals(L, 2 ^ 30 + 100)
		lu.assertEquals(V, 87654321)
		lu.assertEquals(q, -923372036854775808LL)
		lu.assertEquals(Q, 1846744073709551615ULL)
		lu.assertEquals(f, tonumber(ffi.cast('float', 123.45)))
		lu.assertEquals(d, double)
		lu.assertEquals(n, double)
		lu.assertEquals(c8, 'rawtest1')
		lu.assertEquals(yf, false)
		lu.assertEquals(yt, true)
		lu.assertEquals(s, 'test')
		lu.assertEquals(t.a, 1)
		lu.assertEquals(t.b, 2)
		lu.assertEquals(c12, 'rawtest12345')
		lu.assertErrorMsgContains('Invalid data type', reader.unpack, reader, '/')
		lu.assertErrorMsgContains('Out of data', reader.skip, reader, 1)


test_VarU32 = ->
	blob = BlobWriter!
	lu.assertEquals(blob\vu32size(0), 1)
	lu.assertEquals(blob\vu32size(2 ^ 7 - 1), 1)
	lu.assertEquals(blob\vu32size(2 ^ 7), 2)
	lu.assertEquals(blob\vu32size(2 ^ 14 - 1), 2)
	lu.assertEquals(blob\vu32size(2 ^ 14), 3)
	lu.assertEquals(blob\vu32size(2 ^ 21 - 1), 3)
	lu.assertEquals(blob\vu32size(2 ^ 21), 4)
	lu.assertEquals(blob\vu32size(2 ^ 28 - 1), 4)
	lu.assertEquals(blob\vu32size(2 ^ 28), 5)
	lu.assertEquals(blob\vu32size(2 ^ 32 - 1), 5)

	with blob
		\vu32(0)
		\vu32(2 ^ 7)
		\vu32(2 ^ 11)
		\vu32(2 ^ 27)
		\vu32(2 ^ 31)
	lu.assertErrorMsgContains('Exceeded', blob.vu32, blob, 2 ^ 33)

	blob = BlobReader(blob\tostring!)
	lu.assertEquals(blob\vu32!, 0)
	lu.assertEquals(blob\vu32!, 2 ^ 7)
	lu.assertEquals(blob\vu32!, 2 ^ 11)
	lu.assertEquals(blob\vu32!, 2 ^ 27)
	lu.assertEquals(blob\vu32!, 2 ^ 31)

test_Reader_ByteOrder = ->
	posNum = 2^33 + 1234567.89
	negNum = -2^33 - 1234567.89

	for _, item in ipairs({ { e: '<', fn: 'blob.le' }, { e: '>', fn: 'blob.be' } } )
		file = io.open(item.fn, 'rb')
		dat = file\read('*all')
		file\close!
		b3 = BlobReader(dat, item.e)
		lu.assertEquals(b3\u8!, 0)
		lu.assertEquals(b3\s8!, 0)
		lu.assertEquals(b3\u8!, 2 ^ 8 - 1)
		lu.assertEquals(b3\s8!, -(2 ^ 7 - 1))
		lu.assertEquals(b3\u16!, 0)
		lu.assertEquals(b3\s16!, 0)
		lu.assertEquals(b3\u16!, 2 ^ 16 - 1)
		lu.assertEquals(b3\s16!, -(2 ^ 15 - 1))
		lu.assertEquals(b3\u32!, 0)
		lu.assertEquals(b3\s32!, 0)
		lu.assertEquals(b3\u32!, 2 ^ 32 - 1)
		lu.assertEquals(b3\s32!, -(2 ^ 31 - 1))
		lu.assertEquals(b3\u64!, 18446744073709551615ULL)
		lu.assertEquals(b3\s64!, -9223372036854775808LL)
		lu.assertEquals(b3\f64!, posNum)
		lu.assertEquals(b3\f64!, negNum)
		lu.assertEquals(b3\u32!, 0x12345678)
		lu.assertEquals(b3\string!, 'end')

test_Reader_unpack = ->
	posNum = 2^33 + 1234567.89
	negNum = -2^33 - 1234567.89

	for _, item in ipairs({ { e: '<', fn: 'blob.le' }, { e: '>', fn: 'blob.be' } } )
		file = io.open(item.fn, 'rb')
		dat = file\read('*all')
		file\close!
		b = BlobReader(dat, item.e)
		b1, b2, b3, b4, w1, w2, w3, w4, d1, d2, d3, d4, q1, q2, n1, n2, d5, s1 = b\unpack('BbBbHhHhLlLlQqddLs')
		lu.assertEquals(b1, 0)
		lu.assertEquals(b2, 0)
		lu.assertEquals(b3, 2 ^ 8 - 1)
		lu.assertEquals(b4, -(2 ^ 7 - 1))
		lu.assertEquals(w1, 0)
		lu.assertEquals(w2, 0)
		lu.assertEquals(w3, 2 ^ 16 - 1)
		lu.assertEquals(w4, -(2 ^ 15 - 1))
		lu.assertEquals(d1, 0)
		lu.assertEquals(d2, 0)
		lu.assertEquals(d3, 2 ^ 32 - 1)
		lu.assertEquals(d4, -(2 ^ 31 - 1))
		lu.assertEquals(q1, 18446744073709551615ULL)
		lu.assertEquals(q2, -9223372036854775808LL)
		lu.assertEquals(n1, posNum)
		lu.assertEquals(n2, negNum)
		lu.assertEquals(d5, 0x12345678)
		lu.assertEquals(s1, 'end')

test_xxxLastCheckGlobals = ->
	for k, v in pairs(_G)
		unless k\match('^test_.*')
			print('\nLEAKED GLOBAL:', k) if _globals[k] == nil
			lu.assertTrue(_globals[k] ~= nil)

lu.LuaUnit.new!\runSuite!
