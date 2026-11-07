# Architecture and Workflow Diagrams

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

---

## 1. Solution Architecture

This diagram shows how data moves through the project and which tool does which job.

```text
+--------------------------------------------------------------+
|  1. DATA GENERATION (Python script, fixed random seed)       |
|     Creates synthetic vendors, installations, POs, invoices, |
|     payments, workflow events, and a defect injection log    |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|  2. RAW CSV FILES  (data\raw, never edited by hand)          |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|  3. DATA PROFILING (Python / Jupyter)                        |
|     Counts, missing values, duplicates, invalid values       |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|  4. MYSQL DATABASE                                           |
|     Tables, keys, constraints, SQL for reconciliation,       |
|     quality checks, KPIs and analysis                        |
+------+----------------------+-----------------------+--------+
       |                      |                       |
       v                      v                       v
+--------------+     +------------------+    +------------------+
| 5. PYTHON    |     | 6. EXCEL         |    | 7. POWER BI      |
| EDA, anomaly |     | Power Query,     |    | Data model, DAX  |
| analysis,    |     | SUMIFS, Pivots,  |    | measures, 5      |
| charts       |     | exception report |    | dashboard pages  |
+------+-------+     +--------+---------+    +--------+---------+
       |                      |                       |
       +----------------------+-----------------------+
                               |
                               v
+--------------------------------------------------------------+
|  8. CROSS-TOOL RECONCILIATION                                |
|     SQL totals = Python totals = Excel totals = Power BI     |
|     Any difference is investigated, never forced to match    |
+------------------------------+-------------------------------+
                               |
                               v
+--------------------------------------------------------------+
|  9. FINDINGS, RECOMMENDATIONS, README, PORTFOLIO             |
+--------------------------------------------------------------+
```

### Role of each tool

| Tool | Main job |
|---|---|
| Python | Generate data, profile it, explore it, investigate anomalies |
| MySQL | Store data and do joins, reconciliation, KPIs and exception queries |
| Excel | Business-friendly reconciliation and an independent check |
| Power BI | Governed data model and interactive dashboards |

---

## 2. Business Process Workflow

This diagram shows the business process the project analyses, from installation to payment. Each stage lists the check that the project applies to it.

```text
 [1] VENDOR ONBOARDING
        |
        v
 [2] INSTALLATION RECORDED
        |   Check: mandatory fields present, valid property type, valid dates
        v
 [3] EXPECTED REBATE CALCULATED
        |   Check: (flats x £60) + (houses x £90) is correct
        v
 [4] PURCHASE ORDER CREATED
        |   Check: PO value agrees with expected rebate
        v
 [5] VENDOR INVOICE SUBMITTED
        |   Check: duplicate invoice reference, invoice vs PO balance
        v
 [6] INVOICE REVIEW  --------->  REJECTED  ---->  RESUBMITTED (back to [5])
        |   Check: valid status transition
        v
 [7] PAYMENT PROCESSED
        |   Check: payment allocations add up, possible duplicate payment
        v
 [8] CLOSED (fully paid)       or      PARTLY PAID / OUTSTANDING / OVERDUE
```

### Where exceptions arise

| Stage | Typical exception | KPI affected |
|---|---|---|
| 2 | Missing or invalid data | K11 |
| 3 | Wrong rebate calculation | K1, K7 |
| 4 | PO differs from expected rebate | K2, K7 |
| 5 | Duplicate or mismatched invoice | K3, K7, K12 |
| 6 | Rejection, delay, reopening | K8, K10 |
| 7 | Overpayment, underpayment, duplicate payment | K4, K7, K12 |
| 8 | Unpaid or overdue balance | K5, K6 |

### How to read the workflow

- Stages 2 to 7 are the stages where we measure processing time (K10) and SLA compliance (K8).
- The loop from REJECTED back to stage 5 is why one invoice can have several workflow events, and why we count a resubmitted invoice only once.