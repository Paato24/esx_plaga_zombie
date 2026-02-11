local ESX = exports['es_extended']:getSharedObject()

local PlayerData = {}
local IsWorker = false
local IsBoss = false
local TabletOpen = false
local TargetZonesRegistered = false

local CachedOrders = {}
local CachedStock = {}
local SocietyBalance = 0

local function notify(notifType, description)
    lib.notify({
        type = notifType,
        description = description
    })
end

local function formatMoney(value)
    local left, num, right = tostring(math.floor(value or 0)):match('^([^%d]*%d)(%d*)(.-)$')
    return left .. (num:reverse():gsub('(%d%d%d)', '%1.'):reverse()) .. right
end

local function getIngredientLabel(itemName)
    for _, point in ipairs(Config.IngredientPoints) do
        if point.item == itemName then
            return point.label
        end
    end

    return itemName
end

local function sortedKeys(inputTable)
    local keys = {}
    for key in pairs(inputTable) do
        keys[#keys + 1] = key
    end

    table.sort(keys)
    return keys
end

local function getRecipeIngredientsText(ingredients, quantity)
    local lines = {}

    for itemName, amount in pairs(ingredients or {}) do
        lines[#lines + 1] = ('%s x%d'):format(getIngredientLabel(itemName), amount * (quantity or 1))
    end

    table.sort(lines)
    return table.concat(lines, ', ')
end

local function closeTablet()
    if not TabletOpen then
        return
    end

    TabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

local function updateJobState()
    local job = PlayerData.job
    IsWorker = job and job.name == Config.JobName or false
    IsBoss = false

    if IsWorker and job.grade_name and Config.BossGrades[job.grade_name] then
        IsBoss = true
    end

    if not IsWorker then
        closeTablet()
    end
end

local function refreshStateFromServer()
    local state = lib.callback.await('paatodev_burger:server:getPlayerState', false)
    if not state then
        return
    end

    IsWorker = state.isWorker or false
    IsBoss = state.isBoss or false
    SocietyBalance = state.societyBalance or 0
    CachedStock = state.stock or {}
    CachedOrders = state.orders or {}
end

local function pushTabletData()
    if not TabletOpen then
        return
    end

    SendNUIMessage({
        action = 'updateData',
        orders = CachedOrders,
        stock = CachedStock,
        societyBalance = SocietyBalance,
        statuses = Config.OrderStatuses
    })
end

local function openSupplyMenu()
    local options = {}

    for _, packageKey in ipairs(sortedKeys(Config.SupplyPackages)) do
        local package = Config.SupplyPackages[packageKey]
        local contentLines = {}

        for itemName, amount in pairs(package.items) do
            contentLines[#contentLines + 1] = ('%s x%d'):format(getIngredientLabel(itemName), amount)
        end

        table.sort(contentLines)

        options[#options + 1] = {
            title = package.label,
            description = ('Precio: $%s\nIncluye: %s'):format(
                formatMoney(package.price),
                table.concat(contentLines, ', ')
            ),
            icon = 'cart-shopping',
            onSelect = function()
                local response = lib.callback.await('paatodev_burger:server:buySupplyPackage', false, packageKey)
                if response and response.ok then
                    notify('success', response.message)
                    refreshStateFromServer()
                else
                    notify('error', response and response.message or 'No fue posible comprar insumos.')
                end
            end
        }
    end

    lib.registerContext({
        id = 'paatodev_burger_supply_menu',
        title = 'Compra de insumos',
        menu = 'paatodev_burger_boss_menu',
        options = options
    })

    lib.showContext('paatodev_burger_supply_menu')
end

local function openStockMenu()
    local options = {}

    for _, point in ipairs(Config.IngredientPoints) do
        options[#options + 1] = {
            title = point.label,
            description = ('Stock disponible: %d'):format(CachedStock[point.item] or 0),
            icon = 'warehouse',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'paatodev_burger_stock_menu',
        title = 'Stock actual',
        menu = 'paatodev_burger_boss_menu',
        options = options
    })

    lib.showContext('paatodev_burger_stock_menu')
end

local function manageSocietyMoney(action)
    local actionLabel = action == 'deposit' and 'Depositar' or 'Retirar'
    local input = lib.inputDialog(('%s dinero de sociedad'):format(actionLabel), {
        {
            type = 'number',
            label = 'Monto',
            description = 'Monto en dolares',
            min = 1,
            required = true
        }
    })

    if not input then
        return
    end

    local amount = math.floor(tonumber(input[1]) or 0)
    if amount <= 0 then
        notify('error', Config.Notifications.invalidAmount)
        return
    end

    local response = lib.callback.await('paatodev_burger:server:bossMoneyAction', false, action, amount)
    if response and response.ok then
        notify('success', response.message)
        refreshStateFromServer()
    else
        notify('error', response and response.message or 'No fue posible completar la operacion.')
    end
end

local function openBossMenu()
    if not IsWorker then
        notify('error', Config.Notifications.onlyWorkers)
        return
    end

    if not IsBoss then
        notify('error', Config.Notifications.onlyBoss)
        return
    end

    refreshStateFromServer()

    lib.registerContext({
        id = 'paatodev_burger_boss_menu',
        title = 'Panel de jefe',
        options = {
            {
                title = ('Saldo sociedad: $%s'):format(formatMoney(SocietyBalance)),
                icon = 'building-columns',
                disabled = true
            },
            {
                title = 'Depositar dinero',
                description = 'Pasa dinero de tu banco a la sociedad.',
                icon = 'money-bill-transfer',
                onSelect = function()
                    manageSocietyMoney('deposit')
                end
            },
            {
                title = 'Retirar dinero',
                description = 'Retira dinero de la sociedad a tu banco.',
                icon = 'money-bill-wave',
                onSelect = function()
                    manageSocietyMoney('withdraw')
                end
            },
            {
                title = 'Comprar productos',
                description = 'Compra lotes de ingredientes para cocina.',
                icon = 'cart-plus',
                onSelect = openSupplyMenu
            },
            {
                title = 'Ver stock actual',
                description = 'Consulta el stock disponible por ingrediente.',
                icon = 'clipboard-list',
                onSelect = openStockMenu
            }
        }
    })

    lib.showContext('paatodev_burger_boss_menu')
end

local function takeIngredient(point)
    if not IsWorker then
        notify('error', Config.Notifications.onlyWorkers)
        return
    end

    local completed = lib.progressCircle({
        duration = Config.ProgressDurations.takeIngredient,
        label = ('Tomando %s del almacen...'):format(point.label),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            combat = true,
            car = true
        }
    })

    if not completed then
        notify('error', Config.Notifications.craftingCancelled)
        return
    end

    local response = lib.callback.await('paatodev_burger:server:takeIngredient', false, point.item)
    if response and response.ok then
        notify('success', response.message)
    else
        notify('error', response and response.message or 'No fue posible retirar ingrediente.')
    end
end

local function startCraft(recipeKey, quantity)
    local response = lib.callback.await('paatodev_burger:server:requestCraft', false, recipeKey, quantity)
    if not response or not response.ok then
        notify('error', response and response.message or Config.Notifications.missingIngredients)
        return
    end

    local craftData = response.data
    if not craftData then
        notify('error', 'No se obtuvo respuesta de crafteo.')
        return
    end

    for _, step in ipairs(craftData.steps or {}) do
        local completed = lib.progressCircle({
            duration = step.duration or Config.ProgressDurations.prepStep,
            label = step.label or 'Preparando...',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                combat = true,
                car = true
            }
        })

        if not completed then
            lib.callback.await('paatodev_burger:server:cancelCraft', false, craftData.token)
            notify('error', Config.Notifications.craftingCancelled)
            return
        end
    end

    local finishResult = lib.callback.await('paatodev_burger:server:finishCraft', false, craftData.token)
    if finishResult and finishResult.ok then
        notify('success', finishResult.message)
    else
        notify('error', finishResult and finishResult.message or 'No fue posible finalizar el crafteo.')
    end
