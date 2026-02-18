local ESX = exports['es_extended']:getSharedObject()

local ClientState = {
    membership = nil,
    points = {},
    pendingInvites = {},
    activeMission = nil
}

local NUIOpen = false
local ActiveContext = {}

local function notify(message)
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message)
        return
    end

    TriggerEvent('chat:addMessage', {
        args = { '[ORG]', message }
    })
end

local function showHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function buildStaticPayload()
    return {
        pointTypes = Config.PointTypes,
        permissionLabels = Config.PermissionLabels,
        organizationTypes = Config.OrganizationTypes,
        levelThresholds = Config.LevelThresholds,
        assetCatalog = Config.AssetCatalog,
        weaponShop = Config.WeaponShop,
        missions = Config.Missions,
        drugRecipes = Config.DrugRecipes
    }
end

local function applySync(syncPayload)
    if type(syncPayload) ~= 'table' then
        return
    end

    ClientState.membership = syncPayload.membership
    ClientState.points = syncPayload.points or {}
    ClientState.pendingInvites = syncPayload.pendingInvites or {}
    ClientState.activeMission = syncPayload.activeMission

    if NUIOpen then
        SendNUIMessage({
            action = 'syncLite',
            sync = syncPayload
        })
    end
end

local function requestInitialSync()
    ESX.TriggerServerCallback('esx_orgs:server:getPlayerState', function(response)
        if not response or response.ok ~= true then
            return
        end

        applySync(response.sync)
    end)
end

local function closeNui()
    NUIOpen = false
    ActiveContext = {}
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openClothingMenu()
    if not ClientState.membership then
        notify(Config.Messages.onlyOrgMembers)
        return
    end

    if Config.Clothing.Mode == 'esx_skin' then
        if Config.Clothing.Saveable then
            TriggerEvent('esx_skin:openSaveableMenu')
        else
            TriggerEvent('esx_skin:openMenu')
        end
        return
    end

    if Config.Clothing.Mode == 'illenium' then
        TriggerEvent('illenium-appearance:client:openOutfitMenu')
        return
    end

    if Config.Clothing.Mode == 'custom' and Config.Clothing.CustomClientEvent ~= '' then
        TriggerEvent(Config.Clothing.CustomClientEvent)
        return
    end

    notify('No hay sistema de ropa configurado.')
end

local function spawnAsset(spawnData)
    if not spawnData or not spawnData.model or not spawnData.coords then
        return false, 'Datos de spawn invalidos.'
    end

    local modelHash = type(spawnData.model) == 'number' and spawnData.model or joaat(spawnData.model)
    if not IsModelInCdimage(modelHash) then
        return false, 'Modelo invalido para este activo.'
    end

    RequestModel(modelHash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) do
        Wait(0)
        if GetGameTimer() > timeout then
            break
        end
    end

    if not HasModelLoaded(modelHash) then
        return false, 'El modelo tardo demasiado en cargar.'
    end

    local coords = spawnData.coords
    local vehicle = CreateVehicle(
        modelHash,
        coords.x + 0.0,
        coords.y + 0.0,
        coords.z + 0.0,
        coords.h + 0.0,
        true,
        false
    )

    SetModelAsNoLongerNeeded(modelHash)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, 'No se pudo crear el activo.'
    end

    if spawnData.plate then
        SetVehicleNumberPlateText(vehicle, spawnData.plate)
    end

    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

    return true
end

local function openNui(route, context)
    if NUIOpen then
        return
    end

    ESX.TriggerServerCallback('esx_orgs:server:getAppData', function(response)
        if not response or response.ok ~= true then
            notify((response and response.message) or 'No se pudo abrir el panel.')
            return
        end

        NUIOpen = true
        ActiveContext = context or {}

        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            route = route or 'overview',
            context = ActiveContext,
            data = response.data,
            static = buildStaticPayload()
        })
    end)
end

