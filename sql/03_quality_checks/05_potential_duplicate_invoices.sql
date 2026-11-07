-- Potential duplicate invoices
-- Answers Q5. Business rule: same vendor, same invoice total, dates within 7 days,
-- different references. Needs human review.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

WITH inv_total AS (
  -- Step 1: one row per invoice with its total (sum the lines BEFORE comparing)
  SELECT ih.invoice_id, ih.vendor_id, ih.invoice_reference, ih.po_id,
         ih.invoice_date, ih.replaces_invoice_id,
         SUM(il.invoice_line_value) AS invoice_total
  FROM invoice_header ih
  JOIN invoice_line il ON il.invoice_id = ih.invoice_id
  WHERE ih.invoice_date IS NOT NULL
    AND ih.invoice_status <> 'Rejected'
  GROUP BY ih.invoice_id, ih.vendor_id, ih.invoice_reference, ih.po_id,
           ih.invoice_date, ih.replaces_invoice_id
),
pairs AS (
  -- Step 2: compare each invoice with every later invoice of the same vendor
  SELECT a.invoice_id AS first_invoice,
         b.invoice_id AS second_invoice,
         (a.po_id = b.po_id) AS same_po
  FROM inv_total a
  JOIN inv_total b
    ON  a.vendor_id = b.vendor_id
    AND a.invoice_total = b.invoice_total
    AND a.invoice_id < b.invoice_id
    AND a.invoice_reference <> b.invoice_reference
    AND ABS(DATEDIFF(a.invoice_date, b.invoice_date)) <= 7
    AND COALESCE(b.replaces_invoice_id, '') <> a.invoice_id
    AND COALESCE(a.replaces_invoice_id, '') <> b.invoice_id
)
SELECT COUNT(*)     AS pairs_by_business_rule,
       SUM(same_po) AS pairs_also_same_po
FROM pairs;