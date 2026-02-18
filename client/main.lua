local ESX = exports['es_extended']:getSharedObject()

local isInfected = false
local infectionStage = 0
local lastAttemptAt = 0
local lastStageMessageAt = 0
local zombieModelSet = {}

for _, model in ipairs(Config.ZombieModels) do
    zombieModelSet[model] = true
end

local function notify(message)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
        return
    end

    TriggerEvent('chat:addMessage', {
        args = { '[Plaga]', message }
    })
end

local function resetVisualState()
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
end

local function applyStageEffects(stage)
    local modifier = Config.TimecycleByStage[stage]

    if modifier then
        SetTimecycleModifier(modifier)
        SetTimecycleModifierStrength(math.min(1.0, 0.2 * stage))
    else
        ClearTimecycleModifier()
    end

    if stage >= 3 then
        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.05 * stage)
    end
end

local function requestInfectionAttempt()
    local now = GetGameTimer()

    if now - lastAttemptAt < Config.InfectionCooldownMs then
        return
    end

    lastAttemptAt = now
    TriggerServerEvent('esx_plaga_zombie:server:attemptInfection')
end

RegisterNetEvent('esx_plaga_zombie:client:sync', function(infected, stage)
    local wasInfected = isInfected

    isInfected = infected == true

    if isInfected then
        infectionStage = math.max(1, math.min(Config.MaxStage, tonumber(stage) or 1))
        applyStageEffects(infectionStage)
    else
        infectionStage = 0
        resetVisualState()
    end

    if isInfected and not wasInfected then
        notify(Config.Messages.infected)
    elseif not isInfected and wasInfected then
        notify(Config.Messages.cured)
    end
end)

AddEventHandler('gameEventTriggered', function(eventName, args)
    if eventName ~= 'CEventNetworkEntityDamage' then
        return
    end

    local victim = args[1]
    if victim ~= PlayerPedId() then
        return
    end

    local attacker = args[2]
    if not attacker or attacker == 0 then
        return
    end

    if not DoesEntityExist(attacker) or not IsEntityAPed(attacker) or IsPedAPlayer(attacker) then
        return
    end

    local attackerModel = GetEntityModel(attacker)
    if not zombieModelSet[attackerModel] then
        return
    end

    requestInfectionAttempt()
end)

CreateThread(function()
    while true do
        if not isInfected then
            Wait(1000)
        else
            Wait(Config.StageTickMs)

            if isInfected then
                local ped = PlayerPedId()

                if DoesEntityExist(ped) and not IsEntityDead(ped) then
                    local damage = Config.DamageByStage[infectionStage] or 0
                    if damage > 0 then
                        local currentHealth = GetEntityHealth(ped)
                        local nextHealth = math.max(Config.MinimumHealth, currentHealth - damage)
                        if currentHealth > Config.MinimumHealth then
                            SetEntityHealth(ped, nextHealth)
                        end
                    end

                    applyStageEffects(infectionStage)

                    local now = GetGameTimer()
                    if now - lastStageMessageAt > 8000 then
                        local stageMessage = Config.StageMessages[infectionStage]
                        if stageMessage then
                            notify(stageMessage)
                        end
                        lastStageMessageAt = now
                    end

                    if infectionStage < Config.MaxStage then
                        infectionStage = infectionStage + 1
                        TriggerServerEvent('esx_plaga_zombie:server:updateStage', infectionStage)
                    end
                end
            end
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    TriggerServerEvent('esx_plaga_zombie:server:requestSync')
end)

AddEventHandler('playerSpawned', function()
    Wait(2000)
    TriggerServerEvent('esx_plaga_zombie:server:requestSync')
end)
