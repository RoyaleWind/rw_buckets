---@class BucketAPI
local bucketAPI = {}
local bucket = nil

RegisterNetEvent('rw_buckets:onBucketUpdate', function(current)
    bucket = current ---@type string|nil
end)

---Validates a bucket key
---@param bucketKey any
---@return boolean isValid
local function validateBucketKey(bucketKey)
    if type(bucketKey) ~= "string" then
        lib.print.error("Invalid bucket key: must be a string")
        return false
    end
    if bucketKey == "" then
        lib.print.error("Invalid bucket key: cannot be empty")
        return false
    end
    return true
end

---Gets the current bucket key
---@return string|nil bucketKey
function bucketAPI.getBucket()
    return bucket
end

---Sets the local player's bucket
---@param bucketKey string
---@return boolean success
function bucketAPI.setMe(bucketKey)
    if not validateBucketKey(bucketKey) then return false end
    return lib.callback.await('rw_buckets:setMeBucket', false, bucketKey) ---@type boolean
end

---Removes the local player from their bucket
function bucketAPI.remMe()
    lib.callback.await('rw_buckets:removeMeFromBucket', false) ---@type boolean
end

---Sets a vehicle's bucket
---@param vehicle number Entity ID of the vehicle
---@param bucketKey string
---@return boolean success
function bucketAPI.setVeh(vehicle, bucketKey)
    if not validateBucketKey(bucketKey) then return false end
    if not vehicle or type(vehicle) ~= "number" then
        lib.print.error("Invalid vehicle: expected number, got " .. (type(vehicle) or "nil"))
        return false
    end
    if not DoesEntityExist(vehicle) then
        lib.print.error("Invalid vehicle: entity does not exist")
        return false
    end
    if GetEntityType(vehicle) ~= 2 then
        lib.print.error("Invalid vehicle: entity is not a vehicle")
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle) ---@type number
    if netId == 0 then
        lib.print.error("Failed to get network ID for vehicle")
        return false
    end

    return lib.callback.await('rw_buckets:setVehBucket', false, netId, bucketKey) ---@type boolean
end

---Removes a vehicle from its bucket
---@param vehicle number Entity ID of the vehicle
---@return boolean success
function bucketAPI.remVeh(vehicle)
    if not vehicle or type(vehicle) ~= "number" then
        lib.print.error("Invalid vehicle: expected number, got " .. (type(vehicle) or "nil"))
        return false
    end
    if not DoesEntityExist(vehicle) then
        lib.print.error("Invalid vehicle: entity does not exist")
        return false
    end
    if GetEntityType(vehicle) ~= 2 then
        lib.print.error("Invalid vehicle: entity is not a vehicle")
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle) ---@type number
    if netId == 0 then
        lib.print.error("Failed to get network ID for vehicle")
        return false
    end
    
    return lib.callback.await('rw_buckets:removeVehFromBucket', false, netId) ---@type boolean
end

---Sets both player and their vehicle to a bucket
---@param bucketKey string
---@return boolean success
function bucketAPI.setMeAndVeh(bucketKey)
    if not validateBucketKey(bucketKey) then return false end
    
    local veh = cache.vehicle ---@type number|nil
    if not veh or type(veh) ~= "number" then
        lib.print.error("Not in a vehicle")
        return false
    end
    if cache.seat ~= -1 then
        lib.print.error("Must be the driver to set vehicle bucket")
        return false
    end
    if not DoesEntityExist(veh) then
        lib.print.error("Vehicle no longer exists")
        return false
    end
    
    -- Set vehicle bucket first
    if not bucketAPI.setVeh(veh, bucketKey) then 
        lib.print.error("Failed to set vehicle bucket")
        return false 
    end
    
    -- Then set player bucket
    if bucketAPI.setMe(bucketKey) then
        TaskWarpPedIntoVehicle(cache.ped, veh, -1) -- Ensure player stays in vehicle
        return true
    end
    
    -- If player bucket fails, reset vehicle bucket
    bucketAPI.remVeh(veh)
    lib.print.error("Failed to set player bucket, vehicle bucket reset")
    return false
end

---Removes both player and their vehicle from their bucket
---@return boolean success
function bucketAPI.remMeAndVeh()
    local veh = cache.vehicle ---@type number|nil
    if not veh or type(veh) ~= "number" then
        lib.print.error("Not in a vehicle")
        return false
    end
    if cache.seat ~= -1 then
        lib.print.error("Must be the driver to remove vehicle bucket")
        return false
    end
    if not DoesEntityExist(veh) then
        lib.print.error("Vehicle no longer exists")
        return false
    end
    
    -- Remove vehicle bucket first
    local vehicleSuccess = bucketAPI.remVeh(veh)
    if not vehicleSuccess then
        lib.print.error("Failed to remove vehicle from bucket")
        return false
    end
    
    -- Then remove player from bucket
    local playerSuccess = bucketAPI.remMe()
    if playerSuccess then
        TaskWarpPedIntoVehicle(cache.ped, veh, -1) -- Ensure player stays in vehicle
        return true
    end
    
    lib.print.error("Failed to remove player from bucket")
    return false
end

-- Export all API functions
for exportName, exportFunction in pairs(bucketAPI) do
    exports(exportName, exportFunction)
end
