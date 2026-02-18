Config = {}

Config.InteractKey = 38 -- E

Config.Marker = {
    Type = 1,
    DrawDistance = 35.0,
    InteractDistance = 2.25,
    Scale = {
        x = 1.25,
        y = 1.25,
        z = 0.40
    },
    Alpha = 165
}

Config.ServerDistanceTolerance = 3.0
Config.MissionCompletionDistance = 8.0
Config.InviteDurationMinutes = 30
Config.MaxPointsPerType = 12

Config.CreationMoneyAccount = 'bank' -- bank or cash
Config.PlayerDepositAccount = 'cash' -- bank or cash
Config.PlayerWithdrawAccount = 'cash' -- bank or cash
Config.CreationNameMinLength = 3
Config.CreationNameMaxLength = 32
Config.TagMinLength = 2
Config.TagMaxLength = 6

Config.Stash = {
    Slots = 140,
    MaxWeight = 600000
}

Config.Clothing = {
    Mode = 'esx_skin', -- esx_skin, illenium, custom
    CustomClientEvent = '',
    Saveable = true
}

Config.CreationPointCustomization = {
    Enabled = true,
    MaxCustomPoints = 30,
    AllowMultiplePerType = true,
    MaxDistanceFromCreationMarker = 300.0,
    RequiredPointTypes = {
        'boss',
        'organization',
        'inventory',
        'clothing',
        'mission',
        'invite',
        'garage',
        'hangar',
        'drug_process',
        'weapon_shop'
    }
}

Config.PointVisibility = {
    Enabled = true,
    DefaultMinRankWeight = 0,
    MinRankByPointType = {
        boss = 70,
        organization = 0,
        inventory = 0,
        clothing = 0,
        mission = 0,
        invite = 55,
        weapon_shop = 30,
        drug_process = 30,
        garage = 0,
        hangar = 40
    }
}

Config.Blips = {
    Enabled = true,
    Scale = 0.78,
    DefaultSprite = 84,
    DefaultColor = 27,
    DefaultMinRankWeight = 0,
    MinRankByPointType = {
        boss = 70,
        invite = 55,
        hangar = 40
    },
    SpriteByPointType = {
        boss = 457,
        clothing = 73,
        inventory = 478,
        organization = 84,
        mission = 280,
        drug_process = 499,
        weapon_shop = 110,
        invite = 153,
        garage = 357,
        hangar = 64
    },
    ColorByPointType = {
        boss = 1,
        clothing = 3,
        inventory = 46,
        organization = 7,
        mission = 2,
        drug_process = 25,
        weapon_shop = 17,
        invite = 4,
        garage = 38,
        hangar = 39
    }
}

Config.VehicleKeys = {
    Enabled = false,
    ClientEvent = 'vehiclekeys:client:SetOwner'
}

Config.MissionsSettings = {
    Cooperative = true,
    RequireJoinToComplete = true,
    RewardSplitMode = 'split', -- split or full
    XpBonusPerExtraParticipant = 0.10,
    MaxXpBonusMultiplier = 1.50
}

Config.Economy = {
    DynamicPricing = true,
    LevelDiscountPerLevel = 2.0,
    MaxLevelDiscount = 30.0,
    WeaponUsageIncreasePerPurchase = 4.0,
    DrugUsageIncreasePerProcess = 3.0,
    MaxUsageIncrease = 45.0,
    DailyLimits = {
        weaponPurchases = 8,
        drugProcesses = 12
    },
    DefaultDrugProcessFee = 8000
}

Config.Logs = {
    MaxRowsInNui = 180
}

Config.LevelThresholds = {
    0,
    600,
    1500,
    2800,
    4500,
    6800,
    9800,
    13500,
    18000,
    23500
}

Config.PermissionLabels = {
    manage_org = 'Gestion general',
    manage_members = 'Gestion de miembros',
    manage_ranks = 'Gestion de rangos',
    manage_points = 'Gestion de puntos',
    manage_assets = 'Gestion de activos',
    manage_funds = 'Gestion de fondos',
    manage_shop = 'Gestion de tiendas',
    manage_invites = 'Gestion de invitaciones',
    use_stash = 'Usar inventario org',
    use_clothing = 'Usar ropa org',
    use_drugs = 'Procesar drogas',
    use_weapons = 'Usar tienda de armas',
    use_garage = 'Usar garaje',
    use_hangar = 'Usar hangar',
    use_missions = 'Iniciar misiones'
}