end

local function openCraftMenu()
    if not IsWorker then
        notify('error', Config.Notifications.onlyWorkers)
        return
    end

    local options = {}

    for _, recipeKey in ipairs(sortedKeys(Config.Recipes)) do
        local recipe = Config.Recipes[recipeKey]
        options[#options + 1] = {
            title = recipe.label,
            description = ('%s\nRequiere: %s'):format(
                recipe.description,
                getRecipeIngredientsText(recipe.ingredients, 1)
            ),
            icon = 'burger',
            onSelect = function()
                local input = lib.inputDialog(('Preparar %s'):format(recipe.label), {
                    {
                        type = 'number',
                        label = 'Cantidad',
                        description = 'Cantidad a preparar',
                        default = 1,
                        min = 1,
                        max = 10,
                        required = true
                    }
                })

                if not input then
                    return
                end

                local quantity = math.floor(tonumber(input[1]) or 1)
                startCraft(recipeKey, quantity)
            end
        }
    end

    lib.registerContext({
        id = 'paatodev_burger_craft_menu',
        title = 'Cocina de hamburguesas',
        options = options
    })

    lib.showContext('paatodev_burger_craft_menu')
end

local function placeCustomerOrder(recipeKey)
    local recipe = Config.Recipes[recipeKey]
    if not recipe then
        notify('error', 'Receta invalida.')
        return
    end

    local input = lib.inputDialog(('Pedir %s'):format(recipe.label), {
        {
            type = 'number',
            label = 'Cantidad',
            description = 'Minimo 1, maximo 10',
            default = 1,
            min = 1,
            max = 10,
            required = true
        },
        {
            type = 'select',
            label = 'Metodo de pago',
            options = {
                { value = 'cash', label = 'Efectivo' },
                { value = 'bank', label = 'Banco' }
            },
            required = true,
            default = 'cash'
        }
    })

    if not input then
        return
    end

    local quantity = math.floor(tonumber(input[1]) or 1)
    local paymentMethod = tostring(input[2] or 'cash')
    local response = lib.callback.await('paatodev_burger:server:placeOrder', false, recipeKey, quantity, paymentMethod)

    if response and response.ok then
        notify('success', response.message)
    else
        notify('error', response and response.message or 'No fue posible realizar el pedido.')
    end
