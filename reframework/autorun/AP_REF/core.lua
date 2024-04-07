-- TODO: since we had to shove this into its own folder, maybe split this into multiple files?
local AP = nil
while AP == nil do
	AP = package.loadlib("lua-apclientpp.dll", "luaopen_apclientpp")
end
AP = AP()
local AP_REF = {}
AP_REF.AP = AP
-- You should set these values from within your mod
AP_REF.APGameName = ""
AP_REF.APItemsHandling = 7 -- shouldn't need to change this
AP_REF.APTags = {} -- these are reserved for any additional tags, Lua-APClientPP is always applied, and TextOnly when relevant

AP_REF.APColors = {
    red="EE0000",
    blue="6495ED",
    green="00FF7F",
    yellow="FAFAD2",
    cyan="00EEEE",
    magenta="EE00EE",
    black="000000",
    white="FFFFFF",
    red_bg="FF0000",
    blue_bg="0000FF",
    green_bg="00FF00",
    yellow_bg="FFFF00",
    cyan_bg="00FFFF",
    magenta_bg="FF00FF",
    black_bg="000000",
    white_bg="FFFFFF"
}

local function setDefault (t, d)
	local mt = {__index = function () return d end}
	setmetatable(t, mt)
end

setDefault(AP_REF.APColors, "FFFFFF")

AP_REF.APCurrentPlayerColor = "EE00EE"
AP_REF.APOtherPlayerColor = "FAFAD2"
AP_REF.APProgessionColor = "AF99EF"
AP_REF.APUsefulColor = "6D8BE8"
AP_REF.APFillerColor = "00EEEE"
AP_REF.APTrapColor = "FA8072"
AP_REF.APLocationColor = "00FF7F"
AP_REF.APEntranceColor = "6495ED"

function AP_REF.HexToImguiColor(color)
	local r = string.sub(color, 1, 2)
	local g = string.sub(color, 3, 4)
	local b = string.sub(color, 5, 6)
	return tonumber("FF"..b..g..r, 16)
end

AP_REF.clientEnabled = true
AP_REF.clientDisabledMessage = ""

function AP_REF.EnableInGameClient()
    AP_REF.clientEnabled = true
    AP_REF.clientDisabledMessage = ""
end

function AP_REF.DisableInGameClient(disable_message)
    AP_REF.clientEnabled = false

    if disable_message then
        AP_REF.clientDisabledMessage = disable_message
    end
end

-----------------------------------

-- Utilize at your own peril
AP_REF.APClient = nil
-----------------------------------

local host = "localhost:38281"
local slot = "Player1"
local password = ""

local mainWindowVisible = true
local showMainWindow = true
local textLog = {}
local connected = false
local current_text = ""

local disconnect_client = false

local DEBUG = false

local function debug_print(str)
	if DEBUG then
		log.debug(str)
	end
end

local function callback_passthrough()
	a = 1 + 1
end

local function callback_passthrough_one_arg(pass)
	debug_print(pass)
	a = 1 + 1
end

local function callback_passthrough_two_arg(pass1, pass2)
	debug_print(pass1)
	debug_print(pass2)
	a = 1 + 1
end

local function callback_passthrough_three_arg(pass1, pass2, pass3)
	debug_print(pass1)
	debug_print(pass2)
	debug_print(pass3)
	a = 1 + 1
end

