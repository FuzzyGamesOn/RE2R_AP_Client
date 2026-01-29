local GUISave = {}
GUISave.font = "Prompt-Medium.ttf"
GUISave.font_size = 24
GUISave.pulse_counter = 0

function GUISave.CheckForAndDisplayMessages()
    -- if no last save timestamp, nothing to do
    if SaveData.lastSaveTimestamp == nil then
        GUISave.pulse_counter = 0
        return
    end

    -- if the last text addition was X time ago or more, clear the text
    if os.time() - SaveData.lastSaveTimestamp > 3 then -- 3 seconds
        GUISave.pulse_counter = 0
        return
    end

    local display_size = imgui.get_display_size()
    
    imgui.set_next_window_pos({ display_size.x - 100, display_size.y - 100}) -- put it in the bottom right corner
    imgui.begin_window("Archipelago Save Notification", nil,
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

    -- pulse the text color so it looks animated
    if (GUISave.pulse_counter % 45) < 15 then
        imgui.text_colored('Saving...', AP_REF.HexToImguiColor('03fc1c'))
    elseif (GUISave.pulse_counter % 45) > 15 and (GUISave.pulse_counter % 45) < 30 then
        imgui.text_colored('Saving...', AP_REF.HexToImguiColor('04d119'))
    else
        imgui.text_colored('Saving...', AP_REF.HexToImguiColor('059e14'))
    end

    GUISave.pulse_counter = GUISave.pulse_counter + 1

    imgui.pop_style_var(1)
    imgui.pop_font()
    imgui.end_window()
end

return GUISave
