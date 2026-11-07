-- Quality checks 2: duplicates and broken links
-- Answers Q4 and Q5. Mirrors the Python profiling checks.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

-- Check 6: duplicate property_ref in installations
-- (rows involved, and extra copies)
SELECT
  COUNT(*)            AS rows_involved,
  COUNT(*) - COUNT(DISTINCT property_ref) AS extra_copies
FROM installation_transaction
WHERE property_ref IN (
  SELECT property_ref FROM installation_transaction
  GROUP BY property_ref HAVING COUNT(*) > 1
);

-- Check 7: installation appearing on more than one PO line
SELECT
  COUNT(*)            AS rows_involved,
  COUNT(*) - COUNT(DISTINCT transaction_id) AS extra_copies
FROM po_line
WHERE transaction_id IN (
  SELECT transaction_id FROM po_line
  GROUP BY transaction_id HAVING COUNT(*) > 1
);

-- Check 8: confirmed duplicate invoices (same vendor + same reference)
SELECT
  COUNT(*)            AS rows_involved,
  COUNT(*) - COUNT(DISTINCT vendor_id, invoice_reference) AS extra_copies
FROM invoice_header
WHERE (vendor_id, invoice_reference) IN (
  SELECT vendor_id, invoice_reference FROM invoice_header
  GROUP BY vendor_id, invoice_reference HAVING COUNT(*) > 1
);

-- Check 9: confirmed duplicate payments (same vendor + same reference)
SELECT
  COUNT(*)            AS rows_involved,
  COUNT(*) - COUNT(DISTINCT vendor_id, payment_reference) AS extra_copies
FROM payment
WHERE (vendor_id, payment_reference) IN (
  SELECT vendor_id, payment_reference FROM payment
  GROUP BY vendor_id, payment_reference HAVING COUNT(*) > 1
);

-- Check 10: broken links (orphans). LEFT JOIN keeps every child row;
-- a NULL on the parent side means the parent was not found.
SELECT
  (SELECT COUNT(*)
     FROM invoice_line il
     LEFT JOIN po_line pl ON pl.po_line_id = il.po_line_id
    WHERE il.po_line_id IS NOT NULL AND pl.po_line_id IS NULL) AS invoice_line_no_po_line,
  (SELECT COUNT(*)
     FROM payment_allocation pa
     LEFT JOIN invoice_header ih ON ih.invoice_id = pa.invoice_id
    WHERE pa.invoice_id IS NOT NULL AND ih.invoice_id IS NULL) AS allocation_no_invoice,
  (SELECT COUNT(*)
     FROM invoice_header
    WHERE po_id IS NULL) AS invoice_without_po_number;