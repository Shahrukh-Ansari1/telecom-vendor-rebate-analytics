-- Potential duplicate payments
-- Answers Q5. Two versions of the rule are shown so the false-alarm effect is visible.
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

-- Version A (loose): same vendor, same amount, within 3 days, different reference
SELECT COUNT(*) AS loose_rule_pairs
FROM payment a
JOIN payment b
  ON  a.vendor_id = b.vendor_id
  AND a.payment_amount = b.payment_amount
  AND a.payment_id < b.payment_id
  AND a.payment_reference <> b.payment_reference
  AND ABS(DATEDIFF(a.payment_date, b.payment_date)) <= 3
WHERE a.payment_status = 'Completed'
  AND b.payment_status = 'Completed';

-- Version B (tight): Version A, and both payments are allocated to the same invoice
SELECT COUNT(*) AS tight_rule_pairs
FROM (
  SELECT DISTINCT a.payment_id AS first_payment, b.payment_id AS second_payment
  FROM payment a
  JOIN payment b
    ON  a.vendor_id = b.vendor_id
    AND a.payment_amount = b.payment_amount
    AND a.payment_id < b.payment_id
    AND a.payment_reference <> b.payment_reference
    AND ABS(DATEDIFF(a.payment_date, b.payment_date)) <= 3
  JOIN payment_allocation x ON x.payment_id = a.payment_id
  JOIN payment_allocation y ON y.payment_id = b.payment_id
                           AND y.invoice_id = x.invoice_id
  WHERE a.payment_status = 'Completed'
    AND b.payment_status = 'Completed'
) t;