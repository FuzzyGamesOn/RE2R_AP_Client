local Archipelago = {}
Archipelago.seed = nil
Archipelago.slot = nil
Archipelago.apworld_version = nil -- comes over in slot data
Archipelago.weapon_rando = nil -- comes over in slot data
Archipelago.starting_weapon = nil -- comes over in slot data
Archipelago.all_weapons = nil -- comes over in slot data
Archipelago.ammo_pack_modifier = nil -- comes over in slot data
Archipelago.ammo_pack_type_amount = {} -- used if pack modifier is "random by type"
Archipelago.damage_traps_can_kill = false -- comes over in slot data
Archipelago.death_link = false -- comes over in slot data
Archipelago.hasConnectedPrior = false -- keeps track of whether the player has connected at all so players don't have to remove AP mod to play vanilla
Archipelago.isInit = false -- keeps track of whether init things like handlers need to run
Archipelago.waitingForSync = false -- randomizer calls APSync when "waiting for sync"; i.e., when you die
Archipelago.waitingForInvincibilityOff = false -- occasionally, the game "forgets" who the player is, so this is a backup to toggle off item pickup invincibility
Archipelago.canDeathLink = false -- this gets set to true when you're in-game, then a deathlink can send in game over and this is set to false again, repeat
Archipelago.wasDeathLinked = false -- this gets set to true when we're killed from a deathlink, so we don't trigger another deathlink (and a loop)
Archipelago.didGameOver = false -- this gets set to true when we're killed, so that we know when processing items that another killing trap shouldn't be accepted

Archipelago.itemsQueue = {}
Archipelago.isProcessingItems = false -- this is set to true when the queue is being processed so we don't over-give
Archipelago.hasReceivedItemsBefore = false -- this is set to true when the items received handler is called for the first time on the current connection

-- set the game name in apclientpp
AP_REF.APGameName = "Resident Evil 2 Remake"

function Archipelago.Init()
    if not Archipelago.isInit then
        Archipelago.isInit = true
    end
end

function Archipelago.IsConnected()
    return AP_REF.APClient ~= nil and AP_REF.APClient:get_state() == AP_REF.AP.State.SLOT_CONNECTED
end

function Archipelago.GetPlayer()
    local player = {}

    if AP_REF.APClient == nil then
        return {}
    end

    player["slot"] = AP_REF.APClient:get_slot()
    player["seed"] = AP_REF.APClient:get_seed()
    player["number"] = AP_REF.APClient:get_player_number()
    player["alias"] = AP_REF.APClient:get_player_alias(player['number'])
    player["game"] = AP_REF.APClient:get_player_game(player['number'])

    return player
end

function Archipelago.Sync()
    if AP_REF.APClient == nil then
        return
    end

    SaveData.lastSyncTimestamp = os.time()
    AP_REF.APClient:Sync()
end

function Archipelago.DisableInGameClient(client_message)
    AP_REF.DisableInGameClient(client_message)
end

function Archipelago.EnableInGameClient()
    AP_REF.EnableInGameClient()
end

-- server sends slot data when slot is connected
function APSlotConnectedHandler(slot_data)
    Archipelago.hasConnectedPrior = true
    GUI.AddText('Connected.')

    return Archipelago.SlotDataHandler(slot_data)
end
AP_REF.on_slot_connected = APSlotConnectedHandler

function APSlotDisconnectedHandler()
    GUI.AddText('Disconnected.')
    Lookups.Reset()
end
AP_REF.on_socket_disconnected = APSlotDisconnectedHandler -- there's no "slot disconnected", so this is half as good

