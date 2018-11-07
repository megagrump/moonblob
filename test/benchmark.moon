package.moonpath = "#{package.moonpath};../?.moon"

gfx, timer, fs = love.graphics, love.timer.getTime, love.filesystem
BENCHMARK_TIME = .5 -- approx. number of seconds each benchmark runs

collectgarbage('stop')

testData =
	largeNumberArray: -> [ i for i = 1, 2 ^ 16 ]
	largeU32Array: -> [ i * 256 for i = 1, 2 ^ 16 ]
	smallNumberArray: -> [ i * i for i = 1, 255 ]
	smallU8Array: -> [ i for i = 0, 255 ]
	simpleTable: ->
		{
			zero: 0
			number1: 23
			number2: 42
			number3: 666.66
			string: 'text'
			bool: true
			nested: { zero: 0, one: 1 }
		}

	deepTable: ->
		result =
			number: 42
			string: 'text'
			bool: true
			nested: { }

		current = result.nested
		for i = 1, 1000
			current.nested =
				number: i
				string: 'text ' .. i
				bool: true
			current = current.nested
		result

generateData = -> { name, func! for name, func in pairs(testData) }

benchmarks =
	libraries: {}

loadBenchmarks = ->
	dir = fs.getDirectoryItems('benchmarks')
	for item in *dir
		name = item\gsub('%.moon', '')
		benchmark = require('benchmarks.' .. name)

		benchmarks.libraries[name] =
			description: benchmark.description
			results: {}
			serialize: { k, v for k, v in pairs(benchmark.serialize) }
			deserialize: { k, v for k, v in pairs(benchmark.deserialize) }

local benchmark
frame = 0

run = (benchmark, data) ->
	time, counter, resultData = 0, 0
	okay, result = pcall(->
		start = timer!
		while time < BENCHMARK_TIME
			resultData = benchmark(data)
			time = timer! - start
			counter = counter + 1

		return {
			count: counter
			time: time
			data: resultData
		}
	)

	unless okay
		print(result)
		result = {
			count: 0
			time: BENCHMARK_TIME
			error: result
		}

	collectgarbage!
	result

runBenchmarks = ->
	testData = generateData!

	libs = [ name for name in pairs(benchmarks.libraries) ]
	table.sort(libs)

	tests = [ name for name in pairs(testData) ]
	table.sort(tests)

	for test in *tests
		data = testData[test]
		for libName in *libs
			lib = benchmarks.libraries[libName]
			okay, result = pcall(run, lib.serialize[test], data)
			lib.results[test] = { serialize: result }
			coroutine.yield!

			okay, result = pcall(run, lib.deserialize[test], result.data)
			lib.results[test].deserialize = result
			coroutine.yield!

love.load = ->
	loadBenchmarks!
	benchmark = coroutine.create(runBenchmarks)

love.update = ->
	x, y, frame = 10, 1, frame + 1
	frame = frame + 1
	return if frame < 5
	coroutine.resume(benchmark) unless coroutine.status(benchmark) == 'dead'

lineHeight = math.floor(gfx.getFont!\getHeight! * 1.25)

love.keypressed = (key) ->
	love.event.quit! if key == 'escape'

drawResult = (lib, result, max, x, y) ->
	w, h = gfx.getDimensions!
	w, h = w / 2 - 20, lineHeight

	if result.error
		gfx.setColor(1, .4, .4)
		gfx.print("%s FAILED: %s"\format(lib, result.error), x, y)
	else
		gfx.setColor(.2, .2, .8)
		gfx.rectangle('fill', x, y, w * (result.count / max), lineHeight - 2)
		gfx.setColor(1, 1, 1)
		if type(result.data) == 'string'
			gfx.print("%s: %.2f ops/sec (%d bytes)"\format(lib, result.count / result.time, #result.data), x + 10, y)
		else
			gfx.print("%s: %.2f ops/sec"\format(lib, result.count / result.time), x + 10, y)

maxCount = {
	serialize: {}
	deserialize: {}
}

love.draw = ->
	gfx.clear(.2, .2, .2)

	tests = [ name for name in pairs(testData) ]
	table.sort(tests)

	libs = [ name for name in pairs(benchmarks.libraries) ]
	table.sort(libs)

	x, y = 10, 5
	for testName in *tests
		maxCount.serialize[testName] = maxCount.serialize[testName] or 0
		maxCount.deserialize[testName] = maxCount.deserialize[testName] or 0
		for part in *{ 'serialize', 'deserialize' }
			for libName, lib in pairs(benchmarks.libraries)
				count = maxCount[part]
				results = lib.results[testName]
				count[testName] = math.max(results[part].count, count[testName]) if results and results[part]

	ry = y
	for testName in *tests
		for part in *{ 'serialize', 'deserialize' }
			ry, rx = y, x + (part == 'deserialize' and 320 or 0)
			gfx.setColor(1, 1, 1)
			gfx.print(testName .. '.' .. part, rx, y)
			ry += lineHeight
			--for libName, lib in pairs(benchmarks.libraries)
			for libName in *libs
				lib = benchmarks.libraries[libName]
				results = lib.results[testName]
				if results and results[part]
					drawResult(lib.description, results[part], maxCount[part][testName], rx, ry)
				else
					gfx.setColor(1, 1, 1)
					gfx.print("waiting for %s..."\format(lib.description), rx, ry)
				ry += lineHeight
			ry += lineHeight
		y = ry
