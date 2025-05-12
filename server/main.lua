local Logger = require("server.logger")
local Security = require("server.security")
local Persistence = require("server.persistence")
local bucketManager = require("server.BucketManager") ---@type BucketManager
local bucketExports = {}

-- Initialize the system when resource starts
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    Logger:info("RW Buckets initializing", { version = "2.2.0" })
    
    -- Configure security
    Security.permissionGroups = {
        admin = {"command.rw_buckets.admin"},
        manager = {"command.rw_buckets.manager"},
        user = {"command.rw_buckets.user"}
    }
    
    -- Configure persistence
    Persistence.configure({
        saveInterval = 300, -- 5 minutes
        saveOnUpdate = false,
        storage = "file",
        backupCount = 5
    })
    
    -- Initialize the bucket manager
    bucketManager:initialize()
    
    -- Register predefined templates
    bucketManager:registerTemplate("interior", {
        metadata = {
            description = "Interior instance template",
            tags = {"interior", "instance"},
            customData = {}
        },
        settings = {
            allowVehicles = true,
            allowNPCs = true
        }
    })
    
    bucketManager:registerTemplate("property", {
        metadata = {
            description = "Property instance template",
            tags = {"property", "instance"},
            customData = {}
        },
        settings = {
            allowVehicles = false,
            allowNPCs = false
        }
    })
    
    bucketManager:registerTemplate("job", {
        metadata = {
            description = "Job instance template",
            tags = {"job", "instance"},
            customData = {}
        },
        settings = {
            allowVehicles = true,
            allowNPCs = true,
            jobSpecific = true
        }
    })

    -- Register permissions for bucket commands
    lib.addAce('group.admin', 'command.rw_buckets.admin', true)
    lib.addAce('group.admin', 'command.rw_buckets.manager', true)
    lib.addAce('group.admin', 'command.rw_buckets.user', true)
    
    lib.addAce('group.moderator', 'command.rw_buckets.manager', true)
    lib.addAce('group.moderator', 'command.rw_buckets.user', true)
    
    lib.addAce('group.developer', 'command.rw_buckets.admin', true)
    lib.addAce('group.developer', 'command.rw_buckets.manager', true)
    lib.addAce('group.developer', 'command.rw_buckets.user', true)
    
    Logger:info("RW Buckets initialized successfully")
end)

-- <<<Player Exports>>>
---Sets a player's bucket
---@param src number The player ID
---@param key string The bucket key
---@param metadata table|nil Optional metadata if creating a new bucket
---@return boolean success
bucketExports.setPlayerBucket = function(src, key, metadata)
    return bucketManager:setPlayerBucket(src, key, metadata, src)
end

---Removes a player from their bucket
---@param src number The player ID
---@return boolean success
bucketExports.removePlayerFromBucket = function(src)
    return bucketManager:removePlayerFromBucket(src, src)
end

---Gets a player's bucket key
---@param src number The player ID
---@param includeMetadata boolean|nil Whether to include metadata in the result
---@return string|nil key The bucket key
---@return table|nil bucket The full bucket object if includeMetadata is true
bucketExports.getPlayerBucketKey = function(src, includeMetadata)
    local key, bucket = bucketManager:getPlayerBucketKey(src)
    if includeMetadata and bucket then
        return key, bucket
    end
    return key
end

-- <<<Entity Exports>>>
---Sets an entity's bucket
---@param entityId number The entity ID
---@param key string The bucket key
---@param metadata table|nil Optional metadata if creating a new bucket
---@param source number|nil The requesting source (defaults to caller if not provided)
---@return boolean success
bucketExports.setEntityBucket = function(entityId, key, metadata, source)
    return bucketManager:setEntityBucket(entityId, key, metadata, source or GetInvokingResource() and "resource:"..GetInvokingResource() or nil)
end

---Removes an entity from its bucket
---@param entityId number The entity ID
---@param source number|nil The requesting source (defaults to caller if not provided)
---@return boolean success
bucketExports.removeEntityFromBucket = function(entityId, source)
    return bucketManager:removeEntityFromBucket(entityId, source or GetInvokingResource() and "resource:"..GetInvokingResource() or nil)
end

