local GUIInventory = {}
GUIInventory.textList = {}
GUIInventory.font = "Prompt-Medium.ttf"
GUIInventory.font_size = 24
GUIInventory.font_size_bigger = 32

function GUIInventory.Init()
    GUIInventory.textList = {}
    GUIInventory.AddModHeader()
    GUIInventory.AddModWindowHint()
    GUIInventory.AddNotSureHeader()
    GUIInventory.AddTypewriterHint()
    GUIInventory.AddTrackerHint()
end

function GUIInventory.CheckForAndDisplayMessages()
    -- only show the hint text when the REF windows aren't showing, and the player isn't using the item box, and the player IS in their inventory
    if reframework:is_drawing_ui() or not Scene.isUsingInventory() then
        return
    end

    if Scene.isUsingItemBox() then
        return
    end

    imgui.set_next_window_pos({ 50, 350})
    imgui.begin_window("Archipelago Inventory Info", nil,
        1 -- NoTitleBar
        | 2 -- NoResize
        | 4 -- NoMove
        | 8 -- NoScrollbar
        | 64 -- AlwaysAutoResize
        | 128 -- NoBackground
    )
    -- ImGui Window Flags (3rd arg) reference here: https://oprypin.github.io/crystal-imgui/ImGui/ImGuiWindowFlags.html
    
    local font = imgui.load_font(GUIInventory.font, GUIInventory.font_size)
    local fontBigger = imgui.load_font(GUIInventory.font, GUIInventory.font_size_bigger)

    if (font ~= nil) then
        imgui.push_font(font)
    end

    imgui.push_style_var(14, Vector2f.new(0,0)) -- text padding

    for k, textArray in pairs(GUIInventory.textList) do
        hasSeparator = false

        for k2, textItem in pairs(textArray) do
            if textItem.header ~= nil then
                imgui.pop_font()
                imgui.push_font(fontBigger) 
            end

            if textItem.message ~= nil then
                if textItem.header then
                    imgui.text_colored(textItem.message, AP_REF.HexToImguiColor("4287f5"))
                elseif textItem.color then
                    imgui.text_colored(textItem.message, textItem.color)
                else
                    imgui.text_colored(textItem.message, AP_REF.HexToImguiColor("dddddd"))
                end
            end

            if textItem.separator ~= nil and textItem.separator then
                hasSeparator = true
            end

            if textItem.header ~= nil and textItem.header then
                imgui.pop_font()
                imgui.push_font(font)
            end

            imgui.same_line()
        end

        imgui.new_line()

        if hasSeparator then
            imgui.separator()
        end
    end

    imgui.pop_style_var(1)
    imgui.pop_font()
    imgui.end_window()
end

function GUIInventory.AddTexts(textObjects, index)
    for k, textObject in pairs(textObjects) do   
        -- convert legacy colors to a system yellow
        if textObject.color == "green" then
            textObject.color = AP_REF.HexToImguiColor("d9d904")
        end
    end

    if index ~= nil then
        table.insert(GUIInventory.textList, index, textObjects)
    else
        table.insert(GUIInventory.textList, textObjects)
    end
end

function GUIInventory.AddModHeader()
    local textObjects = {
        { message="Welcome to RE2R in AP!", header=true }
    }
    GUIInventory.AddTexts(textObjects)
end

function GUIInventory.AddModWindowHint()
    local textObjects = {
        { message="To show the AP mod windows, \n" },
        { message="press " },
        { message="Insert", color="green" },
        { message=" on your keyboard.\n\n" },
        { message="\n\n" },
        { separator=true }
    }
    GUIInventory.AddTexts(textObjects)

    local textObjects = {
        { message="\n" }
    }
    GUIInventory.AddTexts(textObjects)
end

function GUIInventory.AddNotSureHeader()
    local textObjects = {
        { message="Not sure what to do next?", header=true }
    }
    GUIInventory.AddTexts(textObjects)
end

function GUIInventory.AddTypewriterHint()
    local textObjects = {
        { message="Teleport to any of the " },
        { message="typewriters", color="green" },
        { message=" you've visited before" }
    }
    GUIInventory.AddTexts(textObjects)

    textObjects = {
        { message="using the AP mod windows.\n\n" }
    }
    GUIInventory.AddTexts(textObjects)
end

function GUIInventory.AddTrackerHint()
    local textObjects = {
        { message="Universal Tracker", color="green" },
        { message=" (or the in-progress RE2R " },
        { message="PopTracker", color="green" },
        { message=")" } 
    }
    GUIInventory.AddTexts(textObjects)

    textObjects = {
        { message="can also point you to unchecked locations.\n\n" }
    }
    GUIInventory.AddTexts(textObjects)
end

return GUIInventory