function Archipelago.SlotDataHandler(slot_data)
    local player = Archipelago.GetPlayer()

    -- if the player connected to a different seed than we last connected to, reset everything so it will import properly
    if (Archipelago.seed ~= nil and player["seed"] ~= Archipelago.seed) or (Archipelago.slot ~= nil and player["slot"] ~= Archipelago.slot) then
        GUI.AddText('Resetting mods because seed or slot name was changed.')

        Archipelago.Reset()
        Lookups.Reset()
        Storage.Reset()
    end

    Archipelago.seed = player["seed"]
    Archipelago.slot = player["slot"]

    if slot_data.weapon_rando ~= nil then
        Archipelago.weapon_rando = slot_data.weapon_rando
    end

    if slot_data.starting_weapon ~= nil then
        Archipelago.starting_weapon = slot_data.starting_weapon
    end

    if slot_data.all_weapons ~= nil then
        Archipelago.all_weapons = slot_data.all_weapons
    end

    if slot_data.apworld_version ~= nil then
        Archipelago.apworld_version = slot_data.apworld_version
    end

    if slot_data.ammo_pack_modifier ~= nil then
        Archipelago.ammo_pack_modifier = slot_data.ammo_pack_modifier
    end

    if slot_data.damage_traps_can_kill ~= nil then
        Archipelago.damage_traps_can_kill = slot_data.damage_traps_can_kill
    end

    if slot_data.death_link ~= nil then
        Archipelago.death_link = slot_data.death_link
    end

    Lookups.Load(slot_data.character, slot_data.scenario, string.lower(slot_data.difficulty))
    Storage.Load()

    GUI.AddTexts({
        { message='AP Scenario: ' },
        { message=Lookups.character:gsub("^%l", string.upper) .. ' ' .. string.upper(Lookups.scenario) .. ' ' .. string.upper(Lookups.difficulty), color="green" }
    })

    for t, typewriter_name in pairs(slot_data.unlocked_typewriters) do
        Typewriters.AddUnlockedText(typewriter_name, "", true) -- true for "no_save_warning"
        Typewriters.Unlock(typewriter_name, "")
    end
end

-- sent by server when items are received
function APItemsReceivedHandler(items_received)
    return Archipelago.ItemsReceivedHandler(items_received)
end
AP_REF.on_items_received = APItemsReceivedHandler

function Archipelago.ItemsReceivedHandler(items_received)
    local itemsWaiting = {}
    local damageTrapReceived = false
    local poisonTrapReceived = false

    -- add all of the randomized items to an item queue to wait for send
    for k, row in pairs(items_received) do
        -- if the index of the incoming item is greater than the index of our last item at save, check to see if it's randomized
        -- because ONLY non-randomized items escape the queue; everything else gets queued
        if row["index"] ~= nil and (not Storage.lastSavedItemIndex or row["index"] > Storage.lastSavedItemIndex) then
            local item_data = Archipelago._GetItemFromItemsData({ id = row["item"] })
            local item_name = AP_REF.Sanitize(item_data["name"])
            local location_data = nil
            local is_randomized = 1

            if row["location"] ~= nil and row["location"] > 0 then
                location_data = Archipelago._GetLocationFromLocationData({ id = row["location"] })

                if location_data and location_data['raw_data']['randomized'] ~= nil then
                    is_randomized = location_data['raw_data']['randomized']
                end
            end

            if item_name and 
                not (item_name == "Damage Trap" and damageTrapReceived) and
                not (item_name == "Poison Trap" and poisonTrapReceived)
            then
                if item_name == "Damage Trap" then
                    damageTrapReceived = true
                end

                if item_name == "Poison Trap" then
                    poisonTrapReceived = true
                end

                if item_name and row["player"] ~= nil and is_randomized == 0 then
                    Archipelago.ReceiveItem(AP_REF.Sanitize(item_name), row["player"], is_randomized)
                else
                    table.insert(Archipelago.itemsQueue, row)
                    table.insert(itemsWaiting, item_name)
                end
            end
        end
    end

    if not Archipelago.CanReceiveItems() and #itemsWaiting > 0 then
        if Scene.isCharacterAda() or Scene.isCharacterSherry() then
            GUI.AddTexts({
                { message="Item(s) waiting for main character: " },
                { message=table.concat(itemsWaiting, ", "), color=AP_REF.HexToImguiColor("AAAAAA") }
            })
            
        else
            GUI.AddTexts({
                { message="Item(s) waiting for nearby item box: " },
                { message=table.concat(itemsWaiting, ", "), color=AP_REF.HexToImguiColor("AAAAAA") }
            })
        end
    end

    Archipelago.hasReceivedItemsBefore = true
end