---Gets an entity's bucket key
---@param entityId number The entity ID
---@param includeMetadata boolean|nil Whether to include metadata in the result
---@return string|nil key The bucket key
---@return table|nil bucket The full bucket object if includeMetadata is true
bucketExports.getEntityBucketKey = function(entityId, includeMetadata)
    local key, bucket = bucketManager:getEntityBucketKey(entityId)
    if includeMetadata and bucket then
        return key, bucket
    end
    return key
end

-- <<<Bucket Exports>>>
---Gets the contents of a bucket
---@param key string The bucket key
---@param includeMetadata boolean|nil Whether to include metadata in the result
---@return table bucket The bucket contents
bucketExports.getBucketContents = function(key, includeMetadata)
    return bucketManager:getBucketContents(key, includeMetadata)
end

---Gets all active bucket keys
---@param includeMetadata boolean|nil Whether to include metadata in the result
---@param filter table|nil Optional filter criteria
---@return table<number, {id: number, key: string, metadata: table|nil}> buckets
bucketExports.getActiveBucketKeys = function(includeMetadata, filter)
    return bucketManager:getActiveBucketKeys(includeMetadata, filter)
end

---Kills a bucket and removes all its contents
---@param key string The bucket key
---@param source number|nil The requesting source
---@return boolean success
bucketExports.killBucket = function(key, source)
    return bucketManager:killBucket(key, source or GetInvokingResource() and "resource:"..GetInvokingResource() or nil)
end

-- <<<Template Exports>>>
---Register a bucket template
---@param name string Template name
---@param template table Template configuration
---@return boolean success
bucketExports.registerTemplate = function(name, template)
    return bucketManager:registerTemplate(name, template)
end

---Get a bucket template
---@param name string Template name
---@return table|nil template
bucketExports.getTemplate = function(name)
    return bucketManager:getTemplate(name)
end

---Create a bucket from a template
---@param key string Bucket key
---@param templateName string Template name
---@param overrides table|nil Optional overrides for template values
---@param source number|nil The requesting source
---@return number bucketId
bucketExports.createBucketFromTemplate = function(key, templateName, overrides, source)
    return bucketManager:createBucketFromTemplate(key, templateName, overrides, source or GetInvokingResource() and "resource:"..GetInvokingResource() or nil)
end

-- <<<Advanced Bucket Operations>>>
---Merge two buckets together
---@param targetKey string The target bucket key (will contain merged contents)
---@param sourceKey string The source bucket key (will be emptied and deleted)
---@param source number|nil The requesting source
---@return boolean success
bucketExports.mergeBuckets = function(targetKey, sourceKey, source)
    return bucketManager:mergeBuckets(targetKey, sourceKey, source or GetInvokingResource() and "resource:"..GetInvokingResource() or nil)
end

---Update bucket metadata
---@param key string Bucket key
---@param metadata table New metadata fields
---@param source number|nil The requesting source
---@return boolean success
bucketExports.updateBucketMetadata = function(key, metadata, source)
    return bucketManager:updateBucketMetadata(key, metadata, source or GetInvokingResource() and "resource:"..GetInvokingResource() or nil)
end

---Create a new bucket
---@param key string The bucket key
---@param metadata table|nil Optional metadata for the bucket
---@param settings table|nil Optional settings for the bucket
---@param source number|nil The requesting source
---@return number bucketId
bucketExports.createBucket = function(key, metadata, settings, source)
    return bucketManager:createBucket(key, metadata, settings, source or GetInvokingResource() and "resource:"..GetInvokingResource() or nil)
end

-- <<<Export Registration>>>
for exportName, exportFunction in pairs(bucketExports) do
    exports(exportName, exportFunction)
end

-- <<<Callbacks>>>
---Gets the calling player's bucket key
---@param source number
---@return string|nil
lib.callback.register('rw_buckets:getMyBucket', function(source)
    if not source or source <= 0 then return nil end
    if not GetPlayerName(source) then return nil end
    return bucketExports.getPlayerBucketKey(source)
end)

---Gets all active bucket keys
---@param source number
---@return table<number, {id: number, key: string}>
lib.callback.register('rw_buckets:getActiveBuckets', function(source)
    if not source or source <= 0 then return {} end
    return bucketExports.getActiveBucketKeys()
end)

---Gets the contents of a specific bucket
---@param source number
---@param key string
---@return Bucket
lib.callback.register('rw_buckets:getBucketContents', function(source, key)
    if not source or source <= 0 then return { players = {}, entities = {}, key = key or "unknown" } end
    if not key or type(key) ~= "string" then return { players = {}, entities = {}, key = key or "unknown" } end
    return bucketExports.getBucketContents(key)
end)

