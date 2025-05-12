local Logger = require("server.logger")
local Security = require("server.security")
local Helper = require("server.helper")

---@class BucketManager.Buckets
local BucketsModule = {}

-- Create a new bucket
function BucketsModule.createBucket(self, key, metadata, settings, source)
    -- Validate key
    local isValid, errorMsg = Security.validateType(key, "bucketKey", "key")
    if not isValid then
        Logger:error("Failed to create bucket", { error = errorMsg })
        return 0
    end
    
    -- Check if bucket with this key already exists
    if self.keyToId[key] then
        return self.keyToId[key]
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for creating bucket")
        return 0
    end
    
    -- Get next available bucket ID
    local bucketId = 0
    if #self.reusableIds > 0 then
        bucketId = table.remove(self.reusableIds, 1)
    else
        bucketId = self.nextBucketId
        self.nextBucketId = self.nextBucketId + 1
    end
    
    -- Initialize metadata if not provided
    metadata = metadata or {}
    metadata.created = metadata.created or os.time()
    metadata.lastModified = metadata.lastModified or os.time()
    metadata.creator = metadata.creator or (source and tostring(source)) or "system"
    metadata.description = metadata.description or ""
    metadata.tags = metadata.tags or {}
    metadata.customData = metadata.customData or {}
    
    -- Create the bucket
    self.buckets[bucketId] = {
        players = {},
        entities = {},
        key = key,
        metadata = metadata,
        settings = settings or {},
        version = 1
    }
    
    -- Map key to ID
    self.keyToId[key] = bucketId
    
    -- Add to transaction
    self:addToTransaction("create", "bucket", {
        bucketId = bucketId,
        key = key
    }, function()
        -- Rollback: remove created bucket
        self.buckets[bucketId] = nil
        self.keyToId[key] = nil
        table.insert(self.reusableIds, bucketId)
    end)
    
    -- Trigger hooks
    self:triggerHooks("onBucketCreate", bucketId, key, metadata)
    
    -- Audit the operation
    Security.audit(source, "create_bucket", {
        key = key,
        bucketId = bucketId
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for creating bucket")
        return 0
    end
    
    Logger:info("Created bucket", { id = bucketId, key = key })
    return bucketId
end

-- Get or create a bucket with the given key
function BucketsModule.getBucketId(self, key, metadata, settings, source)
    -- Validate key
    local isValid, errorMsg = Security.validateType(key, "bucketKey", "key")
    if not isValid then
        Logger:error("Failed to get bucket ID", { error = errorMsg })
        return 0
    end
    
    -- Return existing bucket ID if it exists
    if self.keyToId[key] then
        return self.keyToId[key]
    end
    
    -- Create new bucket
    return self:createBucket(key, metadata, settings, source)
end

-- Get a player's current bucket key
function BucketsModule.getPlayerBucketKey(self, playerId)
    -- Validate player ID
    local isValid, errorMsg = Security.validateType(playerId, "playerId", "playerId")
    if not isValid then
        Logger:debug("Invalid player ID when getting bucket key", { error = errorMsg })
        return nil
    end
    
    local bucketId = GetPlayerRoutingBucket(playerId)
    if bucketId == 0 then
        return nil -- Default bucket has no key
    end
    
    local bucket = self.buckets[bucketId]
    if not bucket then
        return nil -- Not a tracked bucket
    end
    
    return bucket.key
end

-- Get an entity's current bucket key
function BucketsModule.getEntityBucketKey(self, entityId)
    -- Validate entity ID
    local isValid, errorMsg = Security.validateType(entityId, "entityId", "entityId")
    if not isValid then
        Logger:debug("Invalid entity ID when getting bucket key", { error = errorMsg })
        return nil
    end
    
    local bucketId = GetEntityRoutingBucket(entityId)
    if bucketId == 0 then
        return nil -- Default bucket has no key
    end
    
    local bucket = self.buckets[bucketId]
    if not bucket then
        return nil -- Not a tracked bucket
    end
    
    return bucket.key
end

-- Get bucket contents
function BucketsModule.getBucketContents(self, key, includeMetadata)
    -- Validate bucket key
    local isValid, errorMsg = Security.validateType(key, "bucketKey", "key")
    if not isValid then
        Logger:debug("Invalid key when getting bucket contents", { error = errorMsg })
        return { players = {}, entities = {}, key = key or "unknown" }
    end

    local bucketId = self.keyToId[key]
    if not bucketId or not self.buckets[bucketId] then
        return { players = {}, entities = {}, key = key }
    end
    
    local bucket = self.buckets[bucketId]
    
    -- Basic contents always included
    local contents = {
        players = {},
        entities = {},
        key = key
    }
    
    -- Add player names instead of just IDs for better usability
    for playerId in pairs(bucket.players) do
        contents.players[playerId] = GetPlayerName(playerId) or "Unknown"
    end
    
    -- Copy entity IDs
    for entityId in pairs(bucket.entities) do
        contents.entities[entityId] = true
    end
    
    -- Include additional metadata if requested
    if includeMetadata then
        contents.metadata = bucket.metadata
        contents.settings = bucket.settings
        contents.version = bucket.version
    end
    
    return contents
end

-- Get all active bucket keys
function BucketsModule.getActiveBucketKeys(self, includeMetadata, filter)
    local activeKeys = {}
    local i = 0
    
    for id, bucket in pairs(self.buckets) do
        -- Apply filters if provided
        local includeThisBucket = true
        
        if filter then
            -- Filter by metadata fields
            if filter.metadata and bucket.metadata then
                for field, value in pairs(filter.metadata) do
                    if bucket.metadata[field] ~= value then
                        includeThisBucket = false
                        break
                    end
                end
            end
            
            -- Filter by tags
            if filter.tags and bucket.metadata and bucket.metadata.tags then
                for _, tag in ipairs(filter.tags) do
                    local hasTag = false
                    for _, bucketTag in ipairs(bucket.metadata.tags) do
                        if bucketTag == tag then
                            hasTag = true
                            break
                        end
                    end
                    if not hasTag then
                        includeThisBucket = false
                        break
                    end
                end
            end
            
            -- Filter by containing player
            if filter.hasPlayer and not bucket.players[filter.hasPlayer] then
                includeThisBucket = false
            end
            
            -- Filter by containing entity
            if filter.hasEntity and not bucket.entities[filter.hasEntity] then
                includeThisBucket = false
            end
            
            -- Filter by min/max players
            if filter.minPlayers then
                local playerCount = 0
                for _ in pairs(bucket.players) do playerCount = playerCount + 1 end
                if playerCount < filter.minPlayers then
                    includeThisBucket = false
                end
            end
            
            if filter.maxPlayers then
                local playerCount = 0
                for _ in pairs(bucket.players) do playerCount = playerCount + 1 end
                if playerCount > filter.maxPlayers then
                    includeThisBucket = false
                end
            end
        end
        
        if includeThisBucket then
            i = i + 1
            activeKeys[i] = {
                id = id,
                key = bucket.key
            }
            
            if includeMetadata then
                activeKeys[i].metadata = bucket.metadata
            end
        end
    end
    
    return activeKeys
end

-- Delete a bucket by key
function BucketsModule.killBucket(self, key, source)
    -- Validate bucket key
    local isValid, errorMsg = Security.validateType(key, "bucketKey", "key")
    if not isValid then
        Logger:error("Failed to kill bucket", { error = errorMsg })
        return false
    end
    
    local bucketId = self.keyToId[key]
    if not bucketId or not self.buckets[bucketId] then
        Logger:warn("Attempted to kill non-existent bucket", { key = key })
        return false
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for killing bucket")
        return false
    end
    
    local bucket = self.buckets[bucketId]
    
    -- Store backup for rollback
    local bucketBackup = Helper.deepCopy(bucket)
    
    -- Add to transaction
    self:addToTransaction("delete", "bucket", {
        bucketId = bucketId,
        key = key
    }, function()
        -- Rollback: restore bucket
        self.buckets[bucketId] = bucketBackup
        self.keyToId[key] = bucketId
    end)
    
    -- Reset all players to default bucket
    for playerId in pairs(bucket.players) do
        SetPlayerRoutingBucket(playerId, 0)
    end
    
    -- Reset all entities to default bucket
    for entityId in pairs(bucket.entities) do
        SetEntityRoutingBucket(entityId, 0)
    end
    
    -- Remove the bucket
    self.buckets[bucketId] = nil
    self.keyToId[key] = nil
    
    -- Add ID to reusable pool
    table.insert(self.reusableIds, bucketId)
    table.sort(self.reusableIds)
    
    -- Trigger hooks
    self:triggerHooks("onBucketDelete", bucketId, key)
    
    -- Audit the operation
    Security.audit(source, "kill_bucket", {
        key = key,
        bucketId = bucketId
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for killing bucket")
        return false
    end
    
    Logger:info("Killed bucket", { id = bucketId, key = key })
    return true
end

-- Create a bucket from a template
function BucketsModule.createBucketFromTemplate(self, key, templateName, overrides, source)
    local template = self.templates[templateName]
    if not template then
        Logger:error("Template not found", { name = templateName })
        return 0
    end
    
    -- Combine template with overrides
    local settings = Helper.deepCopy(template.settings or {})
    local metadata = Helper.deepCopy(template.metadata or {})
    
    if overrides then
        if overrides.settings then
            settings = Helper.merge(settings, overrides.settings)
        end
        if overrides.metadata then
            metadata = Helper.merge(metadata, overrides.metadata)
        end
    end
    
    -- Create the bucket
    return self:createBucket(key, metadata, settings, source)
end

-- Merge two buckets
function BucketsModule.mergeBuckets(self, targetKey, sourceKey, source)
    -- Validate parameters
    local paramsValid, errorMsg = Security.validateParams({
        targetKey = targetKey,
        sourceKey = sourceKey
    })
    
    if not paramsValid then
        Logger:error("Failed to merge buckets", { error = errorMsg })
        return false
    end
    
    -- Check that both buckets exist
    local targetId = self.keyToId[targetKey]
    local sourceId = self.keyToId[sourceKey]
    
    if not targetId or not self.buckets[targetId] then
        Logger:error("Target bucket not found", { key = targetKey })
        return false
    end
    
    if not sourceId or not self.buckets[sourceId] then
        Logger:error("Source bucket not found", { key = sourceKey })
        return false
    end
    
    -- Can't merge a bucket with itself
    if targetId == sourceId then
        Logger:warn("Cannot merge bucket with itself", { key = targetKey })
        return false
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for merging buckets")
        return false
    end
    
    local targetBucket = self.buckets[targetId]
    local sourceBucket = self.buckets[sourceId]
    
    -- Store backups for rollback
    local targetBackup = Helper.deepCopy(targetBucket)
    local sourceBackup = Helper.deepCopy(sourceBucket)
    
    -- Add to transaction
    self:addToTransaction("update", "bucket", {
        targetBucketId = targetId,
        targetKey = targetKey,
        sourceBucketId = sourceId,
        sourceKey = sourceKey,
        action = "merge"
    }, function()
        -- Rollback: restore both buckets to original state
        self.buckets[targetId] = targetBackup
        self.buckets[sourceId] = sourceBackup
        
        -- Move players back
        for playerId in pairs(sourceBucket.players) do
            SetPlayerRoutingBucket(playerId, sourceId)
        end
        
        -- Move entities back
        for entityId in pairs(sourceBucket.entities) do
            SetEntityRoutingBucket(entityId, sourceId)
        end
    end)
    
    -- Move all players from source to target
    for playerId in pairs(sourceBucket.players) do
        targetBucket.players[playerId] = true
        SetPlayerRoutingBucket(playerId, targetId)
    end
    
    -- Move all entities from source to target
    for entityId in pairs(sourceBucket.entities) do
        targetBucket.entities[entityId] = true
        SetEntityRoutingBucket(entityId, targetId)
    end
    
    -- Update target metadata
    targetBucket.metadata.lastModified = os.time()
    
    -- Kill the source bucket
    self.buckets[sourceId] = nil
    self.keyToId[sourceKey] = nil
    table.insert(self.reusableIds, sourceId)
    table.sort(self.reusableIds)
    
    -- Trigger hooks
    self:triggerHooks("onBucketMerge", targetId, sourceId, targetKey, sourceKey)
    
    -- Audit the operation
    Security.audit(source, "merge_buckets", {
        targetKey = targetKey,
        sourceKey = sourceKey
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for merging buckets")
        return false
    end
    
    Logger:info("Merged buckets", { 
        targetKey = targetKey, 
        sourceKey = sourceKey 
    })
    
    return true
end

-- Update bucket metadata
function BucketsModule.updateBucketMetadata(self, key, metadata, source)
    -- Validate parameters
    local isValid, errorMsg = Security.validateType(key, "bucketKey", "key")
    if not isValid then
        Logger:error("Failed to update bucket metadata", { error = errorMsg })
        return false
    end
    
    if not metadata or type(metadata) ~= "table" then
        Logger:error("Invalid metadata for update", { key = key })
        return false
    end
    
    local bucketId = self.keyToId[key]
    if not bucketId or not self.buckets[bucketId] then
        Logger:error("Bucket not found for metadata update", { key = key })
        return false
    end
    
    -- Begin transaction
    local txnId = self:beginTransaction(source)
    if not txnId then
        Logger:error("Failed to begin transaction for updating bucket metadata")
        return false
    end
    
    local bucket = self.buckets[bucketId]
    
    -- Store backup for rollback
    local oldMetadata = Helper.deepCopy(bucket.metadata)
    
    -- Add to transaction
    self:addToTransaction("update", "metadata", {
        bucketId = bucketId,
        key = key,
        oldMetadata = oldMetadata
    }, function()
        -- Rollback: restore old metadata
        bucket.metadata = oldMetadata
    end)
    
    -- Update metadata (merge with existing)
    bucket.metadata = Helper.merge(bucket.metadata, metadata)
    bucket.metadata.lastModified = os.time()
    
    -- Increase version
    bucket.version = bucket.version + 1
    
    -- Trigger hooks
    self:triggerHooks("onBucketMetadataChange", bucketId, key, bucket.metadata)
    
    -- Audit the operation
    Security.audit(source, "update_bucket_metadata", {
        key = key,
        bucketId = bucketId
    })
    
    -- Commit transaction
    if not self:commitTransaction() then
        Logger:error("Failed to commit transaction for updating bucket metadata")
        return false
    end
    
    Logger:debug("Updated bucket metadata", { key = key })
    return true
end

return BucketsModule
