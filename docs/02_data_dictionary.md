# Data Dictionary

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

**Conventions:** PK = primary key, FK = foreign key. All money is in GBP, stored with 2 decimal places. Table and column names use lowercase with underscores.

---

## Group 1: Dimension and reference tables

### 1.1 dim_vendor

**Grain:** one row per vendor.
**Purpose:** describes each installation vendor, so results can be grouped by region and category.
**Relationships:** one vendor has many installation transactions (one-to-many).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| vendor_id | VARCHAR(10) | PK | Unique vendor code | Format V001, V002 and so on |
| vendor_name | VARCHAR(100) | | Fictional vendor name | Required, unique |
| region | VARCHAR(30) | | Region the vendor mainly works in | Required, for example North West, London |
| vendor_category | VARCHAR(20) | | Size band of the vendor | Large, Medium, Small |
| onboarding_date | DATE | | Date the vendor was registered | Required, not in the future |
| vendor_status | VARCHAR(15) | | Current status | Active, Inactive, Suspended |

### 1.2 dim_date

**Grain:** one row per calendar day.
**Purpose:** a calendar table for reporting by month, quarter and year. Power BI needs it for time analysis.
**Relationships:** one date has many transactions, invoices, payments and events (one-to-many, from each date column in those tables).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| date_key | INT | PK | Date as a number, YYYYMMDD | For example 20260131 |
| full_date | DATE | | The calendar date | Unique, no gaps |
| year | SMALLINT | | Calendar year | For example 2026 |
| quarter | TINYINT | | Quarter of the year | 1 to 4 |
| month_number | TINYINT | | Month of the year | 1 to 12 |
| month_name | VARCHAR(10) | | Month name | January to December |
| year_month_key | CHAR(7) | | Year and month, for sorting | Format 2026-01 |
| week_of_year | TINYINT | | ISO week number | 1 to 53 |
| day_of_week | VARCHAR(10) | | Day name | Monday to Sunday |
| is_weekend | TINYINT | | Weekend flag | 0 = weekday, 1 = weekend |

### 1.3 business_rules

**Grain:** one row per configurable rule or assumption.
**Purpose:** holds rates, payment terms, thresholds and the reporting date in one place, so no value is hard-coded in scripts or queries.
**Relationships:** none. It is a lookup table read by the scripts and queries.

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| rule_id | VARCHAR(10) | PK | Unique rule code | Format BR01, BR02 and so on |
| rule_name | VARCHAR(50) | | Short name used in code | Required, unique, for example REBATE_PER_FLAT |
| rule_value | VARCHAR(30) | | The value of the rule | Stored as text, converted using value_type |
| value_type | VARCHAR(10) | | How to read the value | DECIMAL, INTEGER, DATE, TEXT |
| rule_kind | VARCHAR(15) | | Rule or assumption | Business rule, Assumption |
| description | VARCHAR(200) | | What the rule means | Required |

**Planned rows (SLA thresholds will be added later):**

| rule_id | rule_name | rule_value | value_type | rule_kind |
|---|---|---|---|---|
| BR01 | REBATE_PER_FLAT | 60.00 | DECIMAL | Business rule |
| BR02 | REBATE_PER_HOUSE | 90.00 | DECIMAL | Business rule |
| BR03 | PAYMENT_TERMS_DAYS | 30 | INTEGER | Assumption |
| BR04 | MIN_VENDOR_TRANSACTIONS | 30 | INTEGER | Assumption |
| BR05 | TIME_BASIS | CALENDAR | TEXT | Assumption |
| BR06 | REPORTING_DATE | (to be set) | DATE | Assumption |

---

## Group 2: Installation transactions

### 2.1 installation_transaction

**Grain:** one row per installation (one property, either a flat or a house).
**Purpose:** the starting point of the money chain. It records what the vendor installed, whether it is eligible for a rebate, and the rebate value the source system recorded.
**Relationships:** many installations belong to one vendor (many-to-one with dim_vendor). Each installation can later be linked to at most one PO line (see Group 3).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| transaction_id | VARCHAR(12) | PK | Unique installation code | Format T000001, T000002 and so on |
| vendor_id | VARCHAR(10) | FK | Vendor who did the installation | Must exist in dim_vendor. Mandatory |
| project_code | VARCHAR(10) | | Project the installation belongs to | Format P01, P02 and so on. Mandatory |
| property_ref | VARCHAR(20) | | Synthetic property reference | Format PR000001. Used to spot the same property installed twice |
| property_type | VARCHAR(10) | | Type of property | Flat, House. Anything else is invalid |
| installation_date | DATE | | Date the installation was completed or attempted | Mandatory. Not in the future. Not before the vendor onboarding date |
| completion_status | VARCHAR(15) | | Outcome of the installation | Completed, Failed, Cancelled |
| is_eligible | TINYINT | | Whether the installation qualifies for a rebate | 1 = eligible, 0 = not eligible. Only Completed installations can be eligible |
| ineligible_reason | VARCHAR(40) | | Why it is not eligible | Blank when eligible. For example Not completed, Outside project scope |
| expected_rebate_recorded | DECIMAL(10,2) | | Rebate value written by the source system | Should be 60.00 (flat), 90.00 (house) or 0.00 (not eligible). Wrong values are planted on purpose |
| recorded_date | DATE | | Date the record was entered | On or after installation_date |

