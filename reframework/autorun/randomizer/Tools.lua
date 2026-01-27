local Tools = {}

function Tools.ShowGUI()
    local scenario_text = '(not connected)'
    local deathlink_text = '(not connected)'
    local deathlink_color = AP_REF.HexToImguiColor('FFFFFF')
    local version_text = tostring(Manifest.version)
    local version_mismatch = false

    -- if the lookups contain data, then we're connected, so do everything that needs connection
    if Lookups.character and Lookups.scenario then
        scenario_text = Lookups.character:gsub("^%l", string.upper) .. " " .. string.upper(Lookups.scenario) .. 
            " - " .. Lookups.difficulty:gsub("^%l", string.upper)

        if Archipelago.death_link then
            deathlink_text = "On"
        else
            deathlink_text = "Off"
            deathlink_color = AP_REF.HexToImguiColor('777777')
        end

        if Archipelago.apworld_version == nil or Archipelago.apworld_version ~= Manifest.version then
            if Archipelago.apworld_version ~= nil then
                version_text = version_text .. ' (world is ' .. Archipelago.apworld_version .. ')'
            else
                version_text = version_text .. ' (world is outdated)'
            end

            version_mismatch = true
        else
            version_text = version_text .. ' (matches)'
        end
    end
    
    -- local player_character_text = "   (not in-game)"
    -- if Scene.isCharacterLeon() then player_character_text = "   Leon" end
    -- if Scene.isCharacterAda() then player_character_text = "   Ada" end
    -- if Scene.isCharacterClaire() then player_character_text = "   Claire" end
    -- if Scene.isCharacterSherry() then player_character_text = "   Sherry" end

    imgui.set_next_window_size(Vector2f.new(320, 750), 0)
    imgui.begin_window("Archipelago Game Mod ", nil,
        8 -- NoScrollbar
    )

    imgui.text_colored(" Mod Version Number: ", -10825765)
    imgui.same_line() 

    if version_mismatch then
        imgui.text_colored("    " .. version_text, AP_REF.HexToImguiColor('fa3d2f'))
    else
        imgui.text("    " .. version_text)
    end

    imgui.text_colored(" AP Scenario & Difficulty: ", -10825765)
    imgui.same_line()
    imgui.text(scenario_text)

    imgui.text_colored(" DeathLink: ", -10825765)
    imgui.same_line()
    imgui.text_colored("                         " .. deathlink_text, deathlink_color)

    if Archipelago.weapon_rando ~= nil then
        imgui.text_colored(" Weapon Randomizer: ", -10825765)
        imgui.same_line()
        imgui.text("      " .. Archipelago.weapon_rando)

        if Archipelago.weapon_rando ~= nil and Archipelago.weapon_rando ~= "None" then
            local all_weapons = Archipelago.all_weapons

            if string.find(Archipelago.weapon_rando, "Troll") then
                all_weapons = { "Not telling :)" }
            end

            imgui.text_colored(" Included Weapons: ", -10825765)

            if #all_weapons > 6 then
                imgui.text("    (All)")
            else
                for _, weapon in pairs(all_weapons) do
                    if weapon ~= nil then
                        imgui.text("    " .. tostring(weapon))
                    end
                end
            end
        end
    end

    imgui.new_line()

    imgui.separator()
    imgui.text_colored("         The default keyboard key to show or hide", AP_REF.HexToImguiColor('bbbbbb'))
    imgui.text_colored("         these windows is INSERT.", AP_REF.HexToImguiColor('bbbbbb'))
    imgui.separator()

    if Lookups.character and Lookups.scenario then
        imgui.new_line()
        imgui.text_colored(" Missing Items?", AP_REF.HexToImguiColor('09ba39'))
        imgui.text("    If you were sent items at the ")
        imgui.text("    start and didn't receive them,")
        imgui.text("    click this button.")

        imgui.text("  ")
        imgui.same_line()
        
        if imgui.button("Receive Items Again") then
            Storage.lastReceivedItemIndex = -1
            Storage.lastSavedItemIndex = -1
            Archipelago.waitingForSync = true
        end

        imgui.new_line()
        imgui.text_colored(" Missing a starting Hip Pouch?", AP_REF.HexToImguiColor('09ba39'))
        imgui.text("    Click this button to receive")
        imgui.text("    a hip pouch!")

        imgui.text("  ")
        imgui.same_line()
        
        if imgui.button("Receive Hip Pouch") then
            GUI.AddText("Receiving Hip Pouch...")
            Archipelago.ReceiveItem("Hip Pouch", nil, 1)
        end

        imgui.new_line()
        imgui.separator()
    end

    imgui.new_line()
    imgui.text_colored(" Credits:", -10825765)
    imgui.text_colored("   @Fuzzy", AP_REF.HexToImguiColor('08c9b9')) -- AP_REF.HexToImguiColor('08c9b9')) -- AP_REF.HexToImguiColor('5f9de8'))
    imgui.same_line()
    imgui.text("(main dev)")
    imgui.text_colored("   @Solidus Snake", AP_REF.HexToImguiColor('3e84d6'))
    imgui.same_line()
    imgui.text("(CA, CB, LB scenarios)")
    imgui.text_colored("   @Silvris", AP_REF.HexToImguiColor('3e84d6'))
    imgui.same_line()
    imgui.text("(AP client lib)")
    imgui.text_colored("   @Johnny Hamcobbler", AP_REF.HexToImguiColor('3e84d6'))
    imgui.same_line()
    imgui.text("(testing/client)")
    imgui.text_colored("   @Nowhere", AP_REF.HexToImguiColor('3e84d6'))
    imgui.same_line()
    imgui.text("(CA kills)")
    imgui.text_colored("   @Xefir", AP_REF.HexToImguiColor('3e84d6'))
    imgui.same_line()
    imgui.text("(LB kills)")
    imgui.text_colored("   @Ropeyred", AP_REF.HexToImguiColor('3e84d6'))
    imgui.same_line()
    imgui.text("(CB kills)")
    imgui.new_line()

    imgui.end_window()
end

return Tools
