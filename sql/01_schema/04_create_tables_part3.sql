-- Tables part 3: payments, workflow events, defect log
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

CREATE TABLE IF NOT EXISTS payment (
  payment_id         VARCHAR(12)   NOT NULL,
  vendor_id          VARCHAR(10)   NOT NULL,
  payment_reference  VARCHAR(20)   NOT NULL,
  payment_date       DATE          NOT NULL,
  payment_amount     DECIMAL(12,2) NOT NULL,
  payment_status     VARCHAR(15)   NOT NULL,
  PRIMARY KEY (payment_id),
  KEY ix_pay_vendor (vendor_id),
  KEY ix_pay_ref (vendor_id, payment_reference),
  CONSTRAINT fk_pay_vendor FOREIGN KEY (vendor_id) REFERENCES dim_vendor (vendor_id)
);

CREATE TABLE IF NOT EXISTS payment_allocation (
  allocation_id      VARCHAR(12)   NOT NULL,
  payment_id         VARCHAR(12)   NOT NULL,
  invoice_id         VARCHAR(12)   NULL,
  allocation_amount  DECIMAL(12,2) NOT NULL,
  allocation_date    DATE          NOT NULL,
  PRIMARY KEY (allocation_id),
  KEY ix_alc_payment (payment_id),
  KEY ix_alc_invoice (invoice_id),
  CONSTRAINT fk_alc_payment FOREIGN KEY (payment_id) REFERENCES payment (payment_id)
);

CREATE TABLE IF NOT EXISTS workflow_event (
  event_id         VARCHAR(12) NOT NULL,
  entity_type      VARCHAR(15) NOT NULL,
  entity_id        VARCHAR(14) NOT NULL,
  vendor_id        VARCHAR(10) NULL,
  from_status      VARCHAR(20) NULL,
  to_status        VARCHAR(20) NOT NULL,
  event_timestamp  DATETIME    NOT NULL,
  delay_reason     VARCHAR(40) NULL,
  PRIMARY KEY (event_id),
  KEY ix_evt_entity (entity_type, entity_id),
  KEY ix_evt_vendor (vendor_id)
);

CREATE TABLE IF NOT EXISTS defect_injection_log (
  defect_id       VARCHAR(10) NOT NULL,
  table_name      VARCHAR(30) NOT NULL,
  record_id       VARCHAR(14) NOT NULL,
  defect_type     VARCHAR(50) NOT NULL,
  defect_class    VARCHAR(20) NOT NULL,
  original_value  VARCHAR(50) NULL,
  defect_value    VARCHAR(50) NULL,
  injected_rule   VARCHAR(150) NULL,
  PRIMARY KEY (defect_id),
  KEY ix_def_record (table_name, record_id)
);

SHOW TABLES;