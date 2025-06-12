local BucketManager = {
    buckets = {},
    keyToId = {},
    reusableIds = {},
    nextBucketId = 1
}

function BucketManager:garbageCollector(bucketId)
    local bucket = self.buckets[bucketId] ---@type Bucket|nil
    if bucket and not next(bucket.players) and not next(bucket.entities) then
        self.keyToId[bucket.key] = nil
        self.buckets[bucketId] = nil
        self.reusableIds[#self.reusableIds + 1] = bucketId
        table.sort(self.reusableIds)
    end
end

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

function BucketManager:getBucketId(key)
    local bucketId = self.keyToId[key]
    if not bucketId then
        bucketId = self:createBucket(key)
    end
    return bucketId
end

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

function BucketManager:getPlayerBucketKey(playerId)
    local bucketId = GetPlayerRoutingBucket(playerId) ---@type number
    local bucket = self.buckets[bucketId] ---@type Bucket|nil
    return bucket and bucket.key or nil
end

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

function BucketManager:getEntityBucketKey(entityId)
    local bucketId = GetEntityRoutingBucket(entityId) ---@type number
    local bucket = self.buckets[bucketId] ---@type Bucket|nil
    return bucket and bucket.key or nil
end

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

function BucketManager:getBucketContents(key)
    if not key or type(key) ~= "string" then
        return { players = {}, entities = {}, key = key or "unknown" }
    end

    local bucketId = self.keyToId[key] ---@type number|nil
    return bucketId and self.buckets[bucketId] or { players = {}, entities = {}, key = key }
end

function BucketManager:getActiveBucketKeys()
    local activeKeys = {}
    local i = 0
    for id, bucket in pairs(self.buckets) do ---@type number, Bucket
        i = i + 1
        activeKeys[i] = { id = id, key = bucket.key }
    end
    return activeKeys
end

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
