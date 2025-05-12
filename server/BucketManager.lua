local Logger = require("server.logger")
local Security = require("server.security")
local Persistence = require("server.persistence")
local Helper = require("server.helper")

-- Load modules
local Core = require("server.modules.core")
local Transactions = require("server.modules.transactions")
local Events = require("server.modules.events")
local Entities = require("server.modules.entities")
local Buckets = require("server.modules.buckets")

---@class BucketManager
local BucketManager = {
    buckets = {}, keyToId = {}, reusableIds = {}, nextBucketId = 1,
    transactions = {}, activeTransactionId = nil, templates = {},
    eventHooks = { onBucketCreate = {}, onBucketDelete = {}, onPlayerBucketChange = {},
                   onEntityBucketChange = {}, onBucketMerge = {}, onBucketMetadataChange = {} },
    initialized = false
}

-- Import module functions
-- Core
BucketManager.initialize = Core.initialize
BucketManager.verifyDataIntegrity = Core.verifyDataIntegrity
BucketManager.cleanupDeadEntities = Core.cleanupDeadEntities
BucketManager.handlePlayerDisconnect = Core.handlePlayerDisconnect
BucketManager.getState = Core.getState
BucketManager.garbageCollector = Core.garbageCollector

-- Transactions
BucketManager.generateTransactionId = Transactions.generateTransactionId
BucketManager.beginTransaction = Transactions.beginTransaction
BucketManager.addToTransaction = Transactions.addToTransaction
BucketManager.commitTransaction = Transactions.commitTransaction
BucketManager.rollbackTransaction = Transactions.rollbackTransaction
BucketManager.withTransaction = Transactions.withTransaction

-- Events
BucketManager.triggerHooks = Events.triggerHooks
BucketManager.registerHook = Events.registerHook
BucketManager.removeHook = Events.removeHook
BucketManager.registerTemplate = Events.registerTemplate

-- Entities
BucketManager.setPlayerBucket = Entities.setPlayerBucket
BucketManager.removePlayerFromBucket = Entities.removePlayerFromBucket
BucketManager.setEntityBucket = Entities.setEntityBucket
BucketManager.removeEntityFromBucket = Entities.removeEntityFromBucket

-- Buckets
BucketManager.createBucket = Buckets.createBucket
BucketManager.getBucketId = Buckets.getBucketId
BucketManager.getPlayerBucketKey = Buckets.getPlayerBucketKey
BucketManager.getEntityBucketKey = Buckets.getEntityBucketKey
BucketManager.getBucketContents = Buckets.getBucketContents
BucketManager.getActiveBucketKeys = Buckets.getActiveBucketKeys
BucketManager.killBucket = Buckets.killBucket
BucketManager.createBucketFromTemplate = Buckets.createBucketFromTemplate
BucketManager.mergeBuckets = Buckets.mergeBuckets
BucketManager.updateBucketMetadata = Buckets.updateBucketMetadata

-- Export the BucketManager
return BucketManager
