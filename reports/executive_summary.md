# Executive Summary

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

**Scope:** Northbridge Telecom Infrastructure (fictional), 6,030 installations, 35 vendors, reporting date 30 Sep 2026. Figures are exposure, not confirmed loss. Defects were planted, so results demonstrate method.

## Headline numbers

| Measure | Value |
|---|---|
| Expected rebate (recorded) | £391,085 |
| PO value | £385,240 |
| Invoiced (excl. rejected) | £382,430 |
| Paid to valid invoices | £345,646 |
| Outstanding / of which overdue | £43,530 / £29,896 |
| Overpaid | £6,746 |
| Installations with a billing-chain break | 565 of 6,030 (9.37%) |

Four tools (SQL, Excel, Python, Power BI) reproduced these totals. Every difference was investigated and explained.

## Main findings

1. **Billing is the largest exposure.** Invoice differs from PO: £10,500; no PO line: £9,630. 104 of the 134 invoice mismatches are installations billed more than once.
2. **Overpayment has three separate causes:** duplicate payments (18), oversized payments (17) and negative invoice lines (14).
3. **Old debt dominates overdue money.** £17,950 (79 invoices) is over 90 days late, about 60% of the overdue total.
4. **SLA compliance is 75% to 80% at every stage;** PO to invoice is weakest (74.6%). Reported compliance moves 11 to 20 points per day of threshold.
5. **Vendor comparison needs volume rules.** The four highest raw rates belonged to vendors with under 20 installations. Ranked vendors range 3.8% to 13.2%.
6. **Loose duplicate rules create false alarms:** 405 invoice pairs shrank to 12 with a same-PO-line test.

## Recommendations

| Priority | Action | Evidence | Effort |
|---|---|---|---|
| 1 | Block a second invoice line against an already-billed PO line | 104 installations billed more than once | Medium |
| 2 | Cap payments at the invoice total and detect duplicate payments | £6,326 overpaid, 18 duplicate payments | Medium |
| 3 | Reject negative invoice lines on entry | 17 negative lines | Low |
| 4 | Chase invoices over 60 days overdue first | £22,438 over 60 days | Low |
| 5 | Agree SLA thresholds before using them as targets | Sensitivity in F7 | Low |

Estimated benefits are not calculated: no savings are claimed.

## Limitations

Synthetic data; illustrative thresholds and rates; Power BI pages for chain status, SLA and ageing use SQL exports; one open item (£1,865 rebate gap not split by cause).