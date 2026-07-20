# Expected Results

Validated with **DuckDB 1.5.4**.

## 1. Grain inventory

| table_name | row_count | distinct_primary_entities |
|---|---:|---:|
| customers | 3 | 3 |
| order_items | 8 | 4 |
| orders | 4 | 4 |

`order_items` contains eight rows but only four distinct orders because its grain is one row per item within an order.

## 2. Global failure summary

| base_rows | joined_rows | row_multiplier | correct_revenue | reported_revenue | revenue_multiplier |
|---:|---:|---:|---:|---:|---:|
| 4 | 8 | 2.0 | 500.00 | 1,000.00 | 2.0 |

## 3. Correct baseline

| customer_name | order_count | revenue |
|---|---:|---:|
| Ada | 2 | 200.00 |
| Ben | 1 | 200.00 |
| Chen | 1 | 100.00 |

## 4. Incorrect result after the fan-out join

| customer_name | joined_rows | reported_revenue |
|---|---:|---:|
| Ada | 4 | 400.00 |
| Ben | 2 | 400.00 |
| Chen | 2 | 200.00 |

## 5. Distinct count masks the measure failure

| customer_name | order_count | reported_revenue |
|---|---:|---:|
| Ada | 2 | 400.00 |
| Ben | 1 | 400.00 |
| Chen | 1 | 200.00 |

The distinct order count is correct, but the order-grain revenue measure remains repeated.

## 6. Multiplication by order

| order_id | rows_after_join | order_total | repeated_order_total |
|---:|---:|---:|---:|
| 1001 | 2 | 120.00 | 240.00 |
| 1002 | 2 | 80.00 | 160.00 |
| 1003 | 2 | 200.00 | 400.00 |
| 1004 | 2 | 100.00 | 200.00 |

## 7. Fix 1 — pre-aggregate detail to order grain

| customer_name | order_count | revenue |
|---|---:|---:|
| Ada | 2 | 200.00 |
| Ben | 1 | 200.00 |
| Chen | 1 | 100.00 |

## 8. Fix 2 — aggregate an item-grain measure

| customer_name | item_rows | revenue |
|---|---:|---:|
| Ada | 4 | 200.00 |
| Ben | 2 | 200.00 |
| Chen | 2 | 100.00 |

## 9. Header-to-detail reconciliation

| order_id | order_total | item_total | difference |
|---:|---:|---:|---:|
| 1001 | 120.00 | 120.00 | 0.00 |
| 1002 | 80.00 | 80.00 | 0.00 |
| 1003 | 200.00 | 200.00 | 0.00 |
| 1004 | 100.00 | 100.00 | 0.00 |

## 10. Automated checks

| test_name | passed |
|---|---|
| fan-out changes revenue | true |
| fan-out changes row count | true |
| fan-out preserves distinct order count | true |
| item detail reconciles to order header | true |
| pre-aggregation restores revenue | true |
| pre-aggregation restores row count | true |

All six tests must return `true`.
