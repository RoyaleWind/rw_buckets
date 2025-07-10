---Sets the player's bucket via callback
---@param source number The player source ID
---@param key string The bucket key to set
---@return boolean success
lib.callback.register('rw_buckets:setMeBucket', function(source, key)
    if not source or source <= 0 then return false end
    if not key or type(key) ~= "string" or key == "" then return false end
    return exports.rw_buckets:setPlayerBucket(source, key)
end)

---Removes the player from their current bucket via callback
---@param source number The player source ID
---@return boolean success
lib.callback.register('rw_buckets:removeMeFromBucket', function(source)
    if not source or source <= 0 then return false end
    return exports.rw_buckets:removePlayerFromBucket(source)
end)

---Sets a vehicle's bucket via callback
---@param source number The player source ID
---@param netId number The network ID of the vehicle
---@param key string The bucket key to set
---@return boolean success
lib.callback.register('rw_buckets:setVehBucket', function(source, netId, key)
    if not source or source <= 0 then return false end
    if not netId then return false end
    if not key or type(key) ~= "string" or key == "" then return false end
    
    local veh = NetworkGetEntityFromNetworkId(netId) ---@type number
    if veh == 0 then return false end -- Check if entity exists
    if not DoesEntityExist(veh) then return false end
    
    return exports.rw_buckets:setEntityBucket(veh, key)
end)

---Removes a vehicle from its bucket via callback
---@param source number The player source ID
---@param netId number The network ID of the vehicle
---@return boolean success
lib.callback.register('rw_buckets:removeVehFromBucket', function(source, netId)
    if not source or source <= 0 then return false end
    if not netId then return false end
    
    local veh = NetworkGetEntityFromNetworkId(netId) ---@type number
    if veh == 0 then return false end -- Check if entity exists
    if not DoesEntityExist(veh) then return false end
    
    return exports.rw_buckets:removeEntityFromBucket(veh)
end)