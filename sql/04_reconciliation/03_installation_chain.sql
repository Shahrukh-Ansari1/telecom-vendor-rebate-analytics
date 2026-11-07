-- Installation chain reconciliation, part 1: installation -> PO -> invoice
-- Answers Q1, Q2, Q3, Q6. One row per installation, one status per row.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

CREATE OR REPLACE VIEW v_installation_chain AS
WITH rates AS (
  SELECT
    MAX(CASE WHEN rule_name = 'REBATE_PER_FLAT'  THEN CAST(rule_value AS DECIMAL(10,2)) END) AS flat_rate,
    MAX(CASE WHEN rule_name = 'REBATE_PER_HOUSE' THEN CAST(rule_value AS DECIMAL(10,2)) END) AS house_rate,
    MAX(CASE WHEN rule_name = 'AMOUNT_TOLERANCE' THEN CAST(rule_value AS DECIMAL(10,2)) END) AS tol
  FROM business_rules
),
po AS (
  -- one row per installation (sum PO lines first)
  SELECT pl.transaction_id,
         SUM(ph.po_status = 'Cancelled') AS cancelled_lines,
         SUM(CASE WHEN ph.po_status <> 'Cancelled' THEN pl.po_line_value ELSE 0 END) AS po_value
  FROM po_line pl
  JOIN po_header ph ON ph.po_id = pl.po_id
  GROUP BY pl.transaction_id
),
inv AS (
  -- one row per installation (sum invoice lines first, Rejected excluded)
  SELECT pl.transaction_id, SUM(il.invoice_line_value) AS invoiced_value
  FROM po_line pl
  JOIN invoice_line il   ON il.po_line_id = pl.po_line_id
  JOIN invoice_header ih ON ih.invoice_id = il.invoice_id
  WHERE ih.invoice_status IN ('Approved', 'Submitted')
  GROUP BY pl.transaction_id
),
base AS (
  SELECT t.transaction_id, t.vendor_id, t.is_eligible,
         CASE WHEN t.is_eligible = 0 THEN 0
              WHEN BINARY t.property_type = 'Flat'  THEN r.flat_rate
              WHEN BINARY t.property_type = 'House' THEN r.house_rate
              ELSE NULL END AS expected_rebate,
         r.tol
  FROM installation_transaction t
  CROSS JOIN rates r
)
SELECT b.transaction_id, b.vendor_id, b.expected_rebate,
       po.po_value, inv.invoiced_value,
       CASE
         WHEN b.is_eligible = 0                       THEN '0. Not eligible (no rebate)'
         WHEN b.expected_rebate IS NULL               THEN '1. Cannot calculate (invalid property type)'
         WHEN po.transaction_id IS NULL               THEN '2. No PO line'
         WHEN po.po_value = 0 AND po.cancelled_lines > 0 THEN '3. PO cancelled'
         WHEN ABS(po.po_value - b.expected_rebate) > b.tol THEN '4. PO differs from rule'
         WHEN inv.transaction_id IS NULL              THEN '5. Not invoiced'
         WHEN ABS(inv.invoiced_value - po.po_value) > b.tol THEN '6. Invoice differs from PO'
         ELSE '7. PO and invoice match'
       END AS chain_status
FROM base b
LEFT JOIN po  ON po.transaction_id  = b.transaction_id
LEFT JOIN inv ON inv.transaction_id = b.transaction_id;

-- Summary: how many installations in each status, and how much money
SELECT chain_status,
       COUNT(*)                                 AS installations,
       ROUND(SUM(COALESCE(expected_rebate, 0)), 2) AS expected_gbp,
       ROUND(SUM(COALESCE(po_value, 0)), 2)        AS po_gbp,
       ROUND(SUM(COALESCE(invoiced_value, 0)), 2)  AS invoiced_gbp
FROM v_installation_chain
GROUP BY chain_status
ORDER BY chain_status;