local Scene = {}

Scene.sceneObject = nil
Scene.mainFlowManager = nil

function Scene.getSceneObject()
    if Scene.sceneObject ~= nil then
        return Scene.sceneObject
    end

    Scene.sceneObject = sdk.call_native_func(sdk.get_native_singleton("via.SceneManager"), sdk.find_type_definition("via.SceneManager"), "get_CurrentScene()")

    return Scene.sceneObject
end

function Scene.getMainFlowManager()
    if Scene.mainFlowManager ~= nil then
        return Scene.mainFlowManager
    end

    -- local gameMaster = Scene.getSceneObject():findGameObject("30_GameMaster")
    local masters = Scene.getSceneObject():findGameObjectsWithTag("Masters")
    local gameMaster = nil

    for k, master in pairs(masters) do
        if master:get_Name() == "30_GameMaster" then
            gameMaster = master

            break
        end
    end

    Scene.mainFlowManager = gameMaster:call("getComponent(System.Type)", sdk.typeof(sdk.game_namespace("gamemastering.MainFlowManager")))

    return Scene.mainFlowManager
end

function Scene.getGUIItemBox()
    if Scene.guiItemBox ~= nil then
        return Scene.guiItemBox
    end

    return Scene.getSceneObject():findGameObject("GUI_ItemBox")
end

function Scene.isTitleScreen()
    return Scene.getMainFlowManager():get_IsInTitle()
end

function Scene.isInGame()
    return Scene.getMainFlowManager():get_IsInGame()
end

function Scene.isGameOver()
    return Scene.getMainFlowManager():get_IsInGameOver()
end

function Scene.isUsingItemBox()
    return Scene.getGUIItemBox():get_DrawSelf() -- is the ItemBox GUI "drawn"?
end

function Scene.getCurrentLocation()
    return Scene.getMainFlowManager():get_LoadLocation()
end

function Scene.getCurrentArea()
    return Scene.getMainFlowManager():get_LoadArea()
end

function Scene.getGameGUID()
    return Scene.getMainFlowManager():get_GameGUID()
end

function Scene.getSaveGUID()
    return Scene.getMainFlowManager():get_SaveGUID()
end

return Scene
