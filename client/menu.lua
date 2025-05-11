local cfg = require("data.cfg")
if not cfg.useDataTables then return end

-- Helper function for notifications
local function notify(title, description, type)
    if cfg.useNotifications then
        lib.notify({ title = title, description = description, type = type })
    end
    
    if cfg.debug then
        print(string.format('[rw_buckets] %s: %s', title, description))
    end
end
function OpenMenuContents(key)
    if not key or type(key) ~= "string" or key == "" then
        notify('Error', 'Invalid bucket key', 'error')
        return
    end
    
    local bucket = lib.callback.await('rw_buckets:getBucketContents', false, key)
    if not bucket then
        notify('Error', 'Failed to fetch bucket data', 'error')
        return
    end

    local b_list = {}
    local playerCount = 0
    local entityCount = 0
    
    -- Add players to the list
    for k, v in pairs(bucket.players) do
        playerCount = playerCount + 1
        local playerName = GetPlayerName(k) or "Unknown"
        local row = {
            tostring("Player"),
            tostring(k),
            playerName
        }
        table.insert(b_list, row)
    end
    
    -- Add entities to the list
    for k, v in pairs(bucket.entities) do
        entityCount = entityCount + 1
        local row = {
            tostring("Entity"),
            tostring(k),
            "--"
        }
        table.insert(b_list, row)
    end

    exports.ip_datatables:open({
        id = "BucketContents: " .. (bucket.key or "-"),
        head = {
            "Type",
            "Id",
            "Name/Info"
        },
        list = b_list,
        footer = {
            "Total: " .. #b_list .. " items " .. 
            "(" .. playerCount .. " players, " .. entityCount .. " entities)"
        },
        actions = {
            ["reset"] = function(_, data)
                if not data or not data[1] or not data[2] then
                    lib.notify({ title = 'Error', description = 'Invalid selection', type = 'error' })
                    return
                end
                
                local success = false
                if data[1] == "Player" then
                    success = lib.callback.await('rw_buckets:removePlayerFromBucket', false, data[2])
                    if success then
                        notify('Success', 'Player removed from bucket', 'success')
                    else
                        notify('Error', 'Failed to remove player from bucket', 'error')
                    end
                else
                    success = lib.callback.await('rw_buckets:removeEntityFromBucket', false, data[2])
                    if success then
                        notify('Success', 'Entity removed from bucket', 'success')
                    else
                        notify('Error', 'Failed to remove entity from bucket', 'error')
                    end
                end
                if success then
                    OpenMenuContents(key)
                end
            end,
        }
    })
end

function OpenMenu()
    local buckets = lib.callback.await('rw_buckets:getActiveBuckets', false)
    if not buckets then
        notify('Error', 'Failed to fetch buckets', 'error')
        return
    end
    
    if next(buckets) == nil then
        notify('Info', 'No active buckets found', 'info')
    end

    local b_list = {}
    for k, v in pairs(buckets) do
        if v and v.id and v.key then
            local playerCount = 0
            local entityCount = 0
            
            -- Count players and entities in this bucket
            local contents = lib.callback.await('rw_buckets:getBucketContents', false, v.key)
            if contents then
                for _ in pairs(contents.players) do playerCount = playerCount + 1 end
                for _ in pairs(contents.entities) do entityCount = entityCount + 1 end
            end
            
            local row = {
                tostring(v.id),
                tostring(v.key),
                tostring(playerCount),
                tostring(entityCount)
            }
            table.insert(b_list, row)
        end
    end


    exports.ip_datatables:open({
        id = "ActiveBuckets",
        head = {
            "Bucket Id",
            "Bucket Key",
            "Players",
            "Entities"
        },
        list = b_list,
        footer = { "Total buckets: " .. #b_list },
        actions = {
            ["contents"] = function(_, data)
                if not data or not data[2] then
                    lib.notify({ title = 'Error', description = 'Invalid selection', type = 'error' })
                    return
                end
                OpenMenuContents(data[2])
            end,
            ["kill"] = function(_, data)
                if not data or not data[2] then
                    lib.notify({ title = 'Error', description = 'Invalid selection', type = 'error' })
                    return
                end
                
                local alert = lib.alertDialog({
                    header = 'Confirm Bucket Deletion',
                    content = 'Are you sure you want to delete bucket "' .. data[2] .. '"?\nThis action cannot be undone and will remove all players and entities from this bucket.',
                    centered = true,
                    cancel = true
                })
                
                if not alert then return end
                if alert == 'confirm' then
                    local success = lib.callback.await('rw_buckets:kill', false, data[2])
                    if not success then
                        notify('Error', 'Failed to delete bucket', 'error')
                        return 
                    end
                    notify('Success', 'Bucket "' .. data[2] .. '" has been deleted', 'success')
                    OpenMenu()
                end
            end,
        }
    })
end

local cooldown = 0
RegisterCommand("buckets", function()
    if GetGameTimer() - cooldown < cfg.commandCooldown then 
        notify('Command Cooldown', 'Please wait before using this command again', 'warning')
        return 
    end
    cooldown = GetGameTimer()
    OpenMenu()
end, false)
