# Project Charter

## Telecom Vendor Rebate, Procurement and Payment Analytics: An End-to-End Business Intelligence Case Study

*An integrated SQL, Python, Advanced Excel and Power BI solution for financial reconciliation, vendor performance, data quality, and operational efficiency.*

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

| Item | Detail |
|---|---|
| Author | Shahrukh Ansari |
| Version | 0.1 (draft) |
| Date | 30 October 2026 |
| Fictional company | Northbridge Telecom Infrastructure |

---

## 1. Business Context

Northbridge Telecom Infrastructure is a fictional company that expands its broadband network with the help of external installation vendors across several regions.

Vendors complete installations at flats and houses. For each eligible completed installation, the company pays the vendor a rebate. The process runs in this order:

1. Vendor registration and onboarding
2. Installation transaction recording
3. Expected rebate calculation
4. Purchase order (PO) creation
5. Vendor invoice submission
6. Invoice and PO reconciliation
7. Payment processing
8. Exception investigation
9. SLA monitoring
10. Management reporting

Because the process crosses several stages and teams, errors can enter at any point. Examples are a wrong rebate amount, a PO that does not match the expected rebate, an invoice that does not match the PO, or a payment made twice.

Management has limited visibility into where these errors occur, how much money they affect, and which stages slow processing down.

---

## 2. Problem Statement

Northbridge pays vendors on the basis of a chain of documents: installation record, expected rebate, PO, invoice and payment. At present there is no single view that checks whether these documents agree with each other.

As a result, the company cannot easily answer:

- Is the expected rebate calculated correctly?
- Do POs and invoices match the amounts they should?
- Are any invoices or payments duplicated?
- How much invoice value is still unpaid, and how much is overdue?
- Which workflow stages cause the most delay?
- Which vendors have the most exceptions, once their transaction volumes are taken into account?

Without these answers, financial leakage (such as overpayments), rework and late payments to vendors go unnoticed.

---

## 3. Objectives

1. **Reconcile** the full chain from installation to payment and identify every point where it breaks.
2. **Quantify** financial exposure from mismatches, duplicates, and outstanding or overdue balances.
3. **Measure** processing efficiency and SLA performance by workflow stage, vendor and month.
4. **Assess data quality** and separate data defects from genuine business exceptions.
5. **Compare vendors fairly**, adjusting for transaction volume.
6. **Recommend controls** that could prevent avoidable discrepancies, based on evidence from the data.
7. **Deliver** the work as a reproducible solution using MySQL, Python, Excel and Power BI.

---

## 4. Scope

**In scope**

- Synthetic data for vendors, installation transactions, purchase orders, invoices, payments and workflow events
- Expected rebate calculation using illustrative rates
- Reconciliation across installation, PO, invoice and payment
- Duplicate detection (confirmed and potential)
- Outstanding balance, overdue balance and invoice ageing
- SLA monitoring using configurable, illustrative thresholds
- Vendor performance comparison adjusted for volume
- Data quality checks and exception categorisation
- A MySQL database, Python analysis, an Excel reconciliation workbook and a Power BI dashboard

**Out of scope (exclusions)**

- Any real BT or other company data, rates, vendor records or internal processes
- Connection to live systems such as SAP
- Machine learning or predictive modelling
- Automated payment or approval workflows
- Tax, currency conversion and accounting entries (all amounts are in GBP)
- Real-time or scheduled data refresh

---

## 5. Stakeholders

| Stakeholder | Interest | Main questions they ask |
|---|---|---|
| Finance Controller | Financial accuracy and exposure | How much money is at risk from mismatches and duplicates? |
| Procurement Manager | PO quality and vendor management | Which vendors have the most exceptions? |
| Accounts Payable Lead | Invoice and payment processing | What is outstanding and overdue? Are any payments duplicated? |
| Operations Manager | Process speed and SLAs | Which workflow stages cause delays? |
| Internal Audit / Controls | Control effectiveness | Where do controls fail, and what would prevent it? |
| Vendor Relationship Manager | Fair treatment of vendors | Are vendor comparisons fair and are payments on time? |

---

## 6. Analytical Questions

Each question is linked to a stakeholder and to the project objective it supports (see Section 3).