**Rebate rule used to check expected_rebate_recorded:**

- Eligible flat: rate for REBATE_PER_FLAT (£60.00)
- Eligible house: rate for REBATE_PER_HOUSE (£90.00)
- Not eligible: £0.00
- Rates are read from the business_rules table, never typed into code.

**Columns intentionally left out:** eligible flat count and eligible house count. They can be worked out from `property_type` and `is_eligible`, and storing them twice would allow them to disagree.

---

## Group 3: Purchase orders

### 3.1 po_header

**Grain:** one row per purchase order.
**Purpose:** records who the PO was raised for, when, and its status.
**Relationships:** many POs belong to one vendor (many-to-one with dim_vendor). One PO has many lines (one-to-many with po_line). One PO can later have many invoices (see Group 4).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| po_id | VARCHAR(12) | PK | Unique PO number | Format PO000001, PO000002 and so on |
| vendor_id | VARCHAR(10) | FK | Vendor the PO is raised for | Must exist in dim_vendor. Mandatory |
| po_date | DATE | | Date the PO was created | Mandatory. Not in the future |
| po_status | VARCHAR(15) | | Current PO status | Open, Closed, Cancelled |
| created_by | VARCHAR(30) | | Synthetic buyer name | Fictional names only |

### 3.2 po_line

**Grain:** one row per PO line. Each line covers exactly one installation.
**Purpose:** holds the value committed to the vendor for one installation. K2 (PO Value) sums this table.
**Relationships:** many lines belong to one PO (many-to-one with po_header). Each line links to one installation (one-to-one in a clean dataset, with transaction_id unique across lines).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| po_line_id | VARCHAR(14) | PK | Unique PO line code | Format POL000001 and so on |
| po_id | VARCHAR(12) | FK | The PO this line belongs to | Must exist in po_header. Mandatory |
| transaction_id | VARCHAR(12) | FK | The installation this line pays for | Must exist in installation_transaction. Unique across lines (an installation should be on only one PO line) |
| line_number | TINYINT | | Position of the line within the PO | 1, 2, 3 and so on, unique within a PO |
| po_line_value | DECIMAL(10,2) | | Value committed for this installation | Should equal the expected rebate. Differences are planted on purpose |

**Columns intentionally left out:** a PO total on the header. It can be calculated by summing lines, and a stored total could disagree with its own lines.

---

## Group 4: Invoices

### 4.1 invoice_header

**Grain:** one row per invoice submission. A resubmitted invoice is a new row.
**Purpose:** records who billed, when, which PO it refers to, and where it stands in review.
**Relationships:** many invoices belong to one vendor (many-to-one with dim_vendor). Many invoices can belong to one PO (many-to-one with po_header). One invoice has many lines (one-to-many with invoice_line). A resubmitted invoice points to the invoice it replaces (self-reference).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| invoice_id | VARCHAR(12) | PK | Unique system code for each submission | Format INV000001 and so on |
| vendor_id | VARCHAR(10) | FK | Vendor who sent the invoice | Must exist in dim_vendor. Mandatory |
| invoice_reference | VARCHAR(20) | | The vendor's own invoice number | Mandatory. Should be unique per vendor. Repeats are a confirmed duplicate unless it is a resubmission |
| po_id | VARCHAR(12) | FK | PO the invoice refers to | Should exist in po_header. Blank or invalid means an unmatched invoice |
| invoice_date | DATE | | Date on the invoice | Mandatory. Not in the future. Not before the PO date |
| received_date | DATE | | Date the company received it | On or after invoice_date |
| invoice_status | VARCHAR(15) | | Review outcome | Submitted, Approved, Rejected, Cancelled |
| rejection_reason | VARCHAR(40) | | Why it was rejected | Filled only when status is Rejected. For example Amount mismatch, Missing PO |
| replaces_invoice_id | VARCHAR(12) | FK | Earlier invoice this one replaces | Blank unless a resubmission. Must exist in invoice_header |

### 4.2 invoice_line

