-- Completed allocations that point to an invoice that does not exist
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

SELECT COUNT(*)                            AS completed_orphan_allocations,
       ROUND(SUM(pa.allocation_amount), 2) AS orphan_amount_gbp
FROM payment_allocation pa
JOIN payment p ON p.payment_id = pa.payment_id
LEFT JOIN invoice_header ih ON ih.invoice_id = pa.invoice_id
WHERE p.payment_status = 'Completed'
  AND ih.invoice_id IS NULL;