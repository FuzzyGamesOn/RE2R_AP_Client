local CutsceneObjects = {}
CutsceneObjects.isInit = false
CutsceneObjects.lastStop = os.time()

function CutsceneObjects.Init()
    if Archipelago.IsConnected() and not CutsceneObjects.isInit then
        CutsceneObjects.isInit = true
        CutsceneObjects.DispersalCartridge()
    end

    -- if the last check for cutscene objects was X time ago or more, trigger another removal
    if os.time() - CutsceneObjects.lastStop > 15 then -- 15 seconds
        CutsceneObjects.isInit = false
    end
end

function CutsceneObjects.DispersalCartridge()
    local dispersalObject = Scene.getSceneObject():findGameObject("sm42_222_SprayingMachine01A_control")
    if not dispersalObject then
        return
    end
    local dispersalComponent = Helpers.component(dispersalObject, "gimmick.option.AddItemToInventorySettings")
    dispersalComponent:set_field("Enable", false)
end

return CutsceneObjects
