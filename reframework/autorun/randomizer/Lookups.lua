local Lookups = {}

Lookups.filepath = Manifest.mod_name .. "/"
Lookups.items = {}
Lookups.all_items = {}
Lookups.locations = {}
Lookups.typewriters = {}
Lookups.character = nil
Lookups.scenario = nil
Lookups.difficulty = nil

function Lookups.Load(character, scenario, difficulty)
    -- If this was already loaded and not cleared, don't load again
    if #Lookups.items > 0 and #Lookups.locations > 0 then
        return
    end

    Lookups.character = character
    Lookups.scenario = scenario
    Lookups.difficulty = difficulty

    character = string.lower(character)
    scenario = string.lower(scenario)

    local leon_file = Lookups.filepath .. "/leon/items.json"
    local claire_file = Lookups.filepath .. "/claire/items.json"
    local location_file = Lookups.filepath .. character .. "/" .. scenario .. "/locations.json"
    local location_hardcore_file = Lookups.filepath .. character .. "/" .. scenario .. "/locations_hardcore.json"
    local enemy_file = Lookups.filepath .. character .. "/" .. scenario .. "/enemies.json"
    local typewriter_file = Lookups.filepath .. character .. "/" .. scenario .. "/typewriters.json"

    -- Load all items from the current character, and a subset of items from the other character 
    --     to support weapon rando without introducing item name collisions

    local base_items_file = nil
    local extra_items_file = nil

    if string.lower(Lookups.character) == 'claire' then
        base_items_file = claire_file
        extra_items_file = leon_file
    else
        base_items_file = leon_file
        extra_items_file = claire_file
    end

    Lookups.items = json.load_file(base_items_file) or {}
    local extra_items = json.load_file(extra_items_file) or {}

    for _, v in pairs(extra_items) do
        if v['type'] == 'Weapon' or v['type'] == 'Subweapon' or v['type'] == 'Ammo' or v['type'] == 'Upgrade' or v['type'] == 'Consumable' or v['type'] == 'Gunpowder' then
            table.insert(Lookups.items, v)
        end
    end

    -- END item loading w/ weapon rando support

    Lookups.locations = json.load_file(location_file) or {}
    Lookups.typewriters = json.load_file(typewriter_file) or {}

    -- have to check for hardcore file in case it's not there
    local hardcore_locations = json.load_file(location_hardcore_file) or {}

    if hardcore_locations then
        for k, v in pairs(hardcore_locations) do
            if not v['remove'] then -- ignore "remove" locations because they're for generation only
                v['hardcore'] = true
                table.insert(Lookups.locations, v)
            end
        end
    end

    local enemy_locations = json.load_file(enemy_file) or {}

    if enemy_locations then
        for k, v in pairs(enemy_locations) do
            -- only add enemies that haven't been "excluded" because they can be missed
            if v['excluded'] == nil or v['excluded'] == 0 then
                table.insert(Lookups.locations, v)
            end
        end
    end
end

function Lookups.Reset()
    Lookups.items = {}
    Lookups.locations = {}
    Lookups.typewriters = {}
    Lookups.character = nil
    Lookups.scenario = nil
    Lookups.difficulty = nil
end

return Lookups
