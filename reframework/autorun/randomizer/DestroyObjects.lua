local DestroyObjects = {}
DestroyObjects.isInit = false
DestroyObjects.lastRemoval = os.time()

function DestroyObjects.Init()
    if Archipelago.IsConnected() and not DestroyObjects.isInit then
        DestroyObjects.isInit = true
        DestroyObjects.DestroyAll()
    end

    -- if the last check for objects to remove was X time ago or more, trigger another removal
    if os.time() - DestroyObjects.lastRemoval > 15 then -- 15 seconds
        DestroyObjects.lastRemoval = os.time()
        DestroyObjects.isInit = false
    end
end

function DestroyObjects.DestroyAll()
    local destroyables = {
        DestroyObjects.GetPurposeGUI(),
        DestroyObjects.GetAdasSecretWeaponLadder(),
        DestroyObjects.GetSherrysKey(),
        DestroyObjects.GetSecretRoomTBarPipe()
    }

    -- if we talked to Marvin, remove the shutter and the panel interact that lets you put a fuse in it to open the shutter
    if Storage.talkedToMarvin then
        -- if hardcore, leave the shutter because new players keep softlocking themselves by skipping marvin's cutscene after dying
        if Lookups.difficulty ~= nil and string.lower(Lookups.difficulty) ~= "hardcore" then 
            table.insert(destroyables, DestroyObjects.GetMainHallShutter())
        end
        
        table.insert(destroyables, DestroyObjects.GetMainHallShutterFusePanel())
    end

    -- if we opened the Chief door with Heart Key as Claire, remove the East Hallway 2F shutter
    if Storage.openedChiefDoor then
        table.insert(destroyables, DestroyObjects.GetEastHallway2FShutter())
    end

    for k, obj in pairs(destroyables) do
        if obj ~= nil then
            obj:call("destroy", obj)
        end        
    end
end

function DestroyObjects.GetPurposeGUI()
    return Scene.getSceneObject():findGameObject("GUI_Purpose")
end

function DestroyObjects.GetAdasSecretWeaponLadder()
    return Scene.getSceneObject():findGameObject("ADA_PlayCF535_00_HoldHackingGun")
end

function DestroyObjects.GetSherrysKey()
    return Scene.getSceneObject():findGameObject("OrphanAsylum_PlayEvent_CF360")
end

function DestroyObjects.GetMainHallShutter()
    return Scene.getSceneObject():findGameObject("sm60_033_PipeShutter01A_gimmick")
end

function DestroyObjects.GetMainHallShutterFusePanel()
    return Scene.getSceneObject():findGameObject("sm42_167_FuseBox01A_control")
end

function DestroyObjects.GetEastHallway2FShutter()
    return Scene.getSceneObject():findGameObject("sm42_003_FireShutter01A_gimmick")
end

function DestroyObjects.GetSecretRoomTBarPipe()
    return Scene.getSceneObject():findGameObject("sm41_028_THandleHole02A_underMegami_gimmick")
end

return DestroyObjects
