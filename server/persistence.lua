local Logger = require("server.logger")
local Security = require("server.security")

---@class Persistence
---@field saveInterval number How often to save data (in seconds)
---@field saveOnUpdate boolean Whether to save on every update
---@field storage string Storage type ('file', 'database', or 'memory')
---@field backupCount number Number of backups to keep
---@field stateVersion number Current state version for migrations
local Persistence = {
    saveInterval = 300, -- 5 minutes
    saveOnUpdate = false,
    storage = "file",
    backupCount = 5,
    stateVersion = 1,
    isLoaded = false,
    lastSaveTime = 0,
    pendingChanges = false
}

-- File paths
local DATA_DIR = "data"
local STATE_FILE = DATA_DIR .. "/bucket_state.json"
local BACKUP_DIR = DATA_DIR .. "/backups"

-- Ensure data directories exist
CreateThread(function()
    -- Create data directory if it doesn't exist
    if not LoadResourceFile(GetCurrentResourceName(), DATA_DIR) then
        SaveResourceFile(GetCurrentResourceName(), DATA_DIR .. "/.placeholder", "", -1)
    end
    
    -- Create backups directory if it doesn't exist
    if not LoadResourceFile(GetCurrentResourceName(), BACKUP_DIR) then
        SaveResourceFile(GetCurrentResourceName(), BACKUP_DIR .. "/.placeholder", "", -1)
    end
end)

---Configure persistence settings
---@param config table Configuration options
function Persistence.configure(config)
    if config.saveInterval and type(config.saveInterval) == "number" then
        Persistence.saveInterval = config.saveInterval
    end
    
    if config.saveOnUpdate ~= nil then
        Persistence.saveOnUpdate = config.saveOnUpdate
    end
    
    if config.storage then
        Persistence.storage = config.storage
    end
    
    if config.backupCount and type(config.backupCount) == "number" then
        Persistence.backupCount = config.backupCount
    end
    
    Logger:info("Persistence configured", {
        saveInterval = Persistence.saveInterval,
        saveOnUpdate = Persistence.saveOnUpdate,
        storage = Persistence.storage,
        backupCount = Persistence.backupCount
    })
end

---Creates a backup of the current state
---@return boolean success
function Persistence.createBackup()
    -- Only create backup if we have state data
    if not Persistence.isLoaded then
        return false
    end
    
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local backupFile = BACKUP_DIR .. "/bucket_state_" .. timestamp .. ".json"
    
    -- Copy current state to backup
    local currentState = LoadResourceFile(GetCurrentResourceName(), STATE_FILE)
    if not currentState then
        Logger:error("Failed to create backup: No current state file")
        return false
    end
    
    -- Save backup
    if SaveResourceFile(GetCurrentResourceName(), backupFile, currentState, -1) then
        Logger:info("Created backup", { file = backupFile })
        
        -- Clean up old backups if we have too many
        Persistence.cleanupOldBackups()
        return true
    else
        Logger:error("Failed to create backup", { file = backupFile })
        return false
    end
end

---Cleans up old backups keeping only the most recent ones
function Persistence.cleanupOldBackups()
    local backups = {}
    local resourceFiles = GetResourceMetadata(GetCurrentResourceName(), 'files') or {}
    
    -- Find all backup files
    for i=1, #resourceFiles do
        local file = resourceFiles[i]
        if string.find(file, "^" .. BACKUP_DIR .. "/bucket_state_") then
            table.insert(backups, file)
        end
    end
    
    -- Sort by filename (which includes timestamp)
    table.sort(backups)
    
    -- Delete oldest backups if we have more than the limit
    while #backups > Persistence.backupCount do
        local oldestBackup = table.remove(backups, 1)
        SaveResourceFile(GetCurrentResourceName(), oldestBackup, "", -1) -- Empty file to delete it
        Logger:debug("Deleted old backup", { file = oldestBackup })
    end
end

---Loads state from storage
---@return table state The loaded state or empty table if none exists
function Persistence.loadState()
    local state = {}
    
    if Persistence.storage == "file" then
        -- Load from file
        local stateJson = LoadResourceFile(GetCurrentResourceName(), STATE_FILE)
        if stateJson and stateJson ~= "" then
            state = json.decode(stateJson) or {}
            
            -- Check version for migrations
            if state.version ~= Persistence.stateVersion then
                state = Persistence.migrateState(state)
            end
            
            Logger:info("Loaded state from file", { 
                buckets = state.buckets and #(table.keys(state.buckets)) or 0
            })
        else
            Logger:info("No saved state found, starting fresh")
            state = { version = Persistence.stateVersion, buckets = {}, keyToId = {}, nextBucketId = 1 }
        end
    elseif Persistence.storage == "database" then
        -- Database implementation would go here
        Logger:warn("Database storage not yet implemented, using in-memory storage")
        state = { version = Persistence.stateVersion, buckets = {}, keyToId = {}, nextBucketId = 1 }
    else
        -- Memory-only storage
        Logger:info("Using in-memory storage (no persistence)")
        state = { version = Persistence.stateVersion, buckets = {}, keyToId = {}, nextBucketId = 1 }
    end
    
    Persistence.isLoaded = true
    Persistence.lastSaveTime = os.time()
    Persistence.pendingChanges = false
    
    return state
