-- Tables part 1: dimensions and installations
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

CREATE TABLE IF NOT EXISTS dim_vendor (
  vendor_id        VARCHAR(10)  NOT NULL,
  vendor_name      VARCHAR(100) NOT NULL,
  region           VARCHAR(30)  NOT NULL,
  vendor_category  VARCHAR(20)  NOT NULL,
  onboarding_date  DATE         NOT NULL,
  vendor_status    VARCHAR(15)  NOT NULL,
  PRIMARY KEY (vendor_id),
  UNIQUE KEY uq_vendor_name (vendor_name)
);

CREATE TABLE IF NOT EXISTS dim_date (
  date_key      INT         NOT NULL,
  full_date     DATE        NOT NULL,
  year          SMALLINT    NOT NULL,
  quarter       TINYINT     NOT NULL,
  month_number  TINYINT     NOT NULL,
  month_name    VARCHAR(10) NOT NULL,
  year_month_key CHAR(7)    NOT NULL,
  week_of_year  TINYINT     NOT NULL,
  day_of_week   VARCHAR(10) NOT NULL,
  is_weekend    TINYINT     NOT NULL,
  PRIMARY KEY (date_key),
  UNIQUE KEY uq_full_date (full_date)
);

CREATE TABLE IF NOT EXISTS business_rules (
  rule_id      VARCHAR(10)  NOT NULL,
  rule_name    VARCHAR(50)  NOT NULL,
  rule_value   VARCHAR(30)  NOT NULL,
  value_type   VARCHAR(10)  NOT NULL,
  rule_kind    VARCHAR(15)  NOT NULL,
  description  VARCHAR(200) NOT NULL,
  PRIMARY KEY (rule_id),
  UNIQUE KEY uq_rule_name (rule_name)
);

CREATE TABLE IF NOT EXISTS installation_transaction (
  transaction_id            VARCHAR(12)   NOT NULL,
  vendor_id                 VARCHAR(10)   NULL,
  project_code              VARCHAR(10)   NULL,
  property_ref              VARCHAR(20)   NOT NULL,
  property_type             VARCHAR(10)   NULL,
  installation_date         DATE          NULL,
  completion_status         VARCHAR(15)   NOT NULL,
  is_eligible               TINYINT       NOT NULL,
  ineligible_reason         VARCHAR(40)   NULL,
  expected_rebate_recorded  DECIMAL(10,2) NOT NULL,
  recorded_date             DATE          NOT NULL,
  PRIMARY KEY (transaction_id),
  KEY ix_inst_vendor (vendor_id),
  KEY ix_inst_property_ref (property_ref),
  CONSTRAINT fk_inst_vendor FOREIGN KEY (vendor_id) REFERENCES dim_vendor (vendor_id)
);

SHOW TABLES;