**Grain:** one row per invoice line. Each line bills one PO line.
**Purpose:** holds the value billed for one installation. K3 (Invoiced Value) sums this table.
**Relationships:** many lines belong to one invoice (many-to-one with invoice_header). Each line links to one PO line (many-to-one with po_line, because a PO line billed twice is a planted defect).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| invoice_line_id | VARCHAR(14) | PK | Unique invoice line code | Format INL000001 and so on |
| invoice_id | VARCHAR(12) | FK | The invoice this line belongs to | Must exist in invoice_header. Mandatory |
| po_line_id | VARCHAR(14) | FK | The PO line being billed | Should exist in po_line. Blank or invalid means an unmatched line |
| line_number | TINYINT | | Position of the line within the invoice | 1, 2, 3 and so on, unique within an invoice |
| invoice_line_value | DECIMAL(10,2) | | Value billed for this line | Should equal the PO line value. Must not be negative. Differences are planted on purpose |

**Columns intentionally left out:**
- An invoice total on the header, and a due date. Totals come from summing lines, and the due date is invoice_date plus PAYMENT_TERMS_DAYS from the business rules.
- A "paid" status. Payment status is worked out from payment allocations, so it cannot disagree with them.

**Loading note:** invoice_reference is deliberately not unique in the database. Duplicates must be able to load so that we can detect them, not be rejected on entry.

---

## Group 5: Payments

### 5.1 payment

**Grain:** one row per payment made to a vendor.
**Purpose:** records the money paid out, when, and its status.
**Relationships:** many payments belong to one vendor (many-to-one with dim_vendor). One payment has many allocations (one-to-many with payment_allocation).

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| payment_id | VARCHAR(12) | PK | Unique payment code | Format PAY000001 and so on |
| vendor_id | VARCHAR(10) | FK | Vendor who was paid | Must exist in dim_vendor. Mandatory |
| payment_reference | VARCHAR(20) | | Reference on the remittance advice | Mandatory. Repeats may indicate a confirmed duplicate payment |
| payment_date | DATE | | Date the payment was made | Mandatory. Not in the future |
| payment_amount | DECIMAL(12,2) | | Total money paid | Must be greater than zero. Should equal the sum of its allocations. Differences are planted on purpose |
| payment_status | VARCHAR(15) | | Outcome of the payment | Completed, Pending, Failed, Reversed |

### 5.2 payment_allocation

**Grain:** one row per amount of a payment applied to one invoice.
**Purpose:** bridge table between payment and invoice. K4 (Paid Value) sums this table, counting only completed payments.
**Relationships:** many allocations belong to one payment (many-to-one with payment). Many allocations belong to one invoice (many-to-one with invoice_header). Together, payment and invoice form a many-to-many relationship, resolved by this table.

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| allocation_id | VARCHAR(12) | PK | Unique allocation code | Format ALC000001 and so on |
| payment_id | VARCHAR(12) | FK | The payment being allocated | Must exist in payment. Mandatory |
| invoice_id | VARCHAR(12) | FK | The invoice being paid | Should exist in invoice_header. Blank or invalid means an unmatched allocation |
| allocation_amount | DECIMAL(12,2) | | Amount applied to this invoice | Should be greater than zero. Negative or zero values are flagged |
| allocation_date | DATE | | Date the allocation was recorded | On or after payment_date |

**Columns intentionally left out:**
- A paid flag or outstanding balance on the invoice. Both are calculated from allocations.
- A unique rule on payment and invoice together. Two allocation rows for the same pair could be a legitimate split or a duplicate, so the database must allow them to load and the checks will investigate.

**Counting rules to remember:**
- Only allocations whose payment has status Completed count towards Paid Value. Failed and Reversed payments are excluded, and Pending payments are reported separately.
- Always sum allocations per invoice before joining to the invoice header. Joining the header directly to allocations before summing multiplies the invoice value, which is the classic double-counting error.

---

## Group 6: Workflow events and defect log

### 6.1 workflow_event

**Grain:** one row per status change of one record (an installation, PO, invoice or payment).
**Purpose:** a history of how each record moved through the process. K8 (SLA Compliance) and K10 (Processing Time) are calculated from this table.
**Relationships:** each event refers to one record through entity_type and entity_id. This is a logical link only, with no database foreign key, so the quality checks must test it.

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| event_id | VARCHAR(12) | PK | Unique event code | Format EVT000001 and so on |
| entity_type | VARCHAR(15) | | Kind of record the event belongs to | Installation, PO, Invoice, Payment |
| entity_id | VARCHAR(14) | | ID of that record | Must exist in the table matching entity_type |
| vendor_id | VARCHAR(10) | FK | Vendor the record belongs to | Must exist in dim_vendor. Stored here to make vendor analysis simpler |
| from_status | VARCHAR(20) | | Status before the change | Blank for the first event of a record |
| to_status | VARCHAR(20) | | Status after the change | Mandatory |
| event_timestamp | DATETIME | | When the change happened | Mandatory. Not in the future. Not before the previous event of the same record |
| delay_reason | VARCHAR(40) | | Reason given for a late stage | Blank if on time. For example Awaiting vendor reply, Missing PO, Approver unavailable |