| ID | Business question | Stakeholder | Objective |
|---|---|---|---|
| Q1 | Is the expected rebate correctly calculated? | Finance Controller | 1 |
| Q2 | Does the PO value align with the expected rebate? | Procurement Manager | 1 |
| Q3 | Does the invoice match the applicable PO balance? | Accounts Payable Lead | 1 |
| Q4 | Are there missing, invalid, duplicated or inconsistent transaction records? | Internal Audit / Controls | 4 |
| Q5 | Are there potential duplicate invoices or payments? | Accounts Payable Lead | 2 |
| Q6 | Which transactions have unexplained financial differences? | Finance Controller | 2 |
| Q7 | How much invoice value remains outstanding? | Accounts Payable Lead | 2 |
| Q8 | How much is overdue under the project's defined rules? | Accounts Payable Lead | 2 |
| Q9 | Which workflow stages contribute most to processing delays? | Operations Manager | 3 |
| Q10 | Which vendors have higher exception rates after accounting for transaction volume? | Vendor Relationship Manager | 5 |
| Q11 | How does SLA performance change over time? | Operations Manager | 3 |
| Q12 | Which exception categories contribute most to financial exposure? | Finance Controller | 2 |
| Q13 | What controls could prevent avoidable discrepancies and rework? | Internal Audit / Controls | 6 |

---

## 7. KPI Definitions

All amounts are in GBP. Rates and thresholds come from the configurable business rules (see `03_business_rules.md`, to be written later). These definitions are provisional until the data model is final.

### 7.1 Financial chain KPIs

| ID | KPI | Business definition | Calculation | Source (grain) | Exclusions and limitations |
|---|---|---|---|---|---|
| K1 | Expected Rebate Value | The rebate the company should owe vendors for eligible completed installations. | SUM of (Eligible Flats x £60) + (Eligible Houses x £90), taken per installation transaction | Installation transaction (one row per installation) | Only eligible, completed installations are counted. Rates are illustrative assumptions, not real policy. Transactions with missing or invalid property type are flagged, not counted silently. |
| K2 | PO Value | The total value committed to vendors through purchase orders. | SUM of PO line values | PO line (one row per line on a PO) | Cancelled POs are excluded. A PO can have several lines, so we sum lines, never headers, to avoid double-counting. |
| K3 | Invoiced Value | The total value vendors have billed. | SUM of invoice line values | Invoice line (one row per line on an invoice) | Rejected invoices are excluded. A resubmitted invoice is counted once, through its replacement. Potential duplicates are flagged and remain in the total until investigated, so exposure is visible. |
| K4 | Paid Value | The value actually paid against invoices. | SUM of payment allocation amounts | Payment allocation (one row per amount of a payment applied to an invoice) | Uses allocations, not payments, because one payment can cover several invoices and one invoice can be paid in several parts. Only completed payments count. |

### 7.2 Balance and control KPIs

| ID | KPI | Business definition | Calculation | Source (grain) | Exclusions and limitations |
|---|---|---|---|---|---|
| K5 | Outstanding Invoice Balance | Invoice value that has been billed but not yet paid, as at the reporting date. | SUM over valid invoices of (Invoiced Value - Paid Value), counting only balances above zero | Invoice header, joined to payment allocation totals per invoice | Rejected and cancelled invoices are excluded. Payments are summed per invoice before joining, to avoid double-counting. Overpaid invoices (negative balance) are reported separately as overpayments, not netted off. Depends on the reporting date. |
| K6 | Overdue Invoice Balance | The part of the outstanding balance that is past its due date, as at the reporting date. | SUM of outstanding balance for invoices where Reporting Date > Due Date. Due Date = Invoice Date + payment terms (days), where payment terms are set in the business rules | Invoice header, joined to payment allocation totals per invoice | The payment terms (for example 30 days) are an illustrative assumption, not company policy. Invoices under investigation are still counted but can be filtered. Depends on the reporting date. |
| K7 | Exception Value | The financial value affected by transactions that fail a reconciliation or control check. | SUM of the absolute financial difference for each exception, counting each transaction once even if it fails several checks | Exception record (one row per transaction per exception type), rolled up to transaction | Difference is measured in the chain stage where it arises (rebate vs PO, PO vs invoice, invoice vs payment). Exception value is exposure, not confirmed loss. Genuine business exceptions (for example an approved partial payment) are kept separate from data-quality defects. |
| K8 | SLA Compliance % | The share of items completed within the SLA threshold for their workflow stage. | Items completed within threshold / Total items completed in the period x 100 | Workflow event (one row per status change), measured per stage | Thresholds are illustrative and configurable, not official policy. Items still open are excluded from the denominator and reported separately. Changing a threshold changes the result, which is why Phase 9 tests alternative thresholds. |

### 7.3 Vendor, efficiency and data quality KPIs

