local Player = {}

function Player.GetCurrentPosition()
    return player.gameobj:get_Transform():get_Position()
end

function Player.WarpToPosition(vectorNew)
    local playerManager = sdk.get_managed_singleton(sdk.game_namespace("PlayerManager"))

    playerManager:setCurrentPosition(vectorNew)
end

function Player.LookAt(transform)
    player.gameobj:get_Transform():lookAt(transform)
end

return Player