local function parse_json_msg(val)
	if val["type"] ~= nil then
		local text_type = val["type"]
		local text = val["text"]
		local color = "FFFFFF"
		if text_type == "color" then
			color = AP_REF.HexToImguiColor(AP_REF.APColors[val["color"]])
		elseif text_type == "player_id" then
			if tonumber(val["text"]) == AP_REF.APClient:get_player_number() then
				color = AP_REF.APCurrentPlayerColor
			else
				color = AP_REF.APOtherPlayerColor
			end
			text = AP_REF.APClient:get_player_alias(tonumber(val["text"]))
			color = AP_REF.HexToImguiColor(color)
		elseif text_type == "player_name" then
			-- according to network docs, this only appears when individual is not slot-resolvable?
			color = AP_REF.HexToImguiColor(AP_REF.APOtherPlayerColor)
		elseif text_type == "item_id" then
			-- resolve item flags
			if (val["flags"] & 1) > 0 then
				color = AP_REF.APProgessionColor
			elseif (val["flags"] & 2) > 0 then
				color = AP_REF.APUsefulColor
			elseif (val["flags"] & 4) > 0 then
				color = AP_REF.APTrapColor
			else
				color = AP_REF.APFillerColor
			end
			text = AP_REF.APClient:get_item_name(tonumber(val["text"]), AP_REF.APClient:get_player_game(tonumber(val["player"])))
			color = AP_REF.HexToImguiColor(color)
		elseif text_type == "item_name" then
			-- resolve item flags
			if val["flags"] & 1 then
				color = AP_REF.APProgessionColor
			elseif val["flags"] & 2 then
				color = AP_REF.APUsefulColor
			elseif val["flags"] & 4 then
				color = AP_REF.APTrapColor
			else
				color = AP_REF.APFillerColor
			end
			color = AP_REF.HexToImguiColor(color)
		elseif text_type == "location_id" then
			-- TODO: become 1933 compliant once a new version of lua-AP_REF.APClientpp releases
			text = AP_REF.APClient:get_location_name(tonumber(val["text"]), AP_REF.APClient:get_player_game(tonumber(val["player"])))
			color = AP_REF.HexToImguiColor(AP_REF.APLocationColor)
		elseif text_type == "location_name" then
			color = AP_REF.HexToImguiColor(AP_REF.APLocationColor)
		elseif text_type == "entrance_name" then
			color = AP_REF.HexToImguiColor(AP_REF.APEntranceColor)
		else
			color = AP_REF.HexToImguiColor(color)
		end
		return {text = text, color = color}
	else
		return {text = val["text"]}
	end
end

AP_REF.on_socket_connected = callback_passthrough
AP_REF.on_socket_error = callback_passthrough_one_arg
AP_REF.on_socket_disconnected = callback_passthrough
AP_REF.on_room_info = callback_passthrough
AP_REF.on_slot_connected = callback_passthrough_one_arg
AP_REF.on_slot_refused = callback_passthrough_one_arg
AP_REF.on_items_received = callback_passthrough_one_arg
AP_REF.on_location_info = callback_passthrough_one_arg
AP_REF.on_location_checked = callback_passthrough_one_arg
AP_REF.on_data_package_changed = callback_passthrough_one_arg
AP_REF.on_print = callback_passthrough_one_arg
AP_REF.on_print_json = callback_passthrough_two_arg
AP_REF.on_bounced = callback_passthrough_one_arg
AP_REF.on_retrieved = callback_passthrough_three_arg
AP_REF.on_set_reply = callback_passthrough_one_arg


local function set_socket_connected_handler(callback)
	function socket_connected()
		debug_print("Socket connected")
		callback()
	end
	AP_REF.APClient:set_socket_connected_handler(socket_connected)
end
local function set_socket_error_handler(callback)
	function socket_error_handler(msg)
		debug_print("Socket error")
		debug_print(msg)
		callback(msg)
	end
	AP_REF.APClient:set_socket_error_handler(socket_error_handler)
end
local function set_socket_disconnected_handler(callback)
	function socket_disconnected_handler()
		debug_print("Socket disconnected")
		callback()
	end
	AP_REF.APClient:set_socket_disconnected_handler(socket_disconnected_handler)
end
local function set_room_info_handler(callback)
	function room_info_handler()
		debug_print("Room info")
		callback()
		local tags = {"Lua-APClientPP"}
		if AP_REF.APGameName == "" then
			table.insert(tags, "TextOnly")
		end
		for i, val in ipairs(AP_REF.APTags) do
			table.insert(tags, val)
		end
		AP_REF.APClient:ConnectSlot(slot, password, AP_REF.APItemsHandling, tags, {0, 4, 3})
	end
	AP_REF.APClient:set_room_info_handler(room_info_handler)
end
local function set_slot_connected_handler(callback)
	function slot_connected_handler(slot_data)
		debug_print("Slot connected")
		callback(slot_data)
	end
	AP_REF.APClient:set_slot_connected_handler(slot_connected_handler)
end
local function set_slot_refused_handler(callback)
	function slot_refused_handler(reasons)
        table.insert(textLog, {{text = table.concat(reasons, ", ")}})
		debug_print("Slot refused: " .. table.concat(reasons, ", "))
		callback(reasons)
		disconnect_client = true
	end
	AP_REF.APClient:set_slot_refused_handler(slot_refused_handler)
end
local function set_items_received_handler(callback)
	function items_received_handler(items)
		debug_print("Items received")
		callback(items)
	end
	AP_REF.APClient:set_items_received_handler(items_received_handler)
