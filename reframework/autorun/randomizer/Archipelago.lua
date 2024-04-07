local Archipelago = {}
Archipelago.hasConnectedPrior = false -- keeps track of whether the player has connected at all so players don't have to remove AP mod to play vanilla
Archipelago.isInit = false -- keeps track of whether init things like handlers need to run
Archipelago.waitingForSync = false -- randomizer calls APSync when "waiting for sync"; i.e., when you die

Archipelago.itemsQueue = {}
Archipelago.isProcessingItems = false -- this is set to true when the queue is being processed so we don't over-give

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
    player["alias"] = AP_REF.APClient:get_player_alias(player.number)

    return player
end

function Archipelago.Sync()
    if AP_REF.APClient == nil then
        return
    end

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
end
AP_REF.on_socket_disconnected = APSlotDisconnectedHandler -- there's no "slot disconnected", so this is half as good

function Archipelago.SlotDataHandler(slot_data)
    Lookups.load(slot_data.character, slot_data.scenario, string.lower(slot_data.difficulty))
    Storage.Load()

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
    local itemsWaiting = 0

    -- add all of the randomized items to an item queue to wait for send
    for k, row in pairs(items_received) do
        -- if the index of the incoming item is greater than the index of our last item at save, check to see if it's randomized
        -- because ONLY non-randomized items escape the queue; everything else gets queued
        if row["index"] ~= nil and (not Storage.lastSavedItemIndex or row["index"] > Storage.lastSavedItemIndex) then
            local item_data = Archipelago._GetItemFromItemsData({ id = row["item"] })
            local location_data = nil
            local is_randomized = 1

            if row["location"] ~= nil and row["location"] > 0 then
                location_data = Archipelago._GetLocationFromLocationData({ id = row["location"] })

                if location_data and location_data['raw_data']['randomized'] ~= nil then
                    is_randomized = location_data['raw_data']['randomized']
                end
            end

            if item_data["name"] and row["player"] ~= nil and is_randomized == 0 then
                Archipelago.ReceiveItem(item_data["name"], row["player"], is_randomized)
            else
                table.insert(Archipelago.itemsQueue, row)
                itemsWaiting = itemsWaiting + 1
            end
        end
    end

    if not Archipelago.CanReceiveItems() and itemsWaiting > 0 then
        GUI.OnceText("Item(s) received, waiting for nearby item box.")
    end
end

