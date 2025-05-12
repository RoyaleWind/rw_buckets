local Logger = require("server.logger")

---@class Security
---@field rateLimits table<string, table> Cache for rate limiting
---@field permissionCache table<string, table> Cache for permissions
local Security = {
    rateLimits = {},
    permissionCache = {},
    maxRatePerMinute = 30, -- Default rate limit per minute
    permissionGroups = {
        -- Customize or extend these groups as needed
        admin = {"command.rw_buckets.admin"},
        manager = {"command.rw_buckets.manager"},
        user = {"command.rw_buckets.user"}
    }
}

-- Clean up rate limiting data periodically
CreateThread(function()
    while true do
        Wait(60000) -- Clean up every minute
        local now = os.time()
        for source, data in pairs(Security.rateLimits) do
            -- Remove entries older than 5 minutes
            if now - data.timestamp > 300 then
                Security.rateLimits[source] = nil
            end
        end
    end
end)

-- Clean up permission cache on player disconnect
AddEventHandler('playerDropped', function()
    local source = source
    Security.permissionCache[tostring(source)] = nil
end)

---Validates that the input is of the expected type
---@param value any The value to validate
---@param expectedType string The expected type
---@param name string The name of the parameter for error messages
---@return boolean isValid
---@return string|nil errorMessage
function Security.validateType(value, expectedType, name)
    if expectedType == "any" then return true, nil end
    
    if value == nil then
        return false, string.format("Parameter '%s' is required", name)
    end
    
    if expectedType == "number" and tonumber(value) then
        return true, nil
    elseif expectedType == "string" and type(value) == "string" then
        return true, nil
    elseif expectedType == "boolean" and type(value) == "boolean" then
        return true, nil
    elseif expectedType == "table" and type(value) == "table" then
        return true, nil
    elseif expectedType == "function" and type(value) == "function" then
        return true, nil
    elseif expectedType == "playerId" then
        local id = tonumber(value)
        if not id then
            return false, string.format("Parameter '%s' must be a valid player ID", name)
        end
        if not GetPlayerName(id) then
            return false, string.format("Player with ID %s does not exist", id)
        end
        return true, nil
    elseif expectedType == "entityId" then
        local id = tonumber(value)
        if not id then
            return false, string.format("Parameter '%s' must be a valid entity ID", name)
        end
        if not DoesEntityExist(id) then
            return false, string.format("Entity with ID %s does not exist", id)
        end
        return true, nil
    elseif expectedType == "bucketKey" then
        if type(value) ~= "string" then
            return false, string.format("Parameter '%s' must be a string", name)
        end
        if value == "" then
            return false, string.format("Parameter '%s' cannot be empty", name)
        end
        -- Additional validation for bucket keys can be added here
        return true, nil
    elseif type(value) == expectedType then
        return true, nil
    end
    
    return false, string.format("Parameter '%s' must be of type %s, got %s", name, expectedType, type(value))
end

---Validates multiple parameters against expected types
---@param params table The parameters to validate
---@param schema table The schema defining expected types
---@return boolean isValid
---@return string|nil errorMessage
function Security.validateParams(params, schema)
    if not params or not schema then
        return false, "Missing parameters or schema"
    end
    
    for name, expectedType in pairs(schema) do
        local isValid, errorMessage = Security.validateType(params[name], expectedType, name)
        if not isValid then
            return false, errorMessage
        end
    end
    
    return true, nil
end

---Sanitizes a string input
---@param input string The input to sanitize
---@return string sanitized
function Security.sanitizeString(input)
    if type(input) ~= "string" then
        return tostring(input)
    end
    
    -- Replace potentially dangerous characters
    local sanitized = input:gsub("[;'\"]", "")
    
    -- Trim excessive whitespace
    sanitized = sanitized:gsub("%s+", " ")
    sanitized = sanitized:match("^%s*(.-)%s*$")
    
    return sanitized
end

---Checks if a player has a specific permission
---@param playerId number The player ID
---@param permission string The permission to check
---@return boolean hasPermission
function Security.hasPermission(playerId, permission)
    if not playerId or not permission then
        return false
    end
    
    -- Check cache first
    local playerKey = tostring(playerId)
    if Security.permissionCache[playerKey] and Security.permissionCache[playerKey][permission] ~= nil then
        return Security.permissionCache[playerKey][permission]
    end
    
    -- Initialize cache for this player if needed
    if not Security.permissionCache[playerKey] then
        Security.permissionCache[playerKey] = {}
    end
    
    -- Check the actual permission
    local hasPermission = IsPlayerAceAllowed(playerId, permission)
    Security.permissionCache[playerKey][permission] = hasPermission
    
    return hasPermission
end

