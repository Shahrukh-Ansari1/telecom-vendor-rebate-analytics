-- Explain Check 13: why do invoice lines differ from their PO line?
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

SELECT
  CASE WHEN il.invoice_line_value < 0 THEN 'Negative invoice line'
       ELSE 'Positive but different value' END AS reason,
  COUNT(*)                                      AS line_count,
  ROUND(SUM(il.invoice_line_value - pl.po_line_value), 2) AS net_difference_gbp
FROM invoice_line il
JOIN po_line pl ON pl.po_line_id = il.po_line_id
WHERE il.invoice_line_value <> pl.po_line_value
GROUP BY reason;