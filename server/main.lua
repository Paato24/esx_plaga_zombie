local ESX = exports['es_extended']:getSharedObject()

local SocietyBalance = 0
local Stock = {}
local Orders = {}
local CraftSessions = {}

local ActiveOrderStatuses = {
    pending = true,
    in_progress = true,
    ready = true
}

local StatusFlow = {
    pending = { in_progress = true, cancelled = true },
    in_progress = { ready = true, cancelled = true },
    ready = { cancelled = true }
}

local function logDebug(message)
    if not Config.Debug then
        return
    end

    print(('[paatodev_burgerjob] %s'):format(message))
end

local function getIdentifier(xPlayer)
    if not xPlayer then
        return nil
    end

    if xPlayer.getIdentifier then
        return xPlayer.getIdentifier()
    end

    return xPlayer.identifier
end

local function getPlayerNameSafe(source, xPlayer)
    if xPlayer and xPlayer.getName then
        local name = xPlayer.getName()
        if name and name ~= '' then
            return name
        end
    end

    return GetPlayerName(source) or ('ID %s'):format(source)
end

local function isWorker(xPlayer)
    return xPlayer and xPlayer.job and xPlayer.job.name == Config.JobName
end

local function isBoss(xPlayer)
    if not isWorker(xPlayer) then
        return false
    end

    return Config.BossGrades[xPlayer.job.grade_name] == true
end

local function getIngredientLabel(itemName)
    for _, point in ipairs(Config.IngredientPoints) do
        if point.item == itemName then
            return point.label
        end
    end

    return itemName
end

local function isNearCoords(source, targetCoords, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - targetCoords) <= (maxDistance or 2.5)
end

local function isNearIngredientPoint(source, itemName)
    for _, point in ipairs(Config.IngredientPoints) do
        if point.item == itemName and isNearCoords(source, point.coords, Config.TargetDistance + 1.0) then
            return true
        end
    end

    return false
end

