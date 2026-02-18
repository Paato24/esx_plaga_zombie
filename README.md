# esx_plaga_zombie

Script para FiveM + ESX Legacy (ultima version) que agrega una plaga zombie con:

- Infeccion por golpes de peds zombie configurables
- Progresion por fases con dano periodico
- Persistencia de estado en base de datos (oxmysql)
- Cura con item (`antidoto_zombie`)
- Comandos admin para infectar/curar jugadores

## Requisitos

- `es_extended` (ESX Legacy)
- `oxmysql`

## Estructura del recurso

```txt
esx_plaga_zombie/
├─ fxmanifest.lua
├─ config.lua
├─ client/main.lua
├─ server/main.lua
└─ sql/install.sql
```

## Instalacion

1. Copia la carpeta del recurso en tu directorio de recursos.
2. Ejecuta `sql/install.sql` en tu base de datos.
3. Agrega el item del antidoto segun tu inventario:
   - ESX clasico (tabla `items`): usa el INSERT comentado del SQL.
   - ox_inventory: registra `antidoto_zombie` en tus items.
4. En `server.cfg`, asegurate de iniciar dependencias antes:

```cfg
ensure oxmysql
ensure es_extended
ensure esx_plaga_zombie
```

## Configuracion rapida (`config.lua`)

- `Config.InfectionChance`: probabilidad de infeccion por golpe (1-100)
- `Config.ZombieModels`: modelos de peds que cuentan como zombies
- `Config.StageTickMs`: cada cuanto empeora la infeccion
- `Config.DamageByStage`: dano por fase
- `Config.AntidoteItem`: item para curarse
- `Config.AdminGroups`: grupos ESX con permisos de comandos admin

## Comandos

- `/estadozombie` -> muestra tu estado de infeccion
- `/infectar [id]` -> infecta jugador (admin/superadmin)
- `/curarzombie [id]` -> cura jugador (admin/superadmin)

Si usas `/infectar` o `/curarzombie` sin ID, se aplica al mismo admin que ejecuta el comando.

## Evento/Export util

Export del server:

```lua
local infected = exports['esx_plaga_zombie']:IsPlayerInfected(playerId)
```

## Notas

- El script tambien crea la tabla `zombie_infections` automaticamente al iniciar.
- Puedes ajustar mensajes, efectos visuales y fases en `config.lua`.