end

---Saves state to storage
---@param state table The state to save
---@return boolean success
function Persistence.saveState(state)
    if not state then
        Logger:error("Cannot save nil state")
        return false
    end
    
    -- Add version to state
    state.version = Persistence.stateVersion
    
    -- Add save timestamp
    state.savedAt = os.time()
    
    if Persistence.storage == "file" then
        -- Save to file
        local stateJson = json.encode(state)
        if SaveResourceFile(GetCurrentResourceName(), STATE_FILE, stateJson, -1) then
            Logger:info("Saved state to file", { 
                buckets = state.buckets and #(table.keys(state.buckets)) or 0
            })
            Persistence.lastSaveTime = os.time()
            Persistence.pendingChanges = false
            return true
        else
            Logger:error("Failed to save state to file")
            return false
        end
    elseif Persistence.storage == "database" then
        -- Database implementation would go here
        Logger:warn("Database storage not yet implemented, state not saved")
        return false
    else
        -- Memory-only storage
        Logger:debug("In-memory storage, state not persisted")
        Persistence.lastSaveTime = os.time()
        Persistence.pendingChanges = false
        return true
    end
end

---Marks that changes were made that need to be saved
function Persistence.markChanged()
    Persistence.pendingChanges = true
end

---Migrates state from old version to current version
---@param oldState table The old state
---@return table newState The migrated state
function Persistence.migrateState(oldState)
    Logger:info("Migrating state", { fromVersion = oldState.version or "unknown", toVersion = Persistence.stateVersion })
    
    -- Initialize new state with current version
    local newState = { 
        version = Persistence.stateVersion,
        buckets = oldState.buckets or {},
        keyToId = oldState.keyToId or {},
        nextBucketId = oldState.nextBucketId or 1
    }
    
    -- Apply migrations based on version
    local oldVersion = oldState.version or 0
    
    if oldVersion < 1 then
        -- Migration to version 1: Add metadata to buckets
        for id, bucket in pairs(newState.buckets) do
            if not bucket.metadata then
                bucket.metadata = {
                    created = os.time(),
                    lastModified = os.time(),
                    creator = "system",
                    description = ""
                }
            end
        end
    end
    
    -- Additional migrations would go here
    
    Logger:info("State migration complete")
    return newState
end

---Restores state from a backup
---@param backupId string|nil Specific backup ID or nil for most recent
---@return boolean success
---@return table|nil state The restored state if successful
function Persistence.restoreFromBackup(backupId)
    local backups = {}
    local resourceFiles = GetResourceMetadata(GetCurrentResourceName(), 'files') or {}
    
    -- Find all backup files
    for i=1, #resourceFiles do
        local file = resourceFiles[i]
        if string.find(file, "^" .. BACKUP_DIR .. "/bucket_state_") then
            table.insert(backups, file)
        end
    end
    
    if #backups == 0 then
        Logger:error("No backups found to restore from")
        return false, nil
    end
    
    -- Sort by filename (which includes timestamp)
    table.sort(backups)
    
    -- Determine which backup to use
    local backupFile
    if backupId then
        -- Find specific backup
        for _, file in ipairs(backups) do
            if string.find(file, backupId) then
                backupFile = file
                break
            end
        end
        
        if not backupFile then
            Logger:error("Specified backup not found", { backupId = backupId })
            return false, nil
        end
    else
        -- Use most recent backup
        backupFile = backups[#backups]
    end
    
    -- Load backup
    local backupJson = LoadResourceFile(GetCurrentResourceName(), backupFile)
    if not backupJson or backupJson == "" then
        Logger:error("Failed to load backup file", { file = backupFile })
        return false, nil
    end
    
    local state = json.decode(backupJson)
    if not state then
        Logger:error("Failed to parse backup file", { file = backupFile })
        return false, nil
    end
    
    -- Check version for migrations
    if state.version ~= Persistence.stateVersion then
        state = Persistence.migrateState(state)
    end
    
    -- Create backup of current state before restoring
    Persistence.createBackup()
    
    -- Save restored state as current
    if Persistence.saveState(state) then
        Logger:info("Successfully restored from backup", { file = backupFile })
        return true, state
    else
        Logger:error("Failed to save restored state", { file = backupFile })
        return false, nil
    end
end

-- Automatic saving thread
CreateThread(function()
    while true do
        Wait(1000) -- Check every second
        
        if Persistence.isLoaded and 
           (Persistence.pendingChanges and os.time() - Persistence.lastSaveTime >= Persistence.saveInterval) then
            -- Get current state from bucket manager
            local bucketManager = require("server.BucketManager")
            local state = bucketManager:getState()
            
            -- Save state
            Persistence.saveState(state)
            
            -- Create periodic backup
            if os.time() - Persistence.lastSaveTime >= Persistence.saveInterval * 4 then
                Persistence.createBackup()
            end
        end
    end
end)

-- Helper: Get table keys count (Lua 5.1 compatibility)
if not table.keys then
    function table.keys(tbl)
        local keys = {}
        for k, _ in pairs(tbl) do
            table.insert(keys, k)
        end
        return keys
    end
end

return Persistence
