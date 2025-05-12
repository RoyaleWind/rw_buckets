---@class Logger
---@field level string The minimum log level to display
---@field logToFile boolean Whether to log to file
---@field logPath string The path to the log file
local Logger = {
    level = "info",
    logToFile = true,
    logPath = "logs/buckets.log",
    levels = {
        debug = 1,
        info = 2,
        warn = 3,
        error = 4,
        fatal = 5
    }
}

-- Initialize logs directory
CreateThread(function()
    if Logger.logToFile then
        -- Ensure logs directory exists
        local logsDir = "logs"
        if not LoadResourceFile(GetCurrentResourceName(), logsDir) then
            SaveResourceFile(GetCurrentResourceName(), logsDir .. "/.placeholder", "", -1)
        end
        
        -- Timestamp for log rotation
        local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
        Logger.logPath = "logs/buckets_" .. timestamp .. ".log"
        
        -- Initialize log file with header
        SaveResourceFile(GetCurrentResourceName(), Logger.logPath, "=== RW BUCKETS LOG STARTED AT " .. timestamp .. " ===\n", -1)
    end
end)

---Format a log message with timestamp and metadata
---@param level string The log level
---@param message string The message to log
---@param metadata table|nil Optional metadata to include
---@return string formatted
function Logger:formatMessage(level, message, metadata)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local formatted = string.format("[%s] [%s] %s", timestamp, level:upper(), message)
    
    if metadata then
        local metaString = "{"
        for k, v in pairs(metadata) do
            if type(v) == "table" then
                metaString = metaString .. k .. ":" .. json.encode(v) .. ", "
            else
                metaString = metaString .. k .. ":" .. tostring(v) .. ", "
            end
        end
        metaString = metaString:sub(1, -3) .. "}" -- Remove trailing comma and space
        formatted = formatted .. " " .. metaString
    end
    
    return formatted
end

---Write a log message to file and console
---@param level string The log level
---@param message string The message to log
---@param metadata table|nil Optional metadata to include
function Logger:log(level, message, metadata)
    if not self.levels[level] or self.levels[level] < self.levels[self.level] then
        return
    end
    
    local formatted = self:formatMessage(level, message, metadata)
    
    -- Console output with color
    local colors = {
        debug = "^5", -- Blue
        info = "^7",  -- White
        warn = "^3",  -- Yellow
        error = "^1", -- Red
        fatal = "^1"  -- Red
    }
    
    print(colors[level] .. formatted .. "^7") -- Reset color at end
    
    -- File output
    if self.logToFile then
        local fileContent = LoadResourceFile(GetCurrentResourceName(), self.logPath) or ""
        fileContent = fileContent .. formatted .. "\n"
        SaveResourceFile(GetCurrentResourceName(), self.logPath, fileContent, -1)
    end
end

---Debug level log
---@param message string The message to log
---@param metadata table|nil Optional metadata to include
function Logger:debug(message, metadata)
    self:log("debug", message, metadata)
end

---Info level log
---@param message string The message to log
---@param metadata table|nil Optional metadata to include
function Logger:info(message, metadata)
    self:log("info", message, metadata)
end

---Warn level log
---@param message string The message to log
---@param metadata table|nil Optional metadata to include
function Logger:warn(message, metadata)
    self:log("warn", message, metadata)
end

---Error level log
---@param message string The message to log
---@param metadata table|nil Optional metadata to include
function Logger:error(message, metadata)
    self:log("error", message, metadata)
end

---Fatal level log
---@param message string The message to log
---@param metadata table|nil Optional metadata to include
function Logger:fatal(message, metadata)
    self:log("fatal", message, metadata)
end

---Configure the logger
---@param config table Configuration parameters
function Logger:configure(config)
    if config.level and self.levels[config.level] then
        self.level = config.level
    end
    
    if config.logToFile ~= nil then
        self.logToFile = config.logToFile
    end
    
    if config.logPath then
        self.logPath = config.logPath
    end
end

-- Limit log file size by rotating logs
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        if Logger.logToFile then
            local fileContent = LoadResourceFile(GetCurrentResourceName(), Logger.logPath) or ""
            -- If file exceeds 5MB, create a new log file
            if #fileContent > 5000000 then
                local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
                Logger.logPath = "logs/buckets_" .. timestamp .. ".log"
                SaveResourceFile(GetCurrentResourceName(), Logger.logPath, "=== RW BUCKETS LOG CONTINUED AT " .. timestamp .. " ===\n", -1)
                Logger:info("Log file rotated due to size limit")
            end
        end
    end
end)

return Logger