end
local function set_location_info_handler(callback)
	function location_info_handler(items)
		debug_print("Locations info")
		callback(items)
	end
	AP_REF.APClient:set_location_info_handler(location_info_handler)
end
local function set_location_checked_handler(callback)
	function location_checked_handler(locations)
		debug_print("Locations checked")
		callback(locations)
	end
	AP_REF.APClient:set_location_checked_handler(location_checked_handler)
end
local function set_data_package_changed_handler(callback)
	function data_package_changed_handler(data_package)
		debug_print("Data package changed")
		callback(data_package)
	end
	AP_REF.APClient:set_data_package_changed_handler(data_package_changed_handler)
end
local function set_print_handler(callback)
	function print_handler(msg)
		debug_print("Print")
		callback(msg)
		table.insert(textLog, {{text = msg}})
		--debug_print(msg)
	end
	AP_REF.APClient:set_print_handler(print_handler)
end
local function set_print_json_handler(callback)
	function print_json_handler(msg, extra)
		debug_print("Print json")
		callback(msg, extra)
		message = {}
		for i, val in ipairs(msg) do
			table.insert(message, parse_json_msg(val))
		end
		table.insert(textLog, message)
	end
	AP_REF.APClient:set_print_json_handler(print_json_handler)
end
local function set_bounced_handler(callback)
	function bounced_handler(bounce)
		debug_print("Bounce")
		callback(bounce)
	end
	AP_REF.APClient:set_bounced_handler(bounced_handler)
end
local function set_retrieved_handler(callback)
	function retrieved_handler(map, keys, extra)
		debug_print("Retrieved")
		callback(map, keys, extra)
	end
	AP_REF.APClient:set_retrieved_handler(retrieved_handler)
end
local function set_set_reply_handler(callback)
	function set_reply_handler(message)
		debug_print("Set Reply")
		callback(message)
	end
	AP_REF.APClient:set_set_reply_handler(set_reply_handler)
end

function APConnect(host)
    local uuid = ""
    AP_REF.APClient = AP(uuid, AP_REF.APGameName, host)
    table.insert(textLog, {{ text = "Connecting..." }})
    debug_print("Connecting")
    set_socket_connected_handler(AP_REF.on_socket_connected)
    set_socket_error_handler(AP_REF.on_socket_error)
    set_socket_disconnected_handler(AP_REF.on_socket_disconnected)
    set_room_info_handler(AP_REF.on_room_info)
    set_slot_connected_handler(AP_REF.on_slot_connected)
    set_slot_refused_handler(AP_REF.on_slot_refused)
    set_items_received_handler(AP_REF.on_items_received)
    set_location_info_handler(AP_REF.on_location_info)
    set_location_checked_handler(AP_REF.on_location_checked)
    set_data_package_changed_handler(AP_REF.on_data_package_changed)
    set_print_handler(AP_REF.on_print)
    set_print_json_handler(AP_REF.on_print_json)
    set_bounced_handler(AP_REF.on_bounced)
    set_retrieved_handler(AP_REF.on_retrieved)
    set_set_reply_handler(AP_REF.on_set_reply)
end

local function DisplayClientCommand(command)
	if command == "help" then
		table.insert(textLog, {{text = "/help - Display useful information about the client. Currently no other commands exist."}})
	else
		table.insert(textLog, {{text = "Could not identify command "..command.."."}})
	end
end

