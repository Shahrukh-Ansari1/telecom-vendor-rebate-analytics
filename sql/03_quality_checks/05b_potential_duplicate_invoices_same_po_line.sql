-- Potential duplicate invoices, review rule: two non-rejected invoices with different
-- references that bill the same PO line. Answers Q5. Needs human review.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

SELECT
  il1.invoice_id AS first_invoice,
  il2.invoice_id AS second_invoice,
  COUNT(*)       AS shared_po_lines
FROM invoice_line il1
JOIN invoice_line il2
  ON  il1.po_line_id = il2.po_line_id
  AND il1.invoice_id < il2.invoice_id
JOIN invoice_header h1 ON h1.invoice_id = il1.invoice_id
JOIN invoice_header h2 ON h2.invoice_id = il2.invoice_id
WHERE h1.invoice_status <> 'Rejected'
  AND h2.invoice_status <> 'Rejected'
  AND h1.invoice_reference <> h2.invoice_reference
  AND COALESCE(h2.replaces_invoice_id, '') <> h1.invoice_id
GROUP BY il1.invoice_id, il2.invoice_id
ORDER BY shared_po_lines DESC;