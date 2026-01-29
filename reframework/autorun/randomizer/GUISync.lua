local GUISync = {}
GUISync.font = "Prompt-Medium.ttf"
GUISync.font_size = 24
GUISync.pulse_counter = 0

function GUISync.Init()
    -- nothing?
end

function GUISync.CheckForAndDisplayMessages()
    -- if no last save timestamp, nothing to do
    if SaveData.lastSyncTimestamp == nil then
        GUISync.pulse_counter = 0
        return
    end

    -- if the last text addition was X time ago or more, clear the text
    if os.time() - SaveData.lastSyncTimestamp > 3 then -- 3 seconds
        GUISync.pulse_counter = 0
        return
    end

    local display_size = imgui.get_display_size()
    
    imgui.set_next_window_pos({ display_size.x - 100, display_size.y - 100}) -- put it in the bottom right corner
    imgui.begin_window("Archipelago Sync Notification", nil,
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
    if (GUISync.pulse_counter % 45) < 15 then
        imgui.text_colored('Syncing...', AP_REF.HexToImguiColor('02e2fa'))
    elseif (GUISync.pulse_counter % 45) > 15 and (GUISync.pulse_counter % 45) < 30 then
        imgui.text_colored('Syncing...', AP_REF.HexToImguiColor('04bdd1'))
    else
        imgui.text_colored('Syncing...', AP_REF.HexToImguiColor('0296a6'))
    end

    GUISync.pulse_counter = GUISync.pulse_counter + 1

    imgui.pop_style_var(1)
    imgui.pop_font()
    imgui.end_window()
end

return GUISync
