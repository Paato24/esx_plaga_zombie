Config = {}

Config.JobName = 'burgerking'
Config.Debug = false

Config.BossGrades = {
    boss = true,
    manager = true
}

Config.TargetDistance = 2.0
Config.OrderSyncDelayMs = 200

Config.Points = {
    Boss = vec3(-1194.64, -895.72, 14.0),
    Craft = vec3(-1198.32, -897.62, 14.0),
    OrderKiosk = vec3(-1193.22, -892.36, 14.0),
    Pickup = vec3(-1194.86, -890.64, 14.0)
}

Config.IngredientPoints = {
    { item = 'bk_meat', label = 'Carne', coords = vec3(-1196.17, -899.78, 14.0) },
    { item = 'bk_bread', label = 'Pan', coords = vec3(-1197.04, -899.98, 14.0) },
    { item = 'bk_onion', label = 'Cebolla', coords = vec3(-1197.86, -900.08, 14.0) },
    { item = 'bk_mustard', label = 'Mostaza', coords = vec3(-1198.68, -900.21, 14.0) },
    { item = 'bk_mayo', label = 'Mayonesa', coords = vec3(-1199.50, -900.31, 14.0) },
    { item = 'bk_ketchup', label = 'Ketchup', coords = vec3(-1200.32, -900.45, 14.0) },
    { item = 'bk_tomato', label = 'Tomate', coords = vec3(-1201.08, -900.56, 14.0) }
}

Config.SupplyPackages = {
    meat_box = {
        label = 'Caja de carne x20',
        price = 900,
        items = {
            bk_meat = 20
        }
    },
    bread_box = {
        label = 'Caja de pan x40',
        price = 700,
        items = {
            bk_bread = 40
        }
    },
    veggie_box = {
        label = 'Caja de vegetales x50',
        price = 600,
        items = {
            bk_onion = 25,
            bk_tomato = 25
        }
    },
    sauce_box = {
        label = 'Caja de salsas x60',
        price = 550,
        items = {
            bk_mustard = 20,
            bk_mayo = 20,
            bk_ketchup = 20
        }
    }
}

Config.Recipes = {
    classic = {
        label = 'Burger Clasica',
        description = 'Carne, pan, cebolla, tomate, ketchup y mostaza.',
        price = 180,
        outputItem = 'bk_burger_classic',
        outputCount = 1,
        ingredients = {
            bk_bread = 2,
            bk_meat = 1,
            bk_onion = 1,
            bk_tomato = 1,
            bk_ketchup = 1,
            bk_mustard = 1
        }
    },
    royal = {
        label = 'Burger Royal',
        description = 'Carne doble, pan, cebolla, tomate, ketchup, mostaza y mayo.',
        price = 260,
        outputItem = 'bk_burger_royal',
        outputCount = 1,
        ingredients = {
            bk_bread = 2,
            bk_meat = 2,
            bk_onion = 1,
            bk_tomato = 1,
            bk_ketchup = 1,
            bk_mustard = 1,
            bk_mayo = 1
        }
    },
    max = {
        label = 'Burger Max',
        description = 'Carne triple con todo: pan, cebolla, tomate, ketchup, mostaza y mayo.',
        price = 340,
        outputItem = 'bk_burger_max',
        outputCount = 1,
        ingredients = {
            bk_bread = 2,
            bk_meat = 3,
            bk_onion = 1,
            bk_tomato = 2,
            bk_ketchup = 1,
            bk_mustard = 1,
            bk_mayo = 1
        }
    }
}

Config.ProgressDurations = {
    takeIngredient = 2000,
    prepStep = 2200,
    grillStep = 3800
}

Config.OrderStatuses = {
    pending = 'Pendiente',
    in_progress = 'En preparacion',
    ready = 'Listo para entregar',
    completed = 'Completado',
    cancelled = 'Cancelado'
}

Config.Notifications = {
    orderPlaced = 'Pedido enviado a cocina.',
    orderReady = 'Tu pedido esta listo para retirar.',
    noReadyOrder = 'No tienes pedidos listos para retirar.',
    onlyWorkers = 'Solo empleados de la hamburgueseria.',
    onlyBoss = 'Solo el jefe o manager puede usar esta opcion.',
    invalidAmount = 'Cantidad invalida.',
    noSocietyFunds = 'La sociedad no tiene suficiente dinero.',
    noStock = 'No hay stock de este ingrediente.',
    craftingCancelled = 'Preparacion cancelada.',
    missingIngredients = 'No tienes todos los ingredientes requeridos.'
}