local function main_menu()
	if mainWindowVisible then
		imgui.set_next_window_size(Vector2f.new(600, 300), 4)
		if showMainWindow then
			showMainWindow = imgui.begin_window("Archipelago Client for REFramework", showMainWindow, nil)
		else
			imgui.begin_window("Archipelago REFramework", nil, nil)
		end

        if not AP_REF.clientEnabled then
            imgui.text(AP_REF.clientDisabledMessage or "Disabled by game.")

            return
        end

		local size = imgui.get_window_size()
		imgui.push_item_width(size.x / 5)
		changed, hostname, _1, _2 = imgui.input_text("Host", host)
		if changed then
			host = hostname
		end
		imgui.same_line()
		changed, slotname, _1, _2 = imgui.input_text("Slot", slot)
		if changed then
			slot = slotname
		end
		imgui.same_line()
		changed, pass, _1, _2 = imgui.input_text("Password", password)
		if changed then
			password = pass
		end
		imgui.same_line()
		if connected then
			if imgui.button("Disconnect") then
                disconnect_client = true
                table.insert(textLog, {{ text = "Disconnected." }})
			end
		else
			if imgui.button("Connect") then
				APConnect(host)
			end
		end
		imgui.pop_item_width()
		imgui.separator()
		imgui.begin_child_window("ScrollRegion", Vector2f.new(size.x-25, size.y-85), true, 0)
		imgui.push_style_var(14, Vector2f.new(0,0))
		for i, value in ipairs(textLog) do
			for i, val in ipairs(value) do
                if val["color"] == nil then
                    val["color"] = AP_REF.HexToImguiColor("FFFFFF")
                end
                imgui.text_colored(val["text"], val["color"])
				imgui.same_line()
			end
			imgui.new_line()
		end
		imgui.pop_style_var()
		imgui.end_child_window()
		imgui.text("Input:")
		imgui.same_line()
		imgui.push_item_width((size.x / 4)*3)
		changed, input, _1, _2 = imgui.input_text("", current_text)
		if changed then
			current_text = input
		end
		imgui.same_line()
		if imgui.button("Send") then
			if current_text ~= "" then
				if string.sub(current_text,1, 1) == "/" then
					DisplayClientCommand(string.sub(current_text, 2))
					current_text = ""
				elseif ap ~= nil then
					AP_REF.APClient:Say(current_text)
					current_text = ""
				end
			end
		end
		imgui.pop_item_width()
		imgui.end_window()
	end
end

local function SaveConfig()
    config = {}
    config["APCurrentPlayerColor"] = AP_REF.APCurrentPlayerColor
    config["APOtherPlayerColor"] = AP_REF.APOtherPlayerColor
    config["APProgessionColor"] = AP_REF.APProgessionColor
    config["APUsefulColor"] = AP_REF.APUsefulColor
    config["APFillerColor"] = AP_REF.APFillerColor
    config["APTrapColor"] = AP_REF.APTrapColor
    config["APLocationColor"] = AP_REF.APLocationColor
	config["APEntranceColor"] = AP_REF.APEntranceColor
    if not json.dump_file("AP_REF.json", config, 4) then
        print("Config cannot be saved!")
    end
end

local function ReadConfig()
    config = json.load_file("AP_REF.json")
    if config ~= nil then
        if config["APCurrentPlayerColor"] ~= nil then
            AP_REF.APCurrentPlayerColor = config["APCurrentPlayerColor"]
        end
        if config["APOtherPlayerColor"] ~= nil then
            AP_REF.APOtherPlayerColor = config["APOtherPlayerColor"]
        end
        if config["APProgessionColor"] ~= nil then
            AP_REF.APProgessionColor = config["APProgessionColor"]
        end
        if config["APUsefulColor"] ~= nil then
            AP_REF.APUsefulColor = config["APUsefulColor"]
        end
        if config["APFillerColor"] ~= nil then
            AP_REF.APFillerColor = config["APFillerColor"]
        end
        if config["APTrapColor"] ~= nil then
            AP_REF.APTrapColor = config["APTrapColor"]
        end
        if config["APLocationColor"] ~= nil then
            AP_REF.APLocationColor = config["APLocationColor"]
        end
		if config["APEntranceColor"] ~= nil then
			AP_REF.APEntranceColor = config["APEntranceColor"]
		end
    else
        SaveConfig()
    end
end

re.on_frame(function()
	if mainWindowVisible then
		main_menu()
	end
end)


re.on_draw_ui(function()
	changed, showWindow = imgui.checkbox("Show Archipelago UI", showMainWindow)
	if changed then
		showMainWindow = showWindow
	end
end)

re.on_script_reset(function()
	AP_REF.APClient = nil
	collectgarbage("collect")
	disconnect_client = false
end)

ReadConfig()

re.on_pre_application_entry("UpdateBehavior", function() 
    --main loop access
	if reframework:is_drawing_ui() and showMainWindow then
		mainWindowVisible = true
	else
		mainWindowVisible = false
	end
	if disconnect_client then
		AP_REF.APClient = nil
		collectgarbage("collect")
		disconnect_client = false
	elseif AP_REF.APClient ~= nil then
		if AP_REF.APClient:get_state() == AP.State.DISCONNECTED then
			connected = false
		else
			connected = true
		end
		AP_REF.APClient:poll()
	else
		connected = false
	end
end)

re.on_config_save(function()
    SaveConfig()
end)

return AP_REF