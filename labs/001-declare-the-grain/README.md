# Declare the grain

A syntactically valid join can preserve every order and still invalidate
an order-level measure.

This lab demonstrates how joining an order-grain table to an item-grain
table changes the relation from one row per order to one row per order
item.

The join increases the row count from 4 to 8 and changes reported revenue
from 500 to 1,000.

## Tested with

```text
DuckDB 1.5.4