function Archipelago.CanReceiveItems()
    -- wait until the player is in game, with AP connected, and with an available item box (that's not in use), and with a reachable inventory
    -- before sending any items over
    return Scene.isInGame() and Archipelago.IsConnected() and ItemBox.GetAnyAvailable() ~= nil and not Scene.isUsingItemBox() 
        and Inventory.GetPlayerInventory() ~= nil and (Scene.isCharacterClaire() or Scene.isCharacterLeon())
end

function Archipelago.CanBeKilled()
    -- wait until the player is in game, with AP connected, before attempting to kill them from a deathlink
    return Scene.isInGame() and Archipelago.IsConnected()
end

function Archipelago.ProcessItemsQueue()
    -- if we're already processing items, wait for that to finish
    if Archipelago.isProcessingItems then
        return
    end

    if #Archipelago.itemsQueue == 0 then
        Archipelago.isProcessingItems = false
        return
    end
    
    Archipelago.isProcessingItems = true
    local items = Archipelago.itemsQueue
    Archipelago.itemsQueue = {}

    for k, row in pairs(items) do
        -- if the index of the incoming item is greater than the index of our last item at save, accept it
        if row["index"] ~= nil and (not Storage.lastSavedItemIndex or row["index"] > Storage.lastSavedItemIndex) then
            local item_data = Archipelago._GetItemFromItemsData({ id = row["item"] })
            local item_name = AP_REF.Sanitize(item_data["name"])
            local location_data = nil
            local is_randomized = 1

            if row["location"] ~= nil and row["location"] > 0 then
                location_data = Archipelago._GetLocationFromLocationData({ id = row["location"] })

                if location_data and location_data['raw_data']['randomized'] ~= nil then
                    is_randomized = location_data['raw_data']['randomized']
                end
            end

            if item_name and row["player"] ~= nil then
                -- if the player game over'd and they're being sent a damage trap right after respawn, ignore / don't receive it
                if Archipelago.didGameOver and item_name == "Damage Trap" then
                    GUI.AddText("Received Damage Trap, but currently respawning. Ignoring.")
                else
                    Archipelago.ReceiveItem(item_name, row["player"], is_randomized)
                end
            end

            -- if the index is also greater than the index of our last received index, update last received
            if row["index"] ~= nil and (not Storage.lastReceivedItemIndex or row["index"] > Storage.lastReceivedItemIndex) then
                Storage.lastReceivedItemIndex = row["index"]
            end
        end
    end

    Storage.Update()

    Archipelago.didGameOver = false -- once items have been received once after GO'ing, let the player die to traps again
    Archipelago.isProcessingItems = false -- unset for the next bit of processing
end

-- sent by server when locations are checked (collect, etc.?)
function APLocationsCheckedHandler(locations_checked)
    return Archipelago.LocationsCheckedHandler(locations_checked)
end
AP_REF.on_location_checked = APLocationsCheckedHandler

function Archipelago.LocationsCheckedHandler(locations_checked)
    local player = Archipelago.GetPlayer()
    
    -- if we received locations that were collected out, mark them sent so we don't get anything from it
    for k, location_id in pairs(locations_checked) do
        local location_name = AP_REF.APClient:get_location_name(tonumber(location_id), player['game'])
        local scenario_suffix = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. ")"
        local scenario_suffix_hardcore = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. "H)"

        for k, loc in pairs(Lookups.locations) do
            local location_name_with_region = loc['region'] .. scenario_suffix .. " - " .. loc['name']
            local location_name_with_region_hardcore = loc['region'] .. scenario_suffix_hardcore .. " - " .. loc['name']

            if location_name_with_region == location_name or location_name_with_region_hardcore == location_name then
                loc['sent'] = true

                break
            end
        end
    end
end

-- called when server is sending JSON data of some sort?
function APPrintJSONHandler(json_rows)
    return Archipelago.PrintJSONHandler(json_rows)
end
AP_REF.on_print_json = APPrintJSONHandler

function Archipelago.PrintJSONHandler(json_rows)
    local player_sender, player_receiver, sender_number, receiver_number, item_id, location_id, item, location = nil
    local player = Archipelago.GetPlayer()

    -- if it's a hint, ignore it and return
    if #json_rows > 0 and json_rows[1]["text"] ~= nil and string.find(json_rows[1]["text"], "[Hint]") then
        return
    end

    for k, row in pairs(json_rows) do
        -- if it's a player id and no sender is set, it's the sender
        if row["type"] ~= nil and row["type"] == "player_id" and not player_sender then
            player_sender = AP_REF.APClient:get_player_alias(tonumber(row["text"]))
            sender_number = tonumber(row["text"])
        -- if it's a player id and the sender is set, it's the receiver
        elseif row["type"] ~= nil and row["type"] == "player_id" and player_sender then
            player_receiver = AP_REF.APClient:get_player_alias(tonumber(row["text"]))        
            receiver_number = tonumber(row["text"])
        elseif row["type"] ~= nil and row["type"] == "item_id" then
            item_id = tonumber(row["text"])            
            
            if (row["flags"] & 1) > 0 then
                item_color = "ce28f7"
            elseif (row["flags"] & 2) > 0 then
                item_color = AP_REF.APUsefulColor
            elseif (row["flags"] & 4) > 0 then
                item_color = AP_REF.APTrapColor
            else
                item_color = "06bda1"
            end
        elseif row["type"] ~= nil and row["type"] == "location_id" then
            location_id = tonumber(row["text"])
        end
    end
    
    if player_sender and item_id and player_receiver and location_id then
        -- if we received, items received will give us the message
        -- if we sent, we want the text here
        -- everything else, don't care.
        if player['alias'] ~= nil and player_sender == player['alias'] then
            if not Storage.lastSavedItemIndex or row == nil or row["index"] == nil or row["index"] > Storage.lastSavedItemIndex then
                if player_receiver then
                    item = AP_REF.APClient:get_item_name(item_id, AP_REF.APClient:get_player_game(receiver_number))
                    location = AP_REF.APClient:get_location_name(location_id, player['game'])

                    GUI.AddSentItemText(player_sender, item, item_color, player_receiver, location)
                end
            end
        end
    end
end

-- called when we send a "Bounce" packet for sending to another game, for things like DeathLink
function APBouncedHandler(json_rows)
    return Archipelago.BouncedHandler(json_rows)
end
AP_REF.on_bounced = APBouncedHandler

function Archipelago.BouncedHandler(json_rows) 
    -- {
    --  "data" : {
    --      "source": "FuzzyLTTP",
    --      "cause": "FuzzyLTTP ran out of hearts.",
    --      "time": 346345764357
    --  },
    --  "cmd": "Bounced"
    --  "tags": { "DeathLink" }
    --  }
    -- }
    
    -- if deathlink isn't enabled, don't receive deathlinks
    if not Archipelago.death_link then
        return
    end

    if json_rows ~= nil and json_rows["tags"] ~= nil then
        -- why doesn't Lua have a way to "find" a value in a table? do we really have to create this from scratch?!
        for k, tag in pairs(json_rows["tags"]) do
            if tag == "DeathLink" then
                if Archipelago.CanBeKilled() then
                    if json_rows["data"]["cause"] then
                        GUI.AddTexts({
                            { message="Deathlink received: " },
                            { message=tostring(json_rows["data"]["cause"]), color="green" }
                        })
                    else
                        GUI.AddTexts({
                            { message="Deathlink received from: " },
                            { message=tostring(json_rows["data"]["source"]), color="green" }
                        })
                    end

                    Archipelago.wasDeathLinked = true
                    Player.Kill()
                end
                
                break
            end
        end
    end
