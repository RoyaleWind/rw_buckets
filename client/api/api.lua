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
    if not DoesEntityExist(vehicle) then
        lib.print.error("Invalid vehicle: entity does not exist")
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
    if not DoesEntityExist(vehicle) then
        lib.print.error("Invalid vehicle: entity does not exist")
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle) ---@type number
    return lib.callback.await('rw_buckets:removeVehFromBucket', false, netId) ---@type boolean
end

---Sets both player and their vehicle to a bucket
---@param bucketKey string
---@return boolean success
function bucketAPI.setMeAndVeh(bucketKey)
    local veh = cache.vehicle ---@type number|nil
    if not veh or cache.seat ~= -1 then
        lib.print.error("Must be the driver to set vehicle bucket")
        return false
    end
    if not bucketAPI.setVeh(veh, bucketKey) then return false end
    if bucketAPI.setMe(bucketKey) then
        TaskWarpPedIntoVehicle(cache.ped, veh, -1) -- Ensure player stays in vehicle
        return true
    end
    return false
end

---Removes both player and their vehicle from their bucket
---@return boolean success
function bucketAPI.remMeAndVeh()
    local veh = cache.vehicle ---@type number|nil
    if not veh or cache.seat ~= -1 then
        lib.print.error("Must be the driver to remove vehicle bucket")
        return false
    end
    if not bucketAPI.remVeh(veh) then return false end
    if bucketAPI.remMe() then
        TaskWarpPedIntoVehicle(cache.ped, veh, -1) -- Ensure player stays in vehicle
        return true
    end
    return false
end

-- Export all API functions
for exportName, exportFunction in pairs(bucketAPI) do
    exports(exportName, exportFunction)
end