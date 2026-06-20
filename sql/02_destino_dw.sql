/* ============================================================================
   PROYECTO: adf-docs-lab
   ARCHIVO : sql/02_destino_dw.sql
   MOTOR   : Azure SQL Database
   CAPA    : DESTINO (Data Warehouse - modelo estrella)
   ----------------------------------------------------------------------------
   Patrón Medallion-lite:

       ventas_oltp ──Copy(ADF)──> stg.*  ──SP carga──> dw.dim_* / dw.fact_sales

   Esquemas:
     stg : staging raw (donde aterriza el Copy Activity de ADF)
     dw  : modelo estrella final (dims + fact con surrogate keys)

   Ejecutar este script COMPLETO en la base de datos destino.
   Sugerencia de nombre de BD: ventas_dw
   NOTA: este script NO inserta datos de negocio (eso lo hacen los SPs del 03).
         Solo dim_date se pre-carga porque es una dimensión generada.
   ============================================================================ */

------------------------------------------------------------------------------
-- 0. Esquemas
------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')
    EXEC('CREATE SCHEMA stg');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
    EXEC('CREATE SCHEMA dw');
GO

------------------------------------------------------------------------------
-- 1. Limpieza idempotente
------------------------------------------------------------------------------
DROP TABLE IF EXISTS dw.fact_sales;
DROP TABLE IF EXISTS dw.dim_customer;
DROP TABLE IF EXISTS dw.dim_product;
DROP TABLE IF EXISTS dw.dim_date;

DROP TABLE IF EXISTS stg.order_items;
DROP TABLE IF EXISTS stg.orders;
DROP TABLE IF EXISTS stg.products;
DROP TABLE IF EXISTS stg.categories;
DROP TABLE IF EXISTS stg.customers;
GO

/* ============================================================================
   CAPA STAGING (stg) - copia cruda del origen, sin constraints.
   Aquí aterrizan los Copy Activities de ADF (truncate & load).
   ============================================================================ */

CREATE TABLE stg.categories (
    category_id    INT,
    category_name  NVARCHAR(100),
    created_at     DATETIME2(0)
);
GO

CREATE TABLE stg.products (
    product_id     INT,
    product_name   NVARCHAR(200),
    category_id    INT,
    unit_price     DECIMAL(12,2),
    is_active      BIT,
    created_at     DATETIME2(0)
);
GO

CREATE TABLE stg.customers (
    customer_id    INT,
    full_name      NVARCHAR(200),
    email          NVARCHAR(200),
    city           NVARCHAR(100),
    country_code   CHAR(2),
    created_at     DATETIME2(0)
);
GO

CREATE TABLE stg.orders (
    order_id       INT,
    customer_id    INT,
    order_date     DATETIME2(0),
    status         VARCHAR(20)
);
GO

CREATE TABLE stg.order_items (
    order_item_id  INT,
    order_id       INT,
    product_id     INT,
    quantity       INT,
    unit_price     DECIMAL(12,2)
);
GO

/* ============================================================================
   CAPA DW (dw) - modelo estrella con surrogate keys
   ============================================================================ */

------------------------------------------------------------------------------
-- 2. dw.dim_date  (dimensión generada, se pre-carga aquí mismo)
--    date_sk en formato YYYYMMDD (ej. 20260601)
------------------------------------------------------------------------------
CREATE TABLE dw.dim_date (
    date_sk        INT           NOT NULL,   -- YYYYMMDD
    full_date      DATE          NOT NULL,
    [year]         SMALLINT      NOT NULL,
    [quarter]      TINYINT       NOT NULL,
    [month]        TINYINT       NOT NULL,
    month_name     NVARCHAR(20)  NOT NULL,
    [day]          TINYINT       NOT NULL,
    day_of_week    TINYINT       NOT NULL,   -- 1=Lunes ... 7=Domingo
    CONSTRAINT PK_dim_date PRIMARY KEY (date_sk)
);
GO

