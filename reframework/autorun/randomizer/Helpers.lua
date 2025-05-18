local Helpers = {}

function Helpers.gameObject(obj_name)
    return Scene.getSceneObject():findGameObject(obj_name)
end

function Helpers.component(obj, component_namespace)
    return obj:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace(component_namespace)))
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

return Helpers