---Kills a bucket if the player has permission
---@param source number
---@param key string
---@return boolean
lib.callback.register('rw_buckets:kill', function(source, key)
    if not source or source <= 0 then return false end
    if not key or type(key) ~= "string" then return false end
    if not IsPlayerAceAllowed(source, "command.rw_buckets") then return false end
    
    bucketExports.killBucket(key)
    return true
end)

---Removes a player from their bucket if the caller has permission
---@param source number
---@param playerId string|number
---@return boolean
lib.callback.register('rw_buckets:removePlayerFromBucket', function(source, playerId)
    if not source or source <= 0 then return false end
    if not playerId then return false end
    if not IsPlayerAceAllowed(source, "command.rw_buckets") then return false end
    
    local pid = tonumber(playerId)
    if not pid or not GetPlayerName(pid) then return false end
    return bucketExports.removePlayerFromBucket(pid)
end)

---Removes an entity from its bucket
---@param source number
---@param entityId string|number
---@return boolean
lib.callback.register('rw_buckets:removeEntityFromBucket', function(source, entityId)
    if not source or source <= 0 then return false end
    if not entityId then return false end
    
    local eid = tonumber(entityId)
    if not eid or not DoesEntityExist(eid) then return false end
    return bucketExports.removeEntityFromBucket(eid)
end)

-- <<<Events>>>
---Cleans up player bucket on disconnect
AddEventHandler('playerDropped', function(reason)
    local src = source ---@type number
    local bucketKey = bucketManager:getPlayerBucketKey(src)
    if bucketKey then
        bucketManager:removePlayerFromBucket(src)
        print(string.format("Player %s removed from bucket: %s", GetPlayerName(src) or src, bucketKey))
    end
end)

-- <<<Commands>>>
lib.addCommand('setpb', { -- Short for "Set Player Bucket"
    help = 'Sets a player\'s bucket',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID' },
        { name = 'bucket', type = 'string', help = 'Bucket name' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    bucketExports.setPlayerBucket(args.id, args.bucket)
end)

lib.addCommand('resetpb', { -- Short for "Reset Player Bucket"
    help = 'Removes a player from their bucket',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    bucketExports.removePlayerFromBucket(args.id)
end)

lib.addCommand('resetb', { -- Short for "Reset Bucket"
    help = 'Resets a player\'s bucket',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID' }
    },
    restricted = { 'group.developer', 'group.admin', 'group.superadmin', 'group.owner' }
}, function(source, args, raw)
    bucketExports.removePlayerFromBucket(args.id)
end)

lib.addCommand('listb', { -- Short for "List Buckets"
    help = 'Lists all active buckets',
    params = {},
    restricted = 'group.developer'
}, function(source, args, raw)
    print(json.encode(bucketExports.getActiveBucketKeys(), { indent = true }))
end)

lib.addCommand('getpb', { -- Short for "Get Player Bucket"
    help = 'Gets a player\'s bucket',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    local bucketKey = bucketExports.getPlayerBucketKey(args.id)
    print(bucketKey and string.format("Player %d is in bucket: %s", args.id, bucketKey) or
        string.format("Player %d is not in any bucket", args.id))
end)

lib.addCommand('showb', { -- Short for "Show Bucket"
    help = 'Shows bucket contents',
    params = {
        { name = 'bucket', type = 'string', help = 'Bucket name' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    local contents = bucketExports.getBucketContents(args.bucket)
    local playerList = {}
    local i = 0
    for playerId in pairs(contents.players) do
        i = i + 1
        playerList[i] = { playerId = playerId, Name = GetPlayerName(playerId) or "Unknown" }
    end
    for entityId in pairs(contents.entities) do
        i = i + 1
        playerList[i] = { playerId = entityId, Name = "Entity" }
    end
    print(next(playerList) and
        string.format("Contents of bucket '%s': %s", args.bucket, json.encode(playerList, { indent = true })) or
        string.format("Bucket '%s' is empty or does not exist", args.bucket))
end)

lib.addCommand('killb', { -- Short for "Kill Bucket"
    help = 'Kills a bucket',
    params = {
        { name = 'bucket', type = 'string', help = 'Bucket name' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    bucketExports.killBucket(args.bucket)
    print(string.format("Bucket '%s' has been killed", args.bucket))
end)