local Logger = require("server.logger")
local Security = require("server.security")

---@class BucketManager.Entities
local EntitiesModule = {}

-- Set a player's bucket
function EntitiesModule.setPlayerBucket(self, playerId, key, metadata, source)
    -- Validate parameters
    local paramsValid, errorMsg = Security.validateParams({
        playerId = playerId,
        key = key
    })
    
    if not paramsValid then
        Logger:error("Failed to set player bucket", { error = errorMsg })
        return false
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for setting player bucket")
        return false
    end
    
    -- Get current bucket information for rollback and logging
    local currentBucketId = GetPlayerRoutingBucket(playerId)
    local currentBucket = self.buckets[currentBucketId]
    local oldBucketKey = currentBucket and currentBucket.key or nil
    
    -- Get or create the target bucket
    local bucketId = self:getBucketId(key, metadata, nil, source)
    if bucketId == 0 then
        self:rollbackTransaction()
        Logger:error("Failed to get or create target bucket")
        return false
    end
    
    -- If player already in this bucket, nothing to do
    if bucketId == currentBucketId then
        self:commitTransaction()
        return true
    end
    
    -- Store operations for possible rollback
    self:addToTransaction("update", "player", {
        playerId = playerId,
        oldBucketId = currentBucketId,
        oldBucketKey = oldBucketKey,
        newBucketId = bucketId,
        newBucketKey = key
    }, function()
        -- Rollback: set routing bucket back, update bucket player lists
        if currentBucket then
            currentBucket.players[playerId] = true
        end
        if self.buckets[bucketId] then
            self.buckets[bucketId].players[playerId] = nil
        end
        SetPlayerRoutingBucket(playerId, currentBucketId)
    end)
    
    -- Remove from current bucket if tracked
    if currentBucket then
        currentBucket.players[playerId] = nil
        currentBucket.metadata.lastModified = os.time()
    end
    
    -- Add to new bucket
    local bucket = self.buckets[bucketId]
    bucket.players[playerId] = true
    bucket.metadata.lastModified = os.time()
    
    -- Set player's routing bucket
    SetPlayerRoutingBucket(playerId, bucketId)
    
    -- Trigger hooks
    self:triggerHooks("onPlayerBucketChange", playerId, oldBucketKey, key)
    
    -- Audit the operation
    Security.audit(source, "set_player_bucket", {
        playerId = playerId,
        oldBucket = oldBucketKey,
        newBucket = key
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for setting player bucket")
        return false
    end
    
    -- Clean up old bucket if empty
    if currentBucket then
        self:garbageCollector(currentBucketId)
    end
    
    Logger:debug("Set player bucket", {
        player = playerId,
        oldBucket = oldBucketKey,
        newBucket = key
    })
    
    return true
end

-- Remove a player from their current bucket
function EntitiesModule.removePlayerFromBucket(self, playerId, source)
    -- Validate player ID
    local isValid, errorMsg = Security.validateType(playerId, "playerId", "playerId")
    if not isValid then
        Logger:error("Failed to remove player from bucket", { error = errorMsg })
        return false
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for removing player from bucket")
        return false
    end
    
    -- Get current bucket information for rollback and logging
    local currentBucketId = GetPlayerRoutingBucket(playerId)
    local currentBucket = self.buckets[currentBucketId]
    local oldBucketKey = currentBucket and currentBucket.key or nil
    
    -- If player isn't in a tracked bucket, just reset to 0
    if not currentBucket then
        -- Nothing to do if already in bucket 0
        if currentBucketId == 0 then
            self:commitTransaction()
            return true
        end
        
        -- Add to transaction
        self:addToTransaction("update", "player", {
            playerId = playerId,
            oldBucketId = currentBucketId,
            action = "reset"
        }, function()
            -- Rollback: set routing bucket back
            SetPlayerRoutingBucket(playerId, currentBucketId)
        end)
        
        -- Reset to bucket 0
        SetPlayerRoutingBucket(playerId, 0)
        
        -- Commit transaction
        if not self:commitTransaction() then
            Logger:error("Failed to commit transaction for resetting player bucket")
            return false
        end
        
        return true
    end
    
    -- Store operations for possible rollback
    self:addToTransaction("update", "player", {
        playerId = playerId,
        oldBucketId = currentBucketId,
        oldBucketKey = oldBucketKey,
        action = "remove"
    }, function()
        -- Rollback: re-add player to old bucket
        if self.buckets[currentBucketId] then
            self.buckets[currentBucketId].players[playerId] = true
            SetPlayerRoutingBucket(playerId, currentBucketId)
        end
    end)
    
    -- Remove from current bucket
    currentBucket.players[playerId] = nil
    currentBucket.metadata.lastModified = os.time()
    
    -- Reset to bucket 0
    SetPlayerRoutingBucket(playerId, 0)
    
    -- Trigger hooks
    self:triggerHooks("onPlayerBucketChange", playerId, oldBucketKey, nil)
    
    -- Audit the operation
    Security.audit(source, "remove_player_from_bucket", {
        playerId = playerId,
        oldBucket = oldBucketKey
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for removing player from bucket")
        return false
    end
    
    -- Clean up old bucket if empty
    self:garbageCollector(currentBucketId)
    
    Logger:debug("Removed player from bucket", {
        player = playerId,
        oldBucket = oldBucketKey
    })
    
    return true
end

-- Set an entity's bucket
function EntitiesModule.setEntityBucket(self, entityId, key, metadata, source)
    -- Validate parameters
    local paramsValid, errorMsg = Security.validateParams({
        entityId = entityId,
        key = key
    })
    
    if not paramsValid then
        Logger:error("Failed to set entity bucket", { error = errorMsg })
        return false
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for setting entity bucket")
        return false
    end
    
    -- Get current bucket information for rollback and logging
    local currentBucketId = GetEntityRoutingBucket(entityId)
    local currentBucket = self.buckets[currentBucketId]
    local oldBucketKey = currentBucket and currentBucket.key or nil
    
    -- Get or create the target bucket
    local bucketId = self:getBucketId(key, metadata, nil, source)
    if bucketId == 0 then
        self:rollbackTransaction()
        Logger:error("Failed to get or create target bucket")
        return false
    end
    
    -- If entity already in this bucket, nothing to do
    if bucketId == currentBucketId then
        self:commitTransaction()
        return true
    end
    
    -- Store operations for possible rollback
    self:addToTransaction("update", "entity", {
        entityId = entityId,
        oldBucketId = currentBucketId,
        oldBucketKey = oldBucketKey,
        newBucketId = bucketId,
        newBucketKey = key
    }, function()
        -- Rollback: set routing bucket back, update bucket entity lists
        if currentBucket then
            currentBucket.entities[entityId] = true
        end
        if self.buckets[bucketId] then
            self.buckets[bucketId].entities[entityId] = nil
        end
        SetEntityRoutingBucket(entityId, currentBucketId)
    end)
    
    -- Remove from current bucket if tracked
    if currentBucket then
        currentBucket.entities[entityId] = nil
        currentBucket.metadata.lastModified = os.time()
    end
    
    -- Add to new bucket
    local bucket = self.buckets[bucketId]
    bucket.entities[entityId] = true
    bucket.metadata.lastModified = os.time()
    
    -- Set entity's routing bucket
    SetEntityRoutingBucket(entityId, bucketId)
    
    -- Trigger hooks
    self:triggerHooks("onEntityBucketChange", entityId, oldBucketKey, key)
    
    -- Audit the operation
    Security.audit(source, "set_entity_bucket", {
        entityId = entityId,
        oldBucket = oldBucketKey,
        newBucket = key
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for setting entity bucket")
        return false
    end
    
    -- Clean up old bucket if empty
    if currentBucket then
        self:garbageCollector(currentBucketId)
    end
    
    Logger:debug("Set entity bucket", {
        entity = entityId,
        oldBucket = oldBucketKey,
        newBucket = key
    })
    
    return true
end

-- Remove an entity from its current bucket
function EntitiesModule.removeEntityFromBucket(self, entityId, source)
    -- Validate entity ID
    local isValid, errorMsg = Security.validateType(entityId, "entityId", "entityId")
    if not isValid then
        Logger:error("Failed to remove entity from bucket", { error = errorMsg })
        return false
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for removing entity from bucket")
        return false
    end
    
    -- Get current bucket information for rollback and logging
    local currentBucketId = GetEntityRoutingBucket(entityId)
    local currentBucket = self.buckets[currentBucketId]
    local oldBucketKey = currentBucket and currentBucket.key or nil
    
    -- If entity isn't in a tracked bucket, just reset to 0
    if not currentBucket then
        -- Nothing to do if already in bucket 0
        if currentBucketId == 0 then
            self:commitTransaction()
            return true
        end
        
        -- Add to transaction
        self:addToTransaction("update", "entity", {
            entityId = entityId,
            oldBucketId = currentBucketId,
            action = "reset"
        }, function()
            -- Rollback: set routing bucket back
            SetEntityRoutingBucket(entityId, currentBucketId)
        end)
        
        -- Reset to bucket 0
        SetEntityRoutingBucket(entityId, 0)
        
        -- Commit transaction
        if not self:commitTransaction() then
            Logger:error("Failed to commit transaction for resetting entity bucket")
            return false
        end
        
        return true
    end
    
    -- Store current state for possible rollback
    self:addToTransaction("update", "entity", {
        entityId = entityId,
        oldBucketId = currentBucketId,
        oldBucketKey = oldBucketKey,
        action = "remove"
    }, function()
        -- Rollback: re-add entity to old bucket
        if self.buckets[currentBucketId] then
            self.buckets[currentBucketId].entities[entityId] = true
            SetEntityRoutingBucket(entityId, currentBucketId)
        end
    end)
    
    -- Remove from current bucket
    currentBucket.entities[entityId] = nil
    currentBucket.metadata.lastModified = os.time()
    
    -- Reset to bucket 0
    SetEntityRoutingBucket(entityId, 0)
    
    -- Trigger hooks
    self:triggerHooks("onEntityBucketChange", entityId, oldBucketKey, nil)
    
    -- Audit the operation
    Security.audit(source, "remove_entity_from_bucket", {
        entityId = entityId,
        oldBucket = oldBucketKey
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for removing entity from bucket")
        return false
    end
    
    -- Clean up old bucket if empty
    self:garbageCollector(currentBucketId)
    
    Logger:debug("Removed entity from bucket", {
        entityId = entityId,
        oldBucket = oldBucketKey
    })
    
    return true
end

return EntitiesModule
