local GUI = {}
GUI.textList = {}
GUI.lastText = os.time()
GUI.lastScenarioCheck = nil
GUI.lastDifficultyCheck = nil
GUI.lastVersionCheck = nil
GUI.lastRTXCheck = nil
GUI.logo = nil
GUI.font = "Prompt-Medium.ttf"
GUI.font_size = 24

function GUI.CheckForAndDisplayMessages()
    if next(GUI.textList) == nil then
        return
    end

    -- if the last text addition was X time ago or more, clear the text
    if os.time() - GUI.lastText > 15 then -- 15 seconds
        GUI.textList = {} -- clear all the messages
    end

    imgui.set_next_window_pos({ 50, 50})
    imgui.begin_window("Archipelago", nil,
        1 -- NoTitleBar
        | 2 -- NoResize
        | 4 -- NoMove
        | 8 -- NoScrollbar
        | 64 -- AlwaysAutoResize
        | 128 -- NoBackground
    )
    -- ImGui Window Flags (3rd arg) reference here: https://oprypin.github.io/crystal-imgui/ImGui/ImGuiWindowFlags.html
    
    local font = imgui.load_font(GUI.font, GUI.font_size)

    if (font ~= nil) then
        imgui.push_font(font)
    end

    imgui.push_style_var(14, Vector2f.new(0,0)) -- text padding

    for k, textArray in pairs(GUI.textList) do
        for k2, textItem in pairs(textArray) do
            if textItem.message ~= nil then
                if textItem.color then
                    imgui.text_colored(textItem.message, textItem.color)    
                else
                    imgui.text(textItem.message)
                end
            end

            imgui.same_line()
        end

        imgui.new_line()
    end

    imgui.pop_style_var(1)
    imgui.pop_font()
    imgui.end_window()
end

function GUI.AddText(message, color, index)
    local textObject = {}
    textObject.message = message
       
    if color ~= nil and color ~= "" then
        textObject.color = GUI.ConvertColorFromText(color)
    end
    
    if index ~= nil then
        table.insert(GUI.textList, index, {textObject})
    else
        table.insert(GUI.textList, {textObject})
    end

    GUI.lastText = os.time()
end

function GUI.AddTexts(textObjects, index)
    for k, textObject in pairs(textObjects) do   
        textObject.color = GUI.ConvertColorFromText(textObject.color)
    end

    if index ~= nil then
        table.insert(GUI.textList, index, textObjects)
    else
        table.insert(GUI.textList, textObjects)
    end

    GUI.lastText = os.time()
end

-- receiving item from self or another player
function GUI.AddReceivedItemText(item_name, item_color, sendingPlayer, selfPlayer, sentToBox)
    local textObjects = {}

    if sendingPlayer == selfPlayer then
        table.insert(textObjects, { message="Found your " })
    else
        table.insert(textObjects, { message="Received " })
    end
    
    -- item name comes in sanitized here, so no AP_REF.Sanitize() call needed
    table.insert(textObjects, { message=item_name, color=AP_REF.HexToImguiColor(item_color) })
    
    if sendingPlayer and sendingPlayer ~= selfPlayer then
        table.insert(textObjects, { message=" from " })
        table.insert(textObjects, { message=sendingPlayer, color = AP_REF.HexToImguiColor(AP_REF.APOtherPlayerColor) })
    end

    if sentToBox then
        table.insert(textObjects, { message=". Sent to item box!" })
    else
        table.insert(textObjects, { message="!" })
    end

    GUI.AddTexts(textObjects)
end

-- sending item to another player
function GUI.AddSentItemText(player_sender, item_name, item_color, player_receiver, location)
    GUI.AddTexts({
        { message=player_sender, color=AP_REF.HexToImguiColor(AP_REF.APCurrentPlayerColor) },
        { message=" sent " },
        { message=AP_REF.Sanitize(item_name), color=AP_REF.HexToImguiColor(item_color) },
        { message=" to " },
        { message=player_receiver, color=AP_REF.HexToImguiColor(AP_REF.APOtherPlayerColor) },
        { message="!"}
    })
end

function GUI.CheckScenarioWarning()
    if not Archipelago.IsConnected() then
        return
    end

    if GUI.lastScenarioCheck ~= nil and os.time() - GUI.lastScenarioCheck < 10 then -- 10 seconds
        return
    end

    local currentCharacter = string.lower(Lookups.character)
    local currentScenario = string.lower(Lookups.scenario)
    local isCorrectScenario = true

    if currentCharacter == "leon" and currentScenario == "a" then
        isCorrectScenario = Scene.isScenarioLeonA() 
    elseif currentCharacter == "leon" and currentScenario == "b" then
        isCorrectScenario = Scene.isScenarioLeonB() 
    elseif currentCharacter == "claire" and currentScenario == "a" then
        isCorrectScenario = Scene.isScenarioClaireA() 
    elseif currentCharacter == "claire" and currentScenario == "b" then
        isCorrectScenario = Scene.isScenarioClaireB() 
    end

    if not isCorrectScenario then
        local intendedScenario = currentCharacter:gsub("^%l", string.upper) .. " " .. currentScenario:gsub("^%l", string.upper)

        GUI.AddTexts({
            { message="Wrong scenario.", color=AP_REF.HexToImguiColor('fa3d2f') },
            { message=" Your YAML was set up to play " },
            { message=intendedScenario, color=AP_REF.HexToImguiColor("d9d904") },
            { message="." }
        }, 1) -- add to the front of the messages, at index 1
    end

    GUI.lastScenarioCheck = os.time()
