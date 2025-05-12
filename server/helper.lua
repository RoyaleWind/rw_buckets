local Helper = {}

-- Deep copy a table with minimal code
function Helper.deepCopy(orig)
    if type(orig) ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[k] = Helper.deepCopy(v) end
    return copy
end

-- Merge two tables efficiently
function Helper.merge(t1, t2)
    for k, v in pairs(t2) do
        t1[k] = (type(v) == "table" and type(t1[k]) == "table") and Helper.merge(t1[k], v) or v
    end
    return t1
end

-- Fast table count
function Helper.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

-- Convert array to hash map for O(1) lookups
function Helper.arrayToMap(arr)
    local map = {}
    for _, v in ipairs(arr) do map[v] = true end
    return map
end

-- Safe JSON handling
function Helper.safeJson(fn, data, default)
    local success, result = pcall(fn, data)
    return success and result or default
end

return Helper