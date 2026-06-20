# Diccionario de datos

Este documento describe las tablas declaradas explícitamente en los scripts SQL del repositorio para las bases `ventas_oltp` y `ventas_dw`.

> Nota: cuando una tabla se referencia en un procedimiento pero no se define en los scripts disponibles (por ejemplo `dw.etl_log`), se marca como `pendiente de confirmar`.

---

## Base `ventas_oltp`

### Esquema `sales`

Las tablas de este esquema representan el modelo transaccional de ventas.

#### `sales.categories`
- **Descripción:** Catálogo de categorías de productos.
- **Claves:**
  - PK: `category_id`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `category_id` | `INT` | No | PK | Identificador de la categoría. Se genera con identidad. |
| `category_name` | `NVARCHAR(100)` | No |  | Nombre de la categoría. |
| `created_at` | `DATETIME2(0)` | No |  | Fecha de creación. Valor por defecto `SYSUTCDATETIME()`. |

#### `sales.products`
- **Descripción:** Catálogo de productos disponibles para venta.
- **Claves:**
  - PK: `product_id`
  - FK: `category_id` → `sales.categories(category_id)`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `product_id` | `INT` | No | PK | Identificador del producto. Se genera con identidad. |
| `product_name` | `NVARCHAR(200)` | No |  | Nombre del producto. |
| `category_id` | `INT` | No | FK | Referencia a la categoría del producto. |
| `unit_price` | `DECIMAL(12,2)` | No |  | Precio unitario del producto. |
| `is_active` | `BIT` | No |  | Indica si el producto está activo. |
| `created_at` | `DATETIME2(0)` | No |  | Fecha de creación. Valor por defecto `SYSUTCDATETIME()`. |

#### `sales.customers`
- **Descripción:** Clientes del negocio.
- **Claves:**
  - PK: `customer_id`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `customer_id` | `INT` | No | PK | Identificador del cliente. Se genera con identidad. |
| `full_name` | `NVARCHAR(200)` | No |  | Nombre completo del cliente. |
| `email` | `NVARCHAR(200)` | Sí |  | Correo electrónico del cliente. |
| `city` | `NVARCHAR(100)` | Sí |  | Ciudad del cliente. |
| `country_code` | `CHAR(2)` | No |  | Código ISO del país. Valor por defecto `PE`. |
| `created_at` | `DATETIME2(0)` | No |  | Fecha de creación. Valor por defecto `SYSUTCDATETIME()`. |

#### `sales.orders`
- **Descripción:** Cabeceras de pedidos realizados por clientes.
- **Claves:**
  - PK: `order_id`
  - FK: `customer_id` → `sales.customers(customer_id)`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `order_id` | `INT` | No | PK | Identificador del pedido. Se genera con identidad. |
| `customer_id` | `INT` | No | FK | Referencia al cliente que realizó el pedido. |
| `order_date` | `DATETIME2(0)` | No |  | Fecha del pedido. |
| `status` | `VARCHAR(20)` | No |  | Estado del pedido. Valor por defecto `CONFIRMED`. |

#### `sales.order_items`
- **Descripción:** Líneas detalle asociadas a cada pedido.
- **Claves:**
  - PK: `order_item_id`
  - FK: `order_id` → `sales.orders(order_id)`
  - FK: `product_id` → `sales.products(product_id)`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `order_item_id` | `INT` | No | PK | Identificador de la línea de pedido. Se genera con identidad. |
| `order_id` | `INT` | No | FK | Referencia al pedido. |
| `product_id` | `INT` | No | FK | Referencia al producto. |
| `quantity` | `INT` | No |  | Cantidad comprada. |
| `unit_price` | `DECIMAL(12,2)` | No |  | Precio unitario de la línea. |

---

## Base `ventas_dw`

### Esquema `stg`

Las tablas del esquema `stg` son tablas de staging, cargadas por ADF con el patrón truncate/load. No se definen restricciones de PK/FK en el script.

#### `stg.categories`
- **Descripción:** Copia cruda de `sales.categories` en staging.
- **Claves:**
  - Sin PK/FK declaradas.
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `category_id` | `INT` | Sí |  | Identificador de categoría desde origen. |
| `category_name` | `NVARCHAR(100)` | Sí |  | Nombre de categoría desde origen. |
| `created_at` | `DATETIME2(0)` | Sí |  | Fecha de creación desde origen. |

#### `stg.products`
- **Descripción:** Copia cruda de `sales.products` en staging.
- **Claves:**
  - Sin PK/FK declaradas.
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `product_id` | `INT` | Sí |  | Identificador de producto desde origen. |
| `product_name` | `NVARCHAR(200)` | Sí |  | Nombre de producto desde origen. |
| `category_id` | `INT` | Sí |  | Identificador de categoría desde origen. |
| `unit_price` | `DECIMAL(12,2)` | Sí |  | Precio unitario desde origen. |
| `is_active` | `BIT` | Sí |  | Indicador de actividad desde origen. |
| `created_at` | `DATETIME2(0)` | Sí |  | Fecha de creación desde origen. |

#### `stg.customers`
- **Descripción:** Copia cruda de `sales.customers` en staging.
- **Claves:**
  - Sin PK/FK declaradas.
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `customer_id` | `INT` | Sí |  | Identificador de cliente desde origen. |
| `full_name` | `NVARCHAR(200)` | Sí |  | Nombre completo desde origen. |
| `email` | `NVARCHAR(200)` | Sí |  | Correo electrónico desde origen. |
| `city` | `NVARCHAR(100)` | Sí |  | Ciudad desde origen. |
| `country_code` | `CHAR(2)` | Sí |  | Código de país desde origen. |
| `created_at` | `DATETIME2(0)` | Sí |  | Fecha de creación desde origen. |

