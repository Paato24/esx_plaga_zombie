local ESX = exports['es_extended']:getSharedObject()

local PlayerStates = {}
local ActiveMissions = {}
local LastActionAt = {}
local LastInviteCleanupAt = 0

math.randomseed(os.time())

local function notify(source, message)
    TriggerClientEvent('esx:showNotification', source, message)
end

local function trim(value)
    if type(value) ~= 'string' then
        return ''
    end

    return (value:gsub('^%s*(.-)%s*$', '%1'))
end

local function decodeJson(value)
    if type(value) == 'table' then
        return value
    end

    if not value or value == '' then
        return {}
    end

    local ok, result = pcall(json.decode, value)
    if ok and type(result) == 'table' then
        return result
    end

    return {}
end

local function encodeJson(value)
    return json.encode(value or {})
end

local function deepCopy(value)
    if type(value) ~= 'table' then
        return value
    end

    local copied = {}
    for key, item in pairs(value) do
        copied[key] = deepCopy(item)
    end
    return copied
end

local function getIdentifier(xPlayer)
    if not xPlayer then
        return nil
    end

    if xPlayer.getIdentifier then
        return xPlayer.getIdentifier()
    end

    if xPlayer.identifier then
        return xPlayer.identifier
    end

    return nil
end

local function getPlayerNameSafe(source, xPlayer)
    if xPlayer and xPlayer.getName then
        return xPlayer.getName()
    end

    local name = GetPlayerName(source)
    if name then
        return name
    end

    return ('Jugador %s'):format(source)
end

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)
    if not coords then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
end