end

function Archipelago.IsItemLocation(location_data)
    location_data = Archipelago.SanitizeLocationData(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data, true) -- include_sent_locations

    if not location then
        return false
    end

    return true
end

function Archipelago.IsLocationRandomized(location_data)
    location_data = Archipelago.SanitizeLocationData(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data, true) -- include_sent_locations

    if not location then
        return false
    end
    
    if location['raw_data']['randomized'] == 0 and not location['raw_data']['force_item'] then
        return false
    end

    return true
end

function Archipelago.IsSentChessPanel(location_data)
    location_data = Archipelago.SanitizeLocationData(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data, true) -- include_sent_locations
    local scenario_suffix = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. ")"
    local scenario_suffix_hardcore = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. "H)"

    if not location then
        return false
    end

    if string.find(location['name'], 'Queen Panel') or string.find(location['name'], 'King Panel') or string.find(location['name'], 'Rook Panel') or 
        string.find(location['name'], 'Bishop Panel') or string.find(location['name'], 'Knight Panel') or string.find(location['name'], 'Pawn Panel') then 

        for k, loc in pairs(Lookups.locations) do
            local location_name_with_region = loc['region'] .. scenario_suffix .. " - " .. loc['name']
            local location_name_with_region_hardcore = loc['region'] .. scenario_suffix_hardcore .. " - " .. loc['name']

            if Lookups.difficulty == 'hardcore' and location['name'] == location_name_with_region_hardcore and loc['sent'] ~= nil and loc['sent'] then
                return true
            elseif location['name'] == location_name_with_region and loc['sent'] ~= nil and loc['sent'] then
                return true
            end
        end
    end

    return false
