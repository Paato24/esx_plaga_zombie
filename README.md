# PaatoDev Macdonald

Trabajo de Macdonald para FiveM con:

- ESX (`es_extended`)
- `ox_inventory`
- `oxmysql`
- `ox_lib`
- `ox_target`
- Tablet NUI en F5 para empleados
- Pedidos de clientes en tiempo real
- Crafteo paso a paso con barra de progreso
- Punto de jefe para sociedad (depositar, retirar, comprar stock)

> Creador: **PaatoDev**

---

## Caracteristicas

- **Punto de pedidos para clientes** (menu con opciones Mc y detalle de ingredientes).
- **Pago en efectivo o banco** para enviar el pedido.
- **Sincronizacion en vivo** a empleados mediante tablet HTML (tecla **F5**).
- **Gestion de estados de pedido**: pendiente -> en preparacion -> listo.
- **Punto de retiro** para que el cliente retire su pedido listo.
- **Sistema de stock de ingredientes** por sociedad.
- **Punto de jefe**:
  - ver saldo de sociedad
  - depositar dinero
  - retirar dinero
  - comprar paquetes de insumos
- **Puntos de ingredientes** para sacar items (carne, pan, cebolla, mostaza, mayonesa, ketchup, tomate).
- **Crafteo paso a paso** con progreso por ingrediente.

---

## Estructura del recurso

```text
paatodev_macdonald/
├─ fxmanifest.lua
├─ config.lua
├─ client/
│  └─ main.lua
├─ server/
│  └─ main.lua
├─ web/
│  ├─ index.html
│  ├─ style.css
│  └─ app.js
└─ sql/
   └─ paatodev_macdonald.sql
```

---

## Instalacion

1. Copia este recurso a tu carpeta `resources`.
2. Renombra la carpeta (si hace falta) a `paatodev_macdonald`.
3. Agrega en `server.cfg`:

```cfg
ensure paatodev_macdonald
```

4. Ejecuta el SQL:
   - `sql/paatodev_macdonald.sql`
5. Agrega los items en `ox_inventory/data/items.lua` (ver ejemplo).
6. Reinicia el servidor.

---

## Dependencias requeridas

- `es_extended`
- `ox_lib`
- `ox_target`
- `ox_inventory`
- `oxmysql`

---

## Items para ox_inventory (ejemplo)

Agrega estos items en tu `ox_inventory/data/items.lua`:

```lua
['mc_meat'] = {
    label = 'Carne',
    weight = 120,
    stack = true,
    close = false,
    description = 'Carne para menu Macdonald'
},
['mc_bread'] = {
    label = 'Pan',
    weight = 80,
    stack = true,
    close = false
},
['mc_onion'] = {
    label = 'Cebolla',
    weight = 40,
    stack = true,
    close = false
},
['mc_mustard'] = {
    label = 'Mostaza',
    weight = 35,
    stack = true,
    close = false
},
['mc_mayo'] = {
    label = 'Mayonesa',
    weight = 35,
    stack = true,
    close = false
},
['mc_ketchup'] = {
    label = 'Ketchup',
    weight = 35,
    stack = true,
    close = false
},
['mc_tomato'] = {
    label = 'Tomate',
    weight = 45,
    stack = true,
    close = false
},
['mc_burger_classic'] = {
    label = 'Mc Clasica',
    weight = 260,
    stack = true,
    close = true,
    description = 'Hamburguesa clasica Macdonald'
},
['mc_burger_royal'] = {
    label = 'Mc Royal',
    weight = 330,
    stack = true,
    close = true
},
['mc_burger_max'] = {
    label = 'Mc Max',
    weight = 380,
    stack = true,
    close = true
},
```

---

## Configuracion principal (`config.lua`)

- `Config.JobName` -> nombre del job (por defecto: `mcdonald`)
- `Config.BossGrades` -> grados que pueden usar panel de jefe
- `Config.Points` -> puntos principales (jefe, cocina, pedidos, retiro)
- `Config.IngredientPoints` -> puntos para retirar ingredientes
- `Config.SupplyPackages` -> paquetes de compra de stock
- `Config.Recipes` -> recetas, precio al cliente y requisitos de crafteo

---

## Flujo de juego recomendado

1. El jefe compra stock desde el punto de jefe.
2. Empleados retiran ingredientes en los puntos de cocina.
3. Clientes hacen pedido y pagan en el punto de pedidos.
4. Empleados abren tablet con **F5** y toman pedidos en tiempo real.
5. Empleados cocinan en la zona de crafteo (paso a paso).
6. Marcan el pedido como listo.
7. Cliente retira en el punto de retiro.

---

## Creditos

- Desarrollo: **PaatoDev**