-- Invoice ageing of outstanding balances (K5, K6)
-- Answers Q8.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

WITH params AS (
  SELECT
    MAX(CASE WHEN rule_name = 'REPORTING_DATE'     THEN CAST(rule_value AS DATE) END)     AS rep_date,
    MAX(CASE WHEN rule_name = 'PAYMENT_TERMS_DAYS' THEN CAST(rule_value AS UNSIGNED) END) AS terms_days
  FROM business_rules
),
inv AS (
  SELECT ih.invoice_id, ih.invoice_date, SUM(il.invoice_line_value) AS invoiced
  FROM invoice_header ih
  JOIN invoice_line il ON il.invoice_id = ih.invoice_id
  WHERE ih.invoice_status IN ('Approved', 'Submitted')
  GROUP BY ih.invoice_id, ih.invoice_date
),
paid AS (
  SELECT pa.invoice_id, SUM(pa.allocation_amount) AS paid
  FROM payment_allocation pa
  JOIN payment p ON p.payment_id = pa.payment_id
  WHERE p.payment_status = 'Completed'
  GROUP BY pa.invoice_id
),
bal AS (
  SELECT inv.invoice_id,
         inv.invoiced - COALESCE(paid.paid, 0) AS balance,
         DATEDIFF(p.rep_date, DATE_ADD(inv.invoice_date, INTERVAL p.terms_days DAY)) AS days_past_due
  FROM inv
  LEFT JOIN paid ON paid.invoice_id = inv.invoice_id
  CROSS JOIN params p
  WHERE inv.invoice_date IS NOT NULL
)
SELECT
  CASE WHEN days_past_due <= 0  THEN '1. Not yet due'
       WHEN days_past_due <= 30 THEN '2. 1-30 days overdue'
       WHEN days_past_due <= 60 THEN '3. 31-60 days overdue'
       WHEN days_past_due <= 90 THEN '4. 61-90 days overdue'
       ELSE '5. Over 90 days overdue' END AS ageing_bucket,
  COUNT(*)                  AS invoices,
  ROUND(SUM(balance), 2)    AS outstanding_gbp
FROM bal
WHERE balance > 0
GROUP BY ageing_bucket
ORDER BY ageing_bucket;