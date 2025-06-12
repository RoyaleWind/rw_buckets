local bucketManager = require("server.BucketManager")
local bucketExports = {}

Citizen.CreateThread(function()
    lib.addAce('group.admin', 'command.rw_buckets', true)
end)

bucketExports.setPlayerBucket = function(src, key)
    bucketManager:setPlayerBucket(src, key)
end
bucketExports.removePlayerFromBucket = function(src)
    bucketManager:removePlayerFromBucket(src)
end
bucketExports.getPlayerBucketKey = function(src)
    return bucketManager:getPlayerBucketKey(src)
end
bucketExports.setEntityBucket = function(entityId, key)
    bucketManager:setEntityBucket(entityId, key)
end
bucketExports.removeEntityFromBucket = function(entityId)
    bucketManager:removeEntityFromBucket(entityId)
end
bucketExports.getEntityBucketKey = function(entityId)
    return bucketManager:getEntityBucketKey(entityId)
end
bucketExports.getBucketContents = function(key)
    return bucketManager:getBucketContents(key)
end
bucketExports.getActiveBucketKeys = function()
    return bucketManager:getActiveBucketKeys()
end
bucketExports.killBucket = function(key)
    bucketManager:killBucket(key)
end

for exportName, exportFunction in pairs(bucketExports) do
    exports(exportName, exportFunction)
end

lib.callback.register('rw_buckets:getMyBucket', function(source)
    if not source or source <= 0 then return nil end
    if not GetPlayerName(source) then return nil end
    return bucketExports.getPlayerBucketKey(source)
end)

lib.callback.register('rw_buckets:getActiveBuckets', function(source)
    if not source or source <= 0 then return {} end
    return bucketExports.getActiveBucketKeys()
end)

lib.callback.register('rw_buckets:getBucketContents', function(source, key)
    if not source or source <= 0 then return { players = {}, entities = {}, key = key or "unknown" } end
    if not key or type(key) ~= "string" then return { players = {}, entities = {}, key = key or "unknown" } end
    return bucketExports.getBucketContents(key)
end)

lib.callback.register('rw_buckets:kill', function(source, key)
    if not source or source <= 0 then return false end
    if not key or type(key) ~= "string" then return false end
    if not IsPlayerAceAllowed(source, "command.rw_buckets") then return false end
    bucketExports.killBucket(key)
    return true
end)

lib.callback.register('rw_buckets:removePlayerFromBucket', function(source, playerId)
    if not source or source <= 0 then return false end
    if not playerId then return false end
    if not IsPlayerAceAllowed(source, "command.rw_buckets") then return false end
    local pid = tonumber(playerId)
    if not pid or not GetPlayerName(pid) then return false end
    return bucketExports.removePlayerFromBucket(pid)
end)

lib.callback.register('rw_buckets:removeEntityFromBucket', function(source, entityId)
    if not source or source <= 0 then return false end
    if not entityId then return false end
    local eid = tonumber(entityId)
    if not eid or not DoesEntityExist(eid) then return false end
    return bucketExports.removeEntityFromBucket(eid)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local bucketKey = bucketManager:getPlayerBucketKey(src)
    if bucketKey then
        bucketManager:removePlayerFromBucket(src)
        print(string.format("Player %s removed from bucket: %s", GetPlayerName(src) or src, bucketKey))
    end
end)

lib.addCommand('setpb', {
    help = 'Sets a player\'s bucket',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID' },
        { name = 'bucket', type = 'string', help = 'Bucket name' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    bucketExports.setPlayerBucket(args.id, args.bucket)
end)

lib.addCommand('resetpb', {
    help = 'Removes a player from their bucket',
    params = {
        { name = 'id', type = 'playerId', help = 'Player ID' }
    },
    restricted = { 'group.developer', 'group.admin', 'group.superadmin', 'group.owner' }
}, function(source, args, raw)
    bucketExports.removePlayerFromBucket(args.id)
end)

lib.addCommand('listb', {
    help = 'Lists all active buckets',
    params = {},
    restricted = 'group.developer'
}, function(source, args, raw)
    print(json.encode(bucketExports.getActiveBucketKeys(), { indent = true }))
end)

lib.addCommand('getpb', {
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

lib.addCommand('showb', {
    help = 'Shows bucket contents',
    params = {
        { name = 'bucket', type = 'string', help = 'Bucket name' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    local contents = bucketExports.getBucketContents(args.bucket)
    local playerList = {}
    for playerId in pairs(contents.players) do
        playerList[#playerList + 1] = { playerId = playerId, Name = GetPlayerName(playerId) or "Unknown" }
    end
    for entityId in pairs(contents.entities) do
        playerList[#playerList + 1] = { playerId = entityId, Name = "Entity" }
    end
    print(next(playerList) and
        string.format("Contents of bucket '%s': %s", args.bucket, json.encode(playerList, { indent = true })) or
        string.format("Bucket '%s' is empty or does not exist", args.bucket))
end)

lib.addCommand('killb', {
    help = 'Kills a bucket',
    params = {
        { name = 'bucket', type = 'string', help = 'Bucket name' }
    },
    restricted = 'group.developer'
}, function(source, args, raw)
    bucketExports.killBucket(args.bucket)
    print(string.format("Bucket '%s' has been killed", args.bucket))
end)
