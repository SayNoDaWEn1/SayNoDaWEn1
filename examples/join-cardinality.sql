-- JOIN and aggregate cardinality: a small reproducible example.
-- Run the whole file in a fresh SQLite session.
-- Amounts are integer rubles; order 3 intentionally has no items.

CREATE TEMP TABLE demo_orders (
    id INTEGER PRIMARY KEY,
    total INTEGER NOT NULL
);

CREATE TEMP TABLE demo_order_items (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL
);

INSERT INTO demo_orders (id, total) VALUES (1, 1200), (2, 800), (3, 500);
INSERT INTO demo_order_items (id, order_id) VALUES (10, 1), (11, 1), (12, 2);

-- 1. The join repeats order 1 for each of its two items.
-- Expected: inflated_total = 3700. This is NOT the order revenue.
SELECT SUM(o.total) AS inflated_total
FROM demo_orders AS o
LEFT JOIN demo_order_items AS i ON i.order_id = o.id;

-- 2. Revenue for all orders belongs at the order grain.
-- Expected: revenue = 2500.
-- SUM(DISTINCT total) is not a general fix: different orders can cost the same.
SELECT SUM(total) AS revenue
FROM demo_orders;

-- 3. Count the matched item key, not COUNT(*), to preserve zero-item orders.
-- Expected (id, item_count): (1, 2), (2, 1), (3, 0).
SELECT o.id, COUNT(i.id) AS item_count
FROM demo_orders AS o
LEFT JOIN demo_order_items AS i ON i.order_id = o.id
GROUP BY o.id
ORDER BY o.id;

-- 4. If the rule is "only orders with items", use an existence check.
-- Expected: revenue_with_items = 2000. Each order contributes once.
SELECT SUM(o.total) AS revenue_with_items
FROM demo_orders AS o
WHERE EXISTS (
    SELECT 1
    FROM demo_order_items AS i
    WHERE i.order_id = o.id
);
