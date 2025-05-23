---@class Bucket
---@field players table<number, boolean>
---@field entities table<number, boolean>
---@field key string

---@class BucketManager
---@field buckets table<number, Bucket>
---@field keyToId table<string, number>
---@field reusableIds table<number, number>
---@field nextBucketId number
local BucketManager = {
    buckets = {},
    keyToId = {},
    reusableIds = {},
    nextBucketId = 1
}

---Garbage collects an empty bucket
---@param bucketId number
function BucketManager:garbageCollector(bucketId)
    local bucket = self.buckets[bucketId] ---@type Bucket|nil
    if bucket and not next(bucket.players) and not next(bucket.entities) then
        self.keyToId[bucket.key] = nil
        self.buckets[bucketId] = nil
        self.reusableIds[#self.reusableIds + 1] = bucketId
        table.sort(self.reusableIds)
    end
end

---Creates a new bucket with the given key
---@param key string
---@return number bucketId
function BucketManager:createBucket(key)
    if not key or type(key) ~= "string" then
        error("Invalid bucket key: expected string, got " .. (type(key) or "nil"))
        return 0
    end

    local bucketId
    if #self.reusableIds > 0 then
        bucketId = table.remove(self.reusableIds, 1)
    else
        bucketId = self.nextBucketId
        self.nextBucketId = self.nextBucketId + 1
    end
    self.buckets[bucketId] = { players = {}, entities = {}, key = key } ---@type Bucket
    self.keyToId[key] = bucketId
    return bucketId
end

---Gets or creates a bucket ID for a key
---@param key string
---@return number bucketId
function BucketManager:getBucketId(key)
    local bucketId = self.keyToId[key]
    if not bucketId then
        bucketId = self:createBucket(key)
    end
    return bucketId
end

---Sets a player's routing bucket
---@param playerId number
---@param key string
---@return boolean success
function BucketManager:setPlayerBucket(playerId, key)
    if not playerId or not key then return false end
    if not GetPlayerName(playerId) then return false end

    local currentBucketId = GetPlayerRoutingBucket(playerId) ---@type number
    local currentBucket = self.buckets[currentBucketId] ---@type Bucket|nil
    if currentBucket then
        currentBucket.players[playerId] = nil
        self:garbageCollector(currentBucketId)
    end
    
    local bucketId = self:getBucketId(key)
    local bucket = self.buckets[bucketId] ---@type Bucket
    bucket.players[playerId] = true
    
    SetPlayerRoutingBucket(playerId, bucketId)
    TriggerEvent("rw_buckets:onBucketUpdate", playerId, key)
    TriggerClientEvent("rw_buckets:onBucketUpdate", playerId, key)
    return true
end

---Gets the bucket key for a player
---@param playerId number
---@return string|nil key
function BucketManager:getPlayerBucketKey(playerId)
    local bucketId = GetPlayerRoutingBucket(playerId) ---@type number
    local bucket = self.buckets[bucketId] ---@type Bucket|nil
    return bucket and bucket.key or nil
end

---Removes a player from their current bucket
---@param playerId number
---@return boolean success
function BucketManager:removePlayerFromBucket(playerId)
    if not playerId then return false end
    if not GetPlayerName(playerId) then return false end
    
    local currentBucketId = GetPlayerRoutingBucket(playerId) ---@type number
    local currentBucket = self.buckets[currentBucketId] ---@type Bucket|nil
    if currentBucket then
        currentBucket.players[playerId] = nil
        self:garbageCollector(currentBucketId)
    end
    SetPlayerRoutingBucket(playerId, 0)
    TriggerEvent("rw_buckets:onBucketUpdate", playerId, 0)
    TriggerClientEvent("rw_buckets:onBucketUpdate", playerId, 0)
    return true
end

---Sets an entity's routing bucket
---@param entityId number
---@param key string
---@return boolean success
function BucketManager:setEntityBucket(entityId, key)
    if not entityId or not key then return false end
    if not DoesEntityExist(entityId) then return false end

    local currentBucketId = GetEntityRoutingBucket(entityId) ---@type number
    local currentBucket = self.buckets[currentBucketId] ---@type Bucket|nil
    if currentBucket then
        currentBucket.entities[entityId] = nil
        self:garbageCollector(currentBucketId)
    end
    
    local bucketId = self:getBucketId(key)
    local bucket = self.buckets[bucketId] ---@type Bucket
    bucket.entities[entityId] = true
    SetEntityRoutingBucket(entityId, bucketId)
    return true
end

---Gets the bucket key for an entity
---@param entityId number
---@return string|nil key
function BucketManager:getEntityBucketKey(entityId)
    local bucketId = GetEntityRoutingBucket(entityId) ---@type number
    local bucket = self.buckets[bucketId] ---@type Bucket|nil
    return bucket and bucket.key or nil
end

---Removes an entity from its current bucket
---@param entityId number
---@return boolean success
function BucketManager:removeEntityFromBucket(entityId)
    if not entityId then return false end
    if not DoesEntityExist(entityId) then return false end
    
    local currentBucketId = GetEntityRoutingBucket(entityId) ---@type number
    local currentBucket = self.buckets[currentBucketId] ---@type Bucket|nil
    if currentBucket then
        currentBucket.entities[entityId] = nil
        self:garbageCollector(currentBucketId)
    end
    SetEntityRoutingBucket(entityId, 0)
    return true
end

---Gets the contents of a bucket
---@param key string
---@return Bucket contents
function BucketManager:getBucketContents(key)
    if not key or type(key) ~= "string" then
        return { players = {}, entities = {}, key = key or "unknown" }
    end

    local bucketId = self.keyToId[key] ---@type number|nil
    return bucketId and self.buckets[bucketId] or { players = {}, entities = {}, key = key }
end

---Gets all active bucket keys
---@return table<number, {id: number, key: string}> activeKeys
function BucketManager:getActiveBucketKeys()
    local activeKeys = {}
    local i = 0
    for id, bucket in pairs(self.buckets) do ---@type number, Bucket
        i = i + 1
        activeKeys[i] = { id = id, key = bucket.key }
    end
    return activeKeys
end

---Removes all players and entities from a bucket and cleans it up
---@param key string
function BucketManager:killBucket(key)
    local bucketId = self.keyToId[key] ---@type number|nil
    if not bucketId then return end
    
    local bucket = self.buckets[bucketId] ---@type Bucket
    for id in pairs(bucket.players) do ---@type number
        self:removePlayerFromBucket(id)
    end
    for id in pairs(bucket.entities) do ---@type number
        self:removeEntityFromBucket(id)
    end
    self:garbageCollector(bucketId)
end

return BucketManager
