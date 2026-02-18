local ESX = exports['es_extended']:getSharedObject()

local playerStates = {}
local infectionCooldowns = {}

local function getIdentifierFromXPlayer(xPlayer)
    if not xPlayer then
        return nil
    end

    if xPlayer.identifier then
        return xPlayer.identifier
    end

    if xPlayer.getIdentifier then
        return xPlayer.getIdentifier()
    end

    return nil
end

local function notifyPlayer(source, message)
    TriggerClientEvent('esx:showNotification', source, message)
end

local function normalizeStage(stage)
    local parsedStage = tonumber(stage) or 1
    return math.max(1, math.min(Config.MaxStage, parsedStage))
end

local function savePlayerState(source)
    local state = playerStates[source]
    if not state or not state.identifier then
        return
    end

    MySQL.query.await([[
        INSERT INTO zombie_infections (identifier, infected, stage)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE
            infected = VALUES(infected),
            stage = VALUES(stage),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        state.identifier,
        state.infected and 1 or 0,
        state.stage or 0
    })
end

local function setPlayerInfection(source, infected, stage)
    local state = playerStates[source]

    if not state then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then
            return false
        end

        local identifier = getIdentifierFromXPlayer(xPlayer)
        if not identifier then
            return false
        end

        state = {
            identifier = identifier,
            infected = false,
            stage = 0
        }
        playerStates[source] = state
    end

    state.infected = infected == true
    state.stage = state.infected and normalizeStage(stage) or 0

    TriggerClientEvent('esx_plaga_zombie:client:sync', source, state.infected, state.stage)
    savePlayerState(source)

    return true
end

local function loadPlayerState(source, xPlayer)
    local targetPlayer = xPlayer or ESX.GetPlayerFromId(source)
    if not targetPlayer then
        return
    end

    local identifier = getIdentifierFromXPlayer(targetPlayer)
    if not identifier then
        return
    end

    local row = MySQL.single.await(
        'SELECT infected, stage FROM zombie_infections WHERE identifier = ? LIMIT 1',
        { identifier }
    )

    local infected = row and tonumber(row.infected) == 1 or false
    local stage = infected and normalizeStage(row.stage) or 0

    playerStates[source] = {
        identifier = identifier,
        infected = infected,
        stage = stage
    }

    TriggerClientEvent('esx_plaga_zombie:client:sync', source, infected, stage)
end

local function isAdmin(source)
    if source == 0 then
        return true
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or not xPlayer.getGroup then
        return false
    end

    local playerGroup = xPlayer.getGroup()
    return Config.AdminGroups[playerGroup] == true
end

local function parseTargetPlayer(source, argValue)
    local target = tonumber(argValue)

    if not target and source ~= 0 then
        target = source
    end

    if not target or not GetPlayerName(target) then
        return nil
    end

    return target
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS zombie_infections (
            identifier VARCHAR(64) NOT NULL,
            infected TINYINT(1) NOT NULL DEFAULT 0,
            stage TINYINT(2) NOT NULL DEFAULT 0,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    for _, playerId in ipairs(GetPlayers()) do
        loadPlayerState(tonumber(playerId))
    end
end)

RegisterNetEvent('esx_plaga_zombie:server:requestSync', function()
    local sourcePlayer = source

    if playerStates[sourcePlayer] then
        local state = playerStates[sourcePlayer]
        TriggerClientEvent('esx_plaga_zombie:client:sync', sourcePlayer, state.infected, state.stage)
        return
    end

    loadPlayerState(sourcePlayer)
end)

RegisterNetEvent('esx_plaga_zombie:server:attemptInfection', function()
    local sourcePlayer = source
    local now = GetGameTimer()
    local lastAttempt = infectionCooldowns[sourcePlayer] or 0

    if now - lastAttempt < Config.InfectionCooldownMs then
        return
    end

    infectionCooldowns[sourcePlayer] = now

    local state = playerStates[sourcePlayer]
    if not state then
        loadPlayerState(sourcePlayer)
        state = playerStates[sourcePlayer]
    end

    if not state or state.infected then
        return
    end

    if math.random(100) <= Config.InfectionChance then
        setPlayerInfection(sourcePlayer, true, 1)
    end
end)

RegisterNetEvent('esx_plaga_zombie:server:updateStage', function(stage)
    local sourcePlayer = source
    local state = playerStates[sourcePlayer]

    if not state or not state.infected then
        return
    end

    local normalizedStage = normalizeStage(stage)
    if normalizedStage == state.stage then
        return
    end

    state.stage = normalizedStage
    savePlayerState(sourcePlayer)
end)

ESX.RegisterUsableItem(Config.AntidoteItem, function(source)
    local sourcePlayer = source
    local state = playerStates[sourcePlayer]

    if not state or not state.infected then
        notifyPlayer(sourcePlayer, Config.Messages.antidoteNoNeed)
        return
    end

    local xPlayer = ESX.GetPlayerFromId(sourcePlayer)
    if not xPlayer then
        return
    end

    xPlayer.removeInventoryItem(Config.AntidoteItem, 1)
    setPlayerInfection(sourcePlayer, false, 0)
    notifyPlayer(sourcePlayer, Config.Messages.antidoteUsed)
end)

RegisterCommand(Config.Commands.status, function(source)
    local sourcePlayer = source
    if sourcePlayer == 0 then
        print('[esx_plaga_zombie] Este comando solo se puede usar in-game.')
        return
    end

    local state = playerStates[sourcePlayer]
    if not state or not state.infected then
        notifyPlayer(sourcePlayer, Config.Messages.notInfected)
        return
    end

    notifyPlayer(
        sourcePlayer,
        ('Infeccion activa. Fase %s/%s.'):format(state.stage, Config.MaxStage)
    )
end, false)

RegisterCommand(Config.Commands.infect, function(source, args)
    local sourcePlayer = source

    if not isAdmin(sourcePlayer) then
        if sourcePlayer ~= 0 then
            notifyPlayer(sourcePlayer, Config.Messages.noPermission)
        end
        return
    end

    local targetPlayer = parseTargetPlayer(sourcePlayer, args[1])
    if not targetPlayer then
        if sourcePlayer == 0 then
            print('[esx_plaga_zombie] Uso: /' .. Config.Commands.infect .. ' [id]')
        else
            notifyPlayer(sourcePlayer, Config.Messages.invalidPlayer)
        end
        return
    end

    local state = playerStates[targetPlayer]
    if state and state.infected then
        if sourcePlayer ~= 0 then
            notifyPlayer(sourcePlayer, Config.Messages.alreadyInfected)
        end
        return
    end

    setPlayerInfection(targetPlayer, true, 1)
    notifyPlayer(targetPlayer, Config.Messages.infected)

    if sourcePlayer ~= 0 and sourcePlayer ~= targetPlayer then
        notifyPlayer(sourcePlayer, ('Jugador %s infectado.'):format(targetPlayer))
    end
end, false)

RegisterCommand(Config.Commands.cure, function(source, args)
    local sourcePlayer = source

    if not isAdmin(sourcePlayer) then
        if sourcePlayer ~= 0 then
            notifyPlayer(sourcePlayer, Config.Messages.noPermission)
        end
        return
    end

    local targetPlayer = parseTargetPlayer(sourcePlayer, args[1])
    if not targetPlayer then
        if sourcePlayer == 0 then
            print('[esx_plaga_zombie] Uso: /' .. Config.Commands.cure .. ' [id]')
        else
            notifyPlayer(sourcePlayer, Config.Messages.invalidPlayer)
        end
        return
    end

    local state = playerStates[targetPlayer]
    if not state or not state.infected then
        if sourcePlayer ~= 0 then
            notifyPlayer(sourcePlayer, Config.Messages.alreadyHealthy)
        end
        return
    end

    setPlayerInfection(targetPlayer, false, 0)
    notifyPlayer(targetPlayer, Config.Messages.cured)

    if sourcePlayer ~= 0 and sourcePlayer ~= targetPlayer then
        notifyPlayer(sourcePlayer, ('Jugador %s curado.'):format(targetPlayer))
    end
end, false)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    loadPlayerState(playerId, xPlayer)
end)

AddEventHandler('esx:onPlayerLogout', function(playerId)
    savePlayerState(playerId)
    playerStates[playerId] = nil
    infectionCooldowns[playerId] = nil
end)

AddEventHandler('playerDropped', function()
    local sourcePlayer = source
    savePlayerState(sourcePlayer)
    playerStates[sourcePlayer] = nil
    infectionCooldowns[sourcePlayer] = nil
end)

exports('IsPlayerInfected', function(playerId)
    local state = playerStates[playerId]
    return state and state.infected or false
end)