| ID | KPI | Business definition | Calculation | Source (grain) | Exclusions and limitations |
|---|---|---|---|---|---|
| K9 | Vendor Exception Rate | The share of a vendor's transactions that have at least one exception, so vendors of different sizes can be compared fairly. | Transactions with at least one exception / Total transactions for the vendor x 100 | Installation transaction, grouped by vendor | Counts each transaction once. Vendors with fewer than a minimum number of transactions (set in the business rules, for example 30) are shown but marked "low volume" and not ranked. A small sample can give a misleading rate. |
| K10 | Average and Median Processing Time | How long items take to move through a workflow stage, or from end to end. | Days between the start and end event of a stage, then the average and the median across completed items | Workflow event (one row per status change) | Open items are excluded and reported separately. Median is shown beside the average because a few very slow items can pull the average up. Business days vs calendar days is a setting in the business rules. |
| K11 | Data Quality Failure Rate | The share of records that fail at least one data quality check. | Records failing at least one data quality check / Total records checked x 100 | Each source table, reported per table | Covers defects such as missing mandatory fields, invalid dates and invalid property types. Legitimate business exceptions are not counted here. Records are flagged, never deleted. |
| K12 | Potential Duplicate Rate | The share of invoices or payments that look like duplicates and need investigation. | Invoices (or payments) flagged as potential duplicates / Total invoices (or payments) x 100 | Invoice header and payment | Confirmed duplicates (identical references) and potential duplicates (similar vendor, amount and date) are reported separately. Potential duplicates are not proof of error, they need human review. |

---

## 8. Assumptions

These are illustrative modelling choices for this independent project. They are not real company policy. All values will be held in a configurable business-rules table.

| ID | Assumption | Value |
|---|---|---|
| A1 | Rebate per eligible flat | £60 |
| A2 | Rebate per eligible house | £90 |
| A3 | Payment terms (days from invoice date) | 30 (illustrative) |
| A4 | SLA thresholds per workflow stage | To be defined in the business rules |
| A5 | Minimum transactions to rank a vendor | 30 (illustrative) |
| A6 | Reporting date (data snapshot) | One fixed date, to be chosen when the data is generated |
| A7 | Currency | GBP only |
| A8 | Days used for processing time | Calendar days (configurable) |

Business rules are fixed requirements of the scenario (for example, the rebate formula). Assumptions are choices we made where the scenario gave no answer (for example, 30-day payment terms).

---

## 9. Risks and Limitations

| ID | Risk or limitation | Mitigation |
|---|---|---|
| R1 | The data is synthetic, so findings describe this dataset only and cannot be applied to a real company. | State this clearly in every deliverable. Present findings as demonstrations of method. |
| R2 | Defects are planted by us, so a check finding them proves the check works, not that real data behaves this way. | Keep a defect injection log and use it to test the checks. |
| R3 | A small vendor sample can give misleading exception rates. | Use rates, a minimum volume threshold and a "low volume" label. |
| R4 | The tools may disagree because of different logic or rounding. | Cross-tool reconciliation tests in Phase 10. Investigate differences and never adjust figures just to match. |
| R5 | Overdue and outstanding figures depend on the chosen reporting date. | Use one fixed snapshot date in all tools. |
| R6 | Some Python libraries may be blocked by Windows Smart App Control. | Use older, widely trusted versions, recorded in requirements.txt. |
| R7 | Confidential BT information could enter the project by accident. | Use only synthetic data and invented names, rates and rules. |

---

## 10. Expected Deliverables

1. Project charter (this document)
2. Data dictionary, business rules and decision log
3. Python data-generation scripts and synthetic CSV files, plus a defect injection log
4. Data profiling report
5. MySQL database with schema, load, quality, reconciliation, KPI and analysis SQL scripts
6. Excel reconciliation workbook
7. Python analysis notebooks
8. Power BI model and five-page dashboard
9. Testing checklist with cross-tool reconciliation results
10. Findings, recommendations and executive summary
11. README and portfolio screenshots
12. Resume and interview preparation material

---

## 11. Success Criteria

The project is successful when:

1. All 13 analytical questions (Q1 to Q13) are answered with a verified result.
2. All 12 KPIs (K1 to K12) have a documented definition and a calculated value.
3. Key totals agree across SQL, Excel, Python and Power BI, or every difference is explained.
4. The checks detect the defects recorded in the defect injection log.
5. The whole project can be rebuilt from a clean start using the documented steps.
6. Every finding states its data, method, result, interpretation and limitations.
7. I can explain every table, query, measure and decision in my own words.