/* ============================================================================
   PROYECTO: adf-docs-lab
   ARCHIVO : sql/04_metadata_config.sql
   MOTOR   : Azure SQL Database
   CAPA    : CONTROL / METADATA (metadata-driven ingestion)
   ----------------------------------------------------------------------------
   Esta tabla es la FUENTE DE VERDAD del lineage origen->staging.
   ADF la lee con un Lookup y un ForEach itera cada fila con UN solo Copy.

   IMPORTANTE: esta tabla vive en ventas_dw (la lee el Lookup vía LS_SQL_DW),
   pero las filas describen copias desde ventas_oltp (sales.*) hacia stg.*.
   El dataset de origen usa LS_SQL_OLTP; el de destino usa LS_SQL_DW.

   Ejecutar en la base de datos destino: ventas_dw
   ============================================================================ */

------------------------------------------------------------------------------
-- 0. Esquema
------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
    EXEC('CREATE SCHEMA etl');
GO

------------------------------------------------------------------------------
-- 1. Tabla de control
------------------------------------------------------------------------------
DROP TABLE IF EXISTS etl.copy_config;
GO

CREATE TABLE etl.copy_config (
    config_id      INT IDENTITY(1,1) NOT NULL,
    source_schema  VARCHAR(20)  NOT NULL,   -- esquema en ventas_oltp
    source_table   VARCHAR(50)  NOT NULL,   -- tabla en ventas_oltp
    sink_schema    VARCHAR(20)  NOT NULL,   -- esquema en ventas_dw
    sink_table     VARCHAR(50)  NOT NULL,   -- tabla en ventas_dw
    load_order     INT          NOT NULL DEFAULT 0,
    is_active      BIT          NOT NULL DEFAULT 1,
    CONSTRAINT PK_copy_config PRIMARY KEY (config_id)
);
GO

------------------------------------------------------------------------------
-- 2. Filas de configuracion (1 por tabla a copiar)
--    Agregar una tabla nueva al pipeline = insertar una fila aqui. Eso es todo.
------------------------------------------------------------------------------
INSERT INTO etl.copy_config (source_schema, source_table, sink_schema, sink_table, load_order) VALUES
    ('sales', 'categories',  'stg', 'categories',  1),
    ('sales', 'products',    'stg', 'products',    2),
    ('sales', 'customers',   'stg', 'customers',   3),
    ('sales', 'orders',      'stg', 'orders',      4),
    ('sales', 'order_items', 'stg', 'order_items', 5);
GO

------------------------------------------------------------------------------
-- 3. Verificacion
------------------------------------------------------------------------------
SELECT config_id, source_schema, source_table, sink_schema, sink_table, load_order, is_active
FROM etl.copy_config
WHERE is_active = 1
ORDER BY load_order;
GO
