-- SLA compliance by month and stage (K8 trend)
-- Answers Q11. Month = month the stage was completed. Calendar days.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

WITH dur AS (
  SELECT 1 AS stage_no,
         DATE_FORMAT(c.event_timestamp, '%Y-%m') AS period_month,
         DATEDIFF(c.event_timestamp, r.event_timestamp) AS elapsed_days,
         (SELECT CAST(rule_value AS UNSIGNED) FROM business_rules WHERE rule_name = 'SLA_INSTALLATION_TO_REBATE') AS sla_days
  FROM workflow_event r
  JOIN workflow_event c
    ON  c.entity_type = 'Installation' AND c.entity_id = r.entity_id
    AND c.to_status = 'Rebate Calculated'
  WHERE r.entity_type = 'Installation' AND r.to_status = 'Recorded'

  UNION ALL

  SELECT 2,
         DATE_FORMAT(f.first_submitted, '%Y-%m'),
         DATEDIFF(f.first_submitted, p.event_timestamp),
         (SELECT CAST(rule_value AS UNSIGNED) FROM business_rules WHERE rule_name = 'SLA_PO_TO_INVOICE')
  FROM workflow_event p
  JOIN (
    SELECT ih.po_id, MIN(e.event_timestamp) AS first_submitted
    FROM invoice_header ih
    JOIN workflow_event e
      ON e.entity_type = 'Invoice' AND e.entity_id = ih.invoice_id AND e.to_status = 'Submitted'
    WHERE ih.po_id IS NOT NULL
    GROUP BY ih.po_id
  ) f ON f.po_id = p.entity_id
  WHERE p.entity_type = 'PO' AND p.to_status = 'Created'

  UNION ALL

  SELECT 3,
         DATE_FORMAT(d.event_timestamp, '%Y-%m'),
         DATEDIFF(d.event_timestamp, s.event_timestamp),
         (SELECT CAST(rule_value AS UNSIGNED) FROM business_rules WHERE rule_name = 'SLA_INVOICE_REVIEW')
  FROM workflow_event s
  JOIN workflow_event d
    ON  d.entity_type = 'Invoice' AND d.entity_id = s.entity_id
    AND d.to_status IN ('Approved', 'Rejected')
  WHERE s.entity_type = 'Invoice' AND s.to_status = 'Submitted'

  UNION ALL

  SELECT 4,
         DATE_FORMAT(fp.first_paid, '%Y-%m'),
         DATEDIFF(fp.first_paid, a.event_timestamp),
         (SELECT CAST(rule_value AS UNSIGNED) FROM business_rules WHERE rule_name = 'SLA_APPROVAL_TO_PAYMENT')
  FROM workflow_event a
  JOIN (
    SELECT pa.invoice_id, MIN(e.event_timestamp) AS first_paid
    FROM payment_allocation pa
    JOIN workflow_event e
      ON e.entity_type = 'Payment' AND e.entity_id = pa.payment_id AND e.to_status = 'Completed'
    GROUP BY pa.invoice_id
  ) fp ON fp.invoice_id = a.entity_id
  WHERE a.entity_type = 'Invoice' AND a.to_status = 'Approved'
)
SELECT period_month,
  SUM(stage_no = 1 AND elapsed_days >= 0) AS s1_items,
  ROUND(100 * SUM(stage_no = 1 AND elapsed_days >= 0 AND elapsed_days <= sla_days)
            / NULLIF(SUM(stage_no = 1 AND elapsed_days >= 0), 0), 1) AS s1_pct,
  SUM(stage_no = 2 AND elapsed_days >= 0) AS s2_items,
  ROUND(100 * SUM(stage_no = 2 AND elapsed_days >= 0 AND elapsed_days <= sla_days)
            / NULLIF(SUM(stage_no = 2 AND elapsed_days >= 0), 0), 1) AS s2_pct,
  SUM(stage_no = 3 AND elapsed_days >= 0) AS s3_items,
  ROUND(100 * SUM(stage_no = 3 AND elapsed_days >= 0 AND elapsed_days <= sla_days)
            / NULLIF(SUM(stage_no = 3 AND elapsed_days >= 0), 0), 1) AS s3_pct,
  SUM(stage_no = 4 AND elapsed_days >= 0) AS s4_items,
  ROUND(100 * SUM(stage_no = 4 AND elapsed_days >= 0 AND elapsed_days <= sla_days)
            / NULLIF(SUM(stage_no = 4 AND elapsed_days >= 0), 0), 1) AS s4_pct
FROM dur
GROUP BY period_month
ORDER BY period_month;