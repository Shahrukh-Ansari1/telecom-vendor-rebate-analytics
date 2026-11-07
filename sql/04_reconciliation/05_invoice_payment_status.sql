-- Invoice to payment reconciliation, part 2: one status per invoice
-- Answers Q3, Q6, Q7.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

CREATE OR REPLACE VIEW v_invoice_payment_status AS
WITH tol AS (
  SELECT MAX(CASE WHEN rule_name = 'AMOUNT_TOLERANCE' THEN CAST(rule_value AS DECIMAL(10,2)) END) AS tol
  FROM business_rules
),
inv AS (
  -- one row per invoice (sum lines first)
  SELECT ih.invoice_id, ih.vendor_id, ih.invoice_status, ih.invoice_date,
         SUM(il.invoice_line_value) AS invoiced
  FROM invoice_header ih
  JOIN invoice_line il ON il.invoice_id = ih.invoice_id
  GROUP BY ih.invoice_id, ih.vendor_id, ih.invoice_status, ih.invoice_date
),
pay AS (
  -- one row per invoice (sum allocations first, split by payment status)
  SELECT pa.invoice_id,
         SUM(CASE WHEN p.payment_status = 'Completed' THEN pa.allocation_amount ELSE 0 END) AS paid,
         SUM(CASE WHEN p.payment_status = 'Pending'   THEN pa.allocation_amount ELSE 0 END) AS pending
  FROM payment_allocation pa
  JOIN payment p ON p.payment_id = pa.payment_id
  GROUP BY pa.invoice_id
)
SELECT inv.invoice_id, inv.vendor_id, inv.invoice_status, inv.invoice_date,
       inv.invoiced,
       COALESCE(pay.paid, 0)    AS paid,
       COALESCE(pay.pending, 0) AS pending,
       CASE
         WHEN inv.invoice_status = 'Rejected' AND COALESCE(pay.paid, 0) > 0 THEN '1. Rejected but paid'
         WHEN inv.invoice_status = 'Rejected'                               THEN '0. Rejected (not payable)'
         WHEN inv.invoice_status = 'Submitted' AND COALESCE(pay.paid, 0) > 0 THEN '2. Paid before approval'
         WHEN inv.invoice_status = 'Submitted'                              THEN '0. Awaiting review'
         WHEN inv.invoiced <= 0                                             THEN '3. Invoice total not positive'
         WHEN COALESCE(pay.paid, 0) = 0 AND COALESCE(pay.pending, 0) > 0    THEN '4. Payment pending'
         WHEN COALESCE(pay.paid, 0) = 0                                     THEN '5. Unpaid'
         WHEN pay.paid < inv.invoiced - t.tol                               THEN '6. Part paid'
         WHEN pay.paid > inv.invoiced + t.tol                               THEN '8. Overpaid'
         ELSE '7. Fully paid'
       END AS payment_status
FROM inv
CROSS JOIN tol t
LEFT JOIN pay ON pay.invoice_id = inv.invoice_id;

-- Summary
SELECT payment_status,
       COUNT(*)                        AS invoices,
       ROUND(SUM(invoiced), 2)         AS invoiced_gbp,
       ROUND(SUM(paid), 2)             AS paid_gbp,
       ROUND(SUM(invoiced - paid), 2)  AS difference_gbp
FROM v_invoice_payment_status
GROUP BY payment_status
ORDER BY payment_status;