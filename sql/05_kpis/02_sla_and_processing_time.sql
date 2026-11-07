-- SLA compliance (K8) and processing time (K10) by workflow stage
-- Answers Q9 and Q11. Calendar days. Thresholds come from business_rules.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

WITH dur AS (
  -- Stage 1: installation recorded -> rebate calculated
  SELECT '1. Installation to rebate' AS stage,
         DATEDIFF(c.event_timestamp, r.event_timestamp) AS elapsed_days,
         (SELECT CAST(rule_value AS UNSIGNED) FROM business_rules WHERE rule_name = 'SLA_INSTALLATION_TO_REBATE') AS sla_days
  FROM workflow_event r
  JOIN workflow_event c
    ON  c.entity_type = 'Installation' AND c.entity_id = r.entity_id
    AND c.to_status = 'Rebate Calculated'
  WHERE r.entity_type = 'Installation' AND r.to_status = 'Recorded'

  UNION ALL

  -- Stage 2: PO created -> first invoice submitted on that PO
  SELECT '2. PO to invoice',
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

  -- Stage 3: invoice submitted -> approved or rejected
  SELECT '3. Invoice review',
         DATEDIFF(d.event_timestamp, s.event_timestamp),
         (SELECT CAST(rule_value AS UNSIGNED) FROM business_rules WHERE rule_name = 'SLA_INVOICE_REVIEW')
  FROM workflow_event s
  JOIN workflow_event d
    ON  d.entity_type = 'Invoice' AND d.entity_id = s.entity_id
    AND d.to_status IN ('Approved', 'Rejected')
  WHERE s.entity_type = 'Invoice' AND s.to_status = 'Submitted'

  UNION ALL

  -- Stage 4: invoice approved -> first completed payment
  SELECT '4. Approval to payment',
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
),
ranked AS (
  -- Number the valid rows (and the negative rows separately) so we can find the median
  SELECT stage, elapsed_days, sla_days,
         ROW_NUMBER() OVER (PARTITION BY stage, (elapsed_days < 0) ORDER BY elapsed_days) AS rn,
         COUNT(*)     OVER (PARTITION BY stage, (elapsed_days < 0))                       AS grp_count
  FROM dur
)
SELECT stage,
       MAX(sla_days)                                                       AS sla_days,
       SUM(elapsed_days >= 0)                                              AS items_measured,
       ROUND(AVG(CASE WHEN elapsed_days >= 0 THEN elapsed_days END), 2)    AS avg_days,
       AVG(CASE WHEN elapsed_days >= 0
                 AND rn IN (FLOOR((grp_count + 1) / 2), CEIL((grp_count + 1) / 2))
                THEN elapsed_days END)                                     AS median_days,
       MAX(CASE WHEN elapsed_days >= 0 THEN elapsed_days END)              AS max_days,
       SUM(elapsed_days >= 0 AND elapsed_days <= sla_days)                 AS on_time,
       ROUND(100 * SUM(elapsed_days >= 0 AND elapsed_days <= sla_days)
                 / SUM(elapsed_days >= 0), 2)                              AS sla_compliance_pct,
       SUM(elapsed_days < 0)                                               AS excluded_negative
FROM ranked
GROUP BY stage
ORDER BY stage;