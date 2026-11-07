-- Quality checks 1: missing and invalid values
-- Answers Q4. Mirrors the Python profiling checks.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

-- Check 1: missing mandatory fields in installations
SELECT
  SUM(vendor_id IS NULL)         AS missing_vendor,
  SUM(project_code IS NULL)      AS missing_project,
  SUM(installation_date IS NULL) AS missing_install_date
FROM installation_transaction;

-- Check 2: missing invoice date and missing PO number
SELECT
  SUM(invoice_date IS NULL) AS missing_invoice_date,
  SUM(po_id IS NULL)        AS invoice_without_po
FROM invoice_header;

-- Check 3: invalid property type (BINARY makes the comparison case-sensitive,
-- so 'house' and 'FLAT ' are caught as invalid)
SELECT property_type, COUNT(*) AS records
FROM installation_transaction
WHERE BINARY property_type NOT IN ('Flat', 'House')
   OR property_type IS NULL
GROUP BY property_type
ORDER BY records DESC;

-- Check 4: installation dates after the reporting date
SELECT COUNT(*) AS future_installations
FROM installation_transaction
WHERE installation_date > (
  SELECT CAST(rule_value AS DATE) FROM business_rules WHERE rule_name = 'REPORTING_DATE'
);

-- Check 5: negative invoice lines and zero/negative allocations
SELECT
  (SELECT COUNT(*) FROM invoice_line WHERE invoice_line_value < 0)       AS negative_invoice_lines,
  (SELECT COUNT(*) FROM payment_allocation WHERE allocation_amount <= 0) AS bad_allocations;