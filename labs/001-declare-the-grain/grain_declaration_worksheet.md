# Grain Declaration Worksheet

Use this worksheet before writing a model, adding a join, or reviewing analytical SQL.

The purpose is to make one question explicit:

> What does one row represent at each stage of the query?

A query can be syntactically valid while its measures are no longer valid at the resulting grain.

---

## 1. Model identity

**Model or query name:**  
`____________________________________________`

**Owner:**  
`____________________________________________`

**Purpose:**  
Describe the decision, report, or downstream model this output supports.

`__________________________________________________________________`

`__________________________________________________________________`

**Expected output grain:**  
Complete this sentence:

> One row represents _______________________________________________.

Examples:

- one row per customer
- one row per order
- one row per customer per calendar month
- one row per product per warehouse per day

**Columns that identify one output row:**

| Key column | Why it is required |
|---|---|
|  |  |
|  |  |
|  |  |

**Expected uniqueness test:**

```sql
SELECT
    <output_key_columns>,
    COUNT(*) AS row_count
FROM <model_or_query>
GROUP BY <output_key_columns>
HAVING COUNT(*) > 1;
```

**Expected result:** zero rows.

---

## 2. Source grain inventory

Declare the grain of every source before reviewing join syntax.

| Source | One row represents | Unique key | Can the key repeat? | Why? |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

Do not write only “customer table,” “transaction data,” or “item-level table.” State what makes one row distinct.

---

## 3. Join contract

Complete one row for every join.

| Join | Left grain before join | Right grain | Join key | Maximum matches per left row | Resulting grain | Can rows multiply? |
|---|---|---|---|---:|---|---|
| 1 |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |

For each join, complete this sentence:

> One left-side row can match ______ right-side rows.

A `LEFT JOIN` preserves unmatched left rows. It does not guarantee one output row per left-side row.

### Match-count diagnostic

```sql
SELECT
    l.<left_key>,
    COUNT(r.<right_key>) AS right_matches
FROM <left_source> AS l
LEFT JOIN <right_source> AS r
    ON <join_condition>
GROUP BY l.<left_key>
HAVING COUNT(r.<right_key>) > 1
ORDER BY right_matches DESC;
```

Use this result to determine whether the join changes the left-side grain.

---

## 4. Measure grain inventory

Classify every measure by the grain where it is defined exactly once.

| Measure | Source expression | Defined once per | Aggregation used | Valid after current joins? | Evidence |
|---|---|---|---|---|---|
|  |  |  |  |  |  |
|  |  |  |  |  |  |
|  |  |  |  |  |  |

Examples:

| Measure | Defined once per |
|---|---|
| `orders.order_total` | order |
| `order_items.quantity * unit_price` | order item |
| `customers.account_status` | customer |
| `daily_balance.closing_balance` | account per day |

A measure can be mathematically summable and still be invalid in the current relation.

---

## 5. Grain-transition checks

Run these checks before and after each join that may multiply rows.

### Row count

```sql
SELECT COUNT(*) AS row_count
FROM <relation>;
```

### Distinct business-key count

```sql
SELECT COUNT(DISTINCT <business_key>) AS distinct_key_count
FROM <relation>;
```

For composite keys:

```sql
SELECT COUNT(*) AS distinct_key_count
FROM (
    SELECT DISTINCT <key_column_1>, <key_column_2>
    FROM <relation>
);
```

### Duplicate-key check

```sql
SELECT
    <business_key>,
    COUNT(*) AS row_count
FROM <relation>
GROUP BY <business_key>
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
```

### Measure comparison

```sql
SELECT SUM(<measure>) AS measure_total
FROM <relation_before_join>;
```

```sql
SELECT SUM(<measure>) AS measure_total
FROM <relation_after_join>;
```

### Verification record

| Check | Before join | After join | Expected relationship | Pass? |
|---|---:|---:|---|---|
| Row count |  |  |  |  |
| Distinct business keys |  |  |  |  |
| Measure total |  |  |  |  |
| Maximum matches per left key |  |  |  |  |

A stable distinct-key count does not prove that a measure remained valid.

---

## 6. Detail-to-header reconciliation

Use this section when the same business value exists at two grains, such as an order header and order items.

**Header measure:**  
`____________________________________________`

**Detail-derived measure:**  
`____________________________________________`

**Required tolerance:**  
`____________________________________________`

```sql
SELECT
    h.<entity_key>,
    h.<header_measure> AS header_value,
    SUM(<detail_measure_expression>) AS detail_value,
    h.<header_measure> - SUM(<detail_measure_expression>) AS difference
FROM <header_source> AS h
JOIN <detail_source> AS d
    ON <join_condition>
GROUP BY
    h.<entity_key>,
    h.<header_measure>
HAVING ABS(
    h.<header_measure> - SUM(<detail_measure_expression>)
) > <allowed_tolerance>;
```

**Expected result:** zero rows, unless documented exceptions exist.

**Documented exceptions:**

`__________________________________________________________________`

`__________________________________________________________________`

---

## 7. Chosen correction

Select the correction that preserves the intended contract.

- [ ] Aggregate the right-side table to the required grain before joining.
- [ ] Use a measure defined at the resulting detail grain.
- [ ] Join through a deduplicated relationship table.
- [ ] Change the output grain and document the new contract.
- [ ] Separate the logic into multiple models.
- [ ] Remove the join because its columns are not required.
- [ ] Other: `____________________________________________________`

**Why this correction is valid:**

`__________________________________________________________________`

`__________________________________________________________________`

---

## 8. Final model contract

Complete this block and place it in the model documentation or pull request.

```text
Model:
Purpose:
Output grain:
Output key:
Source measures:
Measure grain:
Join cardinality assumptions:
Known grain transitions:
Required reconciliation:
Required uniqueness test:
Required aggregate test:
```

---

## 9. Pull-request review version

### Grain

- What does one row represent before each join?
- What does one row represent after each join?
- Which columns identify one row?
- Can one left-side row match multiple right-side rows?

### Measures

- At what grain is each measure defined once?
- Does the join repeat any measure before aggregation?
- Is `COUNT(DISTINCT ...)` hiding row multiplication while another measure remains repeated?

### Evidence

- Did row count change?
- Did distinct-key count change?
- Did the aggregate total change?
- Was the maximum match count checked?
- Was header-to-detail reconciliation tested?

### Decision

- Is the resulting grain intentional?
- Is every measure valid at that grain?
- Is the grain contract documented next to the model?

**Review rule:** Before aggregating after a join, verify that every measure is unique at the resulting row grain.

---

# Worked example: customer revenue

## Model contract

```text
Model: customer_revenue
Purpose: report total order revenue by customer
Output grain: one row per customer
Output key: customer_id
Source measure: orders.order_total
Measure grain: one value per order
Join assumption: item inputs must be reduced to one row per order
Aggregate test: sum(output.revenue) = sum(orders.order_total)
```

## Source inventory

| Source | Grain | Key |
|---|---|---|
| `customers` | one row per customer | `customer_id` |
| `orders` | one row per order | `order_id` |
| `order_items` | one row per item within an order | `(order_id, line_number)` |

## Join diagnosis

| Check | Before item join | After item join |
|---|---:|---:|
| Rows | 4 | 8 |
| Distinct orders | 4 | 4 |
| Sum of `order_total` | 500.00 | 1,000.00 |

The distinct order count remains correct, but `order_total` is repeated once per item row.

## Correction

Aggregate `order_items` to one row per order before joining, or calculate revenue from an item-grain expression that reconciles to the order header.

**Prevention rule:** Before aggregating after a join, verify that every measure is unique at the resulting row grain.
