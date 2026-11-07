# Findings

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

All figures are from the synthetic dataset at the reporting date of 30 Sep 2026. Exposure is potential impact, not confirmed loss. Defects were planted by the data generator, so these findings demonstrate method, not real-world behaviour.

## F1. Which discrepancy categories carry the most financial exposure?

- **Data and method:** chain status per installation (SQL view), absolute differences, one status per installation.
- **Result:** Invoice differs from PO £10,500 (134 installations); No PO line £9,630 (135); PO differs from rule £6,710 (174); Overpaid £6,326 (46 invoices); Part paid £5,040 (23).
- **Interpretation:** the largest exposure is on the billing side. Of the 134 invoice mismatches, 104 installations were billed more than once.
- **Recommendation:** block a second invoice line against a PO line that is already billed.
- **Limits:** exposure is not loss; stage A and stage B overlap and must not be added.

## F2. Why are invoices paid more than billed?

- **Data and method:** 49 invoices paid above their total, split by cause using the defect log to test the check.
- **Result:** 18 duplicate payments, 17 overpayments and 14 negative invoice lines. No unexplained cases.
- **Interpretation:** one symptom, three causes, each needing a different control.
- **Recommendation:** a payment cap per invoice, duplicate-payment detection, and rejection of negative invoice lines.
- **Limits:** causes are known only because the defects were planted.

## F3. Do vendor exception rates differ once volume is considered?

- **Data and method:** billing-chain exception rate per vendor; only vendors with 30 or more installations are ranked.
- **Result:** 16 vendors ranked, from 3.77% to 13.19%. The four highest raw rates belonged to vendors with 10 to 20 installations and were not ranked.
- **Interpretation:** the spread among ranked vendors is narrow. Vendor size and rate are different things: the largest vendor has the most exceptions but only the fourth-highest rate.
- **Recommendation:** review vendors by rate with a minimum volume, not by exception count.
- **Limits:** the rate covers billing-chain breaks only. The apparent pattern that Medium vendors rank highest has not been tested.

## F4. Where does SLA performance fall short?

- **Data and method:** days between workflow events, first invoice per PO and first completed payment per invoice.
- **Result:** compliance is 80.18% (installation to rebate), 74.60% (PO to invoice), 78.56% (invoice review) and 79.43% (approval to payment). Medians are lower than averages in every stage.
- **Interpretation:** PO to invoice is weakest, and mostly reflects vendor billing delay. Payment has the longest tail (slowest 47 days against a 10-day SLA).
- **Recommendation:** monitor the slowest 10% of items, not just the average.
- **Limits:** thresholds are illustrative. No clear monthly trend; the first and last months hold few items.

## F5. How old is the unpaid money?

- **Data and method:** outstanding balances aged by days past due.
- **Result:** £43,380 aged: £13,484 not yet due, and £29,896 overdue, of which £17,950 (79 invoices) is over 90 days.
- **Interpretation:** about 60% of overdue value is over 90 days old, in small invoices (about £227 each).
- **Recommendation:** chase invoices unpaid beyond 60 days first.
- **Limits:** the reason these are unpaid is not in the data.

## F6. Do potential-duplicate rules need tightening?

- **Result:** matching on amount and date alone flagged 405 invoice pairs and 99 payment pairs. Adding "same PO line billed twice" and "same invoice paid twice" gave 12 and 9.
- **Interpretation:** a loose rule creates mostly false alarms.
- **Recommendation:** use the tighter rules for review queues.
- **Limits:** counts match the planted defects, but record-by-record matching was not done.

## F7. How sensitive is SLA compliance to the threshold?

- **Data and method:** installation-to-rebate stage (6,000 items), compliance recalculated at thresholds of 1 to 4 calendar days.
- **Result:** 60.62% at 1 day, 80.18% at 2 days (current), 91.75% at 3 days, 100.00% at 4 days.
- **Interpretation:** reported compliance changes by 11 to 20 points per day of threshold. The threshold must be stated beside any compliance figure.
- **Recommendation:** agree the threshold with stakeholders before using compliance as a target.
- **Limits:** only stage 1 was tested. Thresholds are illustrative, and the other three stages were not recalculated.