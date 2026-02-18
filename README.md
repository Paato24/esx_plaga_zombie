# esx_org_hub (ESX Legacy)

Script completo para FiveM con:

- ESX Legacy (`es_extended`)
- `oxmysql` (tablas auto creadas)
- `ox_inventory`
- NUI HTML (panel completo)
- Marcadores circulares con tecla **E**

## Incluye

- Creacion de **banda / mafia / cartel**
- Sistema de niveles y progreso (XP + level up)
- Rangos con permisos granulares
- Fondos de organizacion (deposito/retiro)
- Invitaciones a organizacion (con expiracion)
- Puntos interactivos:
  - boss
  - clothing
  - inventory (stash org de ox_inventory)
  - organization
  - mission
  - drug_process
  - weapon_shop
  - invite
  - garage
  - hangar
- Misiones de organizacion (con cooldown)
- Procesamiento de drogas por recetas
- Tienda de armas por nivel/rango
- Gestion de activos:
  - compra de vehiculos y aeronaves
  - sacar/guardar en garage/hangar
- Logs de acciones importantes

## Estructura

```txt
esx_org_hub/
|- fxmanifest.lua
|- config.lua
|- client/main.lua
|- server/main.lua
`- html/
   |- index.html
   |- style.css
   `- app.js
```

## Instalacion

1. Copia la carpeta del recurso a tu carpeta de recursos.
2. Asegura dependencias en `server.cfg`:

```cfg
ensure oxmysql
ensure es_extended
ensure ox_inventory
ensure <nombre_de_tu_carpeta_recurso>
```

3. Reinicia el servidor o ejecuta `ensure <nombre_de_tu_carpeta_recurso>`.

## Base de datos

No necesitas importar SQL manual.
El script crea automaticamente estas tablas con `oxmysql`:

- `orgs`
- `org_ranks`
- `org_members`
- `org_points`
- `org_invites`
- `org_assets`
- `org_logs`
- `org_mission_cooldowns`

## Uso rapido en juego

1. Ve al marcador de registro (configurable en `Config.CreateOrganizationMarkers`).
2. Pulsa **E** y crea la organizacion.
3. Usa los marcadores de la org para abrir paneles y funciones.
4. Ajusta ubicaciones de puntos desde la pestana **Puntos** (en punto boss/organization).

## Configuracion clave (`config.lua`)

- Costos y limites por tipo de org
- Rutas de misiones y recompensas
- Recetas de drogas
- Catalogo de vehiculos y aeronaves
- Tienda de armas
- Permisos y rangos por defecto
- Cuentas de dinero (`bank`/`cash`)

## Notas importantes

- Si tu inventario usa nombres de items distintos, ajusta:
  - `Config.DrugRecipes`
  - `Config.WeaponShop`
- El punto de ropa soporta:
  - `esx_skin`
  - `illenium`
  - evento custom
- Todas las acciones sensibles se validan en servidor.