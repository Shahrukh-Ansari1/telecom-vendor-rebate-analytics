"""
Project settings for the synthetic data generator.

DISCLAIMER: This project is an independent telecom operations analytics
case study developed using synthetic data and illustrative business rules.
It is not an official BT project and does not contain BT operational or
confidential data.
"""

from datetime import date
from pathlib import Path

# ---------------------------------------------------------------
# Paths (built from this file's location, so they work anywhere)
# ---------------------------------------------------------------
PROJECT_ROOT = Path(__file__).resolve().parent.parent
RAW_DATA_DIR = PROJECT_ROOT / "data" / "raw"

# ---------------------------------------------------------------
# Reproducibility: the same seed always gives the same data
# ---------------------------------------------------------------
RANDOM_SEED = 42

# ---------------------------------------------------------------
# Data volume
# ---------------------------------------------------------------
NUM_VENDORS = 35
NUM_INSTALLATIONS = 6000

# Installations happen between these dates
START_DATE = date(2025, 10, 1)
END_DATE = date(2026, 8, 31)

# One fixed snapshot date used in every tool (BR06)
REPORTING_DATE = date(2026, 9, 30)

# ---------------------------------------------------------------
# Business rules (must match docs/03_business_rules.md)
# ---------------------------------------------------------------
REBATE_PER_FLAT = 60.00      # BR01
REBATE_PER_HOUSE = 90.00     # BR02
PAYMENT_TERMS_DAYS = 30      # BR03
MIN_VENDOR_TRANSACTIONS = 30  # BR04
TIME_BASIS = "CALENDAR"      # BR05
AMOUNT_TOLERANCE = 0.00      # BR11

# SLA thresholds in calendar days (BR07 to BR10)
SLA_DAYS = {
    "installation_to_rebate": 2,
    "po_to_invoice": 14,
    "invoice_review": 5,
    "approval_to_payment": 10,
}

# ---------------------------------------------------------------
# Mix of the data
# ---------------------------------------------------------------
PROPERTY_MIX = {"Flat": 0.60, "House": 0.40}
COMPLETION_MIX = {"Completed": 0.90, "Failed": 0.06, "Cancelled": 0.04}
VENDOR_CATEGORY_MIX = {"Large": 0.20, "Medium": 0.40, "Small": 0.40}

REGIONS = [
    "London", "South East", "South West", "East of England",
    "West Midlands", "East Midlands", "North West", "North East",
    "Yorkshire", "Scotland", "Wales",
]

# ---------------------------------------------------------------
# Defect and exception rates (share of records affected)
# ---------------------------------------------------------------
DEFECT_RATES = {
    # installations
    "wrong_rebate": 0.02,
    "missing_vendor": 0.004,
    "missing_project": 0.004,
    "invalid_property_type": 0.004,
    "missing_install_date": 0.003,
    "future_install_date": 0.003,
    "missing_ineligible_reason": 0.01,
    "eligible_not_completed": 0.004,
    "duplicate_installation": 0.005,
    # purchase orders
    "no_po_line": 0.015,
    "cancelled_po": 0.01,
    "po_value_mismatch": 0.025,
    "duplicate_po_line": 0.005,
    # invoices
    "rejected_invoice": 0.07,
    "invoice_missing_po": 0.01,
    "invoice_amount_mismatch": 0.03,
    "invoice_unmatched_line": 0.01,
    "dup_invoice_confirmed": 0.01,
    "dup_invoice_potential": 0.008,
    "missing_invoice_date": 0.003,
    "invoice_before_po": 0.005,
    "negative_invoice_line": 0.003,
    # payments
    "never_paid": 0.04,
    "partial_payment": 0.08,
    "batched_payment": 0.25,
    "dup_payment_confirmed": 0.006,
    "dup_payment_potential": 0.006,
    "payment_amount_mismatch": 0.01,
    "overpayment": 0.01,
    "orphan_allocation": 0.005,
    "negative_allocation": 0.003,
    # workflow events
    "invalid_transition": 0.002,
}