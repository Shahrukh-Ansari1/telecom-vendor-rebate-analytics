USE telecom_rebate;

WITH dur AS (
  SELECT DATEDIFF(c.event_timestamp, r.event_timestamp) AS d
  FROM workflow_event r
  JOIN workflow_event c
    ON c.entity_type = 'Installation' AND c.entity_id = r.entity_id
   AND c.to_status = 'Rebate Calculated'
  WHERE r.entity_type = 'Installation' AND r.to_status = 'Recorded'
)
SELECT t.threshold_days,
       ROUND(100 * SUM(d <= t.threshold_days) / COUNT(*), 2) AS compliance_pct
FROM dur
CROSS JOIN (SELECT 1 AS threshold_days UNION ALL SELECT 2
            UNION ALL SELECT 3 UNION ALL SELECT 4) t
GROUP BY t.threshold_days
ORDER BY t.threshold_days;