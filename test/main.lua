local moonscript = require('moonscript')

table.insert(package.loaders, function(modname)
    modname = modname:gsub("%.", "/")

    local filename = ("%.moon"):gsub("%%", modname)
    local contents
    if love.filesystem.getInfo(filename, "file") then
        contents = love.filesystem.read(filename)
	    return moonscript.loadstring(contents, filename)
    end

	return nil, "Moonscript file not found"
end)

require('benchmark')
