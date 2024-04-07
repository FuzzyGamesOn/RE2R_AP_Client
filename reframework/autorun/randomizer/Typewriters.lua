local Typewriters = {}
Typewriters.unlocked_typewriters = {}

function Typewriters.AddUnlockedText(name, item_name, no_save_warning)
    if #Lookups.typewriters == 0 then -- no typewriters, no typewriters to unlock
        return
    end

    local typewriterText = name

    if #typewriterText == 0 then
        for t, typewriter in pairs(Lookups.typewriters) do
            if typewriter["item_object"] == item_name then
                typewriterText = typewriter["name"]

                break
            end
        end
    end

    if #typewriterText > 0 then
        GUI.AddText("Unlocked ") 
        GUI.AddText(typewriterText, "green")
        GUI.AddText(" typewriter!" .. (not no_save_warning and " Don't forget to save!!" or ""))
    end
end

-- Allowing specifying either the readable name or the item name, so both AP options and Item interaction can unlock
function Typewriters.Unlock(name, item_name)
    if #Lookups.typewriters == 0 then -- no typewriters, no typewriters to unlock
        return
    end

    -- Typewriters.UnlockAll()
    -- return

    for t, typewriter in pairs(Lookups.typewriters) do
        if typewriter["name"] == name or typewriter["item_object"] == item_name then
            Typewriters.unlocked_typewriters[typewriter["item_object"]] = true

            break
        end
    end
end

function Typewriters.UnlockAll()
    if #Lookups.typewriters == 0 then -- no typewriters, no typewriters to unlock
        return
    end

    for t, typewriter in pairs(Lookups.typewriters) do
        Typewriters.unlocked_typewriters[typewriter["item_object"]] = true
    end
end

function Typewriters.GetAllUnlocked()
    local typewriter_item_names = {}

    for typewriter, is_unlocked in pairs(Typewriters.unlocked_typewriters) do
        table.insert(typewriter_item_names, typewriter)
    end

    return typewriter_item_names
end

function Typewriters.DisplayWarpMenu()
    imgui.begin_window("Fast Travel - Typewriters", nil,
        8 -- NoScrollbar
        | 64 -- AlwaysAutoResize
    )

    if #Lookups.typewriters == 0 then
        imgui.text("Connect to AP to see typewriter locations.")
        imgui.end_window()
        
        return
    end

    local font = imgui.load_font("BebasNeue-Regular.ttf", 24)

    if (font ~= nil) then
        imgui.push_font(font)
    end

    for t, typewriter in pairs(Lookups.typewriters) do
        
        -- if the player has unlocked the typewriter by interacting once, set active color; otherwise, set default
        if Typewriters.unlocked_typewriters[typewriter["item_object"]] then
            imgui.push_style_color(imgui.COLOR_BUTTON, Vector4f.new(2.5, 2.5, 2.5, 1.00))
        else
            imgui.push_style_color(imgui.COLOR_BUTTON, Vector4f.new(1, 1, 1, 0.07))
        end

        if imgui.button(typewriter["name"]) then
            -- if the player has unlocked the typewriter by interacting once, let them teleport; otherwise, do nothing
            if Typewriters.unlocked_typewriters[typewriter["item_object"]] then
                local locationThroughManager = sdk.get_managed_singleton(sdk.game_namespace("LocationThroughManager"))
                requestJumpPosition = "requestJumpPosition(" .. sdk.game_namespace("gamemastering.Location.ID") .. 
                    ", via.vec3, via.Quaternion, " .. sdk.game_namespace("gamemastering.Map.ID") .. ", System.Boolean, System.Single)"
        
                local locationId = typewriter["location_id"]
                local mapId = typewriter["map_id"]
                local pos = typewriter["player_position"]
                local position = Vector3f.new(pos[1], pos[2], pos[3])
        
                locationThroughManager:call(requestJumpPosition, locationId, position, Vector3f.new(0, 0, 0):to_quat(), mapId, false, 0)
            end
        end

        imgui.pop_style_color(1)

        -- Break the list onto two lines around the middle; i.e., skip the same_line once
        if not typewriter["line_break"] then
            imgui.same_line()
        end
    end

    imgui.new_line()
    imgui.new_line()

    if imgui.button("Unlock All Typewriters") then
        Typewriters.UnlockAll()
    end
  
    -- Warping while Ada and triggering any cutscenes breaks the game

    imgui.pop_font()
    imgui.end_window()
end

return Typewriters
