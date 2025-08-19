local cfg = require("data.cfg")
local isRedM = (GetConvar('IsRedM', 'false') == 'true')
local exp = exports.rw_datatables 
if not cfg.useDataTables then return end

function OpenMenuContents(key)
    local bucket = lib.callback.await('rw_buckets:getBucketContents', false, key)
    if not bucket then return end

    local b_list = {}
    for k, v in pairs(bucket.players) do
        local row = {
            tostring("Player"),
            tostring(k),
        }
        table.insert(b_list, row)
    end
    for k, v in pairs(bucket.entities) do
        local row = {
            tostring("Entity"),
            tostring(k)
        }
        table.insert(b_list, row)
    end

    exp:open({
        id = "BucketContents: " .. (bucket.key or "-"),
        head = {
            "Type",
            "Id"
        },
        list = b_list,
        actions = {
            ["reset"] = function(_, data)
                if data[1] == "Player" then
                    local sucees = lib.callback.await('rw_buckets:removePlayerFromBucket', false, data[2])
                else
                    local sucees = lib.callback.await('rw_buckets:removeEntityFromBucket', false, data[2])
                end
                OpenMenuContents(key)
            end,
        }
    })
end

function OpenMenu()
    local buckets = lib.callback.await('rw_buckets:getActiveBuckets', false)
    if not buckets then return end

    local b_list = {}
    for k, v in pairs(buckets) do
        local row = {
            tostring(v.id),
            tostring(v.key)
        }
        table.insert(b_list, row)
    end


    exp:open({
        id = "ActiveBuckets",
        head = {
            "Bucket Id",
            "Bucket Key"
        },
        list = b_list,
        actions = {
            ["contents"] = function(_, data)
                OpenMenuContents(data[2])
            end,
            ["kill"] = function(_, data)
                local alert = lib.alertDialog({
                    header = 'Are You Sure',
                    content = 'This is not reversable',
                    centered = true,
                    cancel = true
                })
                if not alert then return end
                if alert == 'confirm' then
                    local sucees = lib.callback.await('rw_buckets:kill', false, data[2])
                    if not sucees then return end
                    OpenMenu()
                end
            end,
        }
    })
end

RegisterNetEvent("rw_buckets:OpenMenu")
AddEventHandler("rw_buckets:OpenMenu", function ()
    print("open")
    OpenMenu()
end)
