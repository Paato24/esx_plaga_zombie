Config = {}

Config.JobName = 'mcdonald'
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
    { item = 'mc_meat', label = 'Carne', coords = vec3(-1196.17, -899.78, 14.0) },
    { item = 'mc_bread', label = 'Pan', coords = vec3(-1197.04, -899.98, 14.0) },
    { item = 'mc_onion', label = 'Cebolla', coords = vec3(-1197.86, -900.08, 14.0) },
    { item = 'mc_mustard', label = 'Mostaza', coords = vec3(-1198.68, -900.21, 14.0) },
    { item = 'mc_mayo', label = 'Mayonesa', coords = vec3(-1199.50, -900.31, 14.0) },
    { item = 'mc_ketchup', label = 'Ketchup', coords = vec3(-1200.32, -900.45, 14.0) },
    { item = 'mc_tomato', label = 'Tomate', coords = vec3(-1201.08, -900.56, 14.0) }
}

Config.SupplyPackages = {
    meat_box = {
        label = 'Caja de carne x20',
        price = 900,
        items = {
            mc_meat = 20
        }
    },
    bread_box = {
        label = 'Caja de pan x40',
        price = 700,
        items = {
            mc_bread = 40
        }
    },
    veggie_box = {
        label = 'Caja de vegetales x50',
        price = 600,
        items = {
            mc_onion = 25,
            mc_tomato = 25
        }
    },
    sauce_box = {
        label = 'Caja de salsas x60',
        price = 550,
        items = {
            mc_mustard = 20,
            mc_mayo = 20,
            mc_ketchup = 20
        }
    }
}

Config.Recipes = {
    classic = {
        label = 'Mc Clasica',
        description = 'Carne, pan, cebolla, tomate, ketchup y mostaza.',
        price = 180,
        outputItem = 'mc_burger_classic',
        outputCount = 1,
        ingredients = {
            mc_bread = 2,
            mc_meat = 1,
            mc_onion = 1,
            mc_tomato = 1,
            mc_ketchup = 1,
            mc_mustard = 1
        }
    },
    royal = {
        label = 'Mc Royal',
        description = 'Carne doble, pan, cebolla, tomate, ketchup, mostaza y mayo.',
        price = 260,
        outputItem = 'mc_burger_royal',
        outputCount = 1,
        ingredients = {
            mc_bread = 2,
            mc_meat = 2,
            mc_onion = 1,
            mc_tomato = 1,
            mc_ketchup = 1,
            mc_mustard = 1,
            mc_mayo = 1
        }
    },
    max = {
        label = 'Mc Max',
        description = 'Carne triple con todo: pan, cebolla, tomate, ketchup, mostaza y mayo.',
        price = 340,
        outputItem = 'mc_burger_max',
        outputCount = 1,
        ingredients = {
            mc_bread = 2,
            mc_meat = 3,
            mc_onion = 1,
            mc_tomato = 2,
            mc_ketchup = 1,
            mc_mustard = 1,
            mc_mayo = 1
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
    onlyWorkers = 'Solo empleados de Macdonald.',
    onlyBoss = 'Solo el jefe o manager puede usar esta opcion.',
    invalidAmount = 'Cantidad invalida.',
    noSocietyFunds = 'La sociedad no tiene suficiente dinero.',
    noStock = 'No hay stock de este ingrediente.',
    craftingCancelled = 'Preparacion cancelada.',
    missingIngredients = 'No tienes todos los ingredientes requeridos.'
}
