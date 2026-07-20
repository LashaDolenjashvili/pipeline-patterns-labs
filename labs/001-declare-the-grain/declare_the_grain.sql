-- Pipeline Patterns — Week 1 proof lab
-- Topic: Declare the Grain
-- Validated with DuckDB v1.5.4

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    customer_name VARCHAR NOT NULL
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    order_total DECIMAL(10, 2) NOT NULL
);

CREATE TABLE order_items (
    order_id INTEGER NOT NULL,
    line_number INTEGER NOT NULL,
    product_name VARCHAR NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (order_id, line_number)
);

INSERT INTO customers VALUES
    (1, 'Ada'),
    (2, 'Ben'),
    (3, 'Chen');

INSERT INTO orders VALUES
    (1001, 1, DATE '2026-07-01', 120.00),
    (1002, 1, DATE '2026-07-03',  80.00),
    (1003, 2, DATE '2026-07-04', 200.00),
    (1004, 3, DATE '2026-07-05', 100.00);

INSERT INTO order_items VALUES
    (1001, 1, 'Keyboard',  1, 70.00),
    (1001, 2, 'Mouse',     1, 50.00),
    (1002, 1, 'Cable',     2, 20.00),
    (1002, 2, 'Adapter',   1, 40.00),
    (1003, 1, 'Monitor',   1, 125.00),
    (1003, 2, 'Stand',     3, 25.00),
    (1004, 1, 'Headset',   1, 60.00),
    (1004, 2, 'Ear pads',  2, 20.00);

-- 1. Grain inventory.
SELECT
    'customers' AS table_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT customer_id) AS distinct_primary_entities
FROM customers
UNION ALL
SELECT 'order_items', COUNT(*), COUNT(DISTINCT order_id)
FROM order_items
UNION ALL
SELECT 'orders', COUNT(*), COUNT(DISTINCT order_id)
FROM orders
ORDER BY table_name;

-- 2. Global failure summary.
WITH base AS (
    SELECT COUNT(*) AS base_rows, SUM(order_total) AS correct_revenue
    FROM orders
),
fanout AS (
    SELECT COUNT(*) AS joined_rows, SUM(o.order_total) AS reported_revenue
    FROM orders AS o
    LEFT JOIN order_items AS i USING (order_id)
)
SELECT
    base_rows,
    joined_rows,
    joined_rows * 1.0 / base_rows AS row_multiplier,
    correct_revenue,
    reported_revenue,
    reported_revenue / correct_revenue AS revenue_multiplier
FROM base
CROSS JOIN fanout;

-- 3. Correct baseline: the input remains one row per order.
SELECT
    c.customer_name,
    COUNT(*) AS order_count,
    SUM(o.order_total) AS revenue
FROM orders AS o
JOIN customers AS c USING (customer_id)
GROUP BY c.customer_name
ORDER BY c.customer_name;

-- 4. Incorrect: the relation moves to one row per order item,
-- while order_total remains an order-grain measure.
SELECT
    c.customer_name,
    COUNT(*) AS joined_rows,
    SUM(o.order_total) AS reported_revenue
FROM orders AS o
LEFT JOIN order_items AS i USING (order_id)
JOIN customers AS c USING (customer_id)
GROUP BY c.customer_name
ORDER BY c.customer_name;

-- 5. COUNT(DISTINCT ...) repairs the count, not the repeated measure.
SELECT
    c.customer_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.order_total) AS reported_revenue
FROM orders AS o
LEFT JOIN order_items AS i USING (order_id)
JOIN customers AS c USING (customer_id)
GROUP BY c.customer_name
ORDER BY c.customer_name;

-- 6. Diagnose multiplication directly at order grain.
SELECT
    o.order_id,
    COUNT(*) AS rows_after_join,
    MIN(o.order_total) AS order_total,
    SUM(o.order_total) AS repeated_order_total
FROM orders AS o
LEFT JOIN order_items AS i USING (order_id)
GROUP BY o.order_id
ORDER BY o.order_id;

-- 7. Fix 1: reduce detail to one row per order before joining.
WITH items_by_order AS (
    SELECT order_id, SUM(quantity * unit_price) AS item_total
    FROM order_items
    GROUP BY order_id
)
SELECT
    c.customer_name,
    COUNT(*) AS order_count,
    SUM(o.order_total) AS revenue
FROM orders AS o
LEFT JOIN items_by_order AS i USING (order_id)
JOIN customers AS c USING (customer_id)
GROUP BY c.customer_name
ORDER BY c.customer_name;

-- 8. Fix 2: stay at item grain and aggregate an item-grain measure.
SELECT
    c.customer_name,
    COUNT(*) AS item_rows,
    SUM(i.quantity * i.unit_price) AS revenue
FROM orders AS o
JOIN order_items AS i USING (order_id)
JOIN customers AS c USING (customer_id)
GROUP BY c.customer_name
ORDER BY c.customer_name;

-- 9. Reconcile the item-derived measure to the order header.
SELECT
    o.order_id,
    o.order_total,
    SUM(i.quantity * i.unit_price) AS item_total,
    o.order_total - SUM(i.quantity * i.unit_price) AS difference
FROM orders AS o
JOIN order_items AS i USING (order_id)
GROUP BY o.order_id, o.order_total
ORDER BY o.order_id;

-- 10. Automated verification checks.
WITH
base AS (
    SELECT COUNT(*) AS row_count, SUM(order_total) AS revenue
    FROM orders
),
fanout AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT o.order_id) AS distinct_orders,
        SUM(o.order_total) AS revenue
    FROM orders AS o
    LEFT JOIN order_items AS i USING (order_id)
),
items_by_order AS (
    SELECT order_id, SUM(quantity * unit_price) AS item_total
    FROM order_items
    GROUP BY order_id
),
restored AS (
    SELECT COUNT(*) AS row_count, SUM(o.order_total) AS revenue
    FROM orders AS o
    LEFT JOIN items_by_order AS i USING (order_id)
),
reconciliation AS (
    SELECT MAX(ABS(o.order_total - item_total)) AS max_difference
    FROM orders AS o
    JOIN items_by_order AS i USING (order_id)
)
SELECT 'fan-out changes row count' AS test_name,
       fanout.row_count <> base.row_count AS passed
FROM base, fanout
UNION ALL
SELECT 'fan-out preserves distinct order count',
       fanout.distinct_orders = base.row_count
FROM base, fanout
UNION ALL
SELECT 'fan-out changes revenue',
       fanout.revenue <> base.revenue
FROM base, fanout
UNION ALL
SELECT 'pre-aggregation restores row count',
       restored.row_count = base.row_count
FROM base, restored
UNION ALL
SELECT 'pre-aggregation restores revenue',
       restored.revenue = base.revenue
FROM base, restored
UNION ALL
SELECT 'item detail reconciles to order header',
       reconciliation.max_difference = 0
FROM reconciliation
ORDER BY test_name;