Config.PointTypes = {
    boss = {
        label = 'Punto jefe',
        interactLabel = 'Abrir panel de jefe',
        color = { r = 220, g = 60, b = 60 },
        radius = 2.0
    },
    clothing = {
        label = 'Punto de ropa',
        interactLabel = 'Abrir vestidor',
        color = { r = 102, g = 153, b = 255 },
        radius = 2.0
    },
    inventory = {
        label = 'Punto de inventario',
        interactLabel = 'Abrir inventario org',
        color = { r = 255, g = 189, b = 66 },
        radius = 2.0
    },
    organization = {
        label = 'Punto de organizacion',
        interactLabel = 'Abrir panel organizacion',
        color = { r = 193, g = 117, b = 255 },
        radius = 2.0
    },
    mission = {
        label = 'Punto de misiones',
        interactLabel = 'Abrir panel de misiones',
        color = { r = 89, g = 214, b = 171 },
        radius = 2.0
    },
    drug_process = {
        label = 'Punto de drogas',
        interactLabel = 'Abrir laboratorio',
        color = { r = 68, g = 200, b = 92 },
        radius = 2.0
    },
    weapon_shop = {
        label = 'Punto tienda armas',
        interactLabel = 'Abrir armeria',
        color = { r = 200, g = 88, b = 34 },
        radius = 2.0
    },
    invite = {
        label = 'Punto de invitacion',
        interactLabel = 'Gestionar invitaciones',
        color = { r = 60, g = 201, b = 211 },
        radius = 2.0
    },
    garage = {
        label = 'Punto de garaje',
        interactLabel = 'Gestionar vehiculos',
        color = { r = 240, g = 202, b = 70 },
        radius = 2.6
    },
    hangar = {
        label = 'Punto de hangar',
        interactLabel = 'Gestionar aeronaves',
        color = { r = 164, g = 200, b = 255 },
        radius = 2.8
    }
}

Config.DefaultPointOffsets = {
    boss = { x = 0.0, y = 0.0, z = 0.0, heading = 0.0 },
    clothing = { x = 2.0, y = 1.0, z = 0.0, heading = 0.0 },
    inventory = { x = -2.0, y = 1.0, z = 0.0, heading = 0.0 },
    organization = { x = 0.0, y = -2.0, z = 0.0, heading = 0.0 },
    mission = { x = 2.0, y = -2.0, z = 0.0, heading = 0.0 },
    drug_process = { x = -2.0, y = -2.0, z = 0.0, heading = 0.0 },
    weapon_shop = { x = 3.5, y = 0.0, z = 0.0, heading = 0.0 },
    invite = { x = -3.5, y = 0.0, z = 0.0, heading = 0.0 },
    garage = { x = 8.0, y = 0.0, z = 0.0, heading = 0.0 },
    hangar = { x = 0.0, y = 12.0, z = 0.0, heading = 0.0 }
}

Config.SpawnOffsets = {
    garage = 6.5,
    hangar = 10.0
}

Config.CreateOrganizationMarkers = {
    {
        label = 'Registro de organizaciones',
        coords = { x = -545.38, y = -204.23, z = 38.22, heading = 185.0 }
    },
    {
        label = 'Registro de organizaciones',
        coords = { x = 314.90, y = -592.53, z = 43.28, heading = 67.0 }
    }
}

