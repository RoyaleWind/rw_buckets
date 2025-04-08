local bucketManager = require("server.BucketManager") ---@type BucketManager
local bucketExports = {}

---Adds ACE permission for bucket commands
Citizen.CreateThread(function()
    lib.addAce('group.admin', 'command.rw_buckets', true)
end)

-- <<<Player Exports>>>
---Sets a player's bucket
---@param src number
---@param key string
bucketExports.setPlayerBucket = function(src, key)
    bucketManager:setPlayerBucket(src, key)
end

---Removes a player from their bucket
---@param src number
bucketExports.removePlayerFromBucket = function(src)
    bucketManager:removePlayerFromBucket(src)
end

---Gets a player's bucket key
---@param src number
---@return string|nil
bucketExports.getPlayerBucketKey = function(src)
    return bucketManager:getPlayerBucketKey(src)
end

-- <<<Entity Exports>>>
---Sets an entity's bucket
---@param entityId number
---@param key string
bucketExports.setEntityBucket = function(entityId, key)
    bucketManager:setEntityBucket(entityId, key)
end

---Removes an entity from its bucket
---@param entityId number
bucketExports.removeEntityFromBucket = function(entityId)
    bucketManager:removeEntityFromBucket(entityId)
end

---Gets an entity's bucket key
---@param entityId number
---@return string|nil
bucketExports.getEntityBucketKey = function(entityId)
    return bucketManager:getEntityBucketKey(entityId)
end

-- <<<Bucket Exports>>>
---Gets the contents of a bucket
---@param key string
---@return Bucket
bucketExports.getBucketContents = function(key)
    return bucketManager:getBucketContents(key)
end

---Gets all active bucket keys
---@return table<number, {id: number, key: string}>
bucketExports.getActiveBucketKeys = function()
    return bucketManager:getActiveBucketKeys()
end

---Kills a bucket and removes all its contents
---@param key string
bucketExports.killBucket = function(key)
    bucketManager:killBucket(key)
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
    return bucketExports.getPlayerBucketKey(source)
end)

---Gets all active bucket keys
---@param source number
---@return table<number, {id: number, key: string}>
lib.callback.register('rw_buckets:getActiveBuckets', function(source)
    return bucketExports.getActiveBucketKeys()
end)

---Gets the contents of a specific bucket
---@param source number
---@param key string
---@return Bucket
lib.callback.register('rw_buckets:getBucketContents', function(source, key)
    return bucketExports.getBucketContents(key)
end)

---Kills a bucket if the player has permission
---@param source number
---@param key string
---@return boolean
lib.callback.register('rw_buckets:kill', function(source, key)
    if not IsPlayerAceAllowed(source, "command.rw_buckets") then return false end
    bucketExports.killBucket(key)
    return true
end)

---Removes a player from their bucket if the caller has permission
---@param source number
---@param playerId string|number
---@return boolean
lib.callback.register('rw_buckets:removePlayerFromBucket', function(source, playerId)
    if not IsPlayerAceAllowed(source, "command.rw_buckets") then return false end
    local pid = tonumber(playerId)
    if not pid or not GetPlayerName(pid) then return false end
    bucketExports.removePlayerFromBucket(pid)
    return true
end)

---Removes an entity from its bucket
---@param source number
---@param entityId string|number
---@return boolean
lib.callback.register('rw_buckets:removeEntityFromBucket', function(source, entityId)
    local eid = tonumber(entityId)
    if not eid or not DoesEntityExist(eid) then return false end
    bucketExports.removeEntityFromBucket(eid)
    return true
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