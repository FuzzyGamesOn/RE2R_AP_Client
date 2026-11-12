local Storage = {}
Storage.storageInitialized = false
Storage.lastReceivedItemIndex = -1
Storage.lastSavedItemIndex = -1
Storage.talkedToMarvin = false
Storage.openedChiefDoor = false
Storage.finishedG1 = false
Storage.typewritersActive = true
Storage.receivedItemNames = {}

function Storage.Load()
    local existing_file = json.load_file(Storage.GetFilePath())
    
    if existing_file ~= nil then
        local unlocked_typewriters = existing_file['unlocked_typewriters'] or {}

        Storage.lastReceivedItemIndex = existing_file['last_received']
        Storage.lastSavedItemIndex = existing_file['last_saved']
        Storage.talkedToMarvin = existing_file['talked_to_marvin'] or false
        Storage.openedChiefDoor = existing_file['opened_chief_door'] or false
        Storage.finishedG1 = existing_file['finished_g1'] or false
        Storage.swappedStartingWeapon = existing_file['swapped_starting_weapon'] or false
        Storage.typewritersActive = existing_file['typewriters_active'] or true
        Storage.receivedItemNames = existing_file['received_item_names'] or {}  

        for k, typewriter in pairs(unlocked_typewriters) do
            Typewriters.Unlock("", typewriter)
        end
    else
        Storage.Update()
    end

    Storage.storageInitialized = true
end

function Storage.Update()
    local player = Archipelago.GetPlayer()
    
    -- no point in writing if filename is bad
    if not player["seed"] or not player["slot"] then
        return
    end

    stored_values = { 
        last_received = Storage.lastReceivedItemIndex, 
        last_saved = Storage.lastSavedItemIndex, 
        talked_to_marvin = Storage.talkedToMarvin,
        opened_chief_door = Storage.openedChiefDoor,

        -- Disabled until Secret Room return is re-enabled (see the note in CutsceneObjects.lua)
        -- finished_g1 = Storage.finishedG1,

        swapped_starting_weapon = Storage.swappedStartingWeapon,
        typewriters_active = Storage.typewritersActive,
        received_item_names = Storage.receivedItemNames,
        unlocked_typewriters = Typewriters.GetAllUnlocked() 
    }

    json.dump_file(Storage.GetFilePath(), stored_values)
end

-- this is called when interacting with typewriters because the user is assumed to save when they visit typewriters
-- we update the last saved item so we won't receive it again if we die and have to restart from our last save
function Storage.UpdateLastSavedItems()
    Storage.lastSavedItemIndex = Storage.lastReceivedItemIndex
    Storage.Update()
end

function Storage.GetFilePath()
    local player = Archipelago.GetPlayer()

    return Lookups.filepath .. "_storage/" .. player["seed"] .. "_" .. player["slot"] .. ".json"
end

function Storage.Reset()
    Storage.storageInitialized = false
    Storage.lastReceivedItemIndex = -1
    Storage.lastSavedItemIndex = -1
    Storage.talkedToMarvin = false
    Storage.openedChiefDoor = false
    Storage.finishedG1 = false
    Storage.swappedStartingWeapon = false
    Storage.typewritersActive = true
    Storage.receivedItemNames = {}
end

return Storage
