/* ============================================================================
   PROYECTO: adf-docs-lab
   ARCHIVO : sql/01_origen_oltp.sql
   MOTOR   : Azure SQL Database
   CAPA    : ORIGEN (OLTP transaccional)
   ----------------------------------------------------------------------------
   Cadena de dependencias (esto es lo que el lineage va a documentar):

       categories  ──< products ──< order_items >── orders >── customers

   Ejecutar este script COMPLETO en la base de datos de origen.
   Sugerencia de nombre de BD: ventas_oltp
   ============================================================================ */

------------------------------------------------------------------------------
-- 0. Esquema
------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'sales')
    EXEC('CREATE SCHEMA sales');
GO

------------------------------------------------------------------------------
-- 1. Limpieza idempotente (drop en orden inverso a las FKs)
------------------------------------------------------------------------------
DROP TABLE IF EXISTS sales.order_items;
DROP TABLE IF EXISTS sales.orders;
DROP TABLE IF EXISTS sales.products;
DROP TABLE IF EXISTS sales.customers;
DROP TABLE IF EXISTS sales.categories;
GO

------------------------------------------------------------------------------
-- 2. categories  (tabla raíz, sin dependencias)
------------------------------------------------------------------------------
CREATE TABLE sales.categories (
    category_id    INT IDENTITY(1,1) NOT NULL,
    category_name  NVARCHAR(100)     NOT NULL,
    created_at     DATETIME2(0)      NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_categories PRIMARY KEY (category_id)
);
GO

------------------------------------------------------------------------------
-- 3. products  (depende de categories)
------------------------------------------------------------------------------
CREATE TABLE sales.products (
    product_id     INT IDENTITY(1,1) NOT NULL,
    product_name   NVARCHAR(200)     NOT NULL,
    category_id    INT               NOT NULL,
    unit_price     DECIMAL(12,2)     NOT NULL,
    is_active      BIT               NOT NULL DEFAULT 1,
    created_at     DATETIME2(0)      NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_products PRIMARY KEY (product_id),
    CONSTRAINT FK_products_categories
        FOREIGN KEY (category_id) REFERENCES sales.categories (category_id)
);
GO

------------------------------------------------------------------------------
-- 4. customers  (tabla raíz, sin dependencias)
------------------------------------------------------------------------------
CREATE TABLE sales.customers (
    customer_id    INT IDENTITY(1,1) NOT NULL,
    full_name      NVARCHAR(200)     NOT NULL,
    email          NVARCHAR(200)     NULL,
    city           NVARCHAR(100)     NULL,
    country_code   CHAR(2)           NOT NULL DEFAULT 'PE',
    created_at     DATETIME2(0)      NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_customers PRIMARY KEY (customer_id)
);
GO

------------------------------------------------------------------------------
-- 5. orders  (depende de customers)
------------------------------------------------------------------------------
CREATE TABLE sales.orders (
    order_id       INT IDENTITY(1,1) NOT NULL,
    customer_id    INT               NOT NULL,
    order_date     DATETIME2(0)      NOT NULL,
    status         VARCHAR(20)       NOT NULL DEFAULT 'CONFIRMED',
    CONSTRAINT PK_orders PRIMARY KEY (order_id),
    CONSTRAINT FK_orders_customers
        FOREIGN KEY (customer_id) REFERENCES sales.customers (customer_id),
    CONSTRAINT CK_orders_status
        CHECK (status IN ('CONFIRMED','SHIPPED','DELIVERED','CANCELLED'))
);
GO

------------------------------------------------------------------------------
-- 6. order_items  (depende de orders y products) -> nodo central del lineage
------------------------------------------------------------------------------
CREATE TABLE sales.order_items (
    order_item_id  INT IDENTITY(1,1) NOT NULL,
    order_id       INT               NOT NULL,
    product_id     INT               NOT NULL,
    quantity       INT               NOT NULL,
    unit_price     DECIMAL(12,2)     NOT NULL,
    CONSTRAINT PK_order_items PRIMARY KEY (order_item_id),
    CONSTRAINT FK_items_orders
        FOREIGN KEY (order_id)   REFERENCES sales.orders (order_id),
    CONSTRAINT FK_items_products
        FOREIGN KEY (product_id) REFERENCES sales.products (product_id),
    CONSTRAINT CK_items_quantity CHECK (quantity > 0)
);
GO

------------------------------------------------------------------------------
-- 7. Seed mínimo (para que los pipelines tengan algo que mover)
------------------------------------------------------------------------------
INSERT INTO sales.categories (category_name) VALUES
    (N'Tecnología'), (N'Hogar'), (N'Gadgets');

INSERT INTO sales.products (product_name, category_id, unit_price) VALUES
    (N'Audífonos Bluetooth', 1, 129.90),
    (N'Teclado mecánico',    1, 249.00),
    (N'Aspiradora robot',    2, 899.00),
    (N'Power bank 20000mAh',  3,  89.90);

INSERT INTO sales.customers (full_name, email, city) VALUES
    (N'Arturo Fajardo', N'arturo@example.com', N'Lima'),
    (N'María Quispe',   N'maria@example.com',  N'Ica'),
    (N'José Gómez',     N'jose@example.com',   N'Chincha');

INSERT INTO sales.orders (customer_id, order_date, status) VALUES
    (1, '2026-06-01T10:15:00', 'DELIVERED'),
    (2, '2026-06-03T16:40:00', 'SHIPPED'),
    (1, '2026-06-10T09:05:00', 'CONFIRMED');

INSERT INTO sales.order_items (order_id, product_id, quantity, unit_price) VALUES
    (1, 1, 1, 129.90),
    (1, 4, 2,  89.90),
    (2, 3, 1, 899.00),
    (3, 2, 1, 249.00);
GO

------------------------------------------------------------------------------
-- 8. Verificación rápida
------------------------------------------------------------------------------
SELECT 'categories'  AS tabla, COUNT(*) AS filas FROM sales.categories
UNION ALL SELECT 'products',    COUNT(*) FROM sales.products
UNION ALL SELECT 'customers',   COUNT(*) FROM sales.customers
UNION ALL SELECT 'orders',      COUNT(*) FROM sales.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM sales.order_items;
GO
