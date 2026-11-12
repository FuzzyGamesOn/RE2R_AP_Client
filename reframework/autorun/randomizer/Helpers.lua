local Helpers = {}

function Helpers.gameObject(obj_name)
    return Scene.getSceneObject():findGameObject(obj_name)
end

function Helpers.component(obj, component_namespace)
    local comp_name = component_namespace

    if not string.find(comp_name, "via.") and not string.find(comp_name, sdk.game_namespace("")) then
        comp_name = sdk.game_namespace(comp_name)
    end

    return obj:call("getComponent(System.Type)", sdk.typeof(comp_name))
end

-- getting transform children is kinda annoying, so here's a helper for it
function Helpers.get_children(xform)
	local children = {}
	local child = xform:call("get_Child")
	while child do 
		table.insert(children, child)
		child = child:call("get_Next")
	end
	return children[1] and children
end

function Helpers.wait(seconds) 
    local start = os.time() 
    repeat until os.time() > start + seconds 
end

function Helpers.set_valuetype(obj, offset_start, value)
    local offset = tonumber(offset_start)
    local value_type = value.type or value:get_type_definition()
    local value_type_size = value_type:get_valuetype_size()

    for x = 0, value_type_size - 1, 1 do
        obj:write_byte(offset + x, value:read_byte(x))
    end
end

function Helpers.get_guid_string(guid)
    return string.format(
        "%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x", 
        guid.mData1, guid.mData2, guid.mData3, guid.mData4_0, guid.mData4_1, guid.mData4_2, 
        guid.mData4_3, guid.mData4_4, guid.mData4_5, guid.mData4_6, guid.mData4_7
    )
end

return Helpers