end

function Archipelago.GetLocationName(location_data)
    location_data = Archipelago.SanitizeLocationData(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data, true) -- include_sent_locations

    if not location then
        return ""
    end

    return location["name"]
end

function Archipelago.CheckForVictoryLocation(location_data)
    location_data = Archipelago.SanitizeLocationData(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data)

    if location ~= nil and location["raw_data"]["victory"] then
        Archipelago.SendVictory()

        return true
    end
    
    return false
end

function Archipelago.SanitizeLocationData(location_data)
    -- remove any character in an item or parent name that is not a letter, number, space, or a handful of symbols
    location_data['item_object'] = location_data['item_object']:gsub("[^A-Za-z0-9()'-_ ]", "")
    location_data['parent_object'] = location_data['parent_object']:gsub("[^A-Za-z0-9()'-_ ]", "")

    return location_data
end

-- Returns:
--   - true if location was sent with no issues
--   - false if location was not sent because it has been sent prior
--   - nil if location was not sent because the AP call failed
function Archipelago.SendLocationCheck(location_data, warn_existing_location)
    if warn_existing_location == nil then
        warn_existing_location = true
    end

    location_data = Archipelago.SanitizeLocationData(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data)
    local location_ids = {}

    if not location or not location['id'] or (location['id'] ~= nil and tonumber(location['id']) < 0) then
        -- if location wasn't found in session unsent locations, check all locations to make sure it's not a wrongly named location (indicating a version mismatch)
        -- if so, show a message; if not, just bail out of here since there's nothing to send
        local location_existing = Archipelago._GetLocationFromLocationData(location_data, true)

        if not location_existing['id'] or (location_existing['id'] ~= nil and tonumber(location_existing['id']) < 0) then
            GUI.AddTexts({
                { message="Invalid location.", color=AP_REF.HexToImguiColor('fa3d2f') },
                { message=" You tried to check " },
                { message=location_existing['name'], color=AP_REF.HexToImguiColor("d9d904") },
                { message=", but it does not exist in the multiworld. " }
            })

            GUI.AddTexts({
                { message="Your apworld version and client version must match.", color=AP_REF.HexToImguiColor('fa3d2f') }
            })
        elseif warn_existing_location then -- enemy kills don't warn because dead enemies respawn and "die" when in range
            GUI.AddTexts({
                { message="Location already checked or collected: ", color=AP_REF.HexToImguiColor("AAAAAA") },
                { message=location_existing['name'] },
                { message=".", color=AP_REF.HexToImguiColor("AAAAAA") }
            })
        end

        return false
    end

    location_ids[1] = location["id"]

    local result = nil

    if Archipelago.IsConnected() then
        result = AP_REF.APClient.LocationChecks(AP_REF.APClient, location_ids)
    end

    if not result then
        return nil
    end

    local sent_loc = location['raw_data']    

    for k, loc in pairs(Lookups.locations) do
        -- StartArea/SherryRoom is the shotgun shell location at start of Labs that can *also* be a shotgun if you haven't gotten one
        -- and it's only 1 location so, if it's there, match it regardless of anything else
        if (string.find(loc['folder_path'], 'StartArea/SherryRoom') and string.find(location_data['folder_path'], 'StartArea/SherryRoom')) or 
            (string.find(loc['folder_path'], 'StartArea/Sherry Room') and string.find(location_data['folder_path'], 'StartArea/Sherry Room')) 
        then
            loc['sent'] = true
            break
        end

        local exact_match = true

        -- check that the location is an exact match of the location's raw data that came back from the lookup
        for lk, lv in pairs(sent_loc) do
            if not loc[lk] or loc[lk] ~= sent_loc[lk] then
                exact_match = false
                break -- if not, skip
            end
        end

        if exact_match then
            loc['sent'] = true
            break
        end
    end

    return true
