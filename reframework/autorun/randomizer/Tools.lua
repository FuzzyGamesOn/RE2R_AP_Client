local Tools = {}

function Tools.ShowGUI()
    imgui.begin_window("Archipelago Game Mod", nil,
        8 -- NoScrollbar
        | 64 -- AlwaysAutoResize
    )

    imgui.text("Mod Version Number: " .. tostring(Manifest.version))
    imgui.new_line()
    imgui.text("Credits:")
    imgui.text("@Fuzzy")
    imgui.text("   - Mod Dev, Leon A")
    imgui.text("@Solidus")
    imgui.text("   - Claire A")
    imgui.new_line()

    imgui.end_window()
end

return Tools