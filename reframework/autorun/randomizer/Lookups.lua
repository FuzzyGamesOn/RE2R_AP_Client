local Lookups = {}

Lookups.filepath = Manifest.mod_name .. "/"
Lookups.items = {}
Lookups.locations = {}
Lookups.typewriters = {}
Lookups.character = nil
Lookups.scenario = nil
Lookups.difficulty = nil

function Lookups.load(character, scenario, difficulty)
    -- If this was already loaded and not cleared, don't load again
    if #Lookups.items > 0 and #Lookups.locations > 0 then
        return
    end

    Lookups.character = character
    Lookups.scenario = scenario
    Lookups.difficulty = difficulty

    character = string.lower(character)
    scenario = string.lower(scenario)

    local item_file = Lookups.filepath .. character .. "/items.json"
    local location_file = Lookups.filepath .. character .. "/" .. scenario .. "/locations.json"
    local location_hardcore_file = Lookups.filepath .. character .. "/" .. scenario .. "/locations_hardcore.json"
    local typewriter_file = Lookups.filepath .. character .. "/" .. scenario .. "/typewriters.json"

    Lookups.items = json.load_file(item_file)
    Lookups.locations = json.load_file(location_file)
    Lookups.typewriters = json.load_file(typewriter_file)

    -- have to check for hardcore file in case it's not there
    local hardcore_locations = json.load_file(location_hardcore_file)

    if hardcore_locations then
        for k, v in pairs(hardcore_locations) do
            v['hardcore'] = true
            table.insert(Lookups.locations, v)
        end
    end
end

function Lookups.clear()
    Lookups.items = {}
    Lookups.locations = {}
end

return Lookups