end

function Archipelago.SendDeathLink()
    -- if deathlink isn't enabled, don't send deathlinks
    if not Archipelago.death_link then
        return
    end

    local player_self = Archipelago.GetPlayer()
    local timeOfDeath = math.floor(AP_REF.APClient:get_server_time())
    local playerName = tostring(player_self.alias)

    local deathLinkData = {
        time = timeOfDeath,
        cause = playerName .. " died.",
        source = playerName
    }

    AP_REF.APClient:Bounce(deathLinkData, nil, nil, { "DeathLink" }) -- data, games, slots, tags
end

function Archipelago.ReceiveItem(item_name, sender, is_randomized)
    local item_ref = nil
    local item_number = nil
    local item_ammo = nil

    -- check for specific duplicates and, if true, don't receive this copy since we already have one
    if ItemDuplicates.Check(item_name) then
        GUI.AddText("Received a " .. item_name .. ", but you already have one. Skipping.")
        return
    end

    for k, item in pairs(Lookups.items) do
        if AP_REF.Sanitize(item.name) == item_name then
            item_ref = item
            item_number = item.decimal
            
            -- if it's a weapon, look up its ammo as well and set to item_ammo
            if item.type == "Weapon" and item.ammo ~= nil then
                for k2, item2 in pairs(Lookups.items) do
                    if AP_REF.Sanitize(item2.name) == item.ammo then
                        item_ammo = item2.decimal

                        break
                    end
                end
            end

            break
        end
    end

    if item_ref and item_number then
        local itemId, weaponId, weaponParts, bulletId, count = nil

        if item_ref.type == "Weapon" or item_ref.type == "Subweapon" then
            itemId = -1
            weaponId = item_number

            if item_ref.type == "Weapon" then
                bulletId = item_ammo
            end
        else
            itemId = item_number
            weaponId = -1
        end

        count = item_ref.count

        if count == nil then
            count = 1
        end

        if item_ref.type == "Ammo" and Archipelago.ammo_pack_modifier ~= "None" then
            local pmod = Archipelago.ammo_pack_modifier -- typing is hard
            local random_min = 1
            local random_max = math.ceil(count * 1.5) -- originally did 2x here, but high rolls made things too easy, this balanced out some

            -- if Max, cap the ammo at the game's defined maximum for each ammo pack (if the pack count is green in-game, it's at the max)
            if pmod == "Max" then 
                local ammo_maxes = {
                    ["Handgun Ammo"] = 60,
                    ["Large-Caliber Handgun Ammo"] = 60,
                    ["Shotgun Shells"] = 20,
                    ["Submachine Gun Ammo"] = 200,
                    ["MAG Ammo"] = 20,
                    ["High-Powered Rounds"] = 20,
                    ["Flame Rounds"] = 10,
                    ["Acid Rounds"] = 10,
                    ["Flamethrower Fuel"] = 400,
                    ["Needle Cartridges"] = 100
                }

                if ammo_maxes[item_ref.name] ~= nil then
                    count = ammo_maxes[item_ref.name]
                else
                    count = 500
                end
            end
            if pmod == "Double" then count = count * 2 end
            if pmod == "Half" then count = math.ceil(count / 2) end
            if pmod == "Only Three" then count = 3 end
            if pmod == "Only Two" then count = 2 end
            if pmod == "Only One" then count = 1 end
            if pmod == "Random Always" then count = math.random(random_min, random_max) end
            
            if pmod == "Random By Type" then
                if Archipelago.ammo_pack_type_amount[item_name] == nil then
                    Archipelago.ammo_pack_type_amount[item_name] = math.random(random_min, random_max)
                end

                count = Archipelago.ammo_pack_type_amount[item_name]
            end
        end

        if item_ref.progression == 1 then
            item_color = "ce28f7"
        elseif item_ref.type ~= "Lore" and item_ref.type ~= "Trap" then
            item_color = AP_REF.APUsefulColor
        elseif item_ref.type == "Trap" then
            item_color = AP_REF.APTrapColor
        else
            item_color = "06bda1"
        end
        
        local player_self = Archipelago.GetPlayer()
        local sentToBox = false

        if sender == nil then
            sender = player_self.number
        end

        if is_randomized > 0 then
            if item_name == "Damage Trap" then
                Player.Damage(Archipelago.damage_traps_can_kill)
                GUI.AddReceivedItemText(item_name, item_color, tostring(AP_REF.APClient:get_player_alias(sender)), tostring(player_self.alias), sentToBox)

                return
            end

            if item_name == "Poison Trap" then
                Player.Poison()
                GUI.AddReceivedItemText(item_name, item_color, tostring(AP_REF.APClient:get_player_alias(sender)), tostring(player_self.alias), sentToBox)

                return
            end

            -- max slots is 20, so only process a new hip pouch if it will result in no more than 20
            if item_name == "Hip Pouch" then
                if Inventory.GetMaxSlots() <= 18 then
                    Inventory.IncreaseMaxSlots(2) -- simulate receiving the hip pouch by increasing player inv slots by 2
                    GUI.AddReceivedItemText(item_name, item_color, tostring(AP_REF.APClient:get_player_alias(sender)), tostring(player_self.alias), sentToBox)
                else
                    GUI.AddText("Received Hip Pouch, but inventory is at maximum size. Ignoring.")
                end

                return
            end

            -- sending weapons to inventory causes them to not work until boxed + retrieved, so send weapons to box always for now
            -- also send 2-slot wide items to box by default
            if 
                item_ref.type ~= "Weapon" and item_ref.type ~= "Subweapon" and Inventory.HasSpaceForItem() and
                (item_name ~= "Large Gear" and item_name ~= "Joint Plug")
            then
                local addedToInv = Inventory.AddItem(tonumber(itemId), tonumber(weaponId), weaponParts, bulletId, tonumber(count))

                -- if adding to inventory failed, add it to the box as a backup
                if addedToInv then
                    sentToBox = false
                else
                    ItemBox.AddItem(tonumber(itemId), tonumber(weaponId), weaponParts, bulletId, tonumber(count))
                    sentToBox = true    
                end
            -- if this item is a weapon/subweapon or the player doesn't have room in inventory, send to the box
            else
                ItemBox.AddItem(tonumber(itemId), tonumber(weaponId), weaponParts, bulletId, tonumber(count))
                sentToBox = true
            end
        end

        GUI.AddReceivedItemText(item_name, item_color, tostring(AP_REF.APClient:get_player_alias(sender)), tostring(player_self.alias), sentToBox)
    end
