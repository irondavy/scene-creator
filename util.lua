local util = {}


local uuidLib = require 'vendor.uuid'
uuidLib.seed()


function util.unpackPairs(t)
    local rets, nArgs = {}, 0
    for k, v in pairs(t) do
        rets[nArgs + 1], rets[nArgs + 2] = k, v
        nArgs = nArgs + 2
    end
    return unpack(rets, 1, nArgs)
end

function util.deepCopyTable(t)
    local typ = type(t)
    if typ == 'nil' or typ == 'boolean' or typ == 'number' or typ == 'string' or typ == 'function' then
        return t
    elseif typ == 'table' then
        local u = {}
        for k, v in pairs(t) do
            u[util.deepCopyTable(k)] = util.deepCopyTable(v)
        end
        return u
    else
        error('deepCopyTable: bad type')
    end
end


function util.quantize(value, divisor, start)
    if divisor == 0 then
        return value
    end
    start = start or 0
    return divisor * math.floor(0.5 + (value - start) / divisor) + start
end


function util.uuid()
    return uuidLib()
end


function util.stacktrace(message)
    local stack = debug.traceback(message, 2)
    for chunkName, filename in pairs(CHUNK_NAME_TO_FILE_NAME) do
        local pattern = '%[string "' .. chunkName .. '"%]'
        stack = stack:gsub(pattern, filename)
    end
    return stack
end


local ui = castle.ui

function util.uiRow(id, ...)
    local nArgs = select('#', ...)
    local args = { ... }
    ui.box(id, { flexDirection = 'row', alignItems = 'flex-start' }, function()
        for i = 1, nArgs do
            ui.box(tostring(i), { flex = 1 }, args[i])
            if i < nArgs then
                ui.box('space', { width = 16 }, function() end)
            end
        end
    end)
end


return util
