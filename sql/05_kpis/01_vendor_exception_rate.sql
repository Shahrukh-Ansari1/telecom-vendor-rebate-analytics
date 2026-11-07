-- Vendor exception rate (K9), adjusted for volume
-- Answers Q10. Billing-chain exceptions only (chain status 1 to 6).
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

SELECT vendor_id, vendor_name, vendor_category,
       txn_count, exception_count, exception_rate_pct, volume_flag,
       CASE WHEN volume_flag = 'Ranked'
            THEN RANK() OVER (PARTITION BY volume_flag ORDER BY exception_rate_pct DESC)
       END AS rank_no
FROM (
  SELECT COALESCE(c.vendor_id, 'Unassigned')    AS vendor_id,
         COALESCE(d.vendor_name, '(no vendor)') AS vendor_name,
         d.vendor_category,
         COUNT(*)                               AS txn_count,
         SUM(c.chain_status NOT LIKE '0.%' AND c.chain_status NOT LIKE '7.%') AS exception_count,
         ROUND(100 * SUM(c.chain_status NOT LIKE '0.%' AND c.chain_status NOT LIKE '7.%') / COUNT(*), 2) AS exception_rate_pct,
         CASE WHEN c.vendor_id IS NULL        THEN 'Unassigned'
              WHEN COUNT(*) < m.min_txn       THEN 'Low volume'
              ELSE 'Ranked' END               AS volume_flag
  FROM v_installation_chain c
  LEFT JOIN dim_vendor d ON d.vendor_id = c.vendor_id
  CROSS JOIN (
    SELECT CAST(rule_value AS UNSIGNED) AS min_txn
    FROM business_rules WHERE rule_name = 'MIN_VENDOR_TRANSACTIONS'
  ) m
  GROUP BY c.vendor_id, d.vendor_name, d.vendor_category, m.min_txn
) v
ORDER BY (volume_flag = 'Ranked') DESC, exception_rate_pct DESC;