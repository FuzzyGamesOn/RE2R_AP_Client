local SaveData = {}

SaveData.isInit = false -- keeps track of whether init things like hook need to run
SaveData.debug = false -- show debug when testing
SaveData.lastSaveTimestamp = nil -- updated by the hooks below
SaveData.lastSyncTimestamp = nil -- updated by the Archipelago.Sync() call in this client mod

function SaveData.Init()
    if not SaveData.isInit then
        SaveData.isInit = true

        SaveData.SetupLoadHook()

        SaveData.SetupAutosaveHook()
        SaveData.SetupAutosaveRogueHook()
        SaveData.SetupSaveHook()
        SaveData.SetupSave2Hook() -- this one seems to get called on autosave triggers
        SaveData.SetupSaveLoadAfterHook()
    end
end

-- ---------------------
-- Load hooks
-- ---------------------

function SaveData.SetupLoadHook() 
    local sdm = sdk.find_type_definition(sdk.game_namespace("gamemastering.SaveDataManager"))
    local autosave_method = sdm:get_method("loadGameSaveData")

    sdk.hook(autosave_method, function(args)
        -- we use IsConnected() instead of .hasConnectedPrior here because you can't sync when you're disconnected (obvs)
        --    also, we check to see if the current connection has received items before; if not, no need to trigger a sync because first connect syncs already
        if not Archipelago.IsConnected() or not Archipelago.hasReceivedItemsBefore then
            return
        end

        if SaveData.debug then log.debug("triggered load hook") end

        Archipelago.waitingForSync = true
    end)
end


-- ---------------------
-- Autosave / Save hooks
-- ---------------------

function SaveData.SetupAutosaveHook()
    local sdm = sdk.find_type_definition(sdk.game_namespace("gamemastering.SaveDataManager"))
    local autosave_method = sdm:get_method("requestSaveGameDataAuto")

    sdk.hook(autosave_method, function(args)
        if not Archipelago.hasConnectedPrior then
            return
        end

        if SaveData.debug then log.debug("triggered autosave hook") end

        Storage.UpdateLastSavedItems()
        SaveData.lastSaveTimestamp = os.time()
    end)
end

function SaveData.SetupAutosaveRogueHook()
    local sdm = sdk.find_type_definition(sdk.game_namespace("gamemastering.SaveDataManager"))
    local autosave_method = sdm:get_method("requestSaveGameDataRogueAuto")

    sdk.hook(autosave_method, function(args)
        if not Archipelago.hasConnectedPrior then
            return
        end

        if SaveData.debug then log.debug("triggered autosave rogue hook") end

        Storage.UpdateLastSavedItems()
        SaveData.lastSaveTimestamp = os.time()
    end)
end

function SaveData.SetupSaveHook()
    local sdm = sdk.find_type_definition(sdk.game_namespace("gamemastering.SaveDataManager"))
    local autosave_method = sdm:get_method("requestSaveGameData")

    sdk.hook(autosave_method, function(args)
        if not Archipelago.hasConnectedPrior then
            return
        end

        if SaveData.debug then log.debug("triggered manual save hook") end

        Storage.UpdateLastSavedItems()
        SaveData.lastSaveTimestamp = os.time()
    end)
end

function SaveData.SetupSave2Hook()
    local sdm = sdk.find_type_definition(sdk.game_namespace("gamemastering.SaveDataManager"))
    local autosave_method = sdm:get_method("saveGameSaveData")

    sdk.hook(autosave_method, function(args)
        -- we use .hasConnectedPrior instead of .IsConnected() because we want to keep up with the in-game saves
        --    even if the player has somehow disconnected from AP in the meantime
        --    to prevent duplicating the items that they had already received on continue
        if not Archipelago.hasConnectedPrior then
            return
        end

        if SaveData.debug then log.debug("triggered manual save 2 hook") end

        Storage.UpdateLastSavedItems()
        SaveData.lastSaveTimestamp = os.time()
    end)
end

function SaveData.SetupSaveLoadAfterHook()
    local sdm = sdk.find_type_definition(sdk.game_namespace("gamemastering.SaveDataManager"))
    local autosave_method = sdm:get_method("set_IsLoadAfterTime")

    sdk.hook(autosave_method, function(args)
        if not Archipelago.hasConnectedPrior then
            return
        end

        if SaveData.debug then log.debug("triggered save load after hook") end

        Storage.UpdateLastSavedItems()
        SaveData.lastSaveTimestamp = os.time()
    end)
end


-- Don't have a use for this yet, but seemed handy to have, so throwing this here for now.

function SaveData.RequestAutoSave()
    local sdm = Scene.getSaveDataManager()

    sdm:call("requestSaveGameDataAuto")
end

function SaveData.RequestSaveToSlot(slot_id)
    -- slot ids start counting at 1 on the load screen, not counting auto-saves
    -- SaveMode 1 is "SCENARIO"
    local sdm = Scene.getSaveDataManager()

    sdm:call("requestSaveGameData(" .. sdk.game_namespace("gamemastering.SaveDataManager.SaveMode") .. ", System.Int32)", 1, slot_id)
end

return SaveData
