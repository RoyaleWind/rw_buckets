---Sets the player's bucket via callback
---@param source number The player source ID
---@param key string The bucket key to set
---@return boolean success
lib.callback.register('rw_buckets:setMeBucket', function(source, key)
    exports.rw_buckets:setPlayerBucket(source, key)
    return true
end)

---Removes the player from their current bucket via callback
---@param source number The player source ID
---@return boolean success
lib.callback.register('rw_buckets:removeMeFromBucket', function(source)
    exports.rw_buckets:removePlayerFromBucket(source)
    return true
end)

---Sets a vehicle's bucket via callback
---@param source number The player source ID
---@param netId number The network ID of the vehicle
---@param key string The bucket key to set
---@return boolean success
lib.callback.register('rw_buckets:setVehBucket', function(source, netId, key)
    if not netId then return false end
    local veh = NetworkGetEntityFromNetworkId(netId) ---@type number
    if veh == 0 then return false end -- Check if entity exists
    exports.rw_buckets:setEntityBucket(veh, key)
    return true
end)

---Removes a vehicle from its bucket via callback
---@param source number The player source ID
---@param netId number The network ID of the vehicle
---@return boolean success
lib.callback.register('rw_buckets:removeVehFromBucket', function(source, netId)
    if not netId then return false end
    local veh = NetworkGetEntityFromNetworkId(netId) ---@type number
    if veh == 0 then return false end -- Check if entity exists
    exports.rw_buckets:removeEntityFromBucket(veh)
    return true
end)