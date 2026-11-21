-- Why do 134 installations have an invoice that differs from the PO?
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

SELECT cause,
       COUNT(*)                                        AS installations,
       ROUND(SUM(invoiced_value - po_value), 2)        AS net_difference_gbp
FROM (
  SELECT v.transaction_id, v.po_value, v.invoiced_value,
         CASE WHEN x.billed_times > 1 THEN 'Billed more than once'
              WHEN x.has_negative = 1 THEN 'Negative invoice line'
              ELSE 'Billed once, different value' END AS cause
  FROM v_installation_chain v
  JOIN (
    SELECT pl.transaction_id,
           COUNT(*)                      AS billed_times,
           MAX(il.invoice_line_value < 0) AS has_negative
    FROM po_line pl
    JOIN invoice_line il   ON il.po_line_id = pl.po_line_id
    JOIN invoice_header ih ON ih.invoice_id = il.invoice_id
    WHERE ih.invoice_status IN ('Approved', 'Submitted')
    GROUP BY pl.transaction_id
  ) x ON x.transaction_id = v.transaction_id
  WHERE v.chain_status = '6. Invoice differs from PO'
) t
GROUP BY cause
ORDER BY installations DESC;