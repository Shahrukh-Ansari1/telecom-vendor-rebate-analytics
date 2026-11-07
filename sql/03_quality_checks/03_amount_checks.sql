-- Quality checks 3: amount checks
-- Answers Q1, Q2, Q3.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

-- Check 11: recorded rebate vs the business rule
-- The rates come from business_rules, not typed into the query.
SELECT COUNT(*) AS wrong_rebate
FROM installation_transaction t
CROSS JOIN (
  SELECT
    MAX(CASE WHEN rule_name = 'REBATE_PER_FLAT'  THEN CAST(rule_value AS DECIMAL(10,2)) END) AS flat_rate,
    MAX(CASE WHEN rule_name = 'REBATE_PER_HOUSE' THEN CAST(rule_value AS DECIMAL(10,2)) END) AS house_rate
  FROM business_rules
) r
WHERE BINARY t.property_type IN ('Flat', 'House')
  AND t.expected_rebate_recorded <>
      CASE WHEN t.is_eligible = 0 THEN 0
           WHEN t.property_type = 'Flat' THEN r.flat_rate
           ELSE r.house_rate END;

-- Check 12: PO line value vs the rule's rebate
SELECT COUNT(*) AS po_differs_from_rule
FROM po_line pl
JOIN installation_transaction t ON t.transaction_id = pl.transaction_id
CROSS JOIN (
  SELECT
    MAX(CASE WHEN rule_name = 'REBATE_PER_FLAT'  THEN CAST(rule_value AS DECIMAL(10,2)) END) AS flat_rate,
    MAX(CASE WHEN rule_name = 'REBATE_PER_HOUSE' THEN CAST(rule_value AS DECIMAL(10,2)) END) AS house_rate
  FROM business_rules
) r
WHERE BINARY t.property_type IN ('Flat', 'House')
  AND pl.po_line_value <>
      CASE WHEN t.is_eligible = 0 THEN 0
           WHEN t.property_type = 'Flat' THEN r.flat_rate
           ELSE r.house_rate END;

-- Check 13: invoice line value vs its PO line value
-- Only lines that do link to a PO line (broken links were counted in Check 10)
SELECT COUNT(*) AS invoice_differs_from_po
FROM invoice_line il
JOIN po_line pl ON pl.po_line_id = il.po_line_id
WHERE il.invoice_line_value <> pl.po_line_value;

-- Check 14: eligible but not Completed
SELECT COUNT(*) AS eligible_not_completed
FROM installation_transaction
WHERE is_eligible = 1 AND completion_status <> 'Completed';