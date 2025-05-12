---@class BucketAPI
local bucketAPI = {}
local currentBucket = nil
local bucketMetadata = nil
local showBucketIndicator = false
local transitionEffects = true
local bucketUI = nil

-- Configuration
local config = {
    indicator = {
        show = false,        -- Whether to show bucket indicator by default
        position = "top-left", -- Position on screen: "top-left", "top-right", "bottom-left", "bottom-right"
        fadeTime = 3000,     -- Time in ms for indicator to fade after bucket change
        style = "default"    -- UI style: "default", "minimal", "detailed"
    },
    transitions = {
        enabled = true,      -- Whether to use transition effects
        type = "fade",      -- Type of transition: "fade", "flash", "blur", "none"
        duration = 500,      -- Duration in ms
        color = {0, 0, 0, 200} -- RGBA for fade/flash effect
    }
}

--- Event when bucket changes
RegisterNetEvent('rw_buckets:onBucketUpdate', function(current, meta)
    local oldBucket = currentBucket
    currentBucket = current ---@type string|nil
    bucketMetadata = meta
    
    -- Show transition effect if enabled and bucket actually changed
    if config.transitions.enabled and oldBucket ~= currentBucket then
        bucketAPI.playTransitionEffect()
    end
    
    -- Update bucket indicator if enabled
    if config.indicator.show then
        bucketAPI.showIndicator(config.indicator.fadeTime)
    end
    
    -- Trigger local event for other scripts to use
    TriggerEvent('rw_buckets:bucketChanged', currentBucket, oldBucket, bucketMetadata)
    
    lib.callback.await('rw_buckets:clientAcknowledgeBucketChange', false, currentBucket)
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

---Gets the current bucket key and metadata
---@param includeMetadata boolean|nil Whether to include metadata in the result
---@return string|nil bucketKey
---@return table|nil metadata Bucket metadata if includeMetadata is true
function bucketAPI.getBucket(includeMetadata)
    if includeMetadata then
        return currentBucket, bucketMetadata
    end
    return currentBucket
end

---Configure the bucket API
---@param newConfig table Configuration options
---@return boolean success
function bucketAPI.configure(newConfig)
    if not newConfig or type(newConfig) ~= "table" then
        lib.print.error("Invalid configuration: must be a table")
        return false
    end
    
    -- Update indicator settings
    if newConfig.indicator then
        for k, v in pairs(newConfig.indicator) do
            config.indicator[k] = v
        end
    end
    
    -- Update transition settings
    if newConfig.transitions then
        for k, v in pairs(newConfig.transitions) do
            config.transitions[k] = v
        end
    end
    
    -- Apply immediate settings
    if newConfig.indicator and newConfig.indicator.show ~= nil then
        showBucketIndicator = newConfig.indicator.show
        if showBucketIndicator then
            bucketAPI.showIndicator(0)
        else
            bucketAPI.hideIndicator()
        end
    end
    
    if newConfig.transitions and newConfig.transitions.enabled ~= nil then
        transitionEffects = newConfig.transitions.enabled
    end
    
    return true
end

---Play a transition effect for bucket change
---@param type string|nil Override transition type
---@param duration number|nil Override duration
---@param color table|nil Override color {r,g,b,a}
function bucketAPI.playTransitionEffect(type, duration, color)
    if not transitionEffects then return end
    
    type = type or config.transitions.type
    duration = duration or config.transitions.duration
    color = color or config.transitions.color
    
    if type == "none" then return end
    
    if type == "fade" then
        -- Simple fade in/out transition
        DoScreenFadeOut(duration / 2)
        Wait(duration / 2)
        DoScreenFadeIn(duration / 2)
    elseif type == "flash" then
        -- Quick flash
        SetDrawOrigin(0.0, 0.0, 0.0, 0)
        DrawRect(0.5, 0.5, 1.0, 1.0, color[1], color[2], color[3], color[4])
        SetDrawOrigin(0.0, 0.0, 0.0, 0)
        Wait(duration)
    elseif type == "blur" then
        -- Blur effect (requires shader)
        TriggerScreenblurFadeIn(duration / 1000)
        Wait(duration)
        TriggerScreenblurFadeOut(duration / 1000)
    end
end

---Show the bucket indicator
---@param fadeTime number|nil Time in ms until the indicator fades
function bucketAPI.showIndicator(fadeTime)
    if not showBucketIndicator then return end
    
    -- Initialize UI if needed
    if not bucketUI then
        bucketAPI.createBucketUI()
    end
    
    -- Update UI with current bucket info
    if currentBucket then
        SendNUIMessage({
            action = "updateBucketIndicator",
            bucket = currentBucket,
            metadata = bucketMetadata,
            style = config.indicator.style,
            fadeTime = fadeTime or 0
        })
    else
        SendNUIMessage({
            action = "hideBucketIndicator"
        })
    end
end

---Hide the bucket indicator
function bucketAPI.hideIndicator()
    if bucketUI then
        SendNUIMessage({
            action = "hideBucketIndicator"
        })
    end
end

---Create the bucket indicator UI
function bucketAPI.createBucketUI()
    -- Simple implementation using lib.notify if available
    -- For a full NUI implementation, you would create HTML/CSS/JS files
    bucketUI = true
    
    -- For now we'll use notifications as a simple UI indicator
    if currentBucket then
        lib.notify({
            title = 'Bucket',
            description = 'Current bucket: ' .. currentBucket,
            position = config.indicator.position,
            type = 'info',
            duration = config.indicator.fadeTime
        })
    end
end

---Sets the local player's bucket
---@param bucketKey string The bucket key
---@param metadata table|nil Optional metadata for new bucket
---@param withEffect boolean|nil Whether to use transition effect (defaults to config)
---@return boolean success
function bucketAPI.setMe(bucketKey, metadata, withEffect)
    -- Validate bucket key
    if not validateBucketKey(bucketKey) then return false end
    
    -- Apply transition effect if requested
    if withEffect or (withEffect == nil and config.transitions.enabled) then
        bucketAPI.playTransitionEffect()
    end
    
    -- Set bucket via server callback
    return lib.callback.await('rw_buckets:setMeBucket', false, bucketKey, metadata) ---@type boolean
end

---Removes the local player from their bucket
---@param withEffect boolean|nil Whether to use transition effect (defaults to config)
---@return boolean success
function bucketAPI.remMe(withEffect)
    -- Apply transition effect if requested
    if withEffect or (withEffect == nil and config.transitions.enabled) then
        bucketAPI.playTransitionEffect()
    end
    
    -- Remove from bucket via server callback
    return lib.callback.await('rw_buckets:removeMeFromBucket', false) ---@type boolean
end

---Sets a vehicle's bucket
---@param vehicle number Entity ID of the vehicle
---@param bucketKey string The bucket key
---@param metadata table|nil Optional metadata for new bucket
---@param withEffect boolean|nil Whether to use transition effect (defaults to config)
---@return boolean success
function bucketAPI.setVeh(vehicle, bucketKey, metadata, withEffect)
    -- Validate bucket key
    if not validateBucketKey(bucketKey) then return false end
    
    -- Validate vehicle
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

    -- Get network ID
    local netId = NetworkGetNetworkIdFromEntity(vehicle) ---@type number
    if netId == 0 then
        lib.print.error("Failed to get network ID for vehicle")
        return false
    end
    
    -- Apply transition effect if requested
    if withEffect or (withEffect == nil and config.transitions.enabled) then
        bucketAPI.playTransitionEffect()
    end

    -- Set vehicle bucket via server callback
    return lib.callback.await('rw_buckets:setVehBucket', false, netId, bucketKey, metadata) ---@type boolean
end

---Removes a vehicle from its bucket
---@param vehicle number Entity ID of the vehicle
---@param withEffect boolean|nil Whether to use transition effect (defaults to config)
---@return boolean success
function bucketAPI.remVeh(vehicle, withEffect)
    -- Validate vehicle
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

    -- Get network ID
    local netId = NetworkGetNetworkIdFromEntity(vehicle) ---@type number
    if netId == 0 then
        lib.print.error("Failed to get network ID for vehicle")
        return false
    end
    
    -- Apply transition effect if requested
    if withEffect or (withEffect == nil and config.transitions.enabled) then
        bucketAPI.playTransitionEffect()
    end
    
    -- Remove vehicle from bucket via server callback
    return lib.callback.await('rw_buckets:removeVehFromBucket', false, netId) ---@type boolean
end

---Sets both player and their vehicle to a bucket
---@param bucketKey string The bucket key
---@param metadata table|nil Optional metadata for new bucket
---@param withEffect boolean|nil Whether to use transition effect (defaults to config)
---@return boolean success
function bucketAPI.setMeAndVeh(bucketKey, metadata, withEffect)
    -- Validate bucket key
    if not validateBucketKey(bucketKey) then return false end
    
    -- Validate vehicle and player state
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
    
    -- Apply transition effect if requested (do this once at the start)
    if withEffect or (withEffect == nil and config.transitions.enabled) then
        bucketAPI.playTransitionEffect()
    end
    
    -- Use server-side transaction to ensure both operations succeed or fail together
    local result = lib.callback.await('rw_buckets:setMeAndVehBucket', false, NetworkGetNetworkIdFromEntity(veh), bucketKey, metadata)
    
    if result then
        -- Ensure player stays in vehicle after teleport
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
        return true
    end
    
    lib.print.error("Failed to set player and vehicle bucket")
    return false
end

---Removes both player and their vehicle from their bucket
---@param withEffect boolean|nil Whether to use transition effect (defaults to config)
---@return boolean success
function bucketAPI.remMeAndVeh(withEffect)
    -- Validate vehicle and player state
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
    
    -- Apply transition effect if requested (do this once at the start)
    if withEffect or (withEffect == nil and config.transitions.enabled) then
        bucketAPI.playTransitionEffect()
    end
    
    -- Use server-side transaction to ensure both operations succeed or fail together
    local result = lib.callback.await('rw_buckets:removeMeAndVehFromBucket', false, NetworkGetNetworkIdFromEntity(veh))
    
    if result then
        -- Ensure player stays in vehicle after teleport
        TaskWarpPedIntoVehicle(cache.ped, veh, -1)
        return true
    end
    
    lib.print.error("Failed to remove player and vehicle from bucket")
    return false
end

---Gets information about all active buckets
---@param includeMetadata boolean|nil Whether to include metadata in the result
---@return table buckets Table of active buckets
function bucketAPI.getActiveBuckets(includeMetadata)
    return lib.callback.await('rw_buckets:getActiveBuckets', false, includeMetadata)
end

---Gets information about a specific bucket
---@param bucketKey string The bucket key
---@param includeMetadata boolean|nil Whether to include metadata in the result
---@return table|nil bucket The bucket contents or nil if not found
function bucketAPI.getBucketInfo(bucketKey, includeMetadata)
    if not validateBucketKey(bucketKey) then return nil end
    return lib.callback.await('rw_buckets:getBucketContents', false, bucketKey, includeMetadata)
end

---Toggles bucket UI indicator
---@param show boolean Whether to show or hide the indicator
---@return boolean success
function bucketAPI.toggleIndicator(show)
    showBucketIndicator = show
    config.indicator.show = show
    
    if show then
        bucketAPI.showIndicator(0)
    else
        bucketAPI.hideIndicator()
    end
    
    return true
end

---Toggles bucket transition effects
---@param enable boolean Whether to enable or disable transition effects
---@return boolean success
function bucketAPI.toggleTransitions(enable)
    transitionEffects = enable
    config.transitions.enabled = enable
    return true
end

-- Initialize on resource start
CreateThread(function()
    -- Wait for client to be ready
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    Wait(1000)
    
    -- Get current bucket from server
    currentBucket = lib.callback.await('rw_buckets:getMyBucket', false)
    
    -- Load config from shared config (if it exists)
    if GetResourceState('rw_buckets_config') == 'started' then
        local clientConfig = exports['rw_buckets_config']:getClientConfig()
        if clientConfig then
            bucketAPI.configure(clientConfig)
        end
    end
    
    -- Show indicator if enabled
    if config.indicator.show then
        bucketAPI.showIndicator(config.indicator.fadeTime)
    end
end)

-- Export all API functions
for exportName, exportFunction in pairs(bucketAPI) do
    exports(exportName, exportFunction)
end