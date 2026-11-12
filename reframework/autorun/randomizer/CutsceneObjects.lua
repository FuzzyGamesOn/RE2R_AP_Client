local CutsceneObjects = {}
CutsceneObjects.isInit = false
CutsceneObjects.lastStop = os.time()

function CutsceneObjects.Init()
    if Archipelago.IsConnected() and not CutsceneObjects.isInit then
        CutsceneObjects.isInit = true
        CutsceneObjects.DispersalCartridge()

        if Storage.finishedG1 then
            CutsceneObjects.ReturnToSecretRoom()  
        end
    end

    -- if the last check for cutscene objects was X time ago or more, trigger another removal
    if os.time() - CutsceneObjects.lastStop > 15 then -- 15 seconds
        CutsceneObjects.lastStop = os.time()
        CutsceneObjects.isInit = false
    end
end

function CutsceneObjects.ReturnToSecretRoom()
    -- Claire's portion of this was in progress, and does not currently work.
    -- Need to revisit once Secret Room return is re-enabled for future randomization of typewriters.

    local isClaire = (string.lower(Lookups.character) == "claire")

    -- Leon's bridge parts
    local brokenBridge = Helpers.gameObject("sm60_040_BreakFloor01A_00")
    local brokenBridgeBlocker = Helpers.gameObject("sm60_040_BreakFloor01A_01")

    -- Claire's bridge parts
    if isClaire then
        brokenBridge = Helpers.gameObject("sm60_080_KlareBreakFloor01A_00")
        brokenBridgeBlocker = Helpers.gameObject("sm60_080_KlareBreakFloor01A_01")
    end

    local goddessStatueBase = Helpers.gameObject("sm41_024_NewPoliceStatue01A_gimmick")

    if brokenBridge then
        brokenBridge:call("set_DrawSelf", true)

        if isClaire then
            local brokenBridgeTransform = brokenBridge:call("get_Transform()")
            brokenBridgeTransform:call("set_Position(via.vec3)", Vector3f.new(-14.541, -14.374, -14.261))
        end
    end

    if brokenBridgeBlocker then
        local colBB = Helpers.component(brokenBridgeBlocker, "via.physics.Colliders")
        colBB:call("set_Enabled", false)
    end

    if goddessStatueBase then
        local colSB = Helpers.component(goddessStatueBase, "via.physics.Colliders")
        colSB:call("set_Enabled", false)
    end
end

function CutsceneObjects.DispersalCartridge()
    local dispersalObject = Helpers.gameObject("sm42_222_SprayingMachine01A_control")
    if not dispersalObject then
        return
    end
    local dispersalComponent = Helpers.component(dispersalObject, "gimmick.option.AddItemToInventorySettings")
    dispersalComponent:set_field("Enable", false)
end

return CutsceneObjects
