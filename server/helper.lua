local helper = {}

lib.callback.register('rw_buckets:setMeBucket', function(source, key)
    if not source or source <= 0 then return false end
    if not key or type(key) ~= "string" or key == "" then return false end
    return exports.rw_buckets:setPlayerBucket(source, key)
end)

lib.callback.register('rw_buckets:removeMeFromBucket', function(source)
    if not source or source <= 0 then return false end
    return exports.rw_buckets:removePlayerFromBucket(source)
end)

lib.callback.register('rw_buckets:setVehBucket', function(source, netId, key)
    if not source or source <= 0 then return false end
    if not netId then return false end
    if not key or type(key) ~= "string" or key == "" then return false end
    
    local veh = NetworkGetEntityFromNetworkId(netId) ---@type number
    if veh == 0 then return false end
    if not DoesEntityExist(veh) then return false end
    
    return exports.rw_buckets:setEntityBucket(veh, key)
end)

lib.callback.register('rw_buckets:removeVehFromBucket', function(source, netId)
    if not source or source <= 0 then return false end
    if not netId then return false end
    
    local veh = NetworkGetEntityFromNetworkId(netId) ---@type number
    if veh == 0 then return false end
    if not DoesEntityExist(veh) then return false end
    
    return exports.rw_buckets:removeEntityFromBucket(veh)
end)

return helper