end

function Archipelago.SendVictory()
    AP_REF.APClient:StatusUpdate(AP_REF.AP.ClientStatus.GOAL)   
end

function Archipelago.GatekeepDifficultOptions()
    -- if the rando isn't connected, or none of the problematic options are set, nothing to do
    if not Archipelago.IsConnected() or (not Archipelago.death_link and not Archipelago.damage_traps_can_kill) then
        return
    end

    -- if the player hasn't beaten at least 1 of the scenarios, any one of them, turn off expert-level options due to lack of player experience
    if not (Records.hasBeatenLeonA() or Records.hasBeatenClaireA() or Records.hasBeatenLeonB() or Records.hasBeatenClaireB()) then
        if Archipelago.death_link or Archipelago.damage_traps_can_kill then
            GUI.AddText("Some advanced options are being disabled because ", "gray")
            GUI.AddText("you haven't beaten the game before.", "gray")
        end

        if Archipelago.death_link then
            GUI.AddText("Deathlink has been disabled.")
            Archipelago.death_link = false
        end

        if Archipelago.damage_traps_can_kill then
            GUI.AddText("Damage Traps Can Kill has been disabled.")
            Archipelago.damage_traps_can_kill = false
        end
    end
end

function Archipelago._GetItemFromItemsData(item_data)
    local player = Archipelago.GetPlayer()
    local translated_item = {}
    
    translated_item['name'] = AP_REF.APClient:get_item_name(item_data['id'], player['game'])

    if not translated_item['name'] then
        return nil
    end

    translated_item['id'] = item_data['id']

    -- now that we have name and id, return them
    return translated_item
end