#### `stg.orders`
- **Descripción:** Copia cruda de `sales.orders` en staging.
- **Claves:**
  - Sin PK/FK declaradas.
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `order_id` | `INT` | Sí |  | Identificador de pedido desde origen. |
| `customer_id` | `INT` | Sí |  | Identificador del cliente desde origen. |
| `order_date` | `DATETIME2(0)` | Sí |  | Fecha del pedido desde origen. |
| `status` | `VARCHAR(20)` | Sí |  | Estado del pedido desde origen. |

#### `stg.order_items`
- **Descripción:** Copia cruda de `sales.order_items` en staging.
- **Claves:**
  - Sin PK/FK declaradas.
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `order_item_id` | `INT` | Sí |  | Identificador de la línea de pedido desde origen. |
| `order_id` | `INT` | Sí |  | Identificador del pedido desde origen. |
| `product_id` | `INT` | Sí |  | Identificador del producto desde origen. |
| `quantity` | `INT` | Sí |  | Cantidad desde origen. |
| `unit_price` | `DECIMAL(12,2)` | Sí |  | Precio unitario desde origen. |

### Esquema `dw`

Las tablas del esquema `dw` conforman el modelo estrella final.

#### `dw.dim_date`
- **Descripción:** Dimensión temporal generada y precargada para el año 2026.
- **Claves:**
  - PK: `date_sk`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `date_sk` | `INT` | No | PK | Clave surrogate temporal (`YYYYMMDD`). |
| `full_date` | `DATE` | No |  | Fecha completa. |
| `year` | `SMALLINT` | No |  | Año. |
| `quarter` | `TINYINT` | No |  | Trimestre. |
| `month` | `TINYINT` | No |  | Mes. |
| `month_name` | `NVARCHAR(20)` | No |  | Nombre del mes. |
| `day` | `TINYINT` | No |  | Día del mes. |
| `day_of_week` | `TINYINT` | No |  | Día de la semana (1=Lunes ... 7=Domingo). |

#### `dw.dim_customer`
- **Descripción:** Dimensión tipo SCD1 para clientes.
- **Claves:**
  - PK: `customer_sk`
  - UK: `customer_id`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `customer_sk` | `INT` | No | PK | Clave surrogate de cliente. Se genera con identidad. |
| `customer_id` | `INT` | No | UK | Identificador de negocio del cliente (origen). |
| `full_name` | `NVARCHAR(200)` | No |  | Nombre completo del cliente. |
| `city` | `NVARCHAR(100)` | Sí |  | Ciudad del cliente. |
| `country_code` | `CHAR(2)` | Sí |  | Código de país del cliente. |

#### `dw.dim_product`
- **Descripción:** Dimensión de productos con el nombre de categoría denormalizado.
- **Claves:**
  - PK: `product_sk`
  - UK: `product_id`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `product_sk` | `INT` | No | PK | Clave surrogate de producto. Se genera con identidad. |
| `product_id` | `INT` | No | UK | Identificador de negocio del producto (origen). |
| `product_name` | `NVARCHAR(200)` | No |  | Nombre del producto. |
| `category_name` | `NVARCHAR(100)` | Sí |  | Nombre de la categoría del producto. |
| `unit_price` | `DECIMAL(12,2)` | No |  | Precio unitario del producto. |

#### `dw.fact_sales`
- **Descripción:** Tabla de hechos con el grano de detalle de pedido.
- **Claves:**
  - PK: `sale_sk`
  - FK: `date_sk` → `dw.dim_date(date_sk)`
  - FK: `customer_sk` → `dw.dim_customer(customer_sk)`
  - FK: `product_sk` → `dw.dim_product(product_sk)`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `sale_sk` | `BIGINT` | No | PK | Clave surrogate de la línea de hecho. Se genera con identidad. |
| `date_sk` | `INT` | No | FK | Clave temporal asociada al pedido. |
| `customer_sk` | `INT` | No | FK | Clave surrogate del cliente. |
| `product_sk` | `INT` | No | FK | Clave surrogate del producto. |
| `order_id` | `INT` | No |  | Identificador del pedido (degenerate dimension). |
| `quantity` | `INT` | No |  | Cantidad vendida. |
| `unit_price` | `DECIMAL(12,2)` | No |  | Precio unitario de la línea. |
| `line_total` | `DECIMAL(14,2)` | No |  | Total de la línea (`quantity * unit_price`). |

### Esquema `etl`

#### `etl.copy_config`
- **Descripción:** Tabla de control que define el mapeo origen → staging y el orden de carga para el pipeline metadata-driven.
- **Claves:**
  - PK: `config_id`
- **Columnas:**

| Columna | Tipo | Nulo | Clave | Descripción |
|---|---|---:|---|---|
| `config_id` | `INT` | No | PK | Identificador único de la configuración. Se genera con identidad. |
| `source_schema` | `VARCHAR(20)` | No |  | Esquema de origen en `ventas_oltp`. |
| `source_table` | `VARCHAR(50)` | No |  | Tabla de origen en `ventas_oltp`. |
| `sink_schema` | `VARCHAR(20)` | No |  | Esquema de destino en `ventas_dw`. |
| `sink_table` | `VARCHAR(50)` | No |  | Tabla de destino en `ventas_dw`. |
| `load_order` | `INT` | No |  | Orden de ejecución de la carga. |
| `is_active` | `BIT` | No |  | Indica si la configuración está activa. |

#### `dw.etl_log`
- **Descripción:** Tabla de auditoría de corridas de pipeline referenciada por los stored procedures `usp_log_start` y `usp_log_end`.
- **Estado:** La definición de la tabla no aparece en los scripts disponibles; por lo tanto, su estructura queda **pendiente de confirmar**.