end

local function openCustomerOrderMenu()
    local options = {}

    for _, recipeKey in ipairs(sortedKeys(Config.Recipes)) do
        local recipe = Config.Recipes[recipeKey]
        options[#options + 1] = {
            title = ('%s - $%s'):format(recipe.label, formatMoney(recipe.price)),
            description = ('%s\nContiene: %s'):format(
                recipe.description,
                getRecipeIngredientsText(recipe.ingredients, 1)
            ),
            icon = 'receipt',
            onSelect = function()
                placeCustomerOrder(recipeKey)
            end
        }
    end

    lib.registerContext({
        id = 'paatodev_burger_customer_menu',
        title = 'Menu de pedidos',
        options = options
    })

    lib.showContext('paatodev_burger_customer_menu')
end

local function claimReadyOrder()
    local response = lib.callback.await('paatodev_burger:server:claimReadyOrder', false)
    if response and response.ok then
        notify('success', response.message)
    else
        notify('error', response and response.message or 'No fue posible retirar pedido.')
    end
end

local function openTablet()
    if not IsWorker then
        notify('error', Config.Notifications.onlyWorkers)
        return
    end

    refreshStateFromServer()

    TabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        orders = CachedOrders,
        stock = CachedStock,
        societyBalance = SocietyBalance,
        statuses = Config.OrderStatuses
    })
end

local function toggleTablet()
    if TabletOpen then
        closeTablet()
        return
    end

    openTablet()
end