------------------------------------------------------------------------------
-- 3. dw.dim_customer  (SCD tipo 1)
------------------------------------------------------------------------------
CREATE TABLE dw.dim_customer (
    customer_sk    INT IDENTITY(1,1) NOT NULL,  -- surrogate key
    customer_id    INT               NOT NULL,  -- business key (del origen)
    full_name      NVARCHAR(200)     NOT NULL,
    city           NVARCHAR(100)     NULL,
    country_code   CHAR(2)           NULL,
    CONSTRAINT PK_dim_customer PRIMARY KEY (customer_sk),
    CONSTRAINT UQ_dim_customer_bk UNIQUE (customer_id)
);
GO

------------------------------------------------------------------------------
-- 4. dw.dim_product  (category_name desnormalizado desde categories)
------------------------------------------------------------------------------
CREATE TABLE dw.dim_product (
    product_sk     INT IDENTITY(1,1) NOT NULL,  -- surrogate key
    product_id     INT               NOT NULL,  -- business key
    product_name   NVARCHAR(200)     NOT NULL,
    category_name  NVARCHAR(100)     NULL,
    unit_price     DECIMAL(12,2)     NOT NULL,
    CONSTRAINT PK_dim_product PRIMARY KEY (product_sk),
    CONSTRAINT UQ_dim_product_bk UNIQUE (product_id)
);
GO

------------------------------------------------------------------------------
-- 5. dw.fact_sales  (grano = línea de detalle de pedido)
--    order_id queda como degenerate dimension
------------------------------------------------------------------------------
CREATE TABLE dw.fact_sales (
    sale_sk        BIGINT IDENTITY(1,1) NOT NULL,
    date_sk        INT           NOT NULL,
    customer_sk    INT           NOT NULL,
    product_sk     INT           NOT NULL,
    order_id       INT           NOT NULL,   -- degenerate dimension
    quantity       INT           NOT NULL,
    unit_price     DECIMAL(12,2) NOT NULL,
    line_total     DECIMAL(14,2) NOT NULL,
    CONSTRAINT PK_fact_sales PRIMARY KEY (sale_sk),
    CONSTRAINT FK_fact_date
        FOREIGN KEY (date_sk)     REFERENCES dw.dim_date (date_sk),
    CONSTRAINT FK_fact_customer
        FOREIGN KEY (customer_sk) REFERENCES dw.dim_customer (customer_sk),
    CONSTRAINT FK_fact_product
        FOREIGN KEY (product_sk)  REFERENCES dw.dim_product (product_sk)
);
GO

------------------------------------------------------------------------------
-- 6. Pre-carga de dim_date para el año 2026
------------------------------------------------------------------------------
;WITH fechas AS (
    SELECT CAST('2026-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM fechas WHERE d < '2026-12-31'
)
INSERT INTO dw.dim_date (date_sk, full_date, [year], [quarter], [month], month_name, [day], day_of_week)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd'))                AS date_sk,
    d                                                  AS full_date,
    YEAR(d)                                            AS [year],
    DATEPART(QUARTER, d)                               AS [quarter],
    MONTH(d)                                           AS [month],
    DATENAME(MONTH, d)                                 AS month_name,
    DAY(d)                                             AS [day],
    ((DATEPART(WEEKDAY, d) + @@DATEFIRST - 2) % 7) + 1 AS day_of_week  -- 1=Lunes
FROM fechas
OPTION (MAXRECURSION 0);
GO

------------------------------------------------------------------------------
-- 7. Verificación rápida
------------------------------------------------------------------------------
SELECT 'dim_date' AS tabla, COUNT(*) AS filas FROM dw.dim_date
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dw.dim_customer
UNION ALL SELECT 'dim_product',  COUNT(*) FROM dw.dim_product
UNION ALL SELECT 'fact_sales',   COUNT(*) FROM dw.fact_sales;
GO
