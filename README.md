# PaatoDev Burger Job

Trabajo de hamburgueseria para FiveM con:

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

- **Punto de pedidos para clientes** (menu con hamburguesas, ingredientes y precio).
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
- **Crafteo paso a paso** de hamburguesas con animacion de progreso por ingrediente.

---

## Estructura del recurso

```text
paatodev_burgerjob/
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
   └─ paatodev_burgerjob.sql
```

---

## Instalacion

1. Copia este recurso a tu carpeta `resources`.
2. Renombra la carpeta (opcional) y agrega en `server.cfg`:

```cfg
ensure paatodev_burgerjob
```

3. Ejecuta el SQL:
   - `sql/paatodev_burgerjob.sql`
4. Agrega los items en `ox_inventory/data/items.lua` (ver bloque de ejemplo abajo).
5. Reinicia el servidor.

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
['bk_meat'] = {
    label = 'Carne',
    weight = 120,
    stack = true,
    close = false,
    description = 'Carne para hamburguesas'
},
['bk_bread'] = {
    label = 'Pan',
    weight = 80,
    stack = true,
    close = false,
    description = 'Pan de hamburguesa'
},
['bk_onion'] = {
    label = 'Cebolla',
    weight = 40,
    stack = true,
    close = false
},
['bk_mustard'] = {
    label = 'Mostaza',
    weight = 35,
    stack = true,
    close = false
},
['bk_mayo'] = {
    label = 'Mayonesa',
    weight = 35,
    stack = true,
    close = false
},
['bk_ketchup'] = {
    label = 'Ketchup',
    weight = 35,
    stack = true,
    close = false
},
['bk_tomato'] = {
    label = 'Tomate',
    weight = 45,
    stack = true,
    close = false
},
['bk_burger_classic'] = {
    label = 'Burger Clasica',
    weight = 260,
    stack = true,
    close = true,
    description = 'Hamburguesa clasica'
},
['bk_burger_royal'] = {
    label = 'Burger Royal',
    weight = 330,
    stack = true,
    close = true,
    description = 'Hamburguesa royal'
},
['bk_burger_max'] = {
    label = 'Burger Max',
    weight = 380,
    stack = true,
    close = true,
    description = 'Hamburguesa premium completa'
},
```

> Si quieres que las hamburguesas den hambre/sed, te recomiendo agregar export de `esx_status` o tu sistema de consumo.

---

## Configuracion principal (`config.lua`)

- `Config.JobName` -> nombre del job (por defecto: `burgerking`)
- `Config.BossGrades` -> grados que pueden usar panel de jefe
- `Config.Points` -> puntos principales (jefe, cocina, pedidos, retiro)
- `Config.IngredientPoints` -> puntos individuales para retirar ingredientes
- `Config.SupplyPackages` -> paquetes de compra de stock
- `Config.Recipes` -> recetas, precio al cliente y requisitos de crafteo

Puedes mover todos los puntos a tus coordenadas sin tocar la logica.

---

## Flujo de juego recomendado

1. El jefe compra stock desde el punto de jefe.
2. Empleados retiran ingredientes en los puntos de cocina.
3. Clientes hacen pedido y pagan en el punto de pedidos.
4. Empleados abren tablet con **F5** y toman pedidos en tiempo real.
5. Empleados cocinan hamburguesas en la zona de crafteo (paso a paso).
6. Marcan el pedido como listo.
7. Cliente retira en el punto de retiro.

---

## Estados de pedido

- `pending` -> pendiente
- `in_progress` -> en preparacion
- `ready` -> listo para retirar
- `completed` -> completado (al retirar)
- `cancelled` -> cancelado

---

## Recomendaciones

- Ajustar precios y salarios de job segun economia de tu servidor.
- Definir uniforms por grado si usas skinchanger/fivem-appearance.
- Si quieres mas inmersion, se puede agregar:
  - tickets impresos
  - bandejas por numero de orden
  - sistema de drive-thru
  - reportes diarios de ventas

---

## Creditos

- Desarrollo: **PaatoDev**
- Implementacion tecnica base: ESX + ox ecosystem