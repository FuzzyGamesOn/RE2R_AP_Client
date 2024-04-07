local GUI = {}
GUI.textList = {}
GUI.lastText = os.time()
GUI.logo = nil

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
    
    local font = imgui.load_font("BebasNeue-Regular.ttf", 24)

    if (font ~= nil) then
        imgui.push_font(font)
    end

    for k, textItem in pairs(GUI.textList) do
        if textItem.message ~= nil then
            if textItem.color then
                imgui.text_colored(textItem.message, textItem.color)    
            else
                imgui.text(textItem.message)
            end
    
            if 
                string.sub(textItem.message, -1) ~= '!' and string.sub(textItem.message, -1) ~= ')' 
                and not string.find(textItem.message, 'Connected.') and not string.find(textItem.message, 'Disconnected.') 
                and not string.find(textItem.message, 'connected.')
            then
                imgui.same_line()
            end    
        end
    end

    imgui.pop_font()
    imgui.end_window()
end

function GUI.AddText(message, color)
    local textObject = {}
    textObject.message = message
    textObject.color = color

    -- i don't remember how these colors work, and i hate them
    if (textObject.color == "green") then
        textObject.color = -14710248
    elseif (textObject.color == "yellow") then
        textObject.color = -10825765
    elseif (textObject.color == "blue") then
        textObject.color = -5825765
    end
    
    table.insert(GUI.textList, textObject)
    GUI.lastText = os.time()
end

-- Function for only having one message of this kind in the message list, so we don't spam it unnecessarily.
function GUI.OnceText(message)
    for k, v in pairs(GUI.textList) do
        if v.message == message then
            return
        end
    end

    GUI.AddText(message)
end

-- receiving item from self or another player
function GUI.AddReceivedItemText(item_object, sendingPlayer, selfPlayer, sentToBox)
    if sendingPlayer == selfPlayer then
        GUI.AddText("Found  your ") 
    else
        GUI.AddText("Received ") 
    end
    
    GUI.AddText(item_object, "green")

    if sendingPlayer and sendingPlayer ~= selfPlayer then
        GUI.AddText(" from " .. sendingPlayer)
    end

    if sentToBox then
        GUI.AddText(". Sent to item box!")
    else
        GUI.AddText("!")
    end
end

-- sending item to another player
function GUI.AddSentItemText(player_sender, item, player_receiver, location)
    GUI.AddText(player_sender .. " sent ")
    GUI.AddText(item, "green")
    GUI.AddText(" to " .. player_receiver .. "!")
end

-- sending item to self
-- is this even called ever?
function GUI.AddSentItemSelfText(player_sender, item, location)
    GUI.AddText(player_sender .. " found their ")
    GUI.AddText(item, "green")
    GUI.AddText(" (")
    GUI.AddText(location, "green")
    GUI.AddText(")")
end

function GUI.ClearText()
    GUI.textList = {}
end

return GUI