local function registerTargetZones()
    if TargetZonesRegistered then
        return
    end

    TargetZonesRegistered = true

    exports.ox_target:addSphereZone({
        coords = Config.Points.Boss,
        radius = 1.0,
        debug = Config.Debug,
        options = {
            {
                name = 'paatodev_burger_boss_zone',
                icon = 'fa-solid fa-user-tie',
                label = 'Panel de jefe',
                canInteract = function()
                    return IsWorker
                end,
                onSelect = openBossMenu
            }
        }
    })

    exports.ox_target:addSphereZone({
        coords = Config.Points.Craft,
        radius = 1.2,
        debug = Config.Debug,
        options = {
            {
                name = 'paatodev_burger_craft_zone',
                icon = 'fa-solid fa-kitchen-set',
                label = 'Cocinar hamburguesas',
                canInteract = function()
                    return IsWorker
                end,
                onSelect = openCraftMenu
            }
        }
    })

    exports.ox_target:addSphereZone({
        coords = Config.Points.OrderKiosk,
        radius = 1.2,
        debug = Config.Debug,
        options = {
            {
                name = 'paatodev_burger_order_zone',
                icon = 'fa-solid fa-table-list',
                label = 'Hacer pedido',
                onSelect = openCustomerOrderMenu
            }
        }
    })

    exports.ox_target:addSphereZone({
        coords = Config.Points.Pickup,
        radius = 1.2,
        debug = Config.Debug,
        options = {
            {
                name = 'paatodev_burger_pickup_zone',
                icon = 'fa-solid fa-box',
                label = 'Retirar pedido listo',
                onSelect = claimReadyOrder
            }
        }
    })

    for _, point in ipairs(Config.IngredientPoints) do
        exports.ox_target:addSphereZone({
            coords = point.coords,
            radius = 0.8,
            debug = Config.Debug,
            options = {
                {
                    name = ('paatodev_burger_ingredient_%s'):format(point.item),
                    icon = 'fa-solid fa-box-open',
                    label = ('Tomar %s'):format(point.label),
                    canInteract = function()
                        return IsWorker
                    end,
                    onSelect = function()
                        takeIngredient(point)
                    end
                }
            }
        })
    end
end

RegisterCommand('paatodev_burger_tablet', function()
    toggleTablet()
end, false)
RegisterKeyMapping('paatodev_burger_tablet', 'Abrir tablet de pedidos de hamburgueseria', 'keyboard', 'F5')

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('requestRefresh', function(_, cb)
    refreshStateFromServer()
    pushTabletData()
    cb({ ok = true })
end)

RegisterNUICallback('updateOrderStatus', function(data, cb)
    if not IsWorker then
        cb({ ok = false, message = Config.Notifications.onlyWorkers })
        return
    end

    local orderId = tonumber(data.orderId)
    local status = tostring(data.status or '')
    local response = lib.callback.await('paatodev_burger:server:updateOrderStatus', false, orderId, status)

    if response and response.ok then
        notify('success', response.message)
    else
        notify('error', response and response.message or 'No fue posible actualizar el estado.')
    end

    cb(response or { ok = false, message = 'Sin respuesta del servidor.' })
end)

RegisterNetEvent('paatodev_burger:client:syncOrders', function(orderList)
    CachedOrders = orderList or {}
    pushTabletData()
end)

RegisterNetEvent('paatodev_burger:client:updateSocietyState', function(stock, balance)
    CachedStock = stock or {}
    SocietyBalance = balance or 0
    pushTabletData()
end)

RegisterNetEvent('paatodev_burger:client:newOrderAlert', function(orderData)
    if not IsWorker then
        return
    end

    local label = orderData and orderData.recipeLabel or 'pedido'
    notify('inform', ('Nuevo pedido recibido: %s'):format(label))
end)

RegisterNetEvent('paatodev_burger:client:orderReadyNotify', function(orderId, recipeLabel)
    local label = recipeLabel or 'Tu pedido'
    notify('success', ('%s (#%s) esta listo para retirar.'):format(label, orderId))
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
    updateJobState()
    refreshStateFromServer()
    if IsWorker then
        TriggerServerEvent('paatodev_burger:server:requestFullSync')
    end
end)

RegisterNetEvent('esx:setJob', function(job)
    PlayerData.job = job
    updateJobState()
    refreshStateFromServer()
    if IsWorker then
        TriggerServerEvent('paatodev_burger:server:requestFullSync')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    closeTablet()
end)

CreateThread(function()
    registerTargetZones()

    while true do
        local data = ESX.GetPlayerData()
        if data and data.job then
            PlayerData = data
            break
        end
        Wait(250)
    end

    updateJobState()
    refreshStateFromServer()
    if IsWorker then
        TriggerServerEvent('paatodev_burger:server:requestFullSync')
    end
end)
