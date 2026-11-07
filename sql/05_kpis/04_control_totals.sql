-- Control totals: the reference numbers other tools must match
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

SELECT 'K1 Recorded rebate, all installations (GBP)' AS measure,
       ROUND(SUM(expected_rebate_recorded), 2) AS value FROM installation_transaction
UNION ALL SELECT 'K1 Rule-based expected rebate (GBP)',
       ROUND(SUM(expected_rebate), 2) FROM v_installation_chain
UNION ALL SELECT 'K2 PO line value, all POs (GBP)',
       ROUND(SUM(po_line_value), 2) FROM po_line
UNION ALL SELECT 'K3 Invoiced value, Rejected excluded (GBP)',
       ROUND(SUM(invoiced), 2) FROM v_invoice_payment_status WHERE invoice_status <> 'Rejected'
UNION ALL SELECT 'K4 Paid value, completed payments (GBP)',
       ROUND(SUM(paid), 2) FROM v_invoice_payment_status
UNION ALL SELECT 'K5 Outstanding, Approved + Submitted (GBP)',
       ROUND(SUM(CASE WHEN invoiced - paid > 0 THEN invoiced - paid ELSE 0 END), 2)
       FROM v_invoice_payment_status WHERE invoice_status IN ('Approved','Submitted')
UNION ALL SELECT 'Overpaid, Approved + Submitted (GBP)',
       ROUND(SUM(CASE WHEN invoiced - paid < 0 THEN paid - invoiced ELSE 0 END), 2)
       FROM v_invoice_payment_status WHERE invoice_status IN ('Approved','Submitted')
UNION ALL SELECT 'Installations (count)', COUNT(*) FROM installation_transaction
UNION ALL SELECT 'PO headers (count)', COUNT(*) FROM po_header
UNION ALL SELECT 'Invoices (count)', COUNT(*) FROM invoice_header
UNION ALL SELECT 'Payments (count)', COUNT(*) FROM payment
UNION ALL SELECT 'Billing-chain exceptions (count)',
       COUNT(*) FROM v_installation_chain
       WHERE chain_status NOT LIKE '0.%' AND chain_status NOT LIKE '7.%';