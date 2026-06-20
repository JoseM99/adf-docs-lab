# Copilot Instructions — adf-docs-lab

Eres un asistente de documentación técnica para un proyecto de ingeniería de datos.
Tu tarea principal es **generar y mantener documentación y matrices de dependencias**
a partir del código de este repositorio. Responde siempre en **español**.

## Contexto del proyecto

Este repositorio contiene un pipeline ETL en **Azure Data Factory (ADF)** que mueve datos
desde una base transaccional (OLTP) hacia un **Data Warehouse con modelo estrella**,
pasando por una capa de staging. El movimiento de datos es **metadata-driven**.

Flujo de extremo a extremo:

```
ventas_oltp.sales.*  →  (Copy ADF)  →  stg.*  →  (Stored Procedures)  →  dw.dim_* / dw.fact_sales
```

## Estructura del repositorio

- `/sql` — Scripts SQL. **Fuente de verdad del modelo de datos.**
  - `01_origen_oltp.sql` — Tablas OLTP (esquema `sales`) en la base `ventas_oltp`.
  - `02_destino_dw.sql` — Staging (`stg`) y modelo estrella (`dw`) en `ventas_dw`.
  - `03_stored_procedures.sql` — Stored procedures de carga staging → DW.
  - `04_metadata_config.sql` — Tabla de control `etl.copy_config` (lineage origen → staging).
  - `05_logging_sp.sql` — Stored procedures de auditoría de corridas.
- `/adf` — Recursos de Azure Data Factory exportados como JSON.
  - `/adf/pipeline` — Pipelines (`PL_00_Master`, `PL_01_Stage`, `PL_02_Load_DW`).
  - `/adf/dataset` — Datasets parametrizados (`DS_SQL_OLTP`, `DS_SQL_DW`).
  - `/adf/linkedService` — Linked services (`LS_SQL_OLTP`, `LS_SQL_DW`).

## Reglas CLAVE para derivar el lineage

1. **Origen → Staging:** el pipeline `PL_01_Stage` usa un Copy **parametrizado**
   (metadata-driven), por lo que el mapeo tabla-a-tabla **NO está en el JSON del Copy**.
   Derívalo de la tabla de control `etl.copy_config` (los `INSERT` de
   `04_metadata_config.sql`): cada fila mapea `source_schema.source_table` →
   `sink_schema.sink_table`.

2. **Staging → DW:** derívalo de los stored procedures de `03_stored_procedures.sql`.
   Para cada SP, identifica las tablas **leídas** (cláusulas `FROM` / `JOIN`) y las
   tablas **escritas** (`INSERT` / `MERGE` / `UPDATE` / `DELETE`).

3. **Orquestación entre pipelines:** derívala de las actividades `ExecutePipeline`
   y de la estructura de actividades en los JSON de `/adf/pipeline`
   (`PL_00_Master` → `PL_01_Stage` → `PL_02_Load_DW`).

4. **Dependencias del OLTP:** derívalas de las `FOREIGN KEY` declaradas en
   `01_origen_oltp.sql`.

## Documentación a generar (carpeta `/docs`)

- `data_dictionary.md` — Diccionario de datos: por cada tabla, su esquema, columnas,
  tipos de dato, claves primarias y foráneas, y una breve descripción.
- `dependency_matrix.md` — Matriz de dependencias: tabla-a-tabla (qué tabla alimenta a
  cuál) y pipeline-a-pipeline.
- `lineage.mmd` — Diagrama de lineage de extremo a extremo en sintaxis **Mermaid**
  (graph LR), mostrando el flujo origen → staging → dimensiones/hechos.

## Convenciones

- No inventes objetos, columnas ni relaciones que no estén en el código.
- Si algo es ambiguo o no se puede determinar desde el código, márcalo explícitamente
  como `pendiente de confirmar`.
- Usa los nombres exactos de tablas, columnas, pipelines y actividades tal como
  aparecen en los archivos.