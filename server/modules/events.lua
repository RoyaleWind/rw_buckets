local Logger = require("server.logger")

---@class BucketManager.Events
local EventsModule = {}

-- Trigger registered event hooks
function EventsModule.triggerHooks(self, event, ...)
    if not self.eventHooks[event] then
        return
    end
    
    for _, hook in ipairs(self.eventHooks[event]) do
        local success, error = pcall(hook, ...)
        if not success then
            Logger:error("Event hook failed", { event = event, error = error })
        end
    end
end

-- Register an event hook
function EventsModule.registerHook(self, event, callback)
    if not self.eventHooks[event] then
        Logger:warn("Attempted to register hook for unknown event", { event = event })
        return false, 0
    end
    
    if not callback or type(callback) ~= "function" then
        Logger:warn("Invalid callback provided for event hook", { event = event })
        return false, 0
    end
    
    table.insert(self.eventHooks[event], callback)
    local hookId = #self.eventHooks[event]
    
    Logger:debug("Registered event hook", { event = event, id = hookId })
    return true, hookId
end

-- Remove an event hook
function EventsModule.removeHook(self, event, hookId)
    if not self.eventHooks[event] then
        return false
    end
    
    if not hookId or hookId < 1 or hookId > #self.eventHooks[event] then
        return false
    end
    
    table.remove(self.eventHooks[event], hookId)
    Logger:debug("Removed event hook", { event = event, id = hookId })
    return true
end

-- Register a template for bucket creation
function EventsModule.registerTemplate(self, name, settings)
    if not name or type(name) ~= "string" or name == "" then
        Logger:warn("Invalid template name")
        return false
    end
    
    if not settings or type(settings) ~= "table" then
        Logger:warn("Invalid template settings")
        return false
    end
    
    self.templates[name] = settings
    Logger:info("Registered bucket template", { name = name })
    return true
end

return EventsModule