local function getWorkerSources()
    local sources = {}

    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        local xPlayer = ESX.GetPlayerFromId(source)
        if isWorker(xPlayer) then
            sources[#sources + 1] = source
        end
    end

    return sources
end

local function getSourceByIdentifier(identifier)
    if not identifier then
        return nil
    end

    for _, id in ipairs(GetPlayers()) do
        local source = tonumber(id)
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer and getIdentifier(xPlayer) == identifier then
            return source
        end
    end

    return nil
end

local function copyStock()
    local data = {}
    for itemName, amount in pairs(Stock) do
        data[itemName] = amount
    end
    return data
end

local function orderSort(a, b)
    local priority = {
        pending = 1,
        in_progress = 2,
        ready = 3
    }

    local aPriority = priority[a.status] or 99
    local bPriority = priority[b.status] or 99

    if aPriority == bPriority then
        return a.id < b.id
    end

    return aPriority < bPriority
end

local function getRecipeContentLines(recipe, quantity)
    if not recipe then
        return {}
    end

    local lines = {}
    for itemName, amount in pairs(recipe.ingredients or {}) do
        lines[#lines + 1] = ('%s x%d'):format(getIngredientLabel(itemName), amount * quantity)
    end

    table.sort(lines)
    return lines
end

local function serialiseOrder(order)
    local recipe = Config.Recipes[order.recipe_key]

    return {
        id = order.id,
        recipeKey = order.recipe_key,
        recipeLabel = order.recipe_label or (recipe and recipe.label) or order.recipe_key,
        quantity = order.quantity,
        totalPrice = order.total_price,
        status = order.status,
        statusLabel = Config.OrderStatuses[order.status] or order.status,
        customerName = order.customer_name,
        assignedName = order.assigned_name,
        contents = getRecipeContentLines(recipe, order.quantity),
        createdAt = order.created_at
    }
end

local function getOrdersForClient()
    local list = {}
    for _, order in pairs(Orders) do
        list[#list + 1] = serialiseOrder(order)
    end

    table.sort(list, orderSort)
    return list
end

local function persistSocietyBalance()
    MySQL.update.await('UPDATE paatodev_burger_society SET balance = ?, updated_at = NOW() WHERE job_name = ?', {
        SocietyBalance,
        Config.JobName
    })
end

local function persistStockItem(itemName)
    MySQL.update.await([[
        INSERT INTO paatodev_burger_stock (job_name, item_name, amount)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE amount = VALUES(amount)
    ]], { Config.JobName, itemName, Stock[itemName] or 0 })
end

local function setStockAmount(itemName, amount)
    Stock[itemName] = math.max(0, math.floor(amount or 0))
    persistStockItem(itemName)
end

local function changeStock(itemName, amount)
    setStockAmount(itemName, (Stock[itemName] or 0) + amount)
end

local function getTrackedStockItems()
    local tracked = {}

    for _, point in ipairs(Config.IngredientPoints) do
        tracked[point.item] = true
    end

    for _, package in pairs(Config.SupplyPackages) do
        for itemName in pairs(package.items) do
            tracked[itemName] = true
        end
    end

    for _, recipe in pairs(Config.Recipes) do
        for itemName in pairs(recipe.ingredients or {}) do
            tracked[itemName] = true
        end
    end

    return tracked
end

local function notify(source, notifType, description)
    TriggerClientEvent('ox_lib:notify', source, {
        type = notifType,
        description = description
    })
end

local function broadcastWorkerState()
    local payloadOrders = getOrdersForClient()
    local payloadStock = copyStock()

    for _, source in ipairs(getWorkerSources()) do
        TriggerClientEvent('paatodev_burger:client:syncOrders', source, payloadOrders)
        TriggerClientEvent('paatodev_burger:client:updateSocietyState', source, payloadStock, SocietyBalance)
    end
end

local function ensureDatabase()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS paatodev_burger_society (
            job_name VARCHAR(64) NOT NULL,
            balance INT NOT NULL DEFAULT 0,
            updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (job_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS paatodev_burger_stock (
            job_name VARCHAR(64) NOT NULL,
            item_name VARCHAR(64) NOT NULL,
            amount INT NOT NULL DEFAULT 0,
            PRIMARY KEY (job_name, item_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS paatodev_burger_orders (
            id INT NOT NULL AUTO_INCREMENT,
            job_name VARCHAR(64) NOT NULL,
            customer_identifier VARCHAR(80) NOT NULL,
            customer_name VARCHAR(90) NOT NULL,
            recipe_key VARCHAR(60) NOT NULL,
            recipe_label VARCHAR(90) NOT NULL,
            output_item VARCHAR(64) NOT NULL,
            output_count INT NOT NULL DEFAULT 1,
            quantity INT NOT NULL DEFAULT 1,
            total_price INT NOT NULL DEFAULT 0,
            status VARCHAR(20) NOT NULL DEFAULT 'pending',
            assigned_identifier VARCHAR(80) DEFAULT NULL,
            assigned_name VARCHAR(90) DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_job_status (job_name, status),
            INDEX idx_customer_status (customer_identifier, status)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end

local function loadSociety()
    local row = MySQL.single.await('SELECT balance FROM paatodev_burger_society WHERE job_name = ?', {
        Config.JobName
    })

    if row then
        SocietyBalance = row.balance or 0
        return
    end

    MySQL.insert.await('INSERT INTO paatodev_burger_society (job_name, balance) VALUES (?, ?)', {
        Config.JobName,
        0
    })
    SocietyBalance = 0
end

local function loadStock()
    Stock = {}
    local tracked = getTrackedStockItems()

    for itemName in pairs(tracked) do
        Stock[itemName] = 0
        MySQL.insert.await('INSERT IGNORE INTO paatodev_burger_stock (job_name, item_name, amount) VALUES (?, ?, 0)', {
            Config.JobName,
            itemName
        })
    end

    local rows = MySQL.query.await('SELECT item_name, amount FROM paatodev_burger_stock WHERE job_name = ?', {
        Config.JobName
    }) or {}

    for _, row in ipairs(rows) do
        Stock[row.item_name] = row.amount or 0
    end
end

local function loadOrders()
    Orders = {}
    local rows = MySQL.query.await([[
        SELECT *
        FROM paatodev_burger_orders
        WHERE job_name = ?
          AND status IN ('pending', 'in_progress', 'ready')
        ORDER BY id ASC
    ]], {
        Config.JobName
    }) or {}

    for _, row in ipairs(rows) do
        Orders[row.id] = row
    end
end

local function removePlayerMoney(xPlayer, paymentMethod, amount)
    if paymentMethod == 'bank' then
        local account = xPlayer.getAccount('bank')
        if account and account.money >= amount then
            xPlayer.removeAccountMoney('bank', amount)
            return true
        end
        return false
    end

    if xPlayer.getMoney() >= amount then
        xPlayer.removeMoney(amount)
        return true
    end

    return false
end

local function getItemCount(source, itemName)
    local amount = exports.ox_inventory:Search(source, 'count', itemName)
    return tonumber(amount) or 0
end

local function canCarryItem(source, itemName, amount)
    return exports.ox_inventory:CanCarryItem(source, itemName, amount) == true
end

local function addInventoryItem(source, itemName, amount)
    local result = exports.ox_inventory:AddItem(source, itemName, amount)
    return result ~= false
end

local function removeInventoryItem(source, itemName, amount)
    local result = exports.ox_inventory:RemoveItem(source, itemName, amount)
    return result ~= false
end

CreateThread(function()
    MySQL.ready(function()
        ensureDatabase()
        loadSociety()
        loadStock()
        loadOrders()
        broadcastWorkerState()
        logDebug('Recurso inicializado correctamente.')
    end)
end)

lib.callback.register('paatodev_burger:server:getPlayerState', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    local worker = isWorker(xPlayer)
    local boss = isBoss(xPlayer)

    return {
        isWorker = worker,
        isBoss = boss,
        societyBalance = worker and SocietyBalance or 0,
        stock = worker and copyStock() or {},
        orders = worker and getOrdersForClient() or {},
        statuses = Config.OrderStatuses
    }
end)

lib.callback.register('paatodev_burger:server:bossMoneyAction', function(source, action, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isBoss(xPlayer) then
        return { ok = false, message = Config.Notifications.onlyBoss }
    end

    if not isNearCoords(source, Config.Points.Boss, Config.TargetDistance + 1.0) then
        return { ok = false, message = 'Debes estar en el punto de jefe.' }
    end

    local parsedAmount = math.floor(tonumber(amount) or 0)
    if parsedAmount <= 0 then
        return { ok = false, message = Config.Notifications.invalidAmount }
    end

    if action == 'deposit' then
        local account = xPlayer.getAccount('bank')
        if not account or account.money < parsedAmount then
            return { ok = false, message = 'No tienes suficiente dinero en banco.' }
        end

        xPlayer.removeAccountMoney('bank', parsedAmount)
        SocietyBalance = SocietyBalance + parsedAmount
        persistSocietyBalance()
        broadcastWorkerState()
        return { ok = true, message = ('Depositaste $%d a la sociedad.'):format(parsedAmount), balance = SocietyBalance }
    end

    if action == 'withdraw' then
        if SocietyBalance < parsedAmount then
            return { ok = false, message = Config.Notifications.noSocietyFunds }
        end

        SocietyBalance = SocietyBalance - parsedAmount
        xPlayer.addAccountMoney('bank', parsedAmount)
        persistSocietyBalance()
        broadcastWorkerState()
        return { ok = true, message = ('Retiraste $%d de la sociedad.'):format(parsedAmount), balance = SocietyBalance }
    end

    return { ok = false, message = 'Accion invalida.' }
end)

lib.callback.register('paatodev_burger:server:buySupplyPackage', function(source, packageKey)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isBoss(xPlayer) then
        return { ok = false, message = Config.Notifications.onlyBoss }
    end

    if not isNearCoords(source, Config.Points.Boss, Config.TargetDistance + 1.0) then
        return { ok = false, message = 'Debes estar en el punto de jefe.' }
    end

    local package = Config.SupplyPackages[packageKey]
    if not package then
        return { ok = false, message = 'Paquete de compra invalido.' }
    end

    if SocietyBalance < package.price then
        return { ok = false, message = Config.Notifications.noSocietyFunds }
    end

    SocietyBalance = SocietyBalance - package.price
    persistSocietyBalance()

    for itemName, amount in pairs(package.items) do
        changeStock(itemName, amount)
    end

    broadcastWorkerState()
    return { ok = true, message = ('Compraste %s por $%d.'):format(package.label, package.price), balance = SocietyBalance }
end)

lib.callback.register('paatodev_burger:server:takeIngredient', function(source, itemName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isWorker(xPlayer) then
        return { ok = false, message = Config.Notifications.onlyWorkers }
    end

    if not isNearIngredientPoint(source, itemName) then
        return { ok = false, message = 'Debes estar en el punto del ingrediente.' }
    end

    local currentStock = Stock[itemName] or 0
    if currentStock <= 0 then
        return { ok = false, message = Config.Notifications.noStock }
    end

    if not canCarryItem(source, itemName, 1) then
        return { ok = false, message = 'No tienes espacio en el inventario.' }
    end

    changeStock(itemName, -1)

    if not addInventoryItem(source, itemName, 1) then
        changeStock(itemName, 1)
        return { ok = false, message = 'No fue posible agregar el ingrediente al inventario.' }
    end

    broadcastWorkerState()
    return {
        ok = true,
        message = ('Tomaste 1x %s del almacen.'):format(getIngredientLabel(itemName))
    }
end)

lib.callback.register('paatodev_burger:server:requestCraft', function(source, recipeKey, quantity)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isWorker(xPlayer) then
        return { ok = false, message = Config.Notifications.onlyWorkers }
    end

    if not isNearCoords(source, Config.Points.Craft, Config.TargetDistance + 1.0) then
        return { ok = false, message = 'Debes estar en la zona de cocina.' }
    end

    local recipe = Config.Recipes[recipeKey]
    if not recipe then
        return { ok = false, message = 'Receta invalida.' }
    end

    local parsedQuantity = math.min(10, math.max(1, math.floor(tonumber(quantity) or 1)))

    for itemName, amount in pairs(recipe.ingredients) do
        local needed = amount * parsedQuantity
        if getItemCount(source, itemName) < needed then
            return {
                ok = false,
                message = ('Falta %s x%d para cocinar.'):format(getIngredientLabel(itemName), needed)
            }
        end
    end

    local outputCount = (recipe.outputCount or 1) * parsedQuantity
    if not canCarryItem(source, recipe.outputItem, outputCount) then
        return { ok = false, message = 'No tienes espacio para el resultado final.' }
    end

    local steps = {}
    for itemName, amount in pairs(recipe.ingredients) do
        steps[#steps + 1] = {
            label = ('Agregando %s x%d'):format(getIngredientLabel(itemName), amount * parsedQuantity),
            duration = Config.ProgressDurations.prepStep
        }
    end

    table.sort(steps, function(a, b)
        return a.label < b.label
    end)

    steps[#steps + 1] = {
        label = 'Cocinando y montando la hamburguesa',
        duration = Config.ProgressDurations.grillStep
    }

    local token = ('%s-%s-%s-%s'):format(source, recipeKey, parsedQuantity, math.random(100000, 999999))
    CraftSessions[source] = {
        token = token,
        recipeKey = recipeKey,
        quantity = parsedQuantity,
        expiresAt = GetGameTimer() + 120000
    }

    return {
        ok = true,
        data = {
            token = token,
            recipeLabel = recipe.label,
            steps = steps
        }
    }
end)

lib.callback.register('paatodev_burger:server:cancelCraft', function(source, token)
    local session = CraftSessions[source]
    if session and session.token == token then
        CraftSessions[source] = nil
    end

    return true
end)

lib.callback.register('paatodev_burger:server:finishCraft', function(source, token)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isWorker(xPlayer) then
        return { ok = false, message = Config.Notifications.onlyWorkers }
    end

    if not isNearCoords(source, Config.Points.Craft, Config.TargetDistance + 1.0) then
        return { ok = false, message = 'Debes estar en la zona de cocina.' }
    end

    local session = CraftSessions[source]
    if not session or session.token ~= token then
        return { ok = false, message = 'Sesion de crafteo invalida.' }
    end

    if session.expiresAt < GetGameTimer() then
        CraftSessions[source] = nil
        return { ok = false, message = 'La sesion de crafteo expiro.' }
    end

    local recipe = Config.Recipes[session.recipeKey]
    if not recipe then
        CraftSessions[source] = nil
        return { ok = false, message = 'La receta ya no existe.' }
    end

    local quantity = session.quantity
    local outputCount = (recipe.outputCount or 1) * quantity

    if not canCarryItem(source, recipe.outputItem, outputCount) then
        CraftSessions[source] = nil
        return { ok = false, message = 'No tienes espacio para guardar la hamburguesa.' }
    end

    for itemName, amount in pairs(recipe.ingredients) do
        local needed = amount * quantity
        if getItemCount(source, itemName) < needed then
            CraftSessions[source] = nil
            return {
                ok = false,
                message = ('Faltan ingredientes: %s x%d'):format(getIngredientLabel(itemName), needed)
            }
        end
    end

    local removed = {}
    for itemName, amount in pairs(recipe.ingredients) do
        local needed = amount * quantity
        if removeInventoryItem(source, itemName, needed) then
            removed[itemName] = needed
        else
            for rollbackItem, rollbackAmount in pairs(removed) do
                addInventoryItem(source, rollbackItem, rollbackAmount)
            end
            CraftSessions[source] = nil
            return { ok = false, message = 'No se pudo descontar ingredientes.' }
        end
    end

    if not addInventoryItem(source, recipe.outputItem, outputCount) then
        for rollbackItem, rollbackAmount in pairs(removed) do
            addInventoryItem(source, rollbackItem, rollbackAmount)
        end
        CraftSessions[source] = nil
        return { ok = false, message = 'No se pudo entregar la hamburguesa final.' }
    end

    CraftSessions[source] = nil
    return {
        ok = true,
        message = ('Preparaste %dx %s.'):format(outputCount, recipe.label)
    }
end)

lib.callback.register('paatodev_burger:server:placeOrder', function(source, recipeKey, quantity, paymentMethod)
    if not isNearCoords(source, Config.Points.OrderKiosk, Config.TargetDistance + 1.0) then
        return { ok = false, message = 'Debes estar en el punto de pedidos.' }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return { ok = false, message = 'No fue posible validar tu personaje.' }
    end

    local recipe = Config.Recipes[recipeKey]
    if not recipe then
        return { ok = false, message = 'Receta invalida.' }
    end

    local parsedQuantity = math.min(10, math.max(1, math.floor(tonumber(quantity) or 1)))
    local totalPrice = recipe.price * parsedQuantity
    local selectedPayment = paymentMethod == 'bank' and 'bank' or 'cash'

    if not removePlayerMoney(xPlayer, selectedPayment, totalPrice) then
        return { ok = false, message = 'No tienes dinero suficiente para el pedido.' }
    end

    SocietyBalance = SocietyBalance + totalPrice
    persistSocietyBalance()

    local identifier = getIdentifier(xPlayer)
    local customerName = getPlayerNameSafe(source, xPlayer)
    local outputCount = recipe.outputCount or 1

    local insertId = MySQL.insert.await([[
        INSERT INTO paatodev_burger_orders
            (job_name, customer_identifier, customer_name, recipe_key, recipe_label, output_item, output_count, quantity, total_price, status)
        VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    ]], {
        Config.JobName,
        identifier,
        customerName,
        recipeKey,
        recipe.label,
        recipe.outputItem,
        outputCount,
        parsedQuantity,
        totalPrice
    })

    local createdAt = os.date('%Y-%m-%d %H:%M:%S')
    Orders[insertId] = {
        id = insertId,
        job_name = Config.JobName,
        customer_identifier = identifier,
        customer_name = customerName,
        recipe_key = recipeKey,
        recipe_label = recipe.label,
        output_item = recipe.outputItem,
        output_count = outputCount,
        quantity = parsedQuantity,
        total_price = totalPrice,
        status = 'pending',
        assigned_identifier = nil,
        assigned_name = nil,
        created_at = createdAt
    }

    broadcastWorkerState()

    local orderPreview = serialiseOrder(Orders[insertId])
    for _, workerSource in ipairs(getWorkerSources()) do
        TriggerClientEvent('paatodev_burger:client:newOrderAlert', workerSource, orderPreview)
    end

    return {
        ok = true,
        message = Config.Notifications.orderPlaced,
        orderId = insertId
    }
end)

lib.callback.register('paatodev_burger:server:updateOrderStatus', function(source, orderId, newStatus)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isWorker(xPlayer) then
        return { ok = false, message = Config.Notifications.onlyWorkers }
    end

    local id = math.floor(tonumber(orderId) or 0)
    local status = tostring(newStatus or '')
    local order = Orders[id]

    if not order then
        return { ok = false, message = 'Pedido no encontrado.' }
    end

    if not ActiveOrderStatuses[order.status] then
        return { ok = false, message = 'El pedido ya no esta activo.' }
    end

    if not StatusFlow[order.status] or not StatusFlow[order.status][status] then
        return { ok = false, message = 'No puedes realizar ese cambio de estado.' }
    end

    local identifier = getIdentifier(xPlayer)
    local workerName = getPlayerNameSafe(source, xPlayer)

    if status == 'in_progress' then
        if order.assigned_identifier and order.assigned_identifier ~= identifier then
            return { ok = false, message = 'Este pedido ya fue tomado por otro empleado.' }
        end
        order.assigned_identifier = identifier
        order.assigned_name = workerName
    end

    if status == 'ready' then
        if order.assigned_identifier and order.assigned_identifier ~= identifier then
            return { ok = false, message = 'Solo quien tomo el pedido puede marcarlo listo.' }
        end
        order.assigned_identifier = identifier
        order.assigned_name = workerName
    end

    order.status = status

    MySQL.update.await([[
        UPDATE paatodev_burger_orders
        SET status = ?, assigned_identifier = ?, assigned_name = ?, updated_at = NOW()
        WHERE id = ?
    ]], {
        status,
        order.assigned_identifier,
        order.assigned_name,
        order.id
    })

    if status == 'cancelled' then
        Orders[id] = nil
    end

    broadcastWorkerState()

    if status == 'ready' then
        local customerSource = getSourceByIdentifier(order.customer_identifier)
        if customerSource then
            TriggerClientEvent('paatodev_burger:client:orderReadyNotify', customerSource, order.id, order.recipe_label)
        end
    end

    return { ok = true, message = 'Estado del pedido actualizado.' }
end)

lib.callback.register('paatodev_burger:server:claimReadyOrder', function(source)
    if not isNearCoords(source, Config.Points.Pickup, Config.TargetDistance + 1.0) then
        return { ok = false, message = 'Debes estar en el punto de retiro.' }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return { ok = false, message = 'No fue posible validar tu personaje.' }
    end

    local identifier = getIdentifier(xPlayer)
    local selectedOrder

    for _, order in pairs(Orders) do
        if order.customer_identifier == identifier and order.status == 'ready' then
            if not selectedOrder or order.id < selectedOrder.id then
                selectedOrder = order
            end
        end
    end

    if not selectedOrder then
        return { ok = false, message = Config.Notifications.noReadyOrder }
    end

    local totalOutput = (selectedOrder.output_count or 1) * selectedOrder.quantity
    if not canCarryItem(source, selectedOrder.output_item, totalOutput) then
        return { ok = false, message = 'No tienes espacio para retirar tu pedido.' }
    end

    if not addInventoryItem(source, selectedOrder.output_item, totalOutput) then
        return { ok = false, message = 'No se pudo entregar el pedido, intenta nuevamente.' }
    end

    selectedOrder.status = 'completed'

    MySQL.update.await([[
        UPDATE paatodev_burger_orders
        SET status = 'completed', updated_at = NOW()
        WHERE id = ?
    ]], {
        selectedOrder.id
    })

    Orders[selectedOrder.id] = nil
    broadcastWorkerState()

    return {
        ok = true,
        message = ('Retiraste %dx %s.'):format(totalOutput, selectedOrder.recipe_label)
    }
end)

AddEventHandler('playerDropped', function()
    local source = source
    CraftSessions[source] = nil
end)

RegisterNetEvent('paatodev_burger:server:requestFullSync', function()
    local source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    if not isWorker(xPlayer) then
        return
    end

    TriggerClientEvent('paatodev_burger:client:syncOrders', source, getOrdersForClient())
    TriggerClientEvent('paatodev_burger:client:updateSocietyState', source, copyStock(), SocietyBalance)
end)

RegisterCommand('burgerjob_sync', function(source)
    if source ~= 0 then
        notify(source, 'error', 'Este comando solo puede ejecutarse desde consola.')
        return
    end

    loadSociety()
    loadStock()
    loadOrders()
    broadcastWorkerState()
    logDebug('Sincronizacion manual ejecutada desde consola.')
end, true)