function Archipelago._GetLocationFromLocationData(location_data, include_sent_locations)
    local player = Archipelago.GetPlayer()

    include_sent_locations = include_sent_locations or false

    local translated_location = {}
    local scenario_suffix = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. ")"
    local scenario_suffix_hardcore = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. "H)"

    if location_data['id'] and not location_data['name'] then
        location_data['name'] = AP_REF.APClient:get_location_name(location_data['id'], player['game'])
    end

    -- if the difficulty is hardcore, loop first looking for hardcore locations only so we can prioritize matching those
    if Lookups.difficulty == 'hardcore' then
        for k, loc in pairs(Lookups.locations) do
            if loc['hardcore'] ~= nil and loc['hardcore'] then -- if it doesn't have the hardcore attribute, it's not a hardcore location, skip it for later
                location_name_with_region_hardcore = loc['region'] .. scenario_suffix_hardcore .. " - " .. loc['name']
        
                if location_data['name'] == location_name_with_region_hardcore then
                    translated_location['name'] = location_name_with_region_hardcore
                    translated_location['raw_data'] = loc
        
                    break
                end
        
                if include_sent_locations or not loc['sent'] then
                    -- StartArea/SherryRoom is the shotgun shell location at start of Labs that can *also* be a shotgun if you haven't gotten one
                    -- and it's only 1 location so, if it's there, match it regardless of item object + parent object
                    if (loc['item_object'] == location_data['item_object'] and loc['parent_object'] == location_data['parent_object'] and loc['folder_path'] == location_data['folder_path']) or
                        (loc['folder_path'] ~= nil and location_data['folder_path'] ~= nil and string.find(loc['folder_path'], 'StartArea/SherryRoom') and string.find(location_data['folder_path'], 'StartArea/SherryRoom')) or 
                        (loc['folder_path'] ~= nil and location_data['folder_path'] ~= nil and string.find(loc['folder_path'], 'StartArea/Sherry Room') and string.find(location_data['folder_path'], 'StartArea/Sherry Room')) 
                    then
                        translated_location['name'] = location_name_with_region_hardcore
                        translated_location['raw_data'] = loc
        
                        break
                    end
                end
            end
        end
    end -- end if hardcore diff and looking for hardcore locations

    -- if it's not hardcore difficulty or if the location wasn't matched to a hardcore one, match standard locations instead
    if not translated_location['name'] then
        for k, loc in pairs(Lookups.locations) do
            if not (loc['hardcore'] ~= nil and loc['hardcore']) then -- if it's a hardcore location, we want to skip it here, since we're only handling standards
                location_name_with_region = loc['region'] .. scenario_suffix .. " - " .. loc['name']

                if location_data['name'] == location_name_with_region then
                    translated_location['name'] = location_name_with_region
                    translated_location['raw_data'] = loc

                    break
                end

                if include_sent_locations or not loc['sent'] then
                    -- StartArea/SherryRoom is the shotgun shell location at start of Labs that can *also* be a shotgun if you haven't gotten one
                    -- and it's only 1 location so, if it's there, match it regardless of item object + parent object
                    if (loc['item_object'] == location_data['item_object'] and loc['parent_object'] == location_data['parent_object'] and loc['folder_path'] == location_data['folder_path']) or
                        (loc['folder_path'] ~= nil and location_data['folder_path'] ~= nil and string.find(loc['folder_path'], 'StartArea/SherryRoom') and string.find(location_data['folder_path'], 'StartArea/SherryRoom')) or 
                        (loc['folder_path'] ~= nil and location_data['folder_path'] ~= nil and string.find(loc['folder_path'], 'StartArea/Sherry Room') and string.find(location_data['folder_path'], 'StartArea/Sherry Room')) 
                    then
                        translated_location['name'] = location_name_with_region
                        translated_location['raw_data'] = loc

                        break
                    end
                end
            end
        end
    end -- end if standard diff and looking for standard locations

    if not translated_location['name'] then
        return nil
    end

    translated_location['id'] = AP_REF.APClient:get_location_id(translated_location['name'], player['game'])

    -- now that we have name and id, return them
    return translated_location
end

function Archipelago.Reset()
    Archipelago.seed = nil
    Archipelago.slot = nil
    Archipelago.starting_weapon = nil
    Archipelago.damage_traps_can_kill = false
    Archipelago.death_link = false
    Archipelago.itemsQueue = {}
    Archipelago.hasReceivedItemsBefore = false
end

return Archipelago
