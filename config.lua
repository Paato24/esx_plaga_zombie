Config = {}

-- Probabilidad de infeccion (1-100) cuando un zombie golpea al jugador.
Config.InfectionChance = 30

-- Evita multiples intentos de infeccion por spam de golpes.
Config.InfectionCooldownMs = 15000

-- Tiempo entre ticks de progresion de la infeccion.
Config.StageTickMs = 30000

-- Fase maxima de infeccion.
Config.MaxStage = 4

-- Vida minima para no matar al jugador por el tick.
Config.MinimumHealth = 110

-- Danio aplicado en cada fase por tick.
Config.DamageByStage = {
    [1] = 0,
    [2] = 2,
    [3] = 4,
    [4] = 7
}

-- Mensajes al avanzar de fase.
Config.StageMessages = {
    [1] = 'Sientes un malestar raro... Puede ser una infeccion.',
    [2] = 'La infeccion avanza. Tu cuerpo se debilita.',
    [3] = 'Fiebre alta y dolor intenso. Busca un antidoto.',
    [4] = 'Estado critico. Necesitas curarte ya.'
}

-- Efectos visuales por fase.
Config.TimecycleByStage = {
    [1] = nil,
    [2] = 'damage',
    [3] = 'damage',
    [4] = 'spectator6'
}

-- Modelos de peds que cuentan como zombies.
Config.ZombieModels = {
    `u_m_y_zombie_01`,
    `a_m_m_hillbilly_02`,
    `a_m_m_hillbilly_01`
}

-- Item utilizable para curarse.
Config.AntidoteItem = 'antidoto_zombie'

-- Comandos del recurso.
Config.Commands = {
    infect = 'infectar',
    cure = 'curarzombie',
    status = 'estadozombie'
}

-- Grupos ESX permitidos para comandos administrativos.
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true
}

-- Mensajes generales.
Config.Messages = {
    infected = 'Has sido infectado por la plaga zombie.',
    cured = 'Te has curado de la plaga zombie.',
    notInfected = 'No estas infectado.',
    noPermission = 'No tienes permisos para usar este comando.',
    invalidPlayer = 'Jugador no valido.',
    alreadyInfected = 'Ese jugador ya esta infectado.',
    alreadyHealthy = 'Ese jugador no esta infectado.',
    antidoteNoNeed = 'No puedes usar esto porque no estas infectado.',
    antidoteUsed = 'Has usado un antidoto y te sientes mejor.'
}