end

function GUI.CheckDifficultyWarning()
    if not Archipelago.IsConnected() then
        return
    end

    if GUI.lastDifficultyCheck ~= nil and os.time() - GUI.lastDifficultyCheck < 10 then -- 10 seconds
        return
    end

    local currentDifficulty = string.lower(Lookups.difficulty)
    local isCorrectDifficulty = true

    if currentDifficulty == "assisted" then
        isCorrectDifficulty = Scene.isDifficultyAssisted()
    elseif currentDifficulty == "standard" then
        isCorrectDifficulty = Scene.isDifficultyStandard()
    elseif currentDifficulty == "hardcore" then
        isCorrectDifficulty = Scene.isDifficultyHardcore()
    end

    if not isCorrectDifficulty then
        local intendedDifficulty = currentDifficulty:gsub("^%l", string.upper)

        GUI.AddTexts({
            { message="Wrong difficulty.", color=AP_REF.HexToImguiColor('fa3d2f') },
            { message=" Your YAML was set up to play " },
            { message=intendedDifficulty, color=AP_REF.HexToImguiColor("d9d904") },
            { message="." }
        }, 1) -- add to the front of the messages, at index 1
    end

    GUI.lastDifficultyCheck = os.time()
end

function GUI.CheckVersionWarning()
    if not Archipelago.IsConnected() or Archipelago.apworld_version == nil then
        return
    end

    if GUI.lastVersionCheck ~= nil and os.time() - GUI.lastVersionCheck < 10 then -- 10 seconds
        return
    end

    local isCorrectVersion = Manifest.version == Archipelago.apworld_version

    if not isCorrectVersion then
        GUI.AddTexts({
            { message="-------------------------------------------", color=AP_REF.HexToImguiColor("ff7878") }
        })

        GUI.AddTexts({
            { message="This multiworld was generated using version " },
            { message=Archipelago.apworld_version, color=AP_REF.HexToImguiColor("fc5656") },
            { message=" . Your client is expecting version " },
            { message=Manifest.version, color=AP_REF.HexToImguiColor("d9d904") },
            { message=" ." }
        })

        GUI.AddTexts({
            { message="Regenerate the multiworld with the right apworld version, or downgrade your client to match what you already generated.", color=AP_REF.HexToImguiColor("ff7878") }
        })
    end

    GUI.lastVersionCheck = os.time()
end

function GUI.CheckRTXWarning(shouldBeRTX)
    if GUI.lastRTXCheck ~= nil and os.time() - GUI.lastRTXCheck < 17 then -- 17 seconds
        return
    end

    -- allows for checking from both the non-rtx and the rtx client, just with a different arg
    if not shouldBeRTX then shouldBeRTX = false end

    local isRTX = Scene.isRTX()
 
    -- easy way to test for RTX without switching to RTX
    --isRTX = not isRTX

    if isRTX ~= shouldBeRTX then
        GUI.AddTexts({
            { message="You are using this AP mod on the " },
            { message="wrong version", color=AP_REF.HexToImguiColor('fa3d2f')},
            { message=" of the game." },
        }, 1) -- add to the front of the messages, at index 1
        
        GUI.AddTexts({
            { message="For this AP mod, " },
            { message="you must use the " .. ((shouldBeRTX and "RTX") or "non-RTX"), color=AP_REF.HexToImguiColor('fa3d2f') },
            { message=" version of the game." }    
        }, 2) -- add this right after the message above

        GUI.AddTexts({
            { message="See " },
            { message="step 1 of the Setup Guide", color=AP_REF.HexToImguiColor('fa3d2f') },
            { message=" for more information." }
        }, 3) -- add this right after the message above
    end

    GUI.lastRTXCheck = os.time()
end

function GUI.ConvertColorFromText(color)
    if color == "green" then
        color = "yellow" -- greens were converted to yellows previously, need to replace those with yellow at some point to not do this
    end

    if color == "red" then
        color = AP_REF.HexToImguiColor('fa3d2f')
    end

    if color == "yellow" then
        color = AP_REF.HexToImguiColor("d9d904")
    end

    if color == "gray" then
        color = AP_REF.HexToImguiColor("AAAAAA")
    end

    return color
end

function GUI.ClearText()
    GUI.textList = {}
end

return GUI
