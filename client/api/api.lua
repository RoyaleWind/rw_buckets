local bucketAPI = {}
local bucket = nil

RegisterNetEvent('rw_buckets:onBucketUpdate', function(current)
    bucket = current ---@type string|nil
end)

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

function bucketAPI.getBucket()
    return bucket
end

function bucketAPI.setMe(bucketKey)
    if not validateBucketKey(bucketKey) then return false end
    return lib.callback.await('rw_buckets:setMeBucket', false, bucketKey) ---@type boolean
end

function bucketAPI.remMe()
    lib.callback.await('rw_buckets:removeMeFromBucket', false) ---@type boolean
end

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
    
    if not bucketAPI.setVeh(veh, bucketKey) then 
        lib.print.error("Failed to set vehicle bucket")
        return false 
    end
    
    if bucketAPI.setMe(bucketKey) then
        TaskWarpPedIntoVehicle(cache.ped, veh, -1) 
        return true
    end
    
    bucketAPI.remVeh(veh)
    lib.print.error("Failed to set player bucket, vehicle bucket reset")
    return false
end

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
    
    local vehicleSuccess = bucketAPI.remVeh(veh)
    if not vehicleSuccess then
        lib.print.error("Failed to remove vehicle from bucket")
        return false
    end
    
    local playerSuccess = bucketAPI.remMe()
    if playerSuccess then
        TaskWarpPedIntoVehicle(cache.ped, veh, -1) 
        return true
    end
    
    lib.print.error("Failed to remove player from bucket")
    return false
end

for exportName, exportFunction in pairs(bucketAPI) do
    exports(exportName, exportFunction)
end

local api = {}
return api
