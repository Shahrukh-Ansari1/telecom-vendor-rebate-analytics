# Telecom Vendor Rebate, Procurement and Payment Analytics: An End-to-End Business Intelligence Case Study

*An integrated SQL, Python, Advanced Excel and Power BI solution for financial reconciliation, vendor performance, data quality, and operational efficiency.*

> **Disclaimer:** This project is an independent telecom operations analytics case study developed using synthetic data and illustrative business rules. It is not an official BT project and does not contain BT operational or confidential data.

## Executive summary

A fictional telecom company (Northbridge Telecom Infrastructure) pays installation vendors a rebate per eligible flat (£60) and house (£90). These rates are illustrative assumptions. This project reconciles the full chain from installation to purchase order, invoice and payment across 6,030 synthetic installations and 35 vendors, at a fixed reporting date of 30 Sep 2026.

Key results (details in `reports/executive_summary.md` and `reports/findings.md`):

- 565 of 6,030 installations (9.37%) break somewhere between installation and invoice.
- Largest exposure: invoice differs from PO (£10,500), mostly installations billed more than once.
- £43,530 is outstanding, of which £29,896 is overdue.
- £6,746 is overpaid, from three separate causes.
- SQL, Excel, Python and Power BI reproduce the same totals; every difference was explained.

## Business problem

Payments depend on a chain of documents (installation, PO, invoice, payment) with no single view checking that they agree. The project answers 13 business questions (see `docs/01_project_charter.md`).

## Architecture

Python generates synthetic data (fixed seed) → raw CSVs → Python profiling → MySQL (SQL checks, reconciliation, KPIs) → Excel (independent recalculation, pivots) → Python (checks and charts) → Power BI (model and 5 pages) → findings and documentation.

See `docs/diagrams/architecture_and_workflow.md`.

## Data model

12 tables: `dim_vendor`, `dim_date`, `business_rules`, `installation_transaction`, `po_header`, `po_line`, `invoice_header`, `invoice_line`, `payment`, `payment_allocation`, `workflow_event`, `defect_injection_log`. Money is always summed at line or allocation level to avoid double-counting. Full definitions, grain and relationships are in `docs/02_data_dictionary.md`.

## Business rules

Rates, 30-day payment terms, SLA thresholds and the reporting date are illustrative and configurable. See `docs/03_business_rules.md`.

## SQL methodology

MySQL 8.0 database `telecom_rebate`. Scripts are in `sql/`, in run order:

| Folder | Purpose |
|---|---|
| `01_schema` | Create database and 12 tables. Foreign keys are enforced only where bad data must not load. Unmatched invoices and orphan allocations are allowed to load so the checks can find them. |
| `03_quality_checks` | Missing, invalid, duplicate, broken-link, amount and date-order checks. Potential duplicates use tightened rules (same PO line billed twice, same invoice paid twice). |
| `04_reconciliation` | Invoice balances, ageing, installation chain status (view), invoice payment status (view), exception summary. |
| `05_kpis` | Vendor exception rate, SLA and processing time, monthly SLA trend, control totals. |

Key rules: sum at one grain only (lines, allocations), aggregate before joining, one status per record (the first place the chain breaks), exposure measured as absolute difference, and rates and thresholds read from `business_rules`.

## Excel analysis

`excel/telecom_reconciliation.xlsx` loads the raw CSVs with Power Query and rebuilds K1 to K6, overpaid and the ageing buckets with `SUMIFS`, `COUNTIFS` and helper columns, independently of SQL. A `Control` sheet compares each measure with SQL. Chain status is loaded from a SQL export and presented with conditional formatting and PivotTables.

## Python analysis

- `src/generate_data.py` and `config/settings.py`: reproducible synthetic data (seed 42) with a logged answer key of planted defects.
- `src/load_to_mysql.py`: loads the CSVs into MySQL (blank cells become NULL, parents load before children, row counts verified).
- `notebooks/01_profiling.ipynb`: data profiling, 20 checks.
- `notebooks/02_analysis.ipynb`: recalculates K1 to K6 and compares them with SQL, plus three charts.

## Power BI

`powerbi/telecom_rebate_dashboard.pbix`: single-direction many-to-one relationships, three shortcut relationships kept inactive to avoid ambiguous paths, invoice-level paid, outstanding, overpaid and overdue calculated as columns then summed in measures.

| Page | Screenshot |
|---|---|
| 1 Executive Overview | `screenshots/pbi_page1_executive.png` |
| 2 Financial Reconciliation | `screenshots/pbi_page2_reconciliation.png` |
| 3 Vendor Performance | `screenshots/pbi_page3_vendor.png` |
| 4 SLA and Workflow | `screenshots/pbi_page4_sla.png` |
| 5 Data Quality and Exceptions | `screenshots/pbi_page5_data_quality.png` |

Excel control sheet: `screenshots/excel_control_sheet.png`. Python charts: `screenshots/py_*.png`.

## Findings and recommendations

See `reports/findings.md` (F1 to F7) and `reports/executive_summary.md`. Recommendations are ranked by evidence and effort. No savings are claimed.

## Testing and validation

`docs/05_testing_checklist.md` records structural tests, defect detection against the answer key, cross-tool totals (SQL, Excel, Python, Power BI) and five differences that were investigated and explained, never adjusted.

## Limitations

- Synthetic data with planted defects: findings demonstrate method, not real-world behaviour.
- Rates, payment terms and SLA thresholds are illustrative.
- Power BI hard-codes 30-day terms and the reporting date.
- Power BI pages for chain status, vendor rate, SLA and ageing read SQL exports, so they check presentation, not independent logic.
- Power BI and the loader use local `C:\Projects\...` paths.
- Potential-duplicate counts match planted defects, but record-by-record matching was not done.
- One open item: the £1,865 gap between recorded and rule-based rebate is not split by cause.

## Setup and reproduction (Windows)

1. Install Python 3.13 and MySQL 8.0 (server and Workbench). Excel and Power BI Desktop are needed for those parts.
2. In PowerShell, from the project folder:
   ```
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   python -m pip install -r requirements.txt
   ```
   Note: `pandas` is pinned to 2.2.3 because newer builds were blocked by Windows Smart App Control on the author's PC.
3. Generate the data: `python src\generate_data.py` (writes 12 CSVs to `data\raw`).
4. In MySQL Workbench, run the four files in `sql\01_schema` in order.
5. Load the data: `python src\load_to_mysql.py` (the password is typed when asked and never stored).
6. Run the SQL in `sql\03_quality_checks`, `04_reconciliation` and `05_kpis`.
7. Open the Excel workbook, the notebooks and the Power BI file. Refresh and point the file paths to your own folder if it differs.

## Project structure

```
config/      settings (seed, rates, thresholds, defect rates)
data/        raw (generated CSVs), processed, exports (SQL results)
docs/        charter, data dictionary, business rules, decision log, testing checklist, diagrams
excel/       reconciliation workbook
notebooks/   profiling and analysis
powerbi/     dashboard
reports/     findings and executive summary
screenshots/ dashboard, Excel and Python images
sql/         schema, checks, reconciliation, KPIs
src/         data generator and MySQL loader
```