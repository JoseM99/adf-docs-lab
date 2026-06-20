/* ============================================================================
   PROYECTO: adf-docs-lab
   ARCHIVO : sql/03_stored_procedures.sql
   MOTOR   : Azure SQL Database
   CAPA    : CARGA (stg.* -> dw.dim_* / dw.fact_sales)
   ----------------------------------------------------------------------------
   Estos SPs son el CORAZÓN del lineage que Copilot va a documentar:
   cada uno declara explícitamente de qué tablas LEE y a cuáles ESCRIBE.

       usp_load_dim_customer : stg.customers              -> dw.dim_customer
       usp_load_dim_product  : stg.products, stg.categories -> dw.dim_product
       usp_load_fact_sales   : stg.order_items, stg.orders,
                               dw.dim_*                   -> dw.fact_sales

   Orden de ejecución (lo orquesta ADF):
       1) usp_load_dim_customer
       2) usp_load_dim_product
       3) usp_load_fact_sales   (depende de que las dims ya estén cargadas)

   Ejecutar este script COMPLETO en la base de datos destino (ventas_dw).
   Patrón: CREATE OR ALTER + DELETE/INSERT (recarga completa, idempotente).
   ============================================================================ */

------------------------------------------------------------------------------
-- 1. usp_load_dim_customer
--    LEE : stg.customers
--    ESCRIBE: dw.dim_customer  (SCD1: actualiza existentes, inserta nuevos)
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_load_dim_customer
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.dim_customer AS tgt
    USING (
        SELECT
            customer_id,
            full_name,
            city,
            country_code
        FROM stg.customers
    ) AS src
        ON tgt.customer_id = src.customer_id
    WHEN MATCHED THEN
        UPDATE SET
            tgt.full_name    = src.full_name,
            tgt.city         = src.city,
            tgt.country_code = src.country_code
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (customer_id, full_name, city, country_code)
        VALUES (src.customer_id, src.full_name, src.city, src.country_code);
END;
GO

------------------------------------------------------------------------------
-- 2. usp_load_dim_product
--    LEE : stg.products, stg.categories
--    ESCRIBE: dw.dim_product (denormaliza category_name)
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_load_dim_product
AS
BEGIN
    SET NOCOUNT ON;

    MERGE dw.dim_product AS tgt
    USING (
        SELECT
            p.product_id,
            p.product_name,
            c.category_name,
            p.unit_price
        FROM stg.products  p
        LEFT JOIN stg.categories c
            ON p.category_id = c.category_id
    ) AS src
        ON tgt.product_id = src.product_id
    WHEN MATCHED THEN
        UPDATE SET
            tgt.product_name  = src.product_name,
            tgt.category_name = src.category_name,
            tgt.unit_price    = src.unit_price
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (product_id, product_name, category_name, unit_price)
        VALUES (src.product_id, src.product_name, src.category_name, src.unit_price);
END;
GO

------------------------------------------------------------------------------
-- 3. usp_load_fact_sales
--    LEE : stg.order_items, stg.orders, dw.dim_customer, dw.dim_product, dw.dim_date
--    ESCRIBE: dw.fact_sales  (recarga completa: DELETE + INSERT)
--    Resuelve las surrogate keys vía JOIN contra las dims.
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_load_fact_sales
AS
BEGIN
    SET NOCOUNT ON;

    -- Recarga completa (idempotente)
    DELETE FROM dw.fact_sales;

    INSERT INTO dw.fact_sales
        (date_sk, customer_sk, product_sk, order_id, quantity, unit_price, line_total)
    SELECT
        d.date_sk,
        dc.customer_sk,
        dp.product_sk,
        o.order_id,
        oi.quantity,
        oi.unit_price,
        CAST(oi.quantity * oi.unit_price AS DECIMAL(14,2)) AS line_total
    FROM stg.order_items oi
    INNER JOIN stg.orders       o  ON oi.order_id    = o.order_id
    INNER JOIN dw.dim_customer  dc ON o.customer_id  = dc.customer_id
    INNER JOIN dw.dim_product   dp ON oi.product_id  = dp.product_id
    INNER JOIN dw.dim_date      d  ON CONVERT(INT, FORMAT(o.order_date, 'yyyyMMdd')) = d.date_sk;
END;
GO

------------------------------------------------------------------------------
-- 4. (Opcional) SP orquestador, por si quieres correr todo de un golpe
--    fuera de ADF para probar localmente.
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_load_all
AS
BEGIN
    SET NOCOUNT ON;
    EXEC dw.usp_load_dim_customer;
    EXEC dw.usp_load_dim_product;
    EXEC dw.usp_load_fact_sales;
END;
GO

------------------------------------------------------------------------------
-- 5. Verificación (corre esto DESPUÉS de que ADF haya llenado stg.*)
--    Si quieres probar sin ADF: copia manualmente datos a stg.* y EXEC dw.usp_load_all;
------------------------------------------------------------------------------
-- EXEC dw.usp_load_all;
-- SELECT * FROM dw.fact_sales;
