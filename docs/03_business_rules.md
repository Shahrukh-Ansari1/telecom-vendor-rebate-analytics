# Business Rules

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

**Business rule** = a fixed requirement of the scenario.
**Assumption** = a choice we made where the scenario gave no answer.
All values below are illustrative and are stored in the `business_rules` table, never typed into code.

---

## 1. Rebate rules

| ID | Rule | Value | Kind |
|---|---|---|---|
| BR01 | Rebate per eligible flat | £60.00 | Business rule |
| BR02 | Rebate per eligible house | £90.00 | Business rule |

Expected Rebate = (Eligible Flats x £60) + (Eligible Houses x £90)
A non-eligible installation has an expected rebate of £0.00.

## 2. Eligibility rules

- Only installations with status Completed can be eligible.
- Failed and Cancelled installations are not eligible and must have an ineligible_reason.

## 3. Payment rules

| ID | Rule | Value | Kind |
|---|---|---|---|
| BR03 | Payment terms (days from invoice date) | 30 | Assumption |

- Due Date = Invoice Date + 30 days.
- An invoice is overdue when Reporting Date is later than Due Date and a balance remains.
- Only payments with status Completed count as Paid Value.

## 4. Reporting rules

| ID | Rule | Value | Kind |
|---|---|---|---|
| BR04 | Minimum transactions to rank a vendor | 30 | Assumption |
| BR05 | Time basis for processing time | CALENDAR | Assumption |
| BR06 | Reporting date (snapshot) | 2026-09-30 | Assumption |

- Vendors below the minimum are shown but labelled "low volume" and not ranked.
- The reporting date is one fixed date used in SQL, Excel, Python and Power BI.

## 5. SLA thresholds (illustrative, not company policy)

| ID | Stage | Threshold (calendar days) | Kind |
|---|---|---|---|
| BR07 | Installation recorded to rebate calculated | 2 | Assumption |
| BR08 | PO created to invoice submitted | 14 | Assumption |
| BR09 | Invoice submitted to approved or rejected | 5 | Assumption |
| BR10 | Invoice approved to payment completed | 10 | Assumption |

Phase 9 tests how compliance changes under alternative thresholds.

## 6. Matching tolerance

| ID | Rule | Value | Kind |
|---|---|---|---|
| BR11 | Amount tolerance when matching values | £0.00 | Assumption |

Amounts must match exactly. This is configurable if rounding differences appear.

## 7. Duplicate rules

- **Confirmed duplicate invoice:** same vendor and same invoice_reference, and not a resubmission (replaces_invoice_id is blank).
- **Potential duplicate invoice:** two invoices from the same vendor, not rejected, with different references, that bill the same PO line. Needs human review. (An earlier rule based on amount and dates alone produced too many false alarms, see decision D23.)
- **Confirmed duplicate payment:** same vendor and same payment_reference.
- **Potential duplicate payment:** two completed payments to the same vendor, with the same amount, dates within 3 days and different references, where both are allocated to the same invoice. Needs human review. (See decision D24.)

## 8. Status rules

- Invoice statuses: Submitted, Approved, Rejected, Cancelled.
- Rejected invoices are excluded from Invoiced Value. Their replacement is counted once.
- Cancelled POs and cancelled invoices are excluded from totals.
- Invalid status transitions (see the data dictionary) are flagged, not deleted.

## 9. Defect versus business exception

- **Data defect:** the record is wrong (missing field, wrong rebate, invalid type).
- **Business exception:** the record is correct but needs attention (partial payment, approved rejection, late payment).
- Both are flagged. Only data defects count in the Data Quality Failure Rate (K11).