# Matriz de dependencias

Este documento resume las dependencias derivadas de los scripts SQL y de los JSON de ADF disponibles en el repositorio.

---

## 1) Dependencias tabla → tabla (origen → staging)

Estas relaciones se derivan de la tabla `etl.copy_config` definida en [sql/04_metadata_config.sql](../sql/04_metadata_config.sql).

| Tabla origen | Tabla destino | Base / esquema | Evidencia |
|---|---|---|---|
| `sales.categories` | `stg.categories` | `ventas_oltp` → `ventas_dw` | Fila de `etl.copy_config` con `load_order = 1` |
| `sales.products` | `stg.products` | `ventas_oltp` → `ventas_dw` | Fila de `etl.copy_config` con `load_order = 2` |
| `sales.customers` | `stg.customers` | `ventas_oltp` → `ventas_dw` | Fila de `etl.copy_config` con `load_order = 3` |
| `sales.orders` | `stg.orders` | `ventas_oltp` → `ventas_dw` | Fila de `etl.copy_config` con `load_order = 4` |
| `sales.order_items` | `stg.order_items` | `ventas_oltp` → `ventas_dw` | Fila de `etl.copy_config` con `load_order = 5` |

### Interpretación
- El pipeline `PL_01_Stage` lee `etl.copy_config` mediante un `Lookup`.
- Luego itera cada fila con un `ForEach` y ejecuta un `Copy` dinámico desde `sales.*` hacia `stg.*`.

---

## 2) Dependencias tabla → tabla (staging → DW)

Estas relaciones se derivan de los stored procedures en [sql/03_stored_procedures.sql](../sql/03_stored_procedures.sql).

### 2.1 `dw.usp_load_dim_customer`

| Tabla leída | Tabla escrita | Tipo de dependencia |
|---|---|---|
| `stg.customers` | `dw.dim_customer` | `MERGE` sobre `dw.dim_customer` usando `FROM stg.customers` |

### 2.2 `dw.usp_load_dim_product`

| Tabla leída | Tabla escrita | Tipo de dependencia |
|---|---|---|
| `stg.products` | `dw.dim_product` | `JOIN` con `stg.products` para construir la fuente del `MERGE` |
| `stg.categories` | `dw.dim_product` | `LEFT JOIN` para denormalizar `category_name` |

### 2.3 `dw.usp_load_fact_sales`

| Tabla leída | Tabla escrita | Tipo de dependencia |
|---|---|---|
| `stg.order_items` | `dw.fact_sales` | `INSERT INTO dw.fact_sales` usando datos de `stg.order_items` |
| `stg.orders` | `dw.fact_sales` | `INNER JOIN` sobre `order_id` |
| `dw.dim_customer` | `dw.fact_sales` | `INNER JOIN` para resolver `customer_sk` |
| `dw.dim_product` | `dw.fact_sales` | `INNER JOIN` para resolver `product_sk` |
| `dw.dim_date` | `dw.fact_sales` | `INNER JOIN` para resolver `date_sk` desde `order_date` |

### 2.4 Orden lógico de carga

| Stored procedure | Dependencias de entrada | Dependencias de salida |
|---|---|---|
| `dw.usp_load_dim_customer` | `stg.customers` | `dw.dim_customer` |
| `dw.usp_load_dim_product` | `stg.products`, `stg.categories` | `dw.dim_product` |
| `dw.usp_load_fact_sales` | `stg.order_items`, `stg.orders`, `dw.dim_customer`, `dw.dim_product`, `dw.dim_date` | `dw.fact_sales` |

---

## 3) Dependencias pipeline → pipeline

La información disponible en la carpeta [adf/pipeline](../adf/pipeline) muestra el siguiente flujo de orquestación:

### 3.1 Orquestación observada en el JSON disponible

| Pipeline | Actividad relevante | Dependencia detectada |
|---|---|---|
| `PL_01_Stage` | `SP_Log_Start` | Se ejecuta primero |
| `PL_01_Stage` | `LKP_Config` | Depende de `SP_Log_Start` |
| `PL_01_Stage` | `FE_Tables` | Depende de `LKP_Config` |
| `PL_01_Stage` | `CP_Dynamic` | Se ejecuta dentro del `ForEach` de `FE_Tables` |
| `PL_01_Stage` | `SP_Log_Success` | Depende de `FE_Tables` cuando el resultado es `Succeeded` |
| `PL_01_Stage` | `SP_Log_Failure` | Depende de `FE_Tables` cuando el resultado es `Failed` |

### 3.2 Nota sobre pipeline maestros / downstream

- En el repositorio disponible no se encontraron los archivos `PL_00_Master.json` ni `PL_02_Load_DW.json`.
- Por lo tanto, la relación explícita `PL_00_Master → PL_01_Stage → PL_02_Load_DW` queda **pendiente de confirmar** a partir del contenido real de esos JSON.
- Lo que sí puede afirmarse con evidencia es que el pipeline disponible `PL_01_Stage` hace:
  - `Lookup` sobre `etl.copy_config`
  - `ForEach` sobre las filas obtenidas
  - `Copy` dinámico desde origen a staging
  - `Stored Procedure` de logging al inicio y al final

---

## 4) Resumen ejecutivo

| Nivel | Dependencias principales |
|---|---|
| Origen → staging | `sales.categories → stg.categories`, `sales.products → stg.products`, `sales.customers → stg.customers`, `sales.orders → stg.orders`, `sales.order_items → stg.order_items` |
| Staging → DW | `stg.customers → dw.dim_customer`, `stg.products + stg.categories → dw.dim_product`, `stg.order_items + stg.orders + dw.dim_customer + dw.dim_product + dw.dim_date → dw.fact_sales` |
| Pipeline | `PL_01_Stage` ejecuta el flujo de lookup, iteración y copy; la orquestación maestro/detalle completa está pendiente de confirmar |