---Checks if a player has any permission from a list
---@param playerId number The player ID
---@param permissions table<number, string> List of permissions to check
---@return boolean hasAnyPermission
function Security.hasAnyPermission(playerId, permissions)
    if not playerId or not permissions then
        return false
    end
    
    for _, permission in ipairs(permissions) do
        if Security.hasPermission(playerId, permission) then
            return true
        end
    end
    
    return false
end

---Checks if a player belongs to a permission group
---@param playerId number The player ID
---@param group string The group name
---@return boolean isInGroup
function Security.isInGroup(playerId, group)
    if not playerId or not group or not Security.permissionGroups[group] then
        return false
    end
    
    return Security.hasAnyPermission(playerId, Security.permissionGroups[group])
end

---Applies rate limiting to an operation
---@param source number The source (player) performing the operation
---@param operation string Identifier for the operation being limited
---@param limit number|nil Optional custom limit (defaults to maxRatePerMinute)
---@return boolean allowed
---@return number|nil remainingTime Time until next allowed operation
function Security.applyRateLimit(source, operation, limit)
    if not source or source <= 0 then
        return true, nil -- System operations bypass rate limiting
    end
    
    limit = limit or Security.maxRatePerMinute
    local sourceKey = tostring(source)
    local opKey = operation or "default"
    local now = os.time()
    
    -- Initialize rate limit entry if it doesn't exist
    if not Security.rateLimits[sourceKey] then
        Security.rateLimits[sourceKey] = {
            operations = {},
            timestamp = now
        }
    end
    
    if not Security.rateLimits[sourceKey].operations[opKey] then
        Security.rateLimits[sourceKey].operations[opKey] = {
            count = 0,
            lastReset = now
        }
    end
    
    local opData = Security.rateLimits[sourceKey].operations[opKey]
    
    -- Reset counter if a minute has passed
    if now - opData.lastReset >= 60 then
        opData.count = 0
        opData.lastReset = now
    end
    
    -- Check if rate limit exceeded
    if opData.count >= limit then
        local timeRemaining = 60 - (now - opData.lastReset)
        return false, timeRemaining
    end
    
    -- Increment counter
    opData.count = opData.count + 1
    return true, nil
end

---Creates an audit log entry for an operation
---@param source number The source (player) performing the operation
---@param operation string The operation being performed
---@param details table|nil Optional details about the operation
function Security.audit(source, operation, details)
    local playerName = "System"
    local playerIdentifier = "system"
    
    if source and source > 0 then
        playerName = GetPlayerName(source) or "Unknown"
        for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
            if string.find(identifier, "steam:") then
                playerIdentifier = identifier
                break
            end
        end
    end
    
    Logger:info("Audit", {
        operation = operation,
        player = {
            source = source,
            name = playerName,
            identifier = playerIdentifier
        },
        details = details or {},
        timestamp = os.time()
    })
end

---Encrypts a bucket key for sensitive operations
---@param key string The bucket key to encrypt
---@param salt string|nil Optional salt for encryption
---@return string encryptedKey
function Security.encryptBucketKey(key, salt)
    if not key then return "" end
    
    salt = salt or GetConvar("rw_buckets_salt", "default_salt")
    
    -- Simple XOR-based encryption - replace with more secure method if needed
    local result = ""
    local saltLength = string.len(salt)
    
    for i = 1, string.len(key) do
        local keyByte = string.byte(key, i)
        local saltByte = string.byte(salt, (i % saltLength) + 1)
        result = result .. string.char(bit.bxor(keyByte, saltByte))
    end
    
    -- Convert to hex for storage
    local hexResult = ""
    for i = 1, string.len(result) do
        local hex = string.format("%02X", string.byte(result, i))
        hexResult = hexResult .. hex
    end
    
    return hexResult
end

---Decrypts an encrypted bucket key
---@param encryptedKey string The encrypted bucket key
---@param salt string|nil Optional salt for decryption
---@return string originalKey
function Security.decryptBucketKey(encryptedKey, salt)
    if not encryptedKey then return "" end
    
    salt = salt or GetConvar("rw_buckets_salt", "default_salt")
    
    -- Convert from hex
    local hexPattern = "%x%x"
    local result = ""
    
    for hexPair in encryptedKey:gmatch(hexPattern) do
        result = result .. string.char(tonumber(hexPair, 16))
    end
    
    -- Reverse XOR operation
    local originalKey = ""
    local saltLength = string.len(salt)
    
    for i = 1, string.len(result) do
        local resultByte = string.byte(result, i)
        local saltByte = string.byte(salt, (i % saltLength) + 1)
        originalKey = originalKey .. string.char(bit.bxor(resultByte, saltByte))
    end
    
    return originalKey
end

return Security
