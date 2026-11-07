-- Tables part 2: purchase orders and invoices
-- DISCLAIMER: Independent case study using synthetic data. Not an official BT project.

USE telecom_rebate;

CREATE TABLE IF NOT EXISTS po_header (
  po_id       VARCHAR(12)  NOT NULL,
  vendor_id   VARCHAR(10)  NOT NULL,
  po_date     DATE         NOT NULL,
  po_status   VARCHAR(15)  NOT NULL,
  created_by  VARCHAR(50)  NOT NULL,
  PRIMARY KEY (po_id),
  KEY ix_po_vendor (vendor_id),
  CONSTRAINT fk_po_vendor FOREIGN KEY (vendor_id) REFERENCES dim_vendor (vendor_id)
);

CREATE TABLE IF NOT EXISTS po_line (
  po_line_id     VARCHAR(14)   NOT NULL,
  po_id          VARCHAR(12)   NOT NULL,
  transaction_id VARCHAR(12)   NOT NULL,
  line_number    TINYINT       NOT NULL,
  po_line_value  DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (po_line_id),
  KEY ix_pol_po (po_id),
  KEY ix_pol_txn (transaction_id),
  CONSTRAINT fk_pol_po  FOREIGN KEY (po_id) REFERENCES po_header (po_id),
  CONSTRAINT fk_pol_txn FOREIGN KEY (transaction_id) REFERENCES installation_transaction (transaction_id)
);

CREATE TABLE IF NOT EXISTS invoice_header (
  invoice_id           VARCHAR(12) NOT NULL,
  vendor_id            VARCHAR(10) NOT NULL,
  invoice_reference    VARCHAR(20) NOT NULL,
  po_id                VARCHAR(12) NULL,
  invoice_date         DATE        NULL,
  received_date        DATE        NOT NULL,
  invoice_status       VARCHAR(15) NOT NULL,
  rejection_reason     VARCHAR(40) NULL,
  replaces_invoice_id  VARCHAR(12) NULL,
  PRIMARY KEY (invoice_id),
  KEY ix_inv_vendor (vendor_id),
  KEY ix_inv_po (po_id),
  KEY ix_inv_ref (vendor_id, invoice_reference),
  CONSTRAINT fk_inv_vendor FOREIGN KEY (vendor_id) REFERENCES dim_vendor (vendor_id)
);

CREATE TABLE IF NOT EXISTS invoice_line (
  invoice_line_id     VARCHAR(14)   NOT NULL,
  invoice_id          VARCHAR(12)   NOT NULL,
  po_line_id          VARCHAR(14)   NULL,
  line_number         TINYINT       NOT NULL,
  invoice_line_value  DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (invoice_line_id),
  KEY ix_inl_invoice (invoice_id),
  KEY ix_inl_pol (po_line_id),
  CONSTRAINT fk_inl_invoice FOREIGN KEY (invoice_id) REFERENCES invoice_header (invoice_id)
);

SHOW TABLES;