local function handlePointInteraction(entry)
    if entry.kind == 'create_org' then
        openNui('overview', {
            pointType = 'create_org',
            createIndex = entry.createIndex
        })
        return
    end

    local point = entry.point
    if not point then
        return
    end

    local pointType = point.point_type
    if pointType == 'inventory' then
        TriggerServerEvent('esx_orgs:server:openStash', point.id)
        return
    end

    if pointType == 'clothing' then
        openClothingMenu()
        return
    end

    local routeByType = {
        boss = 'overview',
        organization = 'overview',
        mission = 'missions',
        drug_process = 'processing',
        weapon_shop = 'armory',
        invite = 'invites',
        garage = 'assets',
        hangar = 'assets'
    }

    openNui(routeByType[pointType] or 'overview', {
        pointId = point.id,
        pointType = pointType
    })
end

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb({ ok = true })
end)

RegisterNUICallback('performAction', function(data, cb)
    local actionName = type(data.action) == 'string' and data.action or ''
    if actionName == '' then
        cb({ ok = false, message = 'Accion invalida.' })
        return
    end

    local payload = data.payload or {}
    local context = data.context or ActiveContext or {}

    if actionName == 'setPointHere' then
        local coords = GetEntityCoords(PlayerPedId())
        payload.coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
        payload.heading = GetEntityHeading(PlayerPedId())
    elseif actionName == 'storeCurrentAsset' then
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
            cb({ ok = false, message = 'Debes estar manejando un vehiculo o aeronave.' })
            return
        end

        local plate = GetVehicleNumberPlateText(vehicle) or ''
        payload.plate = (plate:gsub('^%s*(.-)%s*$', '%1'))
    end

    ESX.TriggerServerCallback('esx_orgs:server:handleAction', function(response)
        if not response then
            cb({ ok = false, message = 'Sin respuesta del servidor.' })
            return
        end

        if response.sync then
            applySync(response.sync)
        end

        if response.state and NUIOpen then
            SendNUIMessage({
                action = 'setData',
                data = response.state
            })
        end

        if response.ok and response.spawnData then
            local spawned, spawnError = spawnAsset(response.spawnData)
            if not spawned then
                TriggerServerEvent('esx_orgs:server:assetSpawnFailed', response.spawnData.assetId)
                response.ok = false
                response.message = spawnError or 'No se pudo desplegar el activo.'
            end
        end

        if response.ok and actionName == 'storeCurrentAsset' and response.storeVehicle then
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                SetEntityAsMissionEntity(vehicle, true, true)
                DeleteVehicle(vehicle)
            end
        end

        cb(response)
    end, actionName, payload, context)
end)

RegisterNetEvent('esx_orgs:client:syncState', function(syncPayload)
    applySync(syncPayload)
end)

RegisterNetEvent('esx_orgs:client:setActiveMission', function(missionData)
    ClientState.activeMission = missionData
    if NUIOpen then
        SendNUIMessage({
            action = 'setMission',
            mission = missionData
        })
    end

    if missionData and missionData.target then
        SetNewWaypoint(missionData.target.x + 0.0, missionData.target.y + 0.0)
    end
end)

RegisterNetEvent('esx_orgs:client:openStash', function(stashId)
    if not stashId then
        return
    end

    notify(Config.Messages.stashOpened)
    exports.ox_inventory:openInventory('stash', stashId)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Wait(1000)
    requestInitialSync()
end)

AddEventHandler('esx:playerLoaded', function()
    Wait(1000)
    requestInitialSync()
end)

AddEventHandler('playerSpawned', function()
    Wait(1250)
    requestInitialSync()
end)