local function distanceBetween(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function normalizeTag(rawTag)
    local tag = trim(rawTag):upper():gsub('[^A-Z0-9]', '')
    return tag
end

local function isNearCoords(source, coords, allowedDistance)
    local playerCoords = getPlayerCoords(source)
    if not playerCoords then
        return false
    end

    return distanceBetween(playerCoords, coords) <= allowedDistance
end

local function getAllPermissionKeys()
    local keys = {}
    for permissionKey, _ in pairs(Config.PermissionLabels) do
        keys[#keys + 1] = permissionKey
    end

    table.sort(keys)
    return keys
end

local function buildPermissionMap(rawPermissions)
    local permissions = {}

    if rawPermissions == '*' then
        for permissionKey, _ in pairs(Config.PermissionLabels) do
            permissions[permissionKey] = true
        end
        return permissions
    end

    if type(rawPermissions) ~= 'table' then
        return permissions
    end

    for key, value in pairs(rawPermissions) do
        if type(key) == 'number' and type(value) == 'string' and Config.PermissionLabels[value] then
            permissions[value] = true
        elseif type(key) == 'string' and type(value) == 'boolean' and Config.PermissionLabels[key] then
            permissions[key] = value
        end
    end

    return permissions
end

local function hasPermission(state, permissionKey)
    if not state or not state.orgId then
        return false
    end

    if state.isOwner then
        return true
    end

    if not permissionKey then
        return true
    end

    return state.permissions and state.permissions[permissionKey] == true
end

local function getAccountMode(mode)
    if mode == 'bank' then
        return 'bank'
    end

    return 'cash'
end

local function getPlayerMoney(xPlayer, mode)
    local accountMode = getAccountMode(mode)
    if accountMode == 'bank' then
        local account = xPlayer.getAccount and xPlayer.getAccount('bank')
        return account and (account.money or 0) or 0
    end

    if xPlayer.getMoney then
        return xPlayer.getMoney()
    end

    return 0
end

local function removePlayerMoney(xPlayer, mode, amount)
    local accountMode = getAccountMode(mode)
    if amount <= 0 then
        return false
    end

    if getPlayerMoney(xPlayer, accountMode) < amount then
        return false
    end

    if accountMode == 'bank' then
        if xPlayer.removeAccountMoney then
            xPlayer.removeAccountMoney('bank', amount)
            return true
        end

        return false
    end

    if xPlayer.removeMoney then
        xPlayer.removeMoney(amount)
        return true
    end

    return false
end

local function addPlayerMoney(xPlayer, mode, amount)
    local accountMode = getAccountMode(mode)
    if amount <= 0 then
        return false
    end

    if accountMode == 'bank' then
        if xPlayer.addAccountMoney then
            xPlayer.addAccountMoney('bank', amount)
            return true
        end

        return false
    end

    if xPlayer.addMoney then
        xPlayer.addMoney(amount)
        return true
    end

    return false
end

local function getLevelFromXp(xp)
    local resolvedLevel = 1

    for levelIndex = #Config.LevelThresholds, 1, -1 do
        if xp >= Config.LevelThresholds[levelIndex] then
            resolvedLevel = levelIndex
            break
        end
    end

    return resolvedLevel
end

local function getLevelInfo(level, xp)
    local currentLevel = tonumber(level) or 1
    local currentXp = tonumber(xp) or 0

    local currentThreshold = Config.LevelThresholds[currentLevel] or 0
    local nextThreshold = Config.LevelThresholds[currentLevel + 1]

    local progressPercent = 100
    if nextThreshold then
        local localXp = math.max(0, currentXp - currentThreshold)
        local neededXp = math.max(1, nextThreshold - currentThreshold)
        progressPercent = math.floor((localXp / neededXp) * 100)
        progressPercent = math.max(0, math.min(100, progressPercent))
    end

    return {
        level = currentLevel,
        xp = currentXp,
        nextLevelXp = nextThreshold,
        progressPercent = progressPercent
    }
end

local function cleanupExpiredInvitesIfNeeded()
    local now = os.time()
    if now - LastInviteCleanupAt < 60 then
        return
    end

    LastInviteCleanupAt = now
    MySQL.update.await(
        "UPDATE org_invites SET status = 'expired' WHERE status = 'pending' AND expires_at <= NOW()"
    )
end

local function registerOrgStash(orgId, orgName)
    local stashId = ('org_%s_stash'):format(orgId)
    local stashLabel = ('Org %s'):format(orgName or orgId)

    pcall(function()
        exports.ox_inventory:RegisterStash(
            stashId,
            stashLabel,
            Config.Stash.Slots,
            Config.Stash.MaxWeight,
            false
        )
    end)
end

local function registerAllStashes()
    local rows = MySQL.query.await('SELECT id, name FROM orgs')
    for _, row in ipairs(rows or {}) do
        registerOrgStash(row.id, row.name)
    end
end

local function addLog(orgId, actorIdentifier, actorName, action, details)
    MySQL.insert.await(
        [[
            INSERT INTO org_logs (org_id, actor_identifier, actor_name, action, details)
            VALUES (?, ?, ?, ?, ?)
        ]],
        {
            orgId,
            actorIdentifier or 'unknown',
            actorName or 'unknown',
            action or 'unknown_action',
            encodeJson(details or {})
        }
    )
end

local function getOrgTypeConfig(orgType)
    return Config.OrganizationTypes[orgType]
end

local function getOrgMaxMembers(orgType)
    local orgTypeConfig = getOrgTypeConfig(orgType)
    if not orgTypeConfig then
        return 0
    end

    return tonumber(orgTypeConfig.maxMembers) or 0
end

local function getMemberCount(orgId)
    return MySQL.scalar.await('SELECT COUNT(*) FROM org_members WHERE org_id = ?', { orgId }) or 0
end

local function getSourceByIdentifier(identifier)
    if not identifier then
        return nil
    end

    for _, playerId in ipairs(GetPlayers()) do
        local sourcePlayer = tonumber(playerId)
        local state = PlayerStates[sourcePlayer]

        if state and state.identifier == identifier then
            return sourcePlayer
        end
    end

    return nil
end

local function fetchOrg(orgId)
    local row = MySQL.single.await(
        [[
            SELECT id, name, tag, org_type, level, xp, funds, owner_identifier, created_at, updated_at
            FROM orgs
            WHERE id = ?
            LIMIT 1
        ]],
        { orgId }
    )

    return row
end

local function fetchOrgRanks(orgId)
    local rows = MySQL.query.await(
        [[
            SELECT id, name, weight, permissions
            FROM org_ranks
            WHERE org_id = ?
            ORDER BY weight DESC, id ASC
        ]],
        { orgId }
    )

    for _, row in ipairs(rows or {}) do
        row.permissions = decodeJson(row.permissions)
    end

    return rows or {}
end

local function fetchOrgMembers(orgId)
    local rows = MySQL.query.await(
        [[
            SELECT m.identifier, m.name, m.rank_id, m.joined_at, m.last_online, r.name AS rank_name, r.weight AS rank_weight
            FROM org_members m
            INNER JOIN org_ranks r ON r.id = m.rank_id
            WHERE m.org_id = ?
            ORDER BY r.weight DESC, m.joined_at ASC
        ]],
        { orgId }
    )

    for _, row in ipairs(rows or {}) do
        row.isOnline = getSourceByIdentifier(row.identifier) ~= nil
    end

    return rows or {}
end

local function fetchOrgPoints(orgId)
    local rows = MySQL.query.await(
        [[
            SELECT id, org_id, point_type, label, x, y, z, heading, radius, metadata
            FROM org_points
            WHERE org_id = ?
            ORDER BY id ASC
        ]],
        { orgId }
    )

    for _, row in ipairs(rows or {}) do
        row.metadata = decodeJson(row.metadata)
    end

    return rows or {}
end

local function fetchOrgPointById(orgId, pointId)
    local row = MySQL.single.await(
        [[
            SELECT id, org_id, point_type, label, x, y, z, heading, radius, metadata
            FROM org_points
            WHERE id = ? AND org_id = ?
            LIMIT 1
        ]],
        { pointId, orgId }
    )

    if not row then
        return nil
    end

    row.metadata = decodeJson(row.metadata)
    return row
end

local function fetchOrgAssets(orgId)
    local rows = MySQL.query.await(
        [[
            SELECT id, asset_type, model, label, required_level, required_rank_weight, price, plate, stored, metadata, created_at
            FROM org_assets
            WHERE org_id = ?
            ORDER BY asset_type ASC, created_at DESC
        ]],
        { orgId }
    )

    for _, row in ipairs(rows or {}) do
        row.metadata = decodeJson(row.metadata)
    end

    return rows or {}
end

local function fetchPendingInvitesForPlayer(identifier)
    cleanupExpiredInvitesIfNeeded()

    local rows = MySQL.query.await(
        [[
            SELECT i.id, i.org_id, i.created_at, i.expires_at, o.name AS org_name, o.tag AS org_tag, o.org_type
            FROM org_invites i
            INNER JOIN orgs o ON o.id = i.org_id
            WHERE i.target_identifier = ? AND i.status = 'pending' AND i.expires_at > NOW()
            ORDER BY i.created_at DESC
        ]],
        { identifier }
    )

    return rows or {}
end

local function fetchPendingInvitesForOrg(orgId)
    cleanupExpiredInvitesIfNeeded()

    local rows = MySQL.query.await(
        [[
            SELECT id, target_name, target_identifier, created_at, expires_at, status
            FROM org_invites
            WHERE org_id = ? AND status = 'pending' AND expires_at > NOW()
            ORDER BY created_at DESC
        ]],
        { orgId }
    )

    return rows or {}
end

local function fetchMembershipByIdentifier(identifier)
    local row = MySQL.single.await(
        [[
            SELECT
                m.org_id,
                m.rank_id,
                m.name AS member_name,
                r.name AS rank_name,
                r.weight AS rank_weight,
                r.permissions AS rank_permissions,
                o.name AS org_name,
                o.tag AS org_tag,
                o.org_type AS org_type,
                o.level AS org_level,
                o.xp AS org_xp,
                o.funds AS org_funds,
                o.owner_identifier AS owner_identifier
            FROM org_members m
            INNER JOIN org_ranks r ON r.id = m.rank_id
            INNER JOIN orgs o ON o.id = m.org_id
            WHERE m.identifier = ?
            LIMIT 1
        ]],
        { identifier }
    )

    if not row then
        return nil
    end

    local permissions = decodeJson(row.rank_permissions)

    return {
        orgId = row.org_id,
        rankId = row.rank_id,
        rankName = row.rank_name,
        rankWeight = tonumber(row.rank_weight) or 0,
        permissions = permissions,
        orgName = row.org_name,
        orgTag = row.org_tag,
        orgType = row.org_type,
        orgLevel = tonumber(row.org_level) or 1,
        orgXp = tonumber(row.org_xp) or 0,
        orgFunds = tonumber(row.org_funds) or 0,
        ownerIdentifier = row.owner_identifier
    }
end

local function loadPlayerState(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        PlayerStates[source] = nil
        return nil
    end

    local identifier = getIdentifier(xPlayer)
    if not identifier then
        PlayerStates[source] = nil
        return nil
    end

    local playerName = getPlayerNameSafe(source, xPlayer)
    local memberData = fetchMembershipByIdentifier(identifier)

    local resolvedState = {
        source = source,
        identifier = identifier,
        playerName = playerName,
        orgId = nil,
        rankId = nil,
        rankName = nil,
        rankWeight = 0,
        permissions = {},
        orgName = nil,
        orgTag = nil,
        orgType = nil,
        orgLevel = 1,
        orgXp = 0,
        orgFunds = 0,
        ownerIdentifier = nil,
        isOwner = false
    }

    if memberData then
        resolvedState.orgId = memberData.orgId
        resolvedState.rankId = memberData.rankId
        resolvedState.rankName = memberData.rankName
        resolvedState.rankWeight = memberData.rankWeight
        resolvedState.permissions = memberData.permissions
        resolvedState.orgName = memberData.orgName
        resolvedState.orgTag = memberData.orgTag
        resolvedState.orgType = memberData.orgType
        resolvedState.orgLevel = memberData.orgLevel
        resolvedState.orgXp = memberData.orgXp
        resolvedState.orgFunds = memberData.orgFunds
        resolvedState.ownerIdentifier = memberData.ownerIdentifier
        resolvedState.isOwner = memberData.ownerIdentifier == identifier

        MySQL.update.await(
            [[
                UPDATE org_members
                SET name = ?, last_online = NOW()
                WHERE identifier = ? AND org_id = ?
            ]],
            { playerName, identifier, memberData.orgId }
        )
    end

    PlayerStates[source] = resolvedState
    return resolvedState
end

local function getPlayerState(source)
    if PlayerStates[source] then
        return PlayerStates[source]
    end

    return loadPlayerState(source)
end

local function buildMembershipPayload(state)
    if not state or not state.orgId then
        return nil
    end

    return {
        orgId = state.orgId,
        orgName = state.orgName,
        orgTag = state.orgTag,
        orgType = state.orgType,
        rankId = state.rankId,
        rankName = state.rankName,
        rankWeight = state.rankWeight,
        level = state.orgLevel,
        xp = state.orgXp,
        funds = state.orgFunds,
        isOwner = state.isOwner,
        permissions = state.permissions,
        maxMembers = getOrgMaxMembers(state.orgType),
        levelInfo = getLevelInfo(state.orgLevel, state.orgXp)
    }
end

local function buildSyncPayload(source, forceReload)
    local state = forceReload and loadPlayerState(source) or getPlayerState(source)
    if not state then
        return {
            membership = nil,
            points = {},
            pendingInvites = {},
            activeMission = nil
        }
    end

    local payload = {
        membership = buildMembershipPayload(state),
        points = {},
        pendingInvites = fetchPendingInvitesForPlayer(state.identifier),
        activeMission = ActiveMissions[source]
    }

    if state.orgId then
        payload.points = fetchOrgPoints(state.orgId)
    end

    return payload
end

local function pushSync(source, forceReload)
    local payload = buildSyncPayload(source, forceReload)
    TriggerClientEvent('esx_orgs:client:syncState', source, payload)
end

local function refreshOrgOnlineMembers(orgId)
    for _, playerId in ipairs(GetPlayers()) do
        local sourcePlayer = tonumber(playerId)
        local state = getPlayerState(sourcePlayer)
        if state and state.orgId == orgId then
            pushSync(sourcePlayer, true)
        end
    end
end

local function buildCreateOptionsPayload()
    local options = {}
    for orgType, orgConfig in pairs(Config.OrganizationTypes) do
        options[#options + 1] = {
            type = orgType,
            label = orgConfig.label,
            createPrice = orgConfig.createPrice,
            maxMembers = orgConfig.maxMembers
        }
    end

    table.sort(options, function(a, b)
        return a.createPrice < b.createPrice
    end)

    return options
end

local function getMissionById(missionId)
    for _, mission in ipairs(Config.Missions) do
        if mission.id == missionId then
            return mission
        end
    end

    return nil
end

local function getDrugRecipeById(recipeId)
    for _, recipe in ipairs(Config.DrugRecipes) do
        if recipe.id == recipeId then
            return recipe
        end
    end

    return nil
end

local function getWeaponEntry(itemName)
    for _, weapon in ipairs(Config.WeaponShop) do
        if weapon.item == itemName then
            return weapon
        end
    end

    return nil
end

local function getAssetCatalogEntry(assetType, model)
    local list = Config.AssetCatalog[assetType]
    if type(list) ~= 'table' then
        return nil
    end

    for _, entry in ipairs(list) do
        if entry.model == model then
            return entry
        end
    end

    return nil
end

local function buildAppData(source)
    local state = loadPlayerState(source)
    if not state then
        return nil
    end

    local response = {
        player = {
            source = source,
            name = state.playerName,
            identifier = state.identifier
        },
        membership = nil,
        org = nil,
        members = {},
        ranks = {},
        points = {},
        assets = {},
        orgInvites = {},
        pendingInvites = fetchPendingInvitesForPlayer(state.identifier),
        activeMission = ActiveMissions[source],
        createOptions = buildCreateOptionsPayload()
    }

    if state.orgId then
        local org = fetchOrg(state.orgId)
        if org then
            state.orgName = org.name
            state.orgTag = org.tag
            state.orgType = org.org_type
            state.orgLevel = tonumber(org.level) or 1
            state.orgXp = tonumber(org.xp) or 0
            state.orgFunds = tonumber(org.funds) or 0
            state.ownerIdentifier = org.owner_identifier
            state.isOwner = org.owner_identifier == state.identifier

            response.membership = buildMembershipPayload(state)
            response.org = {
                id = org.id,
                name = org.name,
                tag = org.tag,
                type = org.org_type,
                level = state.orgLevel,
                xp = state.orgXp,
                funds = state.orgFunds,
                maxMembers = getOrgMaxMembers(org.org_type),
                memberCount = getMemberCount(org.id),
                levelInfo = getLevelInfo(state.orgLevel, state.orgXp)
            }
            response.members = fetchOrgMembers(org.id)
            response.ranks = fetchOrgRanks(org.id)
            response.points = fetchOrgPoints(org.id)
            response.assets = fetchOrgAssets(org.id)

            if hasPermission(state, 'manage_invites') then
                response.orgInvites = fetchPendingInvitesForOrg(org.id)
            end
        end
    end

    return response
end

local function enforceActionCooldown(source, actionName, cooldownMs)
    LastActionAt[source] = LastActionAt[source] or {}
    local now = GetGameTimer()
    local last = LastActionAt[source][actionName] or 0

    if now - last < cooldownMs then
        return false
    end

    LastActionAt[source][actionName] = now
    return true
end

local function validateActionPoint(source, context, expectedTypes, requiredPermission)
    local state = getPlayerState(source)
    if not state or not state.orgId then
        return nil, nil, Config.Messages.onlyOrgMembers
    end

    if requiredPermission and not hasPermission(state, requiredPermission) then
        return nil, nil, Config.Messages.noPermission
    end

    if not context or not context.pointId then
        return nil, nil, Config.Messages.notNearPoint
    end

    local pointId = tonumber(context.pointId)
    if not pointId then
        return nil, nil, Config.Messages.notNearPoint
    end

    local point = fetchOrgPointById(state.orgId, pointId)
    if not point then
        return nil, nil, Config.Messages.notNearPoint
    end

    if expectedTypes and #expectedTypes > 0 then
        local matched = false
        for _, allowedType in ipairs(expectedTypes) do
            if point.point_type == allowedType then
                matched = true
                break
            end
        end

        if not matched then
            return nil, nil, Config.Messages.notNearPoint
        end
    end

    local maxDistance = (tonumber(point.radius) or Config.Marker.InteractDistance) + Config.ServerDistanceTolerance
    if not isNearCoords(source, { x = point.x, y = point.y, z = point.z }, maxDistance) then
        return nil, nil, Config.Messages.notNearPoint
    end

    return state, point, nil
end

local function validateCreateMarker(source, context)
    local index = tonumber(context and context.createIndex)
    if not index or not Config.CreateOrganizationMarkers[index] then
        return nil, 'Punto de creacion invalido.'
    end

    local marker = Config.CreateOrganizationMarkers[index]
    local allowedDistance = Config.Marker.InteractDistance + Config.ServerDistanceTolerance
    if not isNearCoords(source, marker.coords, allowedDistance) then
        return nil, Config.Messages.notNearPoint
    end

    return marker, nil
end

local function generatePlate(orgId)
    local suffix = math.random(1111, 9999)
    local plate = ('ORG%s%s'):format(orgId, suffix)
    if #plate > 8 then
        plate = plate:sub(1, 8)
    end

    return plate:upper()
end

local function addOrgXp(orgId, amount, reason, actorIdentifier, actorName)
    if amount <= 0 then
        return nil
    end

    local org = fetchOrg(orgId)
    if not org then
        return nil
    end

    local previousLevel = tonumber(org.level) or 1
    local previousXp = tonumber(org.xp) or 0
    local newXp = previousXp + amount
    local newLevel = getLevelFromXp(newXp)

    MySQL.update.await(
        'UPDATE orgs SET xp = ?, level = ?, updated_at = NOW() WHERE id = ?',
        { newXp, newLevel, orgId }
    )

    if newLevel > previousLevel then
        addLog(orgId, actorIdentifier, actorName, 'org_level_up', {
            from = previousLevel,
            to = newLevel,
            reason = reason or 'xp_gain'
        })

        for _, playerId in ipairs(GetPlayers()) do
            local sourcePlayer = tonumber(playerId)
            local state = getPlayerState(sourcePlayer)
            if state and state.orgId == orgId then
                notify(sourcePlayer, ('Tu organizacion subio a nivel %s.'):format(newLevel))
            end
        end
    end

    return {
        oldLevel = previousLevel,
        newLevel = newLevel,
        oldXp = previousXp,
        newXp = newXp
    }
end

local function actionCreateOrganization(source, payload, context)
    if not enforceActionCooldown(source, 'create_org', 1500) then
        return {
            ok = false,
            message = 'Espera unos segundos para volver a intentarlo.'
        }
    end

    local state = getPlayerState(source)
    if not state then
        return { ok = false, message = 'No se pudo resolver tu sesion.' }
    end

    if state.orgId then
        return { ok = false, message = 'Ya perteneces a una organizacion.' }
    end

    local marker, markerError = validateCreateMarker(source, context)
    if not marker then
        return { ok = false, message = markerError }
    end

    local orgType = trim(payload.orgType):lower()
    local orgConfig = Config.OrganizationTypes[orgType]
    if not orgConfig then
        return { ok = false, message = 'Tipo de organizacion invalido.' }
    end

    local orgName = trim(payload.name)
    if #orgName < Config.CreationNameMinLength or #orgName > Config.CreationNameMaxLength then
        return {
            ok = false,
            message = ('El nombre debe tener entre %s y %s caracteres.'):format(
                Config.CreationNameMinLength,
                Config.CreationNameMaxLength
            )
        }
    end

    local tag = normalizeTag(payload.tag or '')
    if #tag < Config.TagMinLength or #tag > Config.TagMaxLength then
        return {
            ok = false,
            message = ('El tag debe tener entre %s y %s caracteres.'):format(
                Config.TagMinLength,
                Config.TagMaxLength
            )
        }
    end

    local duplicateOrg = MySQL.single.await(
        [[
            SELECT id
            FROM orgs
            WHERE LOWER(name) = LOWER(?) OR tag = ?
            LIMIT 1
        ]],
        { orgName, tag }
    )

    if duplicateOrg then
        return { ok = false, message = 'Ese nombre o tag ya existe.' }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return { ok = false, message = 'Jugador invalido.' }
    end

    if not removePlayerMoney(xPlayer, Config.CreationMoneyAccount, orgConfig.createPrice) then
        return { ok = false, message = 'No tienes dinero suficiente para crear la organizacion.' }
    end

    local orgId = MySQL.insert.await(
        [[
            INSERT INTO orgs (name, tag, org_type, level, xp, funds, owner_identifier)
            VALUES (?, ?, ?, 1, 0, 0, ?)
        ]],
        {
            orgName,
            tag,
            orgType,
            state.identifier
        }
    )

    if not orgId then
        addPlayerMoney(xPlayer, Config.CreationMoneyAccount, orgConfig.createPrice)
        return { ok = false, message = 'No se pudo crear la organizacion.' }
    end

    local bossRankId = nil
    local bossRankWeight = -1

    for _, rankData in ipairs(orgConfig.defaultRanks or {}) do
        local weight = tonumber(rankData.weight) or 0
        local permissions = buildPermissionMap(rankData.permissions)

        local insertedRankId = MySQL.insert.await(
            [[
                INSERT INTO org_ranks (org_id, name, weight, permissions)
                VALUES (?, ?, ?, ?)
            ]],
            {
                orgId,
                rankData.name,
                weight,
                encodeJson(permissions)
            }
        )

        if insertedRankId and weight > bossRankWeight then
            bossRankId = insertedRankId
            bossRankWeight = weight
        end
    end

    if not bossRankId then
        MySQL.update.await('DELETE FROM orgs WHERE id = ?', { orgId })
        addPlayerMoney(xPlayer, Config.CreationMoneyAccount, orgConfig.createPrice)
        return { ok = false, message = 'No se pudieron crear los rangos base.' }
    end

    MySQL.insert.await(
        [[
            INSERT INTO org_members (org_id, identifier, name, rank_id)
            VALUES (?, ?, ?, ?)
        ]],
        {
            orgId,
            state.identifier,
            state.playerName,
            bossRankId
        }
    )

    local baseCoords = marker.coords
    for pointType, offset in pairs(Config.DefaultPointOffsets) do
        local pointConfig = Config.PointTypes[pointType]
        if pointConfig then
            local heading = (baseCoords.heading or 0.0) + (offset.heading or 0.0)

            MySQL.query.await(
                [[
                    INSERT INTO org_points (org_id, point_type, label, x, y, z, heading, radius, metadata)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                        label = VALUES(label),
                        x = VALUES(x),
                        y = VALUES(y),
                        z = VALUES(z),
                        heading = VALUES(heading),
                        radius = VALUES(radius),
                        metadata = VALUES(metadata)
                ]],
                {
                    orgId,
                    pointType,
                    pointConfig.label,
                    baseCoords.x + (offset.x or 0.0),
                    baseCoords.y + (offset.y or 0.0),
                    baseCoords.z + (offset.z or 0.0),
                    heading,
                    pointConfig.radius or 2.0,
                    encodeJson({})
                }
            )
        end
    end

    registerOrgStash(orgId, orgName)

    MySQL.update.await(
        "UPDATE org_invites SET status = 'expired' WHERE target_identifier = ? AND status = 'pending'",
        { state.identifier }
    )

    addLog(orgId, state.identifier, state.playerName, 'org_created', {
        orgType = orgType,
        orgName = orgName,
        orgTag = tag
    })

    pushSync(source, true)

    return {
        ok = true,
        message = Config.Messages.orgCreated,
        refresh = true
    }
end

local function actionDepositFunds(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, nil)
    if not state then
        return { ok = false, message = err }
    end

    local amount = math.floor(tonumber(payload.amount) or 0)
    if amount <= 0 then
        return { ok = false, message = Config.Messages.invalidAmount }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        return { ok = false, message = 'Jugador invalido.' }
    end

    if not removePlayerMoney(xPlayer, Config.PlayerDepositAccount, amount) then
        return { ok = false, message = 'No tienes dinero suficiente.' }
    end

    MySQL.update.await('UPDATE orgs SET funds = funds + ?, updated_at = NOW() WHERE id = ?', {
        amount,
        state.orgId
    })

    addLog(state.orgId, state.identifier, state.playerName, 'deposit_funds', {
        amount = amount
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = ('Deposito realizado: $%s'):format(amount),
        refresh = true
    }
end

local function actionWithdrawFunds(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_funds')
    if not state then
        return { ok = false, message = err }
    end

    local amount = math.floor(tonumber(payload.amount) or 0)
    if amount <= 0 then
        return { ok = false, message = Config.Messages.invalidAmount }
    end

    local affected = MySQL.update.await(
        'UPDATE orgs SET funds = funds - ?, updated_at = NOW() WHERE id = ? AND funds >= ?',
        { amount, state.orgId, amount }
    )

    if (affected or 0) < 1 then
        return { ok = false, message = 'La organizacion no tiene fondos suficientes.' }
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        MySQL.update.await('UPDATE orgs SET funds = funds + ?, updated_at = NOW() WHERE id = ?', {
            amount,
            state.orgId
        })
        return { ok = false, message = 'Jugador invalido.' }
    end

    addPlayerMoney(xPlayer, Config.PlayerWithdrawAccount, amount)

    addLog(state.orgId, state.identifier, state.playerName, 'withdraw_funds', {
        amount = amount
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = ('Retiro realizado: $%s'):format(amount),
        refresh = true
    }
end

local function actionInvitePlayer(source, payload, context)
    if not enforceActionCooldown(source, 'invite_member', 1250) then
        return { ok = false, message = 'Espera un momento para invitar de nuevo.' }
    end

    local state, _, err = validateActionPoint(source, context, { 'invite', 'boss', 'organization' }, 'manage_invites')
    if not state then
        return { ok = false, message = err }
    end

    local targetId = tonumber(payload.targetId)
    if not targetId then
        return { ok = false, message = 'Debes escribir un ID valido.' }
    end

    if targetId == source then
        return { ok = false, message = 'No puedes invitarte a ti mismo.' }
    end

    local targetXPlayer = ESX.GetPlayerFromId(targetId)
    if not targetXPlayer then
        return { ok = false, message = 'Ese jugador no esta conectado.' }
    end

    local targetIdentifier = getIdentifier(targetXPlayer)
    if not targetIdentifier then
        return { ok = false, message = 'No se pudo obtener identificador del objetivo.' }
    end

    local targetMembership = fetchMembershipByIdentifier(targetIdentifier)
    if targetMembership then
        return { ok = false, message = 'Ese jugador ya pertenece a una organizacion.' }
    end

    local org = fetchOrg(state.orgId)
    if not org then
        return { ok = false, message = 'La organizacion ya no existe.' }
    end

    local maxMembers = getOrgMaxMembers(org.org_type)
    if getMemberCount(state.orgId) >= maxMembers then
        return { ok = false, message = 'La organizacion llego al maximo de miembros.' }
    end

    MySQL.update.await(
        [[
            UPDATE org_invites
            SET status = 'cancelled'
            WHERE org_id = ? AND target_identifier = ? AND status = 'pending'
        ]],
        { state.orgId, targetIdentifier }
    )

    MySQL.insert.await(
        [[
            INSERT INTO org_invites (org_id, inviter_identifier, target_identifier, target_name, status, expires_at)
            VALUES (?, ?, ?, ?, 'pending', DATE_ADD(NOW(), INTERVAL ? MINUTE))
        ]],
        {
            state.orgId,
            state.identifier,
            targetIdentifier,
            getPlayerNameSafe(targetId, targetXPlayer),
            Config.InviteDurationMinutes
        }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'invite_sent', {
        targetIdentifier = targetIdentifier,
        targetId = targetId
    })

    notify(targetId, ('Recibiste una invitacion de %s [%s].'):format(state.orgName, state.orgTag))
    pushSync(targetId, true)

    return {
        ok = true,
        message = Config.Messages.inviteSent,
        refresh = true
    }
end

local function actionRespondInvite(source, payload)
    if not enforceActionCooldown(source, 'respond_invite', 1000) then
        return { ok = false, message = 'Espera un momento para responder de nuevo.' }
    end

    local state = getPlayerState(source)
    if not state then
        return { ok = false, message = 'No se pudo resolver tu sesion.' }
    end

    if state.orgId then
        return { ok = false, message = 'Ya perteneces a una organizacion.' }
    end

    local inviteId = tonumber(payload.inviteId)
    if not inviteId then
        return { ok = false, message = 'Invitacion invalida.' }
    end

    local accept = payload.accept == true

    cleanupExpiredInvitesIfNeeded()

    local invite = MySQL.single.await(
        [[
            SELECT id, org_id, inviter_identifier, target_identifier, status, expires_at
            FROM org_invites
            WHERE id = ? AND target_identifier = ? AND status = 'pending' AND expires_at > NOW()
            LIMIT 1
        ]],
        { inviteId, state.identifier }
    )

    if not invite then
        return { ok = false, message = 'La invitacion ya no esta disponible.' }
    end

    if not accept then
        MySQL.update.await(
            "UPDATE org_invites SET status = 'rejected' WHERE id = ?",
            { inviteId }
        )

        return {
            ok = true,
            message = Config.Messages.inviteRejected,
            refresh = true
        }
    end

    local org = fetchOrg(invite.org_id)
    if not org then
        return { ok = false, message = 'La organizacion no existe.' }
    end

    local maxMembers = getOrgMaxMembers(org.org_type)
    if getMemberCount(org.id) >= maxMembers then
        return { ok = false, message = 'La organizacion esta completa.' }
    end

    local lowestRank = MySQL.single.await(
        [[
            SELECT id, weight
            FROM org_ranks
            WHERE org_id = ?
            ORDER BY weight ASC
            LIMIT 1
        ]],
        { org.id }
    )

    if not lowestRank then
        return { ok = false, message = 'La organizacion no tiene rangos configurados.' }
    end

    local insertedMember = MySQL.insert.await(
        [[
            INSERT INTO org_members (org_id, identifier, name, rank_id)
            VALUES (?, ?, ?, ?)
        ]],
        {
            org.id,
            state.identifier,
            state.playerName,
            lowestRank.id
        }
    )

    if not insertedMember then
        return { ok = false, message = 'No se pudo agregar el miembro.' }
    end

    MySQL.update.await(
        "UPDATE org_invites SET status = 'accepted' WHERE id = ?",
        { inviteId }
    )

    addLog(org.id, state.identifier, state.playerName, 'invite_accepted', {
        inviteId = inviteId
    })

    local inviterSource = getSourceByIdentifier(invite.inviter_identifier)
    if inviterSource then
        notify(inviterSource, ('%s acepto la invitacion.'):format(state.playerName))
        pushSync(inviterSource, true)
    end

    refreshOrgOnlineMembers(org.id)
    pushSync(source, true)

    return {
        ok = true,
        message = Config.Messages.inviteAccepted,
        refresh = true
    }
end

local function fetchMemberWithRank(orgId, identifier)
    return MySQL.single.await(
        [[
            SELECT m.identifier, m.rank_id, r.weight, r.name AS rank_name
            FROM org_members m
            INNER JOIN org_ranks r ON r.id = m.rank_id
            WHERE m.org_id = ? AND m.identifier = ?
            LIMIT 1
        ]],
        { orgId, identifier }
    )
end

local function actionPromoteMember(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_members')
    if not state then
        return { ok = false, message = err }
    end

    local targetIdentifier = trim(payload.identifier)
    if targetIdentifier == '' then
        return { ok = false, message = 'Miembro invalido.' }
    end

    if targetIdentifier == state.identifier then
        return { ok = false, message = 'No puedes ascenderte a ti mismo.' }
    end

    local targetMember = fetchMemberWithRank(state.orgId, targetIdentifier)
    if not targetMember then
        return { ok = false, message = 'Miembro no encontrado.' }
    end

    if not state.isOwner and (tonumber(targetMember.weight) or 0) >= state.rankWeight then
        return { ok = false, message = 'No puedes gestionar ese rango.' }
    end

    local candidateRanks = MySQL.query.await(
        [[
            SELECT id, weight
            FROM org_ranks
            WHERE org_id = ? AND weight > ?
            ORDER BY weight ASC
        ]],
        { state.orgId, targetMember.weight }
    )

    local selectedRank = nil
    for _, rankRow in ipairs(candidateRanks or {}) do
        if state.isOwner or rankRow.weight < state.rankWeight then
            selectedRank = rankRow
            break
        end
    end

    if not selectedRank then
        return { ok = false, message = 'No hay un rango superior disponible para ese miembro.' }
    end

    MySQL.update.await(
        [[
            UPDATE org_members
            SET rank_id = ?
            WHERE org_id = ? AND identifier = ?
        ]],
        { selectedRank.id, state.orgId, targetIdentifier }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'member_promoted', {
        targetIdentifier = targetIdentifier,
        toRankId = selectedRank.id
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Miembro ascendido correctamente.',
        refresh = true
    }
end

local function actionDemoteMember(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_members')
    if not state then
        return { ok = false, message = err }
    end

    local targetIdentifier = trim(payload.identifier)
    if targetIdentifier == '' then
        return { ok = false, message = 'Miembro invalido.' }
    end

    if targetIdentifier == state.identifier then
        return { ok = false, message = 'No puedes degradarte a ti mismo.' }
    end

    local targetMember = fetchMemberWithRank(state.orgId, targetIdentifier)
    if not targetMember then
        return { ok = false, message = 'Miembro no encontrado.' }
    end

    if not state.isOwner and (tonumber(targetMember.weight) or 0) >= state.rankWeight then
        return { ok = false, message = 'No puedes gestionar ese rango.' }
    end

    local nextRank = MySQL.single.await(
        [[
            SELECT id, weight
            FROM org_ranks
            WHERE org_id = ? AND weight < ?
            ORDER BY weight DESC
            LIMIT 1
        ]],
        { state.orgId, targetMember.weight }
    )

    if not nextRank then
        return { ok = false, message = 'Ese miembro ya esta en el rango minimo.' }
    end

    MySQL.update.await(
        [[
            UPDATE org_members
            SET rank_id = ?
            WHERE org_id = ? AND identifier = ?
        ]],
        { nextRank.id, state.orgId, targetIdentifier }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'member_demoted', {
        targetIdentifier = targetIdentifier,
        toRankId = nextRank.id
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Miembro degradado correctamente.',
        refresh = true
    }
end

local function actionKickMember(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_members')
    if not state then
        return { ok = false, message = err }
    end

    local targetIdentifier = trim(payload.identifier)
    if targetIdentifier == '' then
        return { ok = false, message = 'Miembro invalido.' }
    end

    if targetIdentifier == state.identifier then
        return { ok = false, message = 'No puedes expulsarte a ti mismo.' }
    end

    local targetMember = fetchMemberWithRank(state.orgId, targetIdentifier)
    if not targetMember then
        return { ok = false, message = 'Miembro no encontrado.' }
    end

    if not state.isOwner and (tonumber(targetMember.weight) or 0) >= state.rankWeight then
        return { ok = false, message = 'No puedes gestionar ese rango.' }
    end

    if targetIdentifier == state.ownerIdentifier then
        return { ok = false, message = 'No puedes expulsar al lider.' }
    end

    MySQL.update.await(
        'DELETE FROM org_members WHERE org_id = ? AND identifier = ?',
        { state.orgId, targetIdentifier }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'member_kicked', {
        targetIdentifier = targetIdentifier
    })

    local targetSource = getSourceByIdentifier(targetIdentifier)
    if targetSource then
        ActiveMissions[targetSource] = nil
        TriggerClientEvent('esx_orgs:client:setActiveMission', targetSource, nil)
        pushSync(targetSource, true)
        notify(targetSource, 'Has sido expulsado de la organizacion.')
    end

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Miembro expulsado.',
        refresh = true
    }
end

local function actionCreateRank(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_ranks')
    if not state then
        return { ok = false, message = err }
    end

    local rankName = trim(payload.name)
    local rankWeight = math.floor(tonumber(payload.weight) or -1)
    if #rankName < 2 or #rankName > 24 then
        return { ok = false, message = 'Nombre de rango invalido.' }
    end

    if rankWeight < 1 or rankWeight > 100 then
        return { ok = false, message = 'El peso del rango debe ser entre 1 y 100.' }
    end

    if not state.isOwner and rankWeight >= state.rankWeight then
        return { ok = false, message = 'No puedes crear rangos iguales o superiores al tuyo.' }
    end

    local permissions = buildPermissionMap(payload.permissions or {})
    local inserted = MySQL.insert.await(
        [[
            INSERT INTO org_ranks (org_id, name, weight, permissions)
            VALUES (?, ?, ?, ?)
        ]],
        { state.orgId, rankName, rankWeight, encodeJson(permissions) }
    )

    if not inserted then
        return { ok = false, message = 'No se pudo crear el rango (puede estar duplicado).' }
    end

    addLog(state.orgId, state.identifier, state.playerName, 'rank_created', {
        rankName = rankName,
        rankWeight = rankWeight
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Rango creado.',
        refresh = true
    }
end

local function actionUpdateRank(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_ranks')
    if not state then
        return { ok = false, message = err }
    end

    local rankId = tonumber(payload.rankId)
    if not rankId then
        return { ok = false, message = 'Rango invalido.' }
    end

    local rank = MySQL.single.await(
        [[
            SELECT id, name, weight
            FROM org_ranks
            WHERE id = ? AND org_id = ?
            LIMIT 1
        ]],
        { rankId, state.orgId }
    )

    if not rank then
        return { ok = false, message = 'Rango no encontrado.' }
    end

    if not state.isOwner and rank.weight >= state.rankWeight then
        return { ok = false, message = 'No puedes editar ese rango.' }
    end

    local newName = trim(payload.name or rank.name)
    local newWeight = math.floor(tonumber(payload.weight) or rank.weight)
    if #newName < 2 or #newName > 24 then
        return { ok = false, message = 'Nombre de rango invalido.' }
    end

    if newWeight < 1 or newWeight > 100 then
        return { ok = false, message = 'Peso de rango invalido.' }
    end

    if not state.isOwner and newWeight >= state.rankWeight then
        return { ok = false, message = 'No puedes asignar un peso igual o mayor al tuyo.' }
    end

    local permissions = buildPermissionMap(payload.permissions or {})

    MySQL.update.await(
        [[
            UPDATE org_ranks
            SET name = ?, weight = ?, permissions = ?
            WHERE id = ? AND org_id = ?
        ]],
        { newName, newWeight, encodeJson(permissions), rankId, state.orgId }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'rank_updated', {
        rankId = rankId,
        rankName = newName,
        rankWeight = newWeight
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Rango actualizado.',
        refresh = true
    }
end

local function actionDeleteRank(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_ranks')
    if not state then
        return { ok = false, message = err }
    end

    local rankId = tonumber(payload.rankId)
    if not rankId then
        return { ok = false, message = 'Rango invalido.' }
    end

    local rank = MySQL.single.await(
        'SELECT id, weight FROM org_ranks WHERE id = ? AND org_id = ? LIMIT 1',
        { rankId, state.orgId }
    )

    if not rank then
        return { ok = false, message = 'Rango no encontrado.' }
    end

    if not state.isOwner and rank.weight >= state.rankWeight then
        return { ok = false, message = 'No puedes eliminar ese rango.' }
    end

    local rankCount = MySQL.scalar.await('SELECT COUNT(*) FROM org_ranks WHERE org_id = ?', { state.orgId }) or 0
    if rankCount <= 1 then
        return { ok = false, message = 'Debe existir al menos un rango.' }
    end

    local inUse = MySQL.scalar.await('SELECT COUNT(*) FROM org_members WHERE org_id = ? AND rank_id = ?', {
        state.orgId,
        rankId
    }) or 0

    if inUse > 0 then
        return { ok = false, message = 'No puedes eliminar un rango en uso.' }
    end

    MySQL.update.await('DELETE FROM org_ranks WHERE org_id = ? AND id = ?', {
        state.orgId,
        rankId
    })

    addLog(state.orgId, state.identifier, state.playerName, 'rank_deleted', {
        rankId = rankId
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Rango eliminado.',
        refresh = true
    }
end

local function actionSetPointHere(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_points')
    if not state then
        return { ok = false, message = err }
    end

    local pointType = trim(payload.pointType)
    local pointConfig = Config.PointTypes[pointType]
    if not pointConfig then
        return { ok = false, message = 'Tipo de punto invalido.' }
    end

    local coords = payload.coords or {}
    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    local heading = tonumber(payload.heading) or 0.0
    if not x or not y or not z then
        return { ok = false, message = 'Coordenadas invalidas.' }
    end

    local radius = tonumber(payload.radius) or tonumber(pointConfig.radius) or 2.0
    radius = math.max(1.5, math.min(5.0, radius))

    MySQL.query.await(
        [[
            INSERT INTO org_points (org_id, point_type, label, x, y, z, heading, radius, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                label = VALUES(label),
                x = VALUES(x),
                y = VALUES(y),
                z = VALUES(z),
                heading = VALUES(heading),
                radius = VALUES(radius),
                metadata = VALUES(metadata)
        ]],
        {
            state.orgId,
            pointType,
            pointConfig.label,
            x,
            y,
            z,
            heading,
            radius,
            encodeJson({})
        }
    )

    if pointType == 'inventory' then
        registerOrgStash(state.orgId, state.orgName)
    end

    addLog(state.orgId, state.identifier, state.playerName, 'point_updated', {
        pointType = pointType,
        x = x,
        y = y,
        z = z
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = ('Punto %s actualizado.'):format(pointConfig.label),
        refresh = true
    }
end

local function actionDeletePoint(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_points')
    if not state then
        return { ok = false, message = err }
    end

    local pointType = trim(payload.pointType)
    if not Config.PointTypes[pointType] then
        return { ok = false, message = 'Tipo de punto invalido.' }
    end

    if pointType == 'boss' then
        local hasOrganizationPoint = MySQL.single.await(
            [[
                SELECT id
                FROM org_points
                WHERE org_id = ? AND point_type = 'organization'
                LIMIT 1
            ]],
            { state.orgId }
        )
        if not hasOrganizationPoint then
            return {
                ok = false,
                message = 'No puedes borrar el punto jefe si no existe punto organizacion.'
            }
        end
    elseif pointType == 'organization' then
        local hasBossPoint = MySQL.single.await(
            [[
                SELECT id
                FROM org_points
                WHERE org_id = ? AND point_type = 'boss'
                LIMIT 1
            ]],
            { state.orgId }
        )
        if not hasBossPoint then
            return {
                ok = false,
                message = 'No puedes borrar el punto organizacion si no existe punto jefe.'
            }
        end
    end

    MySQL.update.await(
        [[
            DELETE FROM org_points
            WHERE org_id = ? AND point_type = ?
        ]],
        {
            state.orgId,
            pointType
        }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'point_deleted', {
        pointType = pointType
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Punto eliminado.',
        refresh = true
    }
end

local function actionBuyAsset(source, payload, context)
    local state, point, err = validateActionPoint(source, context, { 'garage', 'hangar' }, 'manage_assets')
    if not state then
        return { ok = false, message = err }
    end

    local assetType = trim(payload.assetType)
    local model = trim(payload.model)

    if point.point_type == 'garage' and assetType ~= 'vehicle' then
        return { ok = false, message = 'Este punto solo admite vehiculos.' }
    end

    if point.point_type == 'hangar' and assetType ~= 'aircraft' then
        return { ok = false, message = 'Este punto solo admite aeronaves.' }
    end

    local catalogEntry = getAssetCatalogEntry(assetType, model)
    if not catalogEntry then
        return { ok = false, message = 'Activo no disponible.' }
    end

    if state.orgLevel < (catalogEntry.requiredLevel or 1) then
        return { ok = false, message = 'Tu organizacion no tiene el nivel requerido.' }
    end

    if not state.isOwner and state.rankWeight < (catalogEntry.requiredRankWeight or 0) then
        return { ok = false, message = 'Tu rango no puede comprar este activo.' }
    end

    local affected = MySQL.update.await(
        'UPDATE orgs SET funds = funds - ?, updated_at = NOW() WHERE id = ? AND funds >= ?',
        { catalogEntry.price, state.orgId, catalogEntry.price }
    )

    if (affected or 0) < 1 then
        return { ok = false, message = 'Fondos insuficientes en la organizacion.' }
    end

    local plate = generatePlate(state.orgId)
    local insertedAsset = MySQL.insert.await(
        [[
            INSERT INTO org_assets (org_id, asset_type, model, label, required_level, required_rank_weight, price, plate, stored, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
        ]],
        {
            state.orgId,
            assetType,
            catalogEntry.model,
            catalogEntry.label,
            catalogEntry.requiredLevel or 1,
            catalogEntry.requiredRankWeight or 0,
            catalogEntry.price,
            plate,
            encodeJson({})
        }
    )

    if not insertedAsset then
        MySQL.update.await('UPDATE orgs SET funds = funds + ?, updated_at = NOW() WHERE id = ?', {
            catalogEntry.price,
            state.orgId
        })
        return { ok = false, message = 'No se pudo registrar el activo.' }
    end

    addLog(state.orgId, state.identifier, state.playerName, 'asset_bought', {
        assetType = assetType,
        model = catalogEntry.model,
        price = catalogEntry.price,
        plate = plate
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = ('Activo comprado: %s'):format(catalogEntry.label),
        refresh = true
    }
end

local function actionSpawnAsset(source, payload, context)
    local state, point, err
    local expectedPermission = 'use_garage'
    local expectedPointType = 'garage'

    if context and context.pointType == 'hangar' then
        expectedPermission = 'use_hangar'
        expectedPointType = 'hangar'
    end

    state, point, err = validateActionPoint(source, context, { expectedPointType }, expectedPermission)
    if not state then
        return { ok = false, message = err }
    end

    local assetId = tonumber(payload.assetId)
    if not assetId then
        return { ok = false, message = 'Activo invalido.' }
    end

    local asset = MySQL.single.await(
        [[
            SELECT id, asset_type, model, label, required_level, required_rank_weight, plate, stored
            FROM org_assets
            WHERE id = ? AND org_id = ?
            LIMIT 1
        ]],
        { assetId, state.orgId }
    )

    if not asset then
        return { ok = false, message = 'Activo no encontrado.' }
    end

    if expectedPointType == 'garage' and asset.asset_type ~= 'vehicle' then
        return { ok = false, message = 'Ese activo no es terrestre.' }
    end

    if expectedPointType == 'hangar' and asset.asset_type ~= 'aircraft' then
        return { ok = false, message = 'Ese activo no es aereo.' }
    end

    if tonumber(asset.stored) ~= 1 then
        return { ok = false, message = 'Ese activo ya esta desplegado.' }
    end

    if state.orgLevel < (tonumber(asset.required_level) or 1) then
        return { ok = false, message = 'Tu organizacion no tiene nivel para este activo.' }
    end

    if not state.isOwner and state.rankWeight < (tonumber(asset.required_rank_weight) or 0) then
        return { ok = false, message = 'Tu rango no puede desplegar este activo.' }
    end

    local spawnDistance = Config.SpawnOffsets[expectedPointType] or 6.5
    local heading = tonumber(point.heading) or 0.0
    local rad = math.rad(heading)
    local spawnX = point.x + (math.cos(rad) * spawnDistance)
    local spawnY = point.y + (math.sin(rad) * spawnDistance)
    local spawnZ = point.z + 1.0

    MySQL.update.await(
        [[
            UPDATE org_assets
            SET stored = 0, last_spawn_by = ?, updated_at = NOW()
            WHERE id = ? AND org_id = ?
        ]],
        {
            state.identifier,
            asset.id,
            state.orgId
        }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'asset_spawned', {
        assetId = asset.id,
        plate = asset.plate
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = 'Activo desplegado.',
        spawnData = {
            assetId = asset.id,
            assetType = asset.asset_type,
            model = asset.model,
            label = asset.label,
            plate = asset.plate,
            coords = {
                x = spawnX,
                y = spawnY,
                z = spawnZ,
                h = heading
            }
        },
        refresh = true
    }
end

local function actionStoreCurrentAsset(source, payload, context)
    local expectedPermission = 'use_garage'
    local expectedPointType = 'garage'

    if context and context.pointType == 'hangar' then
        expectedPermission = 'use_hangar'
        expectedPointType = 'hangar'
    end

    local state, _, err = validateActionPoint(source, context, { expectedPointType }, expectedPermission)
    if not state then
        return { ok = false, message = err }
    end

    local plate = trim((payload.plate or '')):upper():gsub('%s+', '')
    if plate == '' then
        return { ok = false, message = 'No se detecto matricula del activo.' }
    end

    local expectedAssetType = expectedPointType == 'hangar' and 'aircraft' or 'vehicle'
    local asset = MySQL.single.await(
        [[
            SELECT id, stored
            FROM org_assets
            WHERE org_id = ? AND plate = ? AND asset_type = ?
            LIMIT 1
        ]],
        { state.orgId, plate, expectedAssetType }
    )

    if not asset then
        return { ok = false, message = 'Ese activo no pertenece a tu organizacion.' }
    end

    if tonumber(asset.stored) == 1 then
        return { ok = false, message = 'Ese activo ya estaba guardado.' }
    end

    MySQL.update.await(
        [[
            UPDATE org_assets
            SET stored = 1, updated_at = NOW()
            WHERE id = ? AND org_id = ?
        ]],
        { asset.id, state.orgId }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'asset_stored', {
        assetId = asset.id,
        plate = plate
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = Config.Messages.vehicleStored,
        refresh = true,
        storeVehicle = true
    }
end

local function actionStartMission(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'mission' }, 'use_missions')
    if not state then
        return { ok = false, message = err }
    end

    if ActiveMissions[source] then
        return { ok = false, message = 'Ya tienes una mision activa.' }
    end

    local mission = getMissionById(trim(payload.missionId))
    if not mission then
        return { ok = false, message = 'Mision invalida.' }
    end

    if state.orgLevel < (mission.requiredLevel or 1) then
        return { ok = false, message = 'Tu organizacion no tiene el nivel requerido.' }
    end

    if not state.isOwner and state.rankWeight < (mission.requiredRankWeight or 0) then
        return { ok = false, message = 'Tu rango no puede iniciar esta mision.' }
    end

    local cooldown = MySQL.single.await(
        [[
            SELECT UNIX_TIMESTAMP(next_available_at) AS next_ts
            FROM org_mission_cooldowns
            WHERE org_id = ? AND mission_id = ?
            LIMIT 1
        ]],
        { state.orgId, mission.id }
    )

    if cooldown and cooldown.next_ts and cooldown.next_ts > os.time() then
        local remaining = cooldown.next_ts - os.time()
        local mins = math.floor(remaining / 60)
        local secs = remaining % 60
        return {
            ok = false,
            message = ('Mision en enfriamiento: %sm %ss'):format(mins, secs)
        }
    end

    if not mission.targets or #mission.targets == 0 then
        return { ok = false, message = 'La mision no tiene puntos de destino configurados.' }
    end

    local selectedTarget = mission.targets[math.random(1, #mission.targets)]
    ActiveMissions[source] = {
        orgId = state.orgId,
        missionId = mission.id,
        label = mission.label,
        target = deepCopy(selectedTarget),
        xpGain = mission.xpGain or 0,
        orgFundsReward = mission.orgFundsReward or 0,
        playerMoneyReward = mission.playerMoneyReward or 0,
        startedAt = os.time()
    }

    MySQL.query.await(
        [[
            INSERT INTO org_mission_cooldowns (org_id, mission_id, next_available_at)
            VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))
            ON DUPLICATE KEY UPDATE
                next_available_at = DATE_ADD(NOW(), INTERVAL ? SECOND)
        ]],
        {
            state.orgId,
            mission.id,
            mission.cooldownSeconds or 900,
            mission.cooldownSeconds or 900
        }
    )

    addLog(state.orgId, state.identifier, state.playerName, 'mission_started', {
        missionId = mission.id
    })

    TriggerClientEvent('esx_orgs:client:setActiveMission', source, ActiveMissions[source])

    return {
        ok = true,
        message = Config.Messages.missionStarted,
        refresh = true
    }
end

local function actionCancelMission(source)
    local state = getPlayerState(source)
    if not state or not state.orgId then
        return { ok = false, message = Config.Messages.onlyOrgMembers }
    end

    if not ActiveMissions[source] then
        return { ok = false, message = Config.Messages.missionNoActive }
    end

    ActiveMissions[source] = nil
    TriggerClientEvent('esx_orgs:client:setActiveMission', source, nil)

    return {
        ok = true,
        message = 'Mision cancelada.',
        refresh = true
    }
end

local function actionProcessRecipe(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'drug_process' }, 'use_drugs')
    if not state then
        return { ok = false, message = err }
    end

    local recipe = getDrugRecipeById(trim(payload.recipeId))
    if not recipe then
        return { ok = false, message = 'Receta invalida.' }
    end

    if state.orgLevel < (recipe.requiredLevel or 1) then
        return { ok = false, message = 'Tu organizacion no tiene nivel para esta receta.' }
    end

    if not state.isOwner and state.rankWeight < (recipe.requiredRankWeight or 0) then
        return { ok = false, message = 'Tu rango no puede usar esta receta.' }
    end

    for _, ingredient in ipairs(recipe.inputs or {}) do
        local hasCount = exports.ox_inventory:GetItemCount(source, ingredient.item) or 0
        if hasCount < ingredient.count then
            return {
                ok = false,
                message = ('Falta %s x%s.'):format(ingredient.item, ingredient.count)
            }
        end
    end

    for _, output in ipairs(recipe.outputs or {}) do
        local canCarry = exports.ox_inventory:CanCarryItem(source, output.item, output.count)
        if not canCarry then
            return { ok = false, message = 'No tienes espacio suficiente en inventario.' }
        end
    end

    local removed = {}
    for _, ingredient in ipairs(recipe.inputs or {}) do
        local success = exports.ox_inventory:RemoveItem(source, ingredient.item, ingredient.count)
        if not success then
            for _, rollback in ipairs(removed) do
                exports.ox_inventory:AddItem(source, rollback.item, rollback.count)
            end

            return { ok = false, message = 'No se pudieron consumir materiales.' }
        end

        removed[#removed + 1] = {
            item = ingredient.item,
            count = ingredient.count
        }
    end

    for _, output in ipairs(recipe.outputs or {}) do
        local success = exports.ox_inventory:AddItem(source, output.item, output.count)
        if not success then
            for _, rollback in ipairs(recipe.outputs or {}) do
                exports.ox_inventory:RemoveItem(source, rollback.item, rollback.count)
            end

            for _, rollback in ipairs(removed) do
                exports.ox_inventory:AddItem(source, rollback.item, rollback.count)
            end

            return { ok = false, message = 'No se pudieron entregar los productos finales.' }
        end
    end

    addOrgXp(state.orgId, recipe.xpGain or 0, 'drug_recipe', state.identifier, state.playerName)
    addLog(state.orgId, state.identifier, state.playerName, 'recipe_processed', {
        recipeId = recipe.id
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = Config.Messages.recipeDone,
        refresh = true
    }
end

local function actionBuyWeapon(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'weapon_shop' }, 'use_weapons')
    if not state then
        return { ok = false, message = err }
    end

    local weapon = getWeaponEntry(trim(payload.item))
    if not weapon then
        return { ok = false, message = 'Item no disponible en armeria.' }
    end

    if state.orgLevel < (weapon.requiredLevel or 1) then
        return { ok = false, message = 'Tu organizacion no tiene nivel para esta compra.' }
    end

    if not state.isOwner and state.rankWeight < (weapon.requiredRankWeight or 0) then
        return { ok = false, message = 'Tu rango no puede comprar este item.' }
    end

    if not exports.ox_inventory:CanCarryItem(source, weapon.item, 1) then
        return { ok = false, message = 'No tienes espacio en inventario.' }
    end

    local affected = MySQL.update.await(
        'UPDATE orgs SET funds = funds - ?, updated_at = NOW() WHERE id = ? AND funds >= ?',
        { weapon.price, state.orgId, weapon.price }
    )

    if (affected or 0) < 1 then
        return { ok = false, message = 'Fondos insuficientes en la organizacion.' }
    end

    local metadata = nil
    if weapon.item:sub(1, 7) == 'weapon_' then
        metadata = {
            serial = ('ORG%s%s'):format(state.orgId, math.random(10000, 99999)),
            registered = state.orgTag or 'ORG'
        }
    end

    local added = exports.ox_inventory:AddItem(source, weapon.item, 1, metadata)
    if not added then
        MySQL.update.await(
            'UPDATE orgs SET funds = funds + ?, updated_at = NOW() WHERE id = ?',
            { weapon.price, state.orgId }
        )
        return { ok = false, message = 'No se pudo entregar el item.' }
    end

    addOrgXp(state.orgId, weapon.xpGain or 0, 'weapon_shop', state.identifier, state.playerName)
    addLog(state.orgId, state.identifier, state.playerName, 'weapon_bought', {
        item = weapon.item,
        price = weapon.price
    })

    refreshOrgOnlineMembers(state.orgId)

    return {
        ok = true,
        message = Config.Messages.weaponBought,
        refresh = true
    }
end

local function actionLeaveOrganization(source)
    local state = getPlayerState(source)
    if not state or not state.orgId then
        return { ok = false, message = Config.Messages.onlyOrgMembers }
    end

    if state.isOwner then
        return {
            ok = false,
            message = 'El lider no puede salir sin antes transferir o disolver la organizacion.'
        }
    end

    local oldOrgId = state.orgId
    MySQL.update.await(
        'DELETE FROM org_members WHERE org_id = ? AND identifier = ?',
        { oldOrgId, state.identifier }
    )

    ActiveMissions[source] = nil
    TriggerClientEvent('esx_orgs:client:setActiveMission', source, nil)

    addLog(oldOrgId, state.identifier, state.playerName, 'member_left', {})

    pushSync(source, true)
    refreshOrgOnlineMembers(oldOrgId)

    return {
        ok = true,
        message = 'Saliste de la organizacion.',
        refresh = true
    }
end

local function actionDissolveOrganization(source, payload, context)
    local state, _, err = validateActionPoint(source, context, { 'boss', 'organization' }, 'manage_org')
    if not state then
        return { ok = false, message = err }
    end

    if not state.isOwner then
        return { ok = false, message = 'Solo el lider puede disolver la organizacion.' }
    end

    local confirmation = trim(payload.confirmation or '')
    if confirmation ~= 'CONFIRMAR' then
        return { ok = false, message = "Para disolver debes escribir 'CONFIRMAR'." }
    end

    local orgId = state.orgId
    local memberRows = MySQL.query.await('SELECT identifier FROM org_members WHERE org_id = ?', { orgId })

    MySQL.update.await('DELETE FROM org_members WHERE org_id = ?', { orgId })
    MySQL.update.await('DELETE FROM org_ranks WHERE org_id = ?', { orgId })
    MySQL.update.await('DELETE FROM org_points WHERE org_id = ?', { orgId })
    MySQL.update.await('DELETE FROM org_invites WHERE org_id = ?', { orgId })
    MySQL.update.await('DELETE FROM org_assets WHERE org_id = ?', { orgId })
    MySQL.update.await('DELETE FROM org_logs WHERE org_id = ?', { orgId })
    MySQL.update.await('DELETE FROM org_mission_cooldowns WHERE org_id = ?', { orgId })
    MySQL.update.await('DELETE FROM orgs WHERE id = ?', { orgId })

    for _, row in ipairs(memberRows or {}) do
        local memberSource = getSourceByIdentifier(row.identifier)
        if memberSource then
            ActiveMissions[memberSource] = nil
            TriggerClientEvent('esx_orgs:client:setActiveMission', memberSource, nil)
            pushSync(memberSource, true)
            notify(memberSource, 'Tu organizacion fue disuelta.')
        end
    end

    return {
        ok = true,
        message = 'Organizacion disuelta correctamente.',
        refresh = true
    }
end

local function actionOpenInviteData(source)
    local state = getPlayerState(source)
    if not state then
        return { ok = false, message = 'No se pudo resolver tu sesion.' }
    end

    return {
        ok = true,
        message = 'Invitaciones actualizadas.',
        refresh = true
    }
end

local ActionHandlers = {
    createOrg = actionCreateOrganization,
    depositFunds = actionDepositFunds,
    withdrawFunds = actionWithdrawFunds,
    invitePlayer = actionInvitePlayer,
    respondInvite = actionRespondInvite,
    promoteMember = actionPromoteMember,
    demoteMember = actionDemoteMember,
    kickMember = actionKickMember,
    createRank = actionCreateRank,
    updateRank = actionUpdateRank,
    deleteRank = actionDeleteRank,
    setPointHere = actionSetPointHere,
    deletePoint = actionDeletePoint,
    buyAsset = actionBuyAsset,
    spawnAsset = actionSpawnAsset,
    storeCurrentAsset = actionStoreCurrentAsset,
    startMission = actionStartMission,
    cancelMission = actionCancelMission,
    processRecipe = actionProcessRecipe,
    buyWeapon = actionBuyWeapon,
    leaveOrg = actionLeaveOrganization,
    dissolveOrg = actionDissolveOrganization,
    refreshInvites = actionOpenInviteData
}

RegisterNetEvent('esx_orgs:server:requestSync', function()
    pushSync(source, true)
end)

RegisterNetEvent('esx_orgs:server:openStash', function(pointId)
    local sourcePlayer = source
    local state, _, err = validateActionPoint(
        sourcePlayer,
        { pointId = tonumber(pointId), pointType = 'inventory' },
        { 'inventory' },
        'use_stash'
    )

    if not state then
        notify(sourcePlayer, err)
        return
    end

    local stashId = ('org_%s_stash'):format(state.orgId)
    TriggerClientEvent('esx_orgs:client:openStash', sourcePlayer, stashId)
end)

RegisterNetEvent('esx_orgs:server:completeMission', function()
    local sourcePlayer = source
    local state = getPlayerState(sourcePlayer)
    if not state or not state.orgId then
        notify(sourcePlayer, Config.Messages.onlyOrgMembers)
        return
    end

    local activeMission = ActiveMissions[sourcePlayer]
    if not activeMission then
        notify(sourcePlayer, Config.Messages.missionNoActive)
        return
    end

    if activeMission.orgId ~= state.orgId then
        ActiveMissions[sourcePlayer] = nil
        TriggerClientEvent('esx_orgs:client:setActiveMission', sourcePlayer, nil)
        notify(sourcePlayer, 'Tu mision activa fue cancelada por cambio de organizacion.')
        return
    end

    local missionTarget = activeMission.target
    if not missionTarget then
        ActiveMissions[sourcePlayer] = nil
        TriggerClientEvent('esx_orgs:client:setActiveMission', sourcePlayer, nil)
        notify(sourcePlayer, 'Mision invalida, se cancelo.')
        return
    end

    local nearTarget = isNearCoords(sourcePlayer, missionTarget, Config.MissionCompletionDistance)
    if not nearTarget then
        notify(sourcePlayer, 'Debes estar en el objetivo para completar la mision.')
        return
    end

    ActiveMissions[sourcePlayer] = nil
    TriggerClientEvent('esx_orgs:client:setActiveMission', sourcePlayer, nil)

    if activeMission.orgFundsReward and activeMission.orgFundsReward > 0 then
        MySQL.update.await(
            'UPDATE orgs SET funds = funds + ?, updated_at = NOW() WHERE id = ?',
            { activeMission.orgFundsReward, state.orgId }
        )
    end

    if activeMission.playerMoneyReward and activeMission.playerMoneyReward > 0 then
        local xPlayer = ESX.GetPlayerFromId(sourcePlayer)
        if xPlayer then
            addPlayerMoney(xPlayer, Config.PlayerWithdrawAccount, activeMission.playerMoneyReward)
        end
    end

    addOrgXp(
        state.orgId,
        activeMission.xpGain or 0,
        'mission_complete',
        state.identifier,
        state.playerName
    )

    addLog(state.orgId, state.identifier, state.playerName, 'mission_completed', {
        missionId = activeMission.missionId,
        orgFundsReward = activeMission.orgFundsReward,
        playerMoneyReward = activeMission.playerMoneyReward
    })

    notify(sourcePlayer, Config.Messages.missionCompleted)
    refreshOrgOnlineMembers(state.orgId)
end)

RegisterNetEvent('esx_orgs:server:assetSpawnFailed', function(assetId)
    local sourcePlayer = source
    local state = getPlayerState(sourcePlayer)
    if not state or not state.orgId then
        return
    end

    local resolvedAssetId = tonumber(assetId)
    if not resolvedAssetId then
        return
    end

    MySQL.update.await(
        [[
            UPDATE org_assets
            SET stored = 1, updated_at = NOW()
            WHERE id = ? AND org_id = ? AND stored = 0
        ]],
        { resolvedAssetId, state.orgId }
    )

    refreshOrgOnlineMembers(state.orgId)
end)

ESX.RegisterServerCallback('esx_orgs:server:getPlayerState', function(source, cb)
    cb({
        ok = true,
        sync = buildSyncPayload(source, true)
    })
end)

ESX.RegisterServerCallback('esx_orgs:server:getAppData', function(source, cb)
    local data = buildAppData(source)
    if not data then
        cb({
            ok = false,
            message = 'No se pudo construir la informacion de la app.'
        })
        return
    end

    cb({
        ok = true,
        data = data
    })
end)

ESX.RegisterServerCallback('esx_orgs:server:handleAction', function(source, cb, actionName, payload, context)
    if type(actionName) ~= 'string' then
        cb({ ok = false, message = 'Accion invalida.' })
        return
    end

    local handler = ActionHandlers[actionName]
    if not handler then
        cb({ ok = false, message = 'Accion no soportada.' })
        return
    end

    local ok, result = pcall(handler, source, payload or {}, context or {})
    if not ok then
        print(('[esx_org_hub] Error action "%s": %s'):format(actionName, result))
        cb({ ok = false, message = 'Error interno al ejecutar la accion.' })
        return
    end

    result = result or { ok = false, message = 'Accion sin resultado.' }

    if result.refresh then
        result.state = buildAppData(source)
        result.sync = buildSyncPayload(source, true)
    end

    cb(result)
end)

RegisterCommand('orgestado', function(source)
    if source == 0 then
        print('[esx_org_hub] Este comando es solo in-game.')
        return
    end

    local state = getPlayerState(source)
    if not state or not state.orgId then
        notify(source, 'No perteneces a ninguna organizacion.')
        return
    end

    notify(
        source,
        ('Org: %s [%s] | Rango: %s | Nivel: %s | Fondos: $%s'):format(
            state.orgName,
            state.orgTag,
            state.rankName,
            state.orgLevel,
            state.orgFunds
        )
    )
end, false)

local function createTables()
    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS orgs (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                name VARCHAR(64) NOT NULL,
                tag VARCHAR(12) NOT NULL,
                org_type VARCHAR(32) NOT NULL,
                level INT UNSIGNED NOT NULL DEFAULT 1,
                xp INT UNSIGNED NOT NULL DEFAULT 0,
                funds BIGINT NOT NULL DEFAULT 0,
                owner_identifier VARCHAR(80) NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_orgs_name (name),
                UNIQUE KEY uq_orgs_tag (tag)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )

    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS org_ranks (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                org_id INT UNSIGNED NOT NULL,
                name VARCHAR(48) NOT NULL,
                weight INT NOT NULL DEFAULT 0,
                permissions LONGTEXT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_org_rank_name (org_id, name),
                KEY idx_org_ranks_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )

    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS org_members (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                org_id INT UNSIGNED NOT NULL,
                identifier VARCHAR(80) NOT NULL,
                name VARCHAR(80) NOT NULL,
                rank_id INT UNSIGNED NOT NULL,
                joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_online TIMESTAMP NULL DEFAULT NULL,
                PRIMARY KEY (id),
                UNIQUE KEY uq_org_member_identifier (identifier),
                KEY idx_org_members_org (org_id),
                KEY idx_org_members_rank (rank_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )

    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS org_points (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                org_id INT UNSIGNED NOT NULL,
                point_type VARCHAR(32) NOT NULL,
                label VARCHAR(80) NOT NULL,
                x DOUBLE NOT NULL,
                y DOUBLE NOT NULL,
                z DOUBLE NOT NULL,
                heading FLOAT NOT NULL DEFAULT 0,
                radius FLOAT NOT NULL DEFAULT 2.0,
                metadata LONGTEXT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_org_point_type (org_id, point_type),
                KEY idx_org_points_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )

    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS org_invites (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                org_id INT UNSIGNED NOT NULL,
                inviter_identifier VARCHAR(80) NOT NULL,
                target_identifier VARCHAR(80) NOT NULL,
                target_name VARCHAR(80) NOT NULL,
                status VARCHAR(20) NOT NULL DEFAULT 'pending',
                expires_at TIMESTAMP NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_org_invites_org (org_id),
                KEY idx_org_invites_target (target_identifier),
                KEY idx_org_invites_status (status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )

    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS org_assets (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                org_id INT UNSIGNED NOT NULL,
                asset_type VARCHAR(20) NOT NULL,
                model VARCHAR(64) NOT NULL,
                label VARCHAR(80) NOT NULL,
                required_level INT NOT NULL DEFAULT 1,
                required_rank_weight INT NOT NULL DEFAULT 0,
                price INT NOT NULL DEFAULT 0,
                plate VARCHAR(12) NOT NULL,
                stored TINYINT(1) NOT NULL DEFAULT 1,
                last_spawn_by VARCHAR(80) NULL,
                metadata LONGTEXT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_org_asset_plate (plate),
                KEY idx_org_assets_org (org_id),
                KEY idx_org_assets_type (asset_type)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )

    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS org_logs (
                id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
                org_id INT UNSIGNED NOT NULL,
                actor_identifier VARCHAR(80) NOT NULL,
                actor_name VARCHAR(80) NOT NULL,
                action VARCHAR(64) NOT NULL,
                details LONGTEXT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                KEY idx_org_logs_org (org_id),
                KEY idx_org_logs_action (action)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )

    MySQL.query.await(
        [[
            CREATE TABLE IF NOT EXISTS org_mission_cooldowns (
                id INT UNSIGNED NOT NULL AUTO_INCREMENT,
                org_id INT UNSIGNED NOT NULL,
                mission_id VARCHAR(64) NOT NULL,
                next_available_at TIMESTAMP NOT NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (id),
                UNIQUE KEY uq_org_mission (org_id, mission_id),
                KEY idx_org_mission_org (org_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]
    )
end

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local sourcePlayer = tonumber(playerId) or source
    if not sourcePlayer then
        return
    end

    Wait(750)
    loadPlayerState(sourcePlayer)
    pushSync(sourcePlayer, false)
end)

AddEventHandler('esx:onPlayerLogout', function(playerId)
    local sourcePlayer = tonumber(playerId) or source
    if not sourcePlayer then
        return
    end

    PlayerStates[sourcePlayer] = nil
    ActiveMissions[sourcePlayer] = nil
    LastActionAt[sourcePlayer] = nil
    TriggerClientEvent('esx_orgs:client:setActiveMission', sourcePlayer, nil)
    TriggerClientEvent('esx_orgs:client:syncState', sourcePlayer, {
        membership = nil,
        points = {},
        pendingInvites = {},
        activeMission = nil
    })
end)

AddEventHandler('playerDropped', function()
    local sourcePlayer = source
    PlayerStates[sourcePlayer] = nil
    ActiveMissions[sourcePlayer] = nil
    LastActionAt[sourcePlayer] = nil
end)

MySQL.ready(function()
    createTables()
    registerAllStashes()

    for _, playerId in ipairs(GetPlayers()) do
        local sourcePlayer = tonumber(playerId)
        loadPlayerState(sourcePlayer)
        pushSync(sourcePlayer, false)
    end

    print('[esx_org_hub] Tablas verificadas y sistema iniciado.')
end)