Config.OrganizationTypes = {
    banda = {
        label = 'Banda',
        createPrice = 250000,
        maxMembers = 25,
        defaultRanks = {
            { name = 'Jefe', weight = 100, permissions = '*' },
            {
                name = 'Mano derecha',
                weight = 80,
                permissions = {
                    'manage_members',
                    'manage_invites',
                    'manage_assets',
                    'manage_points',
                    'manage_funds',
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_hangar',
                    'use_missions'
                }
            },
            {
                name = 'Soldado',
                weight = 55,
                permissions = {
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_missions'
                }
            },
            {
                name = 'Recluta',
                weight = 15,
                permissions = {
                    'use_stash',
                    'use_clothing',
                    'use_garage'
                }
            }
        }
    },
    mafia = {
        label = 'Mafia',
        createPrice = 500000,
        maxMembers = 35,
        defaultRanks = {
            { name = 'Don', weight = 100, permissions = '*' },
            {
                name = 'Consigliere',
                weight = 85,
                permissions = {
                    'manage_org',
                    'manage_members',
                    'manage_invites',
                    'manage_assets',
                    'manage_points',
                    'manage_funds',
                    'manage_shop',
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_hangar',
                    'use_missions'
                }
            },
            {
                name = 'Capo',
                weight = 65,
                permissions = {
                    'manage_members',
                    'manage_invites',
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_hangar',
                    'use_missions'
                }
            },
            {
                name = 'Soldado',
                weight = 40,
                permissions = {
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_missions'
                }
            },
            {
                name = 'Asociado',
                weight = 15,
                permissions = {
                    'use_stash',
                    'use_clothing',
                    'use_garage'
                }
            }
        }
    },
    cartel = {
        label = 'Cartel',
        createPrice = 800000,
        maxMembers = 45,
        defaultRanks = {
            { name = 'Patron', weight = 100, permissions = '*' },
            {
                name = 'Comandante',
                weight = 85,
                permissions = {
                    'manage_org',
                    'manage_members',
                    'manage_invites',
                    'manage_assets',
                    'manage_points',
                    'manage_funds',
                    'manage_shop',
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_hangar',
                    'use_missions'
                }
            },
            {
                name = 'Teniente',
                weight = 70,
                permissions = {
                    'manage_members',
                    'manage_invites',
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_hangar',
                    'use_missions'
                }
            },
            {
                name = 'Operativo',
                weight = 45,
                permissions = {
                    'use_stash',
                    'use_clothing',
                    'use_drugs',
                    'use_weapons',
                    'use_garage',
                    'use_hangar',
                    'use_missions'
                }
            },
            {
                name = 'Novato',
                weight = 20,
                permissions = {
                    'use_stash',
                    'use_clothing',
                    'use_garage'
                }
            }
        }
    }
}

Config.AssetCatalog = {
    vehicle = {
        { model = 'sultan', label = 'Sultan', price = 45000, requiredLevel = 1, requiredRankWeight = 0 },
        { model = 'kuruma', label = 'Kuruma', price = 70000, requiredLevel = 2, requiredRankWeight = 40 },
        { model = 'schafter2', label = 'Schafter', price = 90000, requiredLevel = 3, requiredRankWeight = 40 },
        { model = 'jugular', label = 'Jugular', price = 130000, requiredLevel = 4, requiredRankWeight = 55 },
        { model = 'buffalo4', label = 'Buffalo STX', price = 185000, requiredLevel = 6, requiredRankWeight = 65 }
    },
    aircraft = {
        { model = 'maverick', label = 'Maverick', price = 300000, requiredLevel = 4, requiredRankWeight = 55 },
        { model = 'frogger', label = 'Frogger', price = 420000, requiredLevel = 6, requiredRankWeight = 65 },
        { model = 'swift', label = 'Swift', price = 650000, requiredLevel = 8, requiredRankWeight = 75 },
        { model = 'vestra', label = 'Vestra', price = 900000, requiredLevel = 9, requiredRankWeight = 80 }
    }
}

Config.WeaponShop = {
    { item = 'weapon_pistol', label = 'Pistola', price = 65000, requiredLevel = 2, requiredRankWeight = 35, xpGain = 20 },
    { item = 'weapon_combatpistol', label = 'Combat Pistol', price = 85000, requiredLevel = 3, requiredRankWeight = 45, xpGain = 30 },
    { item = 'weapon_microsmg', label = 'Micro SMG', price = 140000, requiredLevel = 4, requiredRankWeight = 55, xpGain = 45 },
    { item = 'weapon_smg', label = 'SMG', price = 210000, requiredLevel = 6, requiredRankWeight = 65, xpGain = 55 },
    { item = 'weapon_assaultrifle', label = 'Assault Rifle', price = 350000, requiredLevel = 8, requiredRankWeight = 80, xpGain = 70 }
}