function Archipelago.CanReceiveItems()
    -- wait until the player is in game, with AP connected, and with an available item box (that's not in use)
    -- before sending any items over
    return Scene.isInGame() and Archipelago.IsConnected() and ItemBox.GetAnyAvailable() ~= nil and not Scene.isUsingItemBox() 
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
            local location_data = nil
            local is_randomized = 1

            if row["location"] ~= nil and row["location"] > 0 then
                location_data = Archipelago._GetLocationFromLocationData({ id = row["location"] })

                if location_data and location_data['raw_data']['randomized'] ~= nil then
                    is_randomized = location_data['raw_data']['randomized']
                end
            end

            if item_data["name"] and row["player"] ~= nil then
                Archipelago.ReceiveItem(item_data["name"], row["player"], is_randomized)
            end

            -- if the index is also greater than the index of our last received index, update last received
            if row["index"] ~= nil and (not Storage.lastReceivedItemIndex or row["index"] > Storage.lastReceivedItemIndex) then
                Storage.lastReceivedItemIndex = row["index"]
            end
        end
    end

    Storage.Update()
    Archipelago.isProcessingItems = false -- unset for the next bit of processing
end

-- sent by server when locations are checked (collect, etc.?)
function APLocationsCheckedHandler(locations_checked)
    return Archipelago.LocationsCheckedHandler(locations_checked)
end
AP_REF.on_location_checked = APLocationsCheckedHandler

function Archipelago.LocationsCheckedHandler(locations_checked)
    -- for k, row in pairs(locations_checked) do
    --     log.debug("k " .. tostring(k) .. ": " .. tostring(row))
    -- end

    -- if we received locations that were collected out, mark them sent so we don't get anything from it
    for k, location_id in pairs(locations_checked) do
        local location_name = AP_REF.APClient:get_location_name(tonumber(location_id))

        for k, loc in pairs(Lookups.locations) do
            if loc['name'] == location_name then
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
    local player_sender, item, player_receiver, location = nil
    local player = Archipelago.GetPlayer()

    -- if it's a hint, ignore it and return
    if #json_rows > 0 and json_rows[1]["text"] ~= nil and string.find(json_rows[1]["text"], "[Hint]") then
        return
    end

    for k, row in pairs(json_rows) do
        -- if it's a player id and no sender is set, it's the sender
        if row["type"] ~= nil and row["type"] == "player_id" and not player_sender then
            player_sender = AP_REF.APClient:get_player_alias(tonumber(row["text"]))

        -- if it's a player id and the sender is set, it's the receiver
        elseif row["type"] ~= nil and row["type"] == "player_id" and player_sender then
            player_receiver = AP_REF.APClient:get_player_alias(tonumber(row["text"]))

        elseif row["type"] ~= nil and row["type"] == "item_id" then
            item = AP_REF.APClient:get_item_name(tonumber(row["text"]))
        elseif row["type"] ~= nil and row["type"] == "location_id" then
            location = AP_REF.APClient:get_location_name(tonumber(row["text"]))
        end
    end

    if player_sender and item and player_receiver and location then
        -- if we received, items received will give us the message
        -- if we sent, we want the text here
        -- everything else, don't care.
        if player['alias'] ~= nil and player_sender == player['alias'] then
            if not Storage.lastSavedItemIndex or row == nil or row["index"] == nil or row["index"] > Storage.lastSavedItemIndex then
                if player_receiver then
                    GUI.AddSentItemText(player_sender, item, player_receiver, location)
                else
                    GUI.AddSentItemSelfText(player_sender, item, location)
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

-- leaving debug here for whenever deathlink gets added
function Archipelago.BouncedHandler(json_rows) 
    log.debug("bounced: ")

    for k, v in pairs(json_rows) do
        log.debug("key " .. tostring(k) .. " is: " .. tostring(v))
    end
end

function Archipelago.IsItemLocation(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data, true) -- include_sent_locations

    if not location then
        return false
    end

    return true
end

function Archipelago.IsLocationRandomized(location_data)
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
    local location = Archipelago._GetLocationFromLocationData(location_data, true) -- include_sent_locations
    local scenario_suffix = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. ")"
    local scenario_suffix_hardcore = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. "H)"

    if not location then
        return false
    end

    if string.find(location['name'], 'Queen Panel') or string.find(location['name'], 'King Panel') or string.find(location['name'], 'Rook Panel') or 
        string.find(location['name'], 'Bishop Panel') or string.find(location['name'], 'Knight Panel') or string.find(location['name'], 'Pawn Panel') then 

        for k, loc in pairs(Lookups.locations) do
            location_name_with_region = loc['region'] .. scenario_suffix .. " - " .. loc['name']
            location_name_with_region_hardcore = loc['region'] .. scenario_suffix_hardcore .. " - " .. loc['name']

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
    local location = Archipelago._GetLocationFromLocationData(location_data, true) -- include_sent_locations

    if not location then
        return ""
    end

    return location["name"]
end

function Archipelago.CheckForVictoryLocation(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data)

    if location ~= nil and location["raw_data"]["victory"] then
        Archipelago.SendVictory()

        return true
    end
    
    return false
end

function Archipelago.SendLocationCheck(location_data)
    local location = Archipelago._GetLocationFromLocationData(location_data)
    local location_ids = {}

    if not location then
        return false
    end

    location_ids[1] = location["id"]

    local result = AP_REF.APClient.LocationChecks(AP_REF.APClient, location_ids)

    for k, loc in pairs(Lookups.locations) do
        -- StartArea/SherryRoom is the shotgun shell location at start of Labs that can *also* be a shotgun if you haven't gotten one
        -- and it's only 1 location so, if it's there, match it regardless of item object + parent object
        if (loc['item_object'] == location_data['item_object'] and loc['parent_object'] == location_data['parent_object'] and loc['folder_path'] == location_data['folder_path']) or
            (string.find(loc['folder_path'], 'StartArea/SherryRoom') and string.find(location_data['folder_path'], 'StartArea/SherryRoom')) or 
            (string.find(loc['folder_path'], 'StartArea/Sherry Room') and string.find(location_data['folder_path'], 'StartArea/Sherry Room')) 
        then
            loc['sent'] = true
            
            break
        end
    end

    return true
end

function Archipelago.ReceiveItem(item_name, sender, is_randomized)
    local item_ref = nil
    local item_number = nil
    local item_ammo = nil

    for k, item in pairs(Lookups.items) do
        if item.name == item_name then
            item_ref = item
            item_number = item.decimal
            
            -- if it's a weapon, look up its ammo as well and set to item_ammo
            if item.type == "Weapon" and item.ammo ~= nil then
                for k2, item2 in pairs(Lookups.items) do
                    if item2.name == item.ammo then
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

        local player_self = Archipelago.GetPlayer()
        local sentToBox = false

        if is_randomized > 0 then
            if item_name == "Hip Pouch" then
                Inventory.IncreaseMaxSlots(2) -- simulate receiving the hip pouch by increasing player inv slots by 2
                GUI.AddReceivedItemText(item_name, tostring(AP_REF.APClient:get_player_alias(sender)), tostring(player_self.alias), sentToBox)

                return
            end

            -- sending weapons to inventory causes them to not work until boxed + retrieved, so send weapons to box always for now
            if item_ref.type ~= "Weapon" and item_ref.type ~= "Subweapon" and Inventory.HasSpaceForItem() then
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

        GUI.AddReceivedItemText(item_name, tostring(AP_REF.APClient:get_player_alias(sender)), tostring(player_self.alias), sentToBox)
    end
end

function Archipelago.SendVictory()
    AP_REF.APClient:StatusUpdate(AP_REF.AP.ClientStatus.GOAL)   
end

function Archipelago._GetItemFromItemsData(item_data)
    local translated_item = {}
    
    translated_item['name'] = AP_REF.APClient:get_item_name(item_data['id'])

    if not translated_item['name'] then
        return nil
    end

    translated_item['id'] = item_data['id']

    -- now that we have name and id, return them
    return translated_item
end

function Archipelago._GetLocationFromLocationData(location_data, include_sent_locations)
    include_sent_locations = include_sent_locations or false

    local translated_location = {}
    local scenario_suffix = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. ")"
    local scenario_suffix_hardcore = " (" .. string.upper(string.sub(Lookups.character, 1, 1) .. Lookups.scenario) .. "H)"

    if location_data['id'] and not location_data['name'] then
        location_data['name'] = AP_REF.APClient:get_location_name(location_data['id'])
    end

    for k, loc in pairs(Lookups.locations) do
        location_name_with_region = loc['region'] .. scenario_suffix .. " - " .. loc['name']
        location_name_with_region_hardcore = loc['region'] .. scenario_suffix_hardcore .. " - " .. loc['name']

        if Lookups.difficulty == 'hardcore' and location_data['name'] == location_name_with_region_hardcore then
            translated_location['name'] = location_name_with_region_hardcore
            translated_location['raw_data'] = loc

            break
        elseif location_data['name'] == location_name_with_region then
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
                if loc['hardcore'] ~= nil and loc['hardcore'] then
                    translated_location['name'] = location_name_with_region_hardcore
                else
                    translated_location['name'] = location_name_with_region
                end

                translated_location['raw_data'] = loc

                break
            end
        end
    end
    
    if not translated_location['name'] then
        return nil
    end

    translated_location['id'] = AP_REF.APClient:get_location_id(translated_location['name'])

    -- now that we have name and id, return them
    return translated_location
end

return Archipelago
