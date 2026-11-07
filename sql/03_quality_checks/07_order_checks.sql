-- Order checks: status transitions and date order
-- Answers Q4.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

-- Check 15: invoice approved before it was submitted
SELECT COUNT(*) AS approved_before_submitted
FROM workflow_event sub
JOIN workflow_event app
  ON  app.entity_type = 'Invoice'
  AND app.entity_id   = sub.entity_id
  AND app.to_status   = 'Approved'
WHERE sub.entity_type = 'Invoice'
  AND sub.to_status   = 'Submitted'
  AND app.event_timestamp < sub.event_timestamp;

-- Check 16: invoice dated before its PO
SELECT COUNT(*) AS invoice_before_po
FROM invoice_header ih
JOIN po_header ph ON ph.po_id = ih.po_id
WHERE ih.invoice_date < ph.po_date;

-- Check 17: received date before invoice date
SELECT COUNT(*) AS received_before_invoice_date
FROM invoice_header
WHERE received_date < invoice_date;