# Testing Checklist and Cross-Tool Reconciliation

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

Rule: differences are investigated and explained, never adjusted to make tools agree.

## 1. Structural tests

| # | Test | Method | Result |
|---|---|---|---|
| T1 | Primary keys unique (12 tables) | Python check in generator | Pass |
| T2 | Row counts: CSV = MySQL | Loader script | Pass (12 of 12) |
| T3 | Generator reproducible | SHA256 hash across two runs | Pass |
| T4 | Blanks loaded as NULL | SQL count (24 null vendor, 0 empty) | Pass |
| T5 | Foreign keys enforced where designed | MySQL load | Pass |

## 2. Defect detection (checks vs answer key)

| # | Check | Found | Planted | Result |
|---|---|---|---|---|
| D1 | Missing vendor / project code | 24 / 24 | 24 / 24 | Pass |
| D2 | Missing installation date | 18 | 18 | Pass |
| D3 | Invalid property type | 24 | 24 | Pass |
| D4 | Wrong rebate | 120 | 120 | Pass |
| D5 | PO differs from rule | 148 | 148 | Pass |
| D6 | Duplicate invoice reference | 19 | 19 | Pass |
| D7 | Potential duplicate invoices | 12 | 12 | Pass (count) |
| D8 | Potential duplicate payments | 9 | 9 | Pass (count) |
| D9 | Approved before submitted | 42 | 42 | Pass |
| D10 | Invoice dated before PO | 9 | 9 | Pass |

Note: D7 and D8 match on count. Record-by-record matching was not done.

## 3. Cross-tool totals

| Measure | SQL | Excel | Python | Power BI |
|---|---|---|---|---|
| K1 Recorded rebate | 391,085 | 391,085 | 391,085 | 391,085 |
| K2 PO value | 385,240 | 385,240 | 385,240 | 385,240 |
| K3 Invoiced (excl. rejected) | 382,430 | 382,430 | 382,430 | 382,430 |
| K4 Paid to valid invoices | 345,646 | 345,646 | 345,646 | 345,646 |
| K5 Outstanding | 43,530 | 43,530 | 43,530 | 43,530 |
| K6 Overdue | 29,896 | 29,896 | 29,896 | 29,896 |
| Overpaid | 6,746 | 6,746 | 6,746 | 6,746 |
| Billing exceptions (count) | 565 | 565 | not tested | 565 |

## 4. Differences found and explained

| # | Difference | Cause | Resolution |
|---|---|---|---|
| E1 | Excel paid 347,773 vs SQL 345,646 | 8 allocations (2,127) point to non-existent invoices | Two named measures (D35) |
| E2 | Ageing total 43,380 vs K5 43,530 | 1 invoice (150) has no invoice date | Confirmed in Excel |
| E3 | Rule-based rebate 389,220 vs recorded 391,085 | Net effect of rebate defects | Not split by cause (open item) |
| E4 | First DAX measures disagreed with SQL | Filter flow through an inactive relationship | Rebuilt as per-invoice columns (D38) |
| E5 | Overpaid 49 invoices vs 46 | 3 invoices had a non-positive total | Explained (46 + 3) |

## 5. Known limitations

- Data is synthetic and defects were planted by us.
- Power BI hard-codes payment terms (30) and the reporting date.
- Power BI loads SQL exports for chain status, SLA, ageing and vendor rate, so those pages check presentation, not independent logic.
- SLA thresholds are illustrative.
- Python was not used to recompute chain status or SLA.