CreateThread(function()
    while true do
        local waitMs = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearest = nil
        local nearestDistance = 99999.0

        if ClientState.membership then
            for _, point in ipairs(ClientState.points or {}) do
                local pointCoords = vector3(point.x + 0.0, point.y + 0.0, point.z + 0.0)
                local distance = #(playerCoords - pointCoords)
                if distance <= Config.Marker.DrawDistance then
                    waitMs = 0
                    local pointTypeConfig = Config.PointTypes[point.point_type] or {}
                    local color = pointTypeConfig.color or { r = 255, g = 255, b = 255 }

                    DrawMarker(
                        Config.Marker.Type,
                        point.x + 0.0,
                        point.y + 0.0,
                        (point.z + 0.0) - 1.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        Config.Marker.Scale.x,
                        Config.Marker.Scale.y,
                        Config.Marker.Scale.z,
                        color.r,
                        color.g,
                        color.b,
                        Config.Marker.Alpha,
                        false,
                        false,
                        2,
                        false,
                        nil,
                        nil,
                        false
                    )

                    if distance <= ((tonumber(point.radius) or Config.Marker.InteractDistance) + 0.2)
                        and distance < nearestDistance then
                        nearestDistance = distance
                        nearest = {
                            kind = 'org_point',
                            point = point
                        }
                    end
                end
            end
        else
            for markerIndex, marker in ipairs(Config.CreateOrganizationMarkers) do
                local markerCoords = vector3(marker.coords.x, marker.coords.y, marker.coords.z)
                local distance = #(playerCoords - markerCoords)

                if distance <= Config.Marker.DrawDistance then
                    waitMs = 0
                    DrawMarker(
                        Config.Marker.Type,
                        marker.coords.x,
                        marker.coords.y,
                        marker.coords.z - 1.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        0.0,
                        Config.Marker.Scale.x,
                        Config.Marker.Scale.y,
                        Config.Marker.Scale.z,
                        80,
                        180,
                        255,
                        Config.Marker.Alpha,
                        false,
                        false,
                        2,
                        false,
                        nil,
                        nil,
                        false
                    )

                    if distance <= (Config.Marker.InteractDistance + 0.2) and distance < nearestDistance then
                        nearestDistance = distance
                        nearest = {
                            kind = 'create_org',
                            createIndex = markerIndex,
                            label = marker.label
                        }
                    end
                end
            end
        end

        if ClientState.activeMission and ClientState.activeMission.target then
            local target = ClientState.activeMission.target
            local targetCoords = vector3(target.x + 0.0, target.y + 0.0, target.z + 0.0)
            local distance = #(playerCoords - targetCoords)

            if distance <= 120.0 then
                waitMs = 0
                DrawMarker(
                    1,
                    target.x + 0.0,
                    target.y + 0.0,
                    target.z - 1.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    0.0,
                    1.45,
                    1.45,
                    0.55,
                    90,
                    255,
                    120,
                    190,
                    false,
                    false,
                    2,
                    false,
                    nil,
                    nil,
                    false
                )

                if distance <= Config.MissionCompletionDistance and distance < nearestDistance then
                    nearestDistance = distance
                    nearest = {
                        kind = 'mission_target'
                    }
                end
            end
        end

        if nearest and not NUIOpen then
            waitMs = 0
            local helpText = '[E] Interactuar'

            if nearest.kind == 'create_org' then
                helpText = ('[E] %s'):format(nearest.label or 'Abrir registro de organizaciones')
            elseif nearest.kind == 'mission_target' then
                helpText = '[E] Completar mision'
            else
                local pointType = nearest.point.point_type
                local pointConfig = Config.PointTypes[pointType] or {}
                helpText = ('[E] %s'):format(pointConfig.interactLabel or nearest.point.label or 'Interactuar')
            end

            showHelpText(helpText)

            if IsControlJustReleased(0, Config.InteractKey) then
                if nearest.kind == 'mission_target' then
                    TriggerServerEvent('esx_orgs:server:completeMission')
                else
                    handlePointInteraction(nearest)
                end
            end
        end

        if NUIOpen and IsControlJustReleased(0, 322) then -- ESC
            closeNui()
        end

        Wait(waitMs)
    end
end)
