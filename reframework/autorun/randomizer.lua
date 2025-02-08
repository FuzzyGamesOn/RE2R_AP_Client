local game_name = reframework:get_game_name()
if game_name ~= "re2" then
    re.msg("This script is only for RE2")
    return
end


log.debug("[Randomizer] Loading mod...")


-- START globals
AP_REF = require("AP_REF/core")

Manifest = require("randomizer/Manifest")
Lookups = require("randomizer/Lookups")

Archipelago = require("randomizer/Archipelago")
CutsceneObjects = require("randomizer/CutsceneObjects")
DestroyObjects = require("randomizer/DestroyObjects")
GUI = require("randomizer/GUI")
Helpers = require("randomizer/Helpers")
Inventory = require("randomizer/Inventory")
ItemBox = require("randomizer/ItemBox")
ItemDuplicates = require("randomizer/ItemDuplicates")
Items = require("randomizer/Items")
Player = require("randomizer/Player")
Scene = require("randomizer/Scene")
StartingWeapon = require("randomizer/StartingWeapon")
Storage = require("randomizer/Storage")
Typewriters = require("randomizer/Typewriters")
Tools = require("randomizer/Tools")
-- END globals


-- For debugging / trying out functionality:
-- Player.GetInventorySlots()
-- ItemBox.GetItems()

-- Door gimmicks (like Door_2_1_003_gimmick) have a GimmickDoor comp
--   that has references to "MyRooms" and "MyLocations", and something about "IsPairComplete"


re.on_pre_application_entry("UpdateBehavior", function()
    -- if not Scene:isInGame() then
    --     Archipelago.DisableInGameClient("Start a new game or load a file before connecting to AP.");
    -- else
    --     Archipelago.EnableInGameClient();
    -- end

    if Scene:isInGame() then 
        Archipelago.Init()
        Items.Init()
        CutsceneObjects.Init()
        DestroyObjects.Init()
        StartingWeapon.Init()

        if Archipelago.waitingForSync then
            Archipelago.waitingForSync = false
            Archipelago.Sync()
        end

        if Archipelago.CanReceiveItems() then
            Archipelago.ProcessItemsQueue()
        end

        -- if the game randomly forgets that the player exists and tries to leave the invincibility flag on from item pickup,
        --   relentlessly check for the player existing until it does, then turn that flag off
        if Archipelago.waitingForInvincibiltyOff then
            if Player.TurnOffInvincibility() then
                Archipelago.waitingForInvincibiltyOff = false
            end
        end

        if Player.waitingForKill then
            Player.Kill()
        else
            Archipelago.canDeathLink = true
            Archipelago.wasDeathLinked = false
        end
    else
        CutsceneObjects.isInit = false -- look for objects that should be destroyed and destroy them again
        DestroyObjects.isInit = false -- look for objects that should be destroyed and destroy them again
    end

    if Scene:isGameOver() then
        if Archipelago.canDeathLink and not Archipelago.wasDeathLinked then
            Archipelago.canDeathLink = false
            Archipelago:SendDeathLink()
        end
        
        if not Archipelago.waitingForSync then
            Archipelago.waitingForSync = true
        end

        Archipelago.didGameOver = true
    end
end)

re.on_frame(function ()
    -- ... one day OpieOP
    -- if Scene:isTitleScreen() then
    --     GUI.ShowRandomizerLogo()
    -- end

    if reframework:is_drawing_ui() then
        Tools.ShowGUI()
    end

    if Scene:isInGame() or Scene:isGameOver() then
        GUI.CheckForAndDisplayMessages()
    end

    if Scene:isInGame() then 
        -- only show the typewriter window when the user presses the reframework hotkey
        if reframework:is_drawing_ui() then
            Typewriters.DisplayWarpMenu()
        end
    end
end)

re.on_draw_ui(function () -- this is only called when Script Generated UI is visible
    -- nothing, but could add some debug stuff here one day
end)

log.debug("[Randomizer] Mod loaded.")
