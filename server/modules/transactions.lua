local Logger = require("server.logger")

---@class BucketManager.Transactions
local TransactionModule = {}

-- Generate a unique transaction ID
function TransactionModule.generateTransactionId(self)
    local id = "txn_" .. os.time() .. "_" .. math.random(100000, 999999)
    return id
end

-- Begin a new transaction
function TransactionModule.beginTransaction(self, source)
    if self.activeTransactionId then
        Logger:warn("Attempted to begin transaction while another is active", {
            activeId = self.activeTransactionId
        })
        return nil
    end
    
    local transactionId = self:generateTransactionId()
    self.transactions[transactionId] = {
        id = transactionId,
        operations = {},
        status = "active",
        startTime = os.time(),
        source = source or 0
    }
    
    self.activeTransactionId = transactionId
    Logger:debug("Transaction begun", { id = transactionId, source = source })
    
    return transactionId
end

-- Add an operation to the current transaction
function TransactionModule.addToTransaction(self, opType, targetType, data, rollbackFn)
    if not self.activeTransactionId then
        Logger:warn("Attempted to add operation with no active transaction")
        return false
    end
    
    local transaction = self.transactions[self.activeTransactionId]
    if not transaction then
        Logger:error("Active transaction not found", { id = self.activeTransactionId })
        self.activeTransactionId = nil
        return false
    end
    
    table.insert(transaction.operations, {
        type = opType,
        target = targetType,
        data = data,
        rollback = rollbackFn
    })
    
    return true
end

-- Commit the current transaction
function TransactionModule.commitTransaction(self)
    if not self.activeTransactionId then
        Logger:warn("Attempted to commit with no active transaction")
        return false
    end
    
    local transaction = self.transactions[self.activeTransactionId]
    if not transaction then
        Logger:error("Active transaction not found", { id = self.activeTransactionId })
        self.activeTransactionId = nil
        return false
    end
    
    transaction.status = "committed"
    local id = self.activeTransactionId
    self.activeTransactionId = nil
    
    Logger:debug("Transaction committed", { 
        id = id, 
        operations = #transaction.operations,
        elapsed = os.time() - transaction.startTime
    })
    
    -- Mark that we have changes to persist
    local Persistence = require("server.persistence")
    Persistence.markChanged()
    
    -- If we're saving on each update, save now
    if Persistence.saveOnUpdate then
        Persistence.saveState(self:getState())
    end
    
    return true
end

-- Rollback the current transaction
function TransactionModule.rollbackTransaction(self)
    if not self.activeTransactionId then
        Logger:warn("Attempted to rollback with no active transaction")
        return false
    end
    
    local transaction = self.transactions[self.activeTransactionId]
    if not transaction then
        Logger:error("Active transaction not found", { id = self.activeTransactionId })
        self.activeTransactionId = nil
        return false
    end
    
    -- Rollback operations in reverse order
    for i = #transaction.operations, 1, -1 do
        local op = transaction.operations[i]
        if op.rollback and type(op.rollback) == "function" then
            local success, error = pcall(op.rollback)
            if not success then
                Logger:error("Rollback failed for operation", {
                    operation = op.type,
                    target = op.target,
                    error = error
                })
            end
        end
    end
    
    transaction.status = "rolled_back"
    local id = self.activeTransactionId
    self.activeTransactionId = nil
    
    Logger:info("Transaction rolled back", { 
        id = id, 
        operations = #transaction.operations,
        elapsed = os.time() - transaction.startTime
    })
    
    return true
end

-- Execute a function within a transaction
function TransactionModule.withTransaction(self, fn, source)
    if not fn or type(fn) ~= "function" then
        return false, nil
    end
    
    local txnId = self:beginTransaction(source)
    if not txnId then
        return false, nil
    end
    
    local success, result = pcall(fn)
    
    if success then
        if self:commitTransaction() then
            return true, result
        else
            return false, nil
        end
    else
        self:rollbackTransaction()
        Logger:error("Transaction function failed", { error = result })
        return false, nil
    end
end

return TransactionModule
