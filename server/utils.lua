local Utils = {}

-- Deep copy a table
function Utils.deepCopy(orig)
    local copy
    if type(orig) == 'table' then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = Utils.deepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

-- Merge two tables
function Utils.merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" and type(t1[k]) == "table" then
            Utils.merge(t1[k], v)
        else
            t1[k] = v
        end
    end
    return t1
end

-- Compact string formatter for quick logging
function Utils.format(pattern, ...)
    return string.format(pattern, ...)
end

-- Safe JSON encoding with error handling
function Utils.safeEncode(data)
    local success, result = pcall(json.encode, data)
    if success then return result end
    return "{\"error\":\"Failed to encode JSON\"}"
end

-- Safe JSON decoding with error handling
function Utils.safeDecode(jsonStr)
    if not jsonStr or type(jsonStr) ~= "string" then return {} end
    local success, result = pcall(json.decode, jsonStr)
    if success then return result end
    return {}
end

-- Fast table key count
function Utils.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

return Utils
