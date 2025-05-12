local Logger = require("server.logger")
local Security = require("server.security")
local Persistence = require("server.persistence")
local Helper = require("server.helper")

---@class BucketManager.Core
local CoreModule = {}

-- Initialization function
function CoreModule.initialize(self)
    if self.initialized then
        return true
    end
    
    Logger:info("Initializing BucketManager")
    
    -- Load persisted state if available
    local state = Persistence.loadState()
    if state and state.buckets then
        self.buckets = state.buckets
        self.keyToId = state.keyToId or {}
        self.nextBucketId = state.nextBucketId or 1
        
        -- Verify data integrity
        self:verifyDataIntegrity()
        
        Logger:info("Loaded buckets from persistent storage", {
            bucketCount = #table.keys(self.buckets)
        })
    end
    
    -- Register event hook for player disconnects
    AddEventHandler('playerDropped', function(reason)
        local source = source
        self:handlePlayerDisconnect(source, reason)
    end)
    
    -- Register periodic cleanup task
    CreateThread(function()
        while true do
            Wait(60000) -- Run every minute
            self:cleanupDeadEntities()
        end
    end)
    
    self.initialized = true
    return true
end

-- Verify the integrity of bucket data and repair if needed
function CoreModule.verifyDataIntegrity(self)
    Logger:info("Verifying bucket data integrity")
    local repairs = 0
    
    -- Check for missing reference keys
    for id, bucket in pairs(self.buckets) do
        if not bucket.key then
            Logger:warn("Bucket missing key", { id = id })
            bucket.key = "recovered_" .. id
            repairs = repairs + 1
        end
        
        if not self.keyToId[bucket.key] then
            Logger:warn("Key to ID mapping missing", { id = id, key = bucket.key })
            self.keyToId[bucket.key] = id
            repairs = repairs + 1
        end
        
        -- Initialize missing fields with defaults
        if not bucket.players then bucket.players = {} end
        if not bucket.entities then bucket.entities = {} end
        if not bucket.metadata then
            bucket.metadata = {
                created = os.time(),
                lastModified = os.time(),
                creator = "system_recovery",
                description = "Recovered bucket",
                tags = {},
                customData = {}
            }
            repairs = repairs + 1
        end
        if not bucket.settings then bucket.settings = {} end
        if not bucket.version then bucket.version = 1 end
        
        -- Check for non-existent players
        for playerId in pairs(bucket.players) do
            if not GetPlayerName(playerId) then
                Logger:debug("Removing non-existent player from bucket", { 
                    player = playerId, 
                    bucket = bucket.key 
                })
                bucket.players[playerId] = nil
                repairs = repairs + 1
            end
        end
    end
    
    -- Check for key to ID references that don't match a bucket
    for key, id in pairs(self.keyToId) do
        if not self.buckets[id] then
            Logger:warn("Key references non-existent bucket ID", { key = key, id = id })
            self.keyToId[key] = nil
            repairs = repairs + 1
        end
    end
    
    if repairs > 0 then
        Logger:info("Completed data integrity repairs", { count = repairs })
        Persistence.markChanged()
    else
        Logger:info("No data integrity issues found")
    end
end

-- Cleanup dead entities that no longer exist
function CoreModule.cleanupDeadEntities(self)
    local removedCount = 0
    
    for bucketId, bucket in pairs(self.buckets) do
        for entityId in pairs(bucket.entities) do
            if not DoesEntityExist(entityId) then
                bucket.entities[entityId] = nil
                removedCount = removedCount + 1
                
                Logger:debug("Removed dead entity from bucket", {
                    entity = entityId,
                    bucket = bucket.key
                })
            end
        end
    end
    
    if removedCount > 0 then
        Logger:info("Cleaned up dead entities", { count = removedCount })
        Persistence.markChanged()
    end
end

-- Handle player disconnect
function CoreModule.handlePlayerDisconnect(self, playerId, reason)
    Logger:debug("Player disconnected", { player = playerId, reason = reason })
    
    -- Get player's current bucket
    local bucketId = GetPlayerRoutingBucket(playerId)
    if bucketId == 0 then return end
    
    local bucket = self.buckets[bucketId]
    if not bucket then return end
    
    -- Remove player from bucket
    if bucket.players[playerId] then
        bucket.players[playerId] = nil
        bucket.metadata.lastModified = os.time()
        
        Logger:debug("Removed disconnected player from bucket", {
            player = playerId,
            bucket = bucket.key
        })
        
        -- Try to garbage collect the bucket if it's now empty
        self:garbageCollector(bucketId)
        
        Persistence.markChanged()
    end
end

-- Return the state for persistence
function CoreModule.getState(self)
    return {
        buckets = self.buckets,
        keyToId = self.keyToId,
        nextBucketId = self.nextBucketId
    }
end

-- Garbage collects an empty bucket
function CoreModule.garbageCollector(self, bucketId)
    local bucket = self.buckets[bucketId]
    if bucket and not next(bucket.players) and not next(bucket.entities) then
        self.keyToId[bucket.key] = nil
        self.buckets[bucketId] = nil
        self.reusableIds[#self.reusableIds + 1] = bucketId
        table.sort(self.reusableIds)
        
        -- Trigger bucket delete hooks
        self:triggerHooks("onBucketDelete", bucketId, bucket.key)
        
        Logger:debug("Garbage collected empty bucket", { id = bucketId, key = bucket.key })
        
        -- Mark changes for persistence
        Persistence.markChanged()
    end
end

return CoreModule
