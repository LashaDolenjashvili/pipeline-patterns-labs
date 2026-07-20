# Grain Review Card

Use this compact version during pull-request review.

## Declare

- Output grain:
- Output key:
- Grain before each join:
- Grain after each join:

## Check each join

- Maximum right-side matches per left row:
- Can rows multiply?
- Is multiplication intentional?

## Check each measure

- Defined once per:
- Repeated after join?
- Valid at resulting grain?

## Run

- Row count before and after
- Distinct key count before and after
- Aggregate total before and after
- Duplicate-key diagnostic
- Header-to-detail reconciliation

## Approve only when

- The resulting grain is named.
- Every measure is valid at that grain.
- Verification queries pass.
- The contract is documented.

**Before aggregating after a join, verify that every measure is unique at the resulting row grain.**