**Valid status transitions (used to detect invalid transitions):**

| entity_type | Allowed path |
|---|---|
| Installation | Recorded, then Rebate Calculated |
| PO | Created, then Closed, or Created, then Cancelled |
| Invoice | Submitted, then Approved. Or Submitted, then Rejected, then Resubmitted (a new invoice) |
| Payment | Initiated, then Completed. Or Initiated, then Failed. Or Completed, then Reversed |

Any other order, for example Approved before Submitted, is an invalid status transition and is flagged.

### 6.2 defect_injection_log

**Grain:** one row per defect deliberately planted by the data generator.
**Purpose:** the answer key. Later we compare it with what our quality checks find, to prove the checks work (success criterion 4).
**Relationships:** none enforced. Each row points to the affected record through table_name and record_id.

| Column | Type | Key | Description | Valid values and rules |
|---|---|---|---|---|
| defect_id | VARCHAR(10) | PK | Unique defect code | Format DEF00001 and so on |
| table_name | VARCHAR(30) | | Table holding the affected record | One of the project tables |
| record_id | VARCHAR(14) | | ID of the affected record | Primary key value in that table |
| defect_type | VARCHAR(40) | | Category of defect | For example Wrong rebate, Missing vendor, Duplicate invoice reference |
| defect_class | VARCHAR(20) | | Data defect or business exception | Data defect, Business exception |
| original_value | VARCHAR(50) | | The correct value before the defect was planted | Blank if the field was empty by design |
| defect_value | VARCHAR(50) | | The value after the defect was planted | The value that appears in the CSV |
| injected_rule | VARCHAR(100) | | Short description of the rule used | For example 3% of eligible flats get a rebate of 90.00 |

**Important:** the defect log is for testing only. The cleaning, SQL and Power BI logic must never read it to decide what to flag. If they did, we would be marking our own homework.

---

## Relationship Summary

All relationships below are in the "one side to many side" direction.

| # | One side (parent) | Many side (child) | Join column | Type | Enforced in database? |
|---|---|---|---|---|---|
| 1 | dim_vendor | installation_transaction | vendor_id | One-to-many | Yes (foreign key) |
| 2 | dim_vendor | po_header | vendor_id | One-to-many | Yes |
| 3 | dim_vendor | invoice_header | vendor_id | One-to-many | Yes |
| 4 | dim_vendor | payment | vendor_id | One-to-many | Yes |
| 5 | dim_vendor | workflow_event | vendor_id | One-to-many | Yes |
| 6 | po_header | po_line | po_id | One-to-many | Yes |
| 7 | installation_transaction | po_line | transaction_id | One-to-one in a clean dataset | Yes (foreign key). Uniqueness is checked, not enforced |
| 8 | po_header | invoice_header | po_id | One-to-many | Checked by queries, because unmatched invoices must be able to load |
| 9 | invoice_header | invoice_line | invoice_id | One-to-many | Yes |
| 10 | po_line | invoice_line | po_line_id | One-to-many (a PO line billed twice is a defect) | Checked by queries |
| 11 | invoice_header | invoice_header | replaces_invoice_id | One-to-many (self-reference) | Checked by queries |
| 12 | payment | payment_allocation | payment_id | One-to-many | Yes |
| 13 | invoice_header | payment_allocation | invoice_id | One-to-many | Checked by queries, because unmatched allocations must be able to load |
| 14 | payment and invoice_header | each other | via payment_allocation | Many-to-many, resolved by the bridge table | See rows 12 and 13 |
| 15 | dim_date | all date columns in fact tables | date_key = date | One-to-many | Power BI only |

### Why some foreign keys are not enforced

If MySQL refused every record with a bad link, the defects we plant (unmatched invoices, orphan allocations) could never load, and our quality checks would have nothing to find. So we enforce only the links that must always be valid, and test the rest with queries.

### The money chain

```text
installation_transaction  --(1 to 1)-->  po_line  --(1 to many)-->  invoice_line
                                                                           |
                                                       (many to 1) invoice_header
                                                                           |
                                                       (1 to many) payment_allocation
                                                                           |
                                                       (many to 1) payment
```

### How the model avoids double-counting

1. **Each KPI is summed at one grain only.** K1 sums installations, K2 sums PO lines, K3 sums invoice lines, K4 sums allocations. Header tables are never summed for money.
2. **No stored totals or paid flags.** Totals and balances are calculated, so they cannot disagree with the detail.
3. **Aggregate before joining.** To compare invoices with payments, sum allocations per invoice first, then join the result to the invoice total. Joining raw lines to raw allocations multiplies rows.
4. **The bridge table breaks the many-to-many relationship** into two one-to-many relationships.
5. **Workflow events are joined only for timing analysis**, never in money calculations, because one record has many events.