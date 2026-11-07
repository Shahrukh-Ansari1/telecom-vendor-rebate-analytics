-- Outstanding, overdue and overpaid invoice balances (K5, K6)
-- Answers Q7 and Q8.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

WITH params AS (
  SELECT
    MAX(CASE WHEN rule_name = 'REPORTING_DATE'      THEN CAST(rule_value AS DATE) END)     AS rep_date,
    MAX(CASE WHEN rule_name = 'PAYMENT_TERMS_DAYS'  THEN CAST(rule_value AS UNSIGNED) END) AS terms_days
  FROM business_rules
),
inv AS (
  -- Step 1: one row per invoice with its total (Rejected invoices excluded)
  SELECT ih.invoice_id, ih.invoice_status, ih.invoice_date,
         SUM(il.invoice_line_value) AS invoiced
  FROM invoice_header ih
  JOIN invoice_line il ON il.invoice_id = ih.invoice_id
  WHERE ih.invoice_status IN ('Approved', 'Submitted')
  GROUP BY ih.invoice_id, ih.invoice_status, ih.invoice_date
),
paid AS (
  -- Step 2: completed payments summed per invoice BEFORE joining
  SELECT pa.invoice_id, SUM(pa.allocation_amount) AS paid
  FROM payment_allocation pa
  JOIN payment p ON p.payment_id = pa.payment_id
  WHERE p.payment_status = 'Completed'
  GROUP BY pa.invoice_id
),
bal AS (
  -- Step 3: join the two summaries and work out balance and due date
  SELECT inv.invoice_id, inv.invoice_status, inv.invoice_date, inv.invoiced,
         COALESCE(paid.paid, 0)                   AS paid,
         inv.invoiced - COALESCE(paid.paid, 0)    AS balance,
         DATE_ADD(inv.invoice_date, INTERVAL p.terms_days DAY) AS due_date,
         p.rep_date
  FROM inv
  LEFT JOIN paid ON paid.invoice_id = inv.invoice_id
  CROSS JOIN params p
)
SELECT
  invoice_status,
  COUNT(*)                                                                   AS invoices,
  ROUND(SUM(invoiced), 2)                                                    AS invoiced_gbp,
  ROUND(SUM(paid), 2)                                                        AS paid_gbp,
  ROUND(SUM(CASE WHEN balance > 0 THEN balance ELSE 0 END), 2)               AS outstanding_gbp,
  ROUND(SUM(CASE WHEN balance > 0 AND due_date < rep_date THEN balance ELSE 0 END), 2) AS overdue_gbp,
  ROUND(SUM(CASE WHEN balance < 0 THEN -balance ELSE 0 END), 2)              AS overpaid_gbp,
  SUM(balance > 0 AND invoice_date IS NULL)                                  AS outstanding_no_invoice_date
FROM bal
GROUP BY invoice_status;