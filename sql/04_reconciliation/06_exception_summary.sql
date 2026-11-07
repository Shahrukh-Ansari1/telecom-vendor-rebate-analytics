-- Exception summary (K7): count and absolute pound exposure per category
-- Answers Q6 and Q12. Exposure is potential financial impact, not confirmed loss.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

SELECT stage, category, records, exposure_gbp
FROM (
  -- Stage A: installation to PO to invoice (one row per installation)
  SELECT 'A. Installation to invoice' AS stage,
         chain_status                 AS category,
         COUNT(*)                     AS records,
         ROUND(SUM(
           CASE
             WHEN chain_status LIKE '1.%' THEN COALESCE(po_value, 0)
             WHEN chain_status LIKE '2.%' THEN expected_rebate
             WHEN chain_status LIKE '3.%' THEN expected_rebate
             WHEN chain_status LIKE '4.%' THEN ABS(po_value - expected_rebate)
             WHEN chain_status LIKE '5.%' THEN po_value
             WHEN chain_status LIKE '6.%' THEN ABS(invoiced_value - po_value)
           END), 2)                   AS exposure_gbp
  FROM v_installation_chain
  WHERE chain_status NOT LIKE '0.%'
    AND chain_status NOT LIKE '7.%'
  GROUP BY chain_status

  UNION ALL

  -- Stage B: invoice to payment (one row per invoice)
  SELECT 'B. Invoice to payment',
         payment_status,
         COUNT(*),
         ROUND(SUM(ABS(invoiced - paid)), 2)
  FROM v_invoice_payment_status
  WHERE payment_status LIKE '3.%'
     OR payment_status LIKE '6.%'
     OR payment_status LIKE '8.%'
  GROUP BY payment_status
) x
ORDER BY exposure_gbp DESC;