Config.DrugRecipes = {
    {
        id = 'cocaine_batch',
        label = 'Procesar cocaina',
        requiredLevel = 3,
        requiredRankWeight = 35,
        xpGain = 90,
        processFee = 12000,
        inputs = {
            { item = 'coca_leaf', count = 6 },
            { item = 'acetone', count = 2 }
        },
        outputs = {
            { item = 'cocaine_brick', count = 1 }
        }
    },
    {
        id = 'meth_batch',
        label = 'Procesar metanfetamina',
        requiredLevel = 5,
        requiredRankWeight = 45,
        xpGain = 120,
        processFee = 16000,
        inputs = {
            { item = 'ephedrine', count = 5 },
            { item = 'chemical_solvent', count = 3 }
        },
        outputs = {
            { item = 'meth_bag', count = 2 }
        }
    },
    {
        id = 'weed_bricks',
        label = 'Empaquetar marihuana',
        requiredLevel = 2,
        requiredRankWeight = 20,
        xpGain = 50,
        processFee = 5000,
        inputs = {
            { item = 'weed', count = 10 }
        },
        outputs = {
            { item = 'weed_brick', count = 1 }
        }
    }
}

Config.Missions = {
    {
        id = 'delivery_docs',
        label = 'Entrega confidencial',
        description = 'Lleva documentos a un contacto sin perder el paquete.',
        requiredLevel = 1,
        requiredRankWeight = 15,
        cooldownSeconds = 900,
        xpGain = 150,
        orgFundsReward = 50000,
        playerMoneyReward = 5000,
        targets = {
            { x = -1046.80, y = -2740.74, z = 21.36 },
            { x = 1729.20, y = 6414.37, z = 35.04 },
            { x = 1262.89, y = -2564.25, z = 42.70 }
        }
    },
    {
        id = 'supply_run',
        label = 'Ruta de suministros',
        description = 'Recoge suministros ilegales y completa la entrega final.',
        requiredLevel = 3,
        requiredRankWeight = 35,
        cooldownSeconds = 1200,
        xpGain = 240,
        orgFundsReward = 90000,
        playerMoneyReward = 9000,
        targets = {
            { x = 2540.38, y = 2590.74, z = 37.95 },
            { x = -2231.39, y = 348.36, z = 174.60 },
            { x = 1413.47, y = 1118.24, z = 114.84 }
        }
    },
    {
        id = 'high_value_transfer',
        label = 'Transferencia de alto valor',
        description = 'Mision de riesgo alto con mayor retorno para la organizacion.',
        requiredLevel = 6,
        requiredRankWeight = 55,
        cooldownSeconds = 1800,
        xpGain = 420,
        orgFundsReward = 160000,
        playerMoneyReward = 15000,
        targets = {
            { x = -1537.16, y = 128.15, z = 57.37 },
            { x = 2676.47, y = 3280.40, z = 55.24 },
            { x = -3048.88, y = 587.67, z = 7.91 }
        }
    }
}

Config.Messages = {
    onlyOrgMembers = 'Debes pertenecer a una organizacion para usar esto.',
    noPermission = 'No tienes permiso para esta accion.',
    notNearPoint = 'Debes estar en el punto correspondiente.',
    invalidAmount = 'Cantidad invalida.',
    orgCreated = 'Organizacion creada correctamente.',
    inviteSent = 'Invitacion enviada.',
    inviteAccepted = 'Invitacion aceptada.',
    inviteRejected = 'Invitacion rechazada.',
    stashOpened = 'Abriendo inventario de organizacion...',
    vehicleStored = 'Activo guardado en el garaje.',
    missionStarted = 'Mision iniciada. Se marco el objetivo en el mapa.',
    missionCompleted = 'Mision completada con exito.',
    missionNoActive = 'No tienes una mision activa.',
    missionAlreadyActive = 'Tu organizacion ya tiene una mision activa.',
    missionJoined = 'Te uniste a la mision activa.',
    missionLeft = 'Saliste de la mision activa.',
    missionNeedJoin = 'Debes unirte a la mision antes de completarla.',
    recipeDone = 'Proceso completado.',
    weaponBought = 'Compra realizada.',
    clothingOpened = 'Abriendo vestidor...',
    ownershipTransferred = 'Liderazgo transferido correctamente.',
    dailyLimitReached = 'Se alcanzo el limite diario para esta accion.',
    createPointCaptured = 'Punto inicial capturado para creacion.',
    createPointRemoved = 'Punto inicial removido.',
    createPointsCleared = 'Puntos iniciales limpiados.'
}
