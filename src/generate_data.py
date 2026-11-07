"""
Synthetic data generator for the telecom vendor rebate project.

DISCLAIMER: This project is an independent telecom operations analytics
case study developed using synthetic data and illustrative business rules.
It is not an official BT project and does not contain BT operational or
confidential data.

Run:  python src\\generate_data.py
Output: 12 CSV files in data\\raw
"""

import random
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "config"))
import settings

R = settings.DEFECT_RATES
REP = settings.REPORTING_DATE
SLA = settings.SLA_DAYS

REJECT_REASONS = ["Missing documentation", "Incorrect property details", "Wrong vendor details"]
DELAY_INSTALL = ["System backlog", "Awaiting vendor reply", "Approver unavailable"]
DELAY_SUBMIT = ["Vendor billing delay", "Awaiting vendor reply"]
DELAY_REVIEW = ["Approver unavailable", "Awaiting vendor reply", "Mismatch investigation", "Missing PO"]
DELAY_PAYMENT = ["Payment run schedule", "Approver unavailable", "Bank processing"]


# =====================================================================
# SECTION 1: Helpers
# =====================================================================
def set_seeds():
    """Fix every random generator so results repeat exactly."""
    random.seed(settings.RANDOM_SEED)
    np.random.seed(settings.RANDOM_SEED)
    Faker.seed(settings.RANDOM_SEED)


def weighted_choice(mix):
    """Pick one key from a dict like {'Flat': 0.6, 'House': 0.4}."""
    return random.choices(list(mix.keys()), weights=list(mix.values()), k=1)[0]


def rule(key, text):
    """Short description of a defect rule, used in the defect log."""
    return f"{R[key]:.1%} of {text}"


class IdFactory:
    """Creates sequential IDs such as PO000001, INV000002."""

    def __init__(self):
        self.counts = {}

    def new(self, prefix, width=6):
        self.counts[prefix] = self.counts.get(prefix, 0) + 1
        return f"{prefix}{self.counts[prefix]:0{width}d}"


class DefectLog:
    """The answer key: records every defect or exception we plant."""

    COLUMNS = ["defect_id", "table_name", "record_id", "defect_type", "defect_class",
               "original_value", "defect_value", "injected_rule"]

    def __init__(self):
        self.rows = []

    @staticmethod
    def _fmt(value):
        if value is None:
            return ""
        if isinstance(value, float):
            return f"{value:.2f}"
        return str(value)

    def add(self, table_name, record_id, defect_type, defect_class, original, new, injected_rule):
        self.rows.append({
            "defect_id": f"DEF{len(self.rows) + 1:05d}",
            "table_name": table_name,
            "record_id": record_id,
            "defect_type": defect_type,
            "defect_class": defect_class,
            "original_value": self._fmt(original),
            "defect_value": self._fmt(new),
            "injected_rule": injected_rule,
        })

    def to_frame(self):
        return pd.DataFrame(self.rows, columns=self.COLUMNS)


def ts(d, hour_min=8, hour_max=17):
    """Turn a date into a datetime with a random working-hours time."""
    return datetime(d.year, d.month, d.day, random.randint(hour_min, hour_max), random.randint(0, 59), 0)


def add_event(events, ids, entity_type, entity_id, vendor_id, from_status, to_status, when, delay_reason=""):
    """Add one row to the workflow event list."""
    events.append({
        "event_id": ids.new("EVT"),
        "entity_type": entity_type,
        "entity_id": entity_id,
        "vendor_id": vendor_id,
        "from_status": from_status,
        "to_status": to_status,
        "event_timestamp": when,
        "delay_reason": delay_reason,
    })


# =====================================================================
# SECTION 2: Reference tables
# =====================================================================
def generate_vendors():
    """dim_vendor: one row per vendor."""
    fake = Faker("en_GB")
    rows = []
    used_names = set()

    for i in range(1, settings.NUM_VENDORS + 1):
        while True:
            name = f"{fake.last_name()} {random.choice(['Networks', 'Fibre', 'Installations', 'Telecom Services', 'Connect'])}"
            if name not in used_names:
                used_names.add(name)
                break

        rows.append({
            "vendor_id": f"V{i:03d}",
            "vendor_name": name,
            "region": random.choice(settings.REGIONS),
            "vendor_category": weighted_choice(settings.VENDOR_CATEGORY_MIX),
            "onboarding_date": settings.START_DATE - timedelta(days=random.randint(30, 900)),
            "vendor_status": random.choices(["Active", "Inactive", "Suspended"], weights=[0.90, 0.07, 0.03], k=1)[0],
        })
    return pd.DataFrame(rows)


def generate_dates():
    """dim_date: one row per calendar day."""
    current = date(2025, 1, 1)
    last_day = date(2026, 12, 31)
    rows = []
    while current <= last_day:
        rows.append({
            "date_key": int(current.strftime("%Y%m%d")),
            "full_date": current,
            "year": current.year,
            "quarter": (current.month - 1) // 3 + 1,
            "month_number": current.month,
            "month_name": current.strftime("%B"),
            "year_month_key": current.strftime("%Y-%m"),
            "week_of_year": current.isocalendar()[1],
            "day_of_week": current.strftime("%A"),
            "is_weekend": 1 if current.weekday() >= 5 else 0,
        })
        current += timedelta(days=1)
    return pd.DataFrame(rows)


def generate_business_rules():
    """business_rules: values come from settings.py so they never disagree."""
    rows = [
        ("BR01", "REBATE_PER_FLAT", f"{settings.REBATE_PER_FLAT:.2f}", "DECIMAL", "Business rule", "Rebate per eligible flat (GBP)"),
        ("BR02", "REBATE_PER_HOUSE", f"{settings.REBATE_PER_HOUSE:.2f}", "DECIMAL", "Business rule", "Rebate per eligible house (GBP)"),
        ("BR03", "PAYMENT_TERMS_DAYS", str(settings.PAYMENT_TERMS_DAYS), "INTEGER", "Assumption", "Days from invoice date to due date"),
        ("BR04", "MIN_VENDOR_TRANSACTIONS", str(settings.MIN_VENDOR_TRANSACTIONS), "INTEGER", "Assumption", "Minimum transactions to rank a vendor"),
        ("BR05", "TIME_BASIS", settings.TIME_BASIS, "TEXT", "Assumption", "Calendar or business days for processing time"),
        ("BR06", "REPORTING_DATE", settings.REPORTING_DATE.isoformat(), "DATE", "Assumption", "Fixed snapshot date used in all tools"),
        ("BR07", "SLA_INSTALLATION_TO_REBATE", str(SLA["installation_to_rebate"]), "INTEGER", "Assumption", "SLA days: installation recorded to rebate calculated"),
        ("BR08", "SLA_PO_TO_INVOICE", str(SLA["po_to_invoice"]), "INTEGER", "Assumption", "SLA days: PO created to invoice submitted"),
        ("BR09", "SLA_INVOICE_REVIEW", str(SLA["invoice_review"]), "INTEGER", "Assumption", "SLA days: invoice submitted to approved or rejected"),
        ("BR10", "SLA_APPROVAL_TO_PAYMENT", str(SLA["approval_to_payment"]), "INTEGER", "Assumption", "SLA days: invoice approved to payment completed"),
        ("BR11", "AMOUNT_TOLERANCE", f"{settings.AMOUNT_TOLERANCE:.2f}", "DECIMAL", "Assumption", "Allowed difference when matching amounts (GBP)"),
    ]
    columns = ["rule_id", "rule_name", "rule_value", "value_type", "rule_kind", "description"]
    return pd.DataFrame(rows, columns=columns)


# =====================================================================
# SECTION 3: Installations (clean) and their workflow events
# =====================================================================
def generate_installations(vendors):
    """installation_transaction: clean rows only. Defects come later."""
    # Large vendors do far more work than small ones. A random factor makes
    # every vendor different, and some small vendors fall under 30 installations.
    size_weight = {"Large": 12, "Medium": 3, "Small": 0.25}
    weights = [size_weight[c] * random.uniform(0.6, 1.4) for c in vendors["vendor_category"]]

    vendor_ids = vendors["vendor_id"].tolist()
    onboarding = dict(zip(vendors["vendor_id"], vendors["onboarding_date"]))
    total_days = (settings.END_DATE - settings.START_DATE).days
    rows = []

    for i in range(1, settings.NUM_INSTALLATIONS + 1):
        vendor_id = random.choices(vendor_ids, weights=weights, k=1)[0]

        install_date = settings.START_DATE + timedelta(days=random.randint(0, total_days))
        if install_date <= onboarding[vendor_id]:
            install_date = onboarding[vendor_id] + timedelta(days=1)

        property_type = weighted_choice(settings.PROPERTY_MIX)
        status = weighted_choice(settings.COMPLETION_MIX)

        if status == "Completed":
            is_eligible, reason = 1, ""
            rebate = settings.REBATE_PER_FLAT if property_type == "Flat" else settings.REBATE_PER_HOUSE
        else:
            is_eligible, reason, rebate = 0, "Not completed", 0.00

        rows.append({
            "transaction_id": f"T{i:06d}",
            "vendor_id": vendor_id,
            "project_code": f"P{random.randint(1, 8):02d}",
            "property_ref": f"PR{i:06d}",
            "property_type": property_type,
            "installation_date": install_date,
            "completion_status": status,
            "is_eligible": is_eligible,
            "ineligible_reason": reason,
            "expected_rebate_recorded": round(rebate, 2),
            "recorded_date": install_date + timedelta(days=random.randint(0, 2)),
        })
    return pd.DataFrame(rows)


def generate_installation_events(installs, ids, events):
    """Two events per installation: Recorded, then Rebate Calculated."""
    for r in installs.itertuples():
        add_event(events, ids, "Installation", r.transaction_id, r.vendor_id, "", "Recorded", ts(r.recorded_date, 8, 12))
        lag = random.choices([0, 1, 2, 3, 4], weights=[30, 30, 20, 12, 8])[0]
        delay = random.choice(DELAY_INSTALL) if lag > SLA["installation_to_rebate"] else ""
        hours = (13, 17) if lag == 0 else (8, 17)
        add_event(events, ids, "Installation", r.transaction_id, r.vendor_id, "Recorded", "Rebate Calculated",
                  ts(r.recorded_date + timedelta(days=lag), *hours), delay)


# =====================================================================
# SECTION 4: Purchase orders
# =====================================================================
def generate_purchase_orders(installs, ids, events, log):
    """po_header and po_line. Each PO line covers exactly one installation."""
    fake = Faker("en_GB")
    buyers = [fake.name() for _ in range(8)]

    eligible = installs[installs["is_eligible"] == 1].copy()

    # A small share of eligible installations never receive a PO line
    skip = np.random.rand(len(eligible)) < R["no_po_line"]
    for tid in eligible.loc[skip, "transaction_id"]:
        log.add("installation_transaction", tid, "Installation without PO line", "Business exception",
                "PO line expected", "No PO line", rule("no_po_line", "eligible installations never get a PO line"))
    eligible = eligible[~skip].sort_values(["vendor_id", "installation_date", "transaction_id"])

    po_rows, line_rows = [], []

    def flush(vendor_id, chunk):
        """Turn a group of installations into one PO with several lines."""
        po_id = ids.new("PO")
        po_date = max(c["installation_date"] for c in chunk) + timedelta(days=random.randint(1, 7))
        status = "Open"
        cancelled = random.random() < R["cancelled_po"]
        if cancelled:
            status = "Cancelled"
            log.add("po_header", po_id, "Cancelled PO", "Business exception", "Open", "Cancelled",
                    rule("cancelled_po", "POs are cancelled before invoicing"))

        po_rows.append({"po_id": po_id, "vendor_id": vendor_id, "po_date": po_date,
                        "po_status": status, "created_by": random.choice(buyers)})
        add_event(events, ids, "PO", po_id, vendor_id, "", "Created", ts(po_date))
        if cancelled:
            add_event(events, ids, "PO", po_id, vendor_id, "Created", "Cancelled",
                      ts(po_date + timedelta(days=random.randint(2, 10))))

        for n, c in enumerate(chunk, start=1):
            value = float(c["expected_rebate_recorded"])
            line_id = ids.new("POL")
            if random.random() < R["po_value_mismatch"]:
                wrong = round(max(0.0, value + random.choice([-30, -20, 10, 30, 60])), 2)
                log.add("po_line", line_id, "PO value differs from expected rebate", "Data defect",
                        value, wrong, rule("po_value_mismatch", "PO lines have a value different from the expected rebate"))
                value = wrong
            line_rows.append({"po_line_id": line_id, "po_id": po_id, "transaction_id": c["transaction_id"],
                              "line_number": n, "po_line_value": round(value, 2)})

    for vendor_id, grp in eligible.groupby("vendor_id"):
        chunk, target = [], random.randint(1, 8)
        for row in grp.to_dict("records"):
            too_long = chunk and (row["installation_date"] - chunk[0]["installation_date"]).days > 30
            if chunk and (len(chunk) >= target or too_long):
                flush(vendor_id, chunk)
                chunk, target = [], random.randint(1, 8)
            chunk.append(row)
        if chunk:
            flush(vendor_id, chunk)

    return pd.DataFrame(po_rows), pd.DataFrame(line_rows)


# =====================================================================
# SECTION 5: Invoices (including rejections, resubmissions, duplicates)
# =====================================================================
def generate_invoices(po_header, po_line, ids, events, log):
    """invoice_header and invoice_line. Returns a list of approved invoices to be paid."""
    ref_seq = {}
    inv_rows, inl_rows, payable = [], [], []
    lines_by_po = {k: g for k, g in po_line.groupby("po_id")}

    def new_reference(vendor_id, d):
        ref_seq[vendor_id] = ref_seq.get(vendor_id, 0) + 1
        return f"{vendor_id}-{d.year}-{ref_seq[vendor_id]:05d}"

    def build_invoice(po_id, vendor_id, lines, inv_date, reference, replaces="",
                      issue=None, allow_reject=True, submit_delay=""):
        invoice_id = ids.new("INV")
        received = min(inv_date + timedelta(days=random.randint(0, 3)), REP)

        # Decide whether the review rejects it
        reject_reason = ""
        if allow_reject:
            if issue and random.random() < 0.5:
                reject_reason = {"missing_po": "Missing PO", "amount": "Amount mismatch",
                                 "unmatched_line": "Unmatched PO line"}[issue]
            elif random.random() < R["rejected_invoice"]:
                reject_reason = random.choice(REJECT_REASONS)

        review_days = random.choices([1, 2, 3, 4, 5, 6, 8, 12], weights=[10, 18, 20, 18, 12, 8, 8, 6])[0]
        decision_date = received + timedelta(days=review_days)
        if decision_date > REP:
            status, decision_date, reject_reason = "Submitted", None, ""   # still waiting at the snapshot
        elif reject_reason:
            status = "Rejected"
        else:
            status = "Approved"

        header_po = po_id
        if issue == "missing_po":
            header_po = ""
            log.add("invoice_header", invoice_id, "Invoice without PO number", "Data defect",
                    po_id, "", rule("invoice_missing_po", "invoices are submitted without a PO number"))

        total = 0.0
        for n, pl in enumerate(lines, start=1):
            line_id = ids.new("INL")
            value = float(pl["po_line_value"])
            po_line_id = pl["po_line_id"]
            if issue == "amount" and n == 1:
                new_value = round(max(0.01, value + random.choice([-20, 10, 30, 90])), 2)
                log.add("invoice_line", line_id, "Invoice value differs from PO line", "Data defect",
                        value, new_value, rule("invoice_amount_mismatch", "invoices bill a value different from the PO line"))
                value = new_value
            if issue == "unmatched_line" and n == 1:
                bad = f"POL9{random.randint(0, 99999):05d}"
                log.add("invoice_line", line_id, "Invoice line without matching PO line", "Data defect",
                        po_line_id, bad, rule("invoice_unmatched_line", "invoices have a line pointing to a PO line that does not exist"))
                po_line_id = bad
            total += value
            inl_rows.append({"invoice_line_id": line_id, "invoice_id": invoice_id, "po_line_id": po_line_id,
                             "line_number": n, "invoice_line_value": round(value, 2)})

        inv_rows.append({
            "invoice_id": invoice_id, "vendor_id": vendor_id, "invoice_reference": reference,
            "po_id": header_po, "invoice_date": inv_date, "received_date": received,
            "invoice_status": status, "rejection_reason": reject_reason, "replaces_invoice_id": replaces,
        })

        add_event(events, ids, "Invoice", invoice_id, vendor_id, "", "Submitted", ts(received), submit_delay)
        if status != "Submitted":
            delay = random.choice(DELAY_REVIEW) if review_days > SLA["invoice_review"] else ""
            add_event(events, ids, "Invoice", invoice_id, vendor_id, "Submitted", status, ts(decision_date), delay)

        if status == "Rejected":
            log.add("invoice_header", invoice_id, "Rejected invoice", "Business exception", "", reject_reason,
                    rule("rejected_invoice", "invoices are rejected at review"))
        if status == "Approved":
            payable.append({"invoice_id": invoice_id, "vendor_id": vendor_id,
                            "amount": round(total, 2), "decision_date": decision_date})

        return {"invoice_id": invoice_id, "status": status, "decision_date": decision_date, "reference": reference}

    for po in po_header[po_header["po_status"] != "Cancelled"].to_dict("records"):
        lines = lines_by_po[po["po_id"]].to_dict("records")

        # Sometimes the vendor bills one PO in two parts
        groups = [lines]
        if len(lines) >= 2 and random.random() < 0.35:
            cut = random.randint(1, len(lines) - 1)
            groups = [lines[:cut], lines[cut:]]

        for gi, group in enumerate(groups):
            lag = random.randint(1, 12) if random.random() > 0.25 else random.randint(15, 40)
            lag += 10 * gi
            inv_date = po["po_date"] + timedelta(days=lag)
            if inv_date > REP:
                continue   # not billed yet at the snapshot date

            submit_delay = random.choice(DELAY_SUBMIT) if lag > SLA["po_to_invoice"] else ""

            issue, roll = None, random.random()
            if roll < R["invoice_missing_po"]:
                issue = "missing_po"
            elif roll < R["invoice_missing_po"] + R["invoice_amount_mismatch"]:
                issue = "amount"
            elif roll < R["invoice_missing_po"] + R["invoice_amount_mismatch"] + R["invoice_unmatched_line"]:
                issue = "unmatched_line"

            res = build_invoice(po["po_id"], po["vendor_id"], group, inv_date,
                                new_reference(po["vendor_id"], inv_date), issue=issue, submit_delay=submit_delay)

            if res["status"] == "Rejected":
                # Most rejected invoices are corrected and resubmitted as a new invoice
                if random.random() < 0.9:
                    re_date = res["decision_date"] + timedelta(days=random.randint(2, 15))
                    if re_date <= REP:
                        res2 = build_invoice(po["po_id"], po["vendor_id"], group, re_date,
                                             res["reference"] + "-R1", replaces=res["invoice_id"], allow_reject=False)
                        log.add("invoice_header", res2["invoice_id"], "Resubmitted invoice", "Business exception",
                                res["invoice_id"], res2["invoice_id"], "Rejected invoices are resubmitted with a -R1 reference")
            elif issue is None:
                roll2, kind = random.random(), None
                if roll2 < R["dup_invoice_confirmed"]:
                    kind = "confirmed"
                elif roll2 < R["dup_invoice_confirmed"] + R["dup_invoice_potential"]:
                    kind = "potential"
                if kind:
                    d_date = inv_date + timedelta(days=random.randint(1, 7))
                    if d_date <= REP:
                        d_ref = res["reference"] if kind == "confirmed" else new_reference(po["vendor_id"], d_date)
                        dup = build_invoice(po["po_id"], po["vendor_id"], group, d_date, d_ref, allow_reject=False)
                        if kind == "confirmed":
                            log.add("invoice_header", dup["invoice_id"], "Duplicate invoice reference", "Data defect",
                                    res["invoice_id"], dup["invoice_id"], rule("dup_invoice_confirmed", "invoices are sent twice with the same reference"))
                        else:
                            log.add("invoice_header", dup["invoice_id"], "Potential duplicate invoice", "Data defect",
                                    res["invoice_id"], dup["invoice_id"], rule("dup_invoice_potential", "invoices are sent again with a new reference, same value, within 7 days"))

    return pd.DataFrame(inv_rows), pd.DataFrame(inl_rows), payable


# =====================================================================
# SECTION 6: Payments and allocations
# =====================================================================
def generate_payments(payable, ids, events, log):
    """payment and payment_allocation (bridge table)."""
    items = []
    for inv in payable:
        if random.random() < R["never_paid"]:
            continue   # still unpaid at the snapshot date

        lag = random.randint(1, 10) if random.random() < 0.8 else random.randint(11, 45)
        pay_date = inv["decision_date"] + timedelta(days=lag)
        parts = [(inv["amount"], pay_date)]

        if random.random() < R["partial_payment"]:
            first = round(inv["amount"] * random.choice([0.3, 0.5, 0.7]), 2)
            second = round(inv["amount"] - first, 2)
            parts = [(first, pay_date), (second, pay_date + timedelta(days=random.randint(5, 40)))]
            log.add("invoice_header", inv["invoice_id"], "Partial payment", "Business exception",
                    inv["amount"], "Paid in 2 parts", rule("partial_payment", "approved invoices are paid in two parts"))

        for amount, d in parts:
            if d <= REP:   # a part dated after the snapshot has not happened yet
                items.append({
                    "invoice_id": inv["invoice_id"], "vendor_id": inv["vendor_id"], "amount": amount,
                    "date": d, "lag": (d - inv["decision_date"]).days,
                    "batch": len(parts) == 1 and random.random() < R["batched_payment"],
                })

    # Some invoices of the same vendor are paid together in one payment
    batches, groups = {}, []
    for it in items:
        if it["batch"]:
            iso = it["date"].isocalendar()
            batches.setdefault((it["vendor_id"], iso[0], iso[1]), []).append(it)
        else:
            groups.append([it])
    groups += list(batches.values())
    groups.sort(key=lambda g: (max(i["date"] for i in g), g[0]["invoice_id"]))

    pay_rows, alc_rows = [], []
    for grp in groups:
        vendor_id = grp[0]["vendor_id"]
        pay_date = max(i["date"] for i in grp)
        pay_id = ids.new("PAY")

        if pay_date > REP - timedelta(days=3):
            status = "Pending"
        else:
            status = random.choices(["Completed", "Failed", "Reversed"], weights=[97, 2, 1])[0]

        pay_rows.append({
            "payment_id": pay_id, "vendor_id": vendor_id, "payment_reference": f"RMT{pay_id[3:]}",
            "payment_date": pay_date, "payment_amount": round(sum(i["amount"] for i in grp), 2),
            "payment_status": status,
        })
        for it in grp:
            alc_rows.append({"allocation_id": ids.new("ALC"), "payment_id": pay_id, "invoice_id": it["invoice_id"],
                             "allocation_amount": it["amount"], "allocation_date": pay_date})

        add_event(events, ids, "Payment", pay_id, vendor_id, "", "Initiated", ts(pay_date, 8, 11))
        if status != "Pending":
            delay = random.choice(DELAY_PAYMENT) if max(i["lag"] for i in grp) > SLA["approval_to_payment"] else ""
            final = "Failed" if status == "Failed" else "Completed"
            add_event(events, ids, "Payment", pay_id, vendor_id, "Initiated", final, ts(pay_date, 13, 17), delay)
        if status == "Reversed":
            add_event(events, ids, "Payment", pay_id, vendor_id, "Completed", "Reversed",
                      ts(pay_date + timedelta(days=random.randint(1, 3))))

    return pd.DataFrame(pay_rows), pd.DataFrame(alc_rows)


def close_purchase_orders(po_header, po_line, inv_header, inv_line, payments, allocs, ids, events):
    """Mark a PO Closed when every one of its lines is on a fully paid, approved invoice."""
    comp = allocs.merge(payments[["payment_id", "payment_status", "payment_date"]], on="payment_id")
    comp = comp[comp["payment_status"] == "Completed"].copy()
    comp["payment_date"] = pd.to_datetime(comp["payment_date"])

    paid = comp.groupby("invoice_id")["allocation_amount"].sum()
    last_pay = comp.groupby("invoice_id")["payment_date"].max()
    total = inv_line.groupby("invoice_id")["invoice_line_value"].sum()

    approved = inv_header.loc[inv_header["invoice_status"] == "Approved", "invoice_id"]
    fully = {i for i in approved if i in paid.index and paid[i] >= total[i] - 0.005}

    il = inv_line[inv_line["invoice_id"].isin(fully)].copy()
    il["last_pay"] = il["invoice_id"].map(last_pay)
    line_done = il.groupby("po_line_id")["last_pay"].max()
    done = set(line_done.index)

    po_header = po_header.copy()
    cancelled = set(po_header.loc[po_header["po_status"] == "Cancelled", "po_id"])
    vendor_of = dict(zip(po_header["po_id"], po_header["vendor_id"]))

    for po_id, g in po_line.groupby("po_id"):
        if po_id in cancelled:
            continue
        line_ids = list(g["po_line_id"])
        if all(l in done for l in line_ids):
            closed_on = max(line_done[l] for l in line_ids).date()
            po_header.loc[po_header["po_id"] == po_id, "po_status"] = "Closed"
            add_event(events, ids, "PO", po_id, vendor_of[po_id], "Created", "Closed", ts(closed_on, 18, 19))
    return po_header


# =====================================================================
# SECTION 7: Defect injection (value-level defects, applied after the clean build)
# =====================================================================
def pick(df, id_col, rate, table, used, mask=None):
    """Choose rows to damage. A record already damaged is never chosen again."""
    pool = df[~df[id_col].isin(used[table])]
    if mask is not None:
        pool = pool[mask(pool)]
    n = min(len(pool), max(1, int(round(len(df) * rate))))
    chosen = random.sample(list(pool.index), n)
    used[table].update(df.loc[chosen, id_col])
    return chosen


def apply_defect(df, idx, col, new, table, id_col, defect_type, defect_class, rule_text, log):
    """Change one value and write the before/after into the defect log."""
    old = df.at[idx, col]
    df.at[idx, col] = new
    log.add(table, df.at[idx, id_col], defect_type, defect_class, old, new, rule_text)


def inject_defects(installs, po_header, po_line, inv_header, inv_line, payments, allocs, events, ids, log):
    used = defaultdict(set)
    for row in log.rows:
        used[row["table_name"]].add(row["record_id"])

    # ---------------- installations ----------------
    t = "installation_transaction"
    inst = installs.copy()

    for idx in pick(inst, "transaction_id", R["wrong_rebate"], t, used):
        old = float(inst.at[idx, "expected_rebate_recorded"])
        new = random.choice([x for x in (0.0, 45.0, 60.0, 90.0, 120.0, old + 10) if abs(x - old) > 0.001])
        apply_defect(inst, idx, "expected_rebate_recorded", new, t, "transaction_id", "Wrong rebate",
                     "Data defect", rule("wrong_rebate", "installations have a wrong recorded rebate"), log)

    for idx in pick(inst, "transaction_id", R["missing_vendor"], t, used):
        apply_defect(inst, idx, "vendor_id", "", t, "transaction_id", "Missing vendor", "Data defect",
                     rule("missing_vendor", "installations have no vendor"), log)

    for idx in pick(inst, "transaction_id", R["missing_project"], t, used):
        apply_defect(inst, idx, "project_code", "", t, "transaction_id", "Missing project code", "Data defect",
                     rule("missing_project", "installations have no project code"), log)

    for idx in pick(inst, "transaction_id", R["invalid_property_type"], t, used):
        apply_defect(inst, idx, "property_type", random.choice(["Bungalow", "Flt", "house", "FLAT ", "Unknown"]),
                     t, "transaction_id", "Invalid property type", "Data defect",
                     rule("invalid_property_type", "installations have an invalid property type"), log)

    for idx in pick(inst, "transaction_id", R["missing_install_date"], t, used):
        apply_defect(inst, idx, "installation_date", None, t, "transaction_id", "Missing installation date",
                     "Data defect", rule("missing_install_date", "installations have no installation date"), log)

    for idx in pick(inst, "transaction_id", R["future_install_date"], t, used):
        apply_defect(inst, idx, "installation_date", REP + timedelta(days=random.randint(30, 200)), t,
                     "transaction_id", "Installation date in the future", "Data defect",
                     rule("future_install_date", "installations are dated after the reporting date"), log)

    for idx in pick(inst, "transaction_id", R["missing_ineligible_reason"], t, used,
                    lambda q: (q["is_eligible"] == 0) & (q["ineligible_reason"] != "")):
        apply_defect(inst, idx, "ineligible_reason", "", t, "transaction_id", "Missing ineligible reason",
                     "Data defect", rule("missing_ineligible_reason", "installations (not eligible) have no reason"), log)

    for idx in pick(inst, "transaction_id", R["eligible_not_completed"], t, used,
                    lambda q: (q["completion_status"] != "Completed") & (q["is_eligible"] == 0)):
        rate_value = settings.REBATE_PER_FLAT if inst.at[idx, "property_type"] == "Flat" else settings.REBATE_PER_HOUSE
        apply_defect(inst, idx, "is_eligible", 1, t, "transaction_id", "Eligible but not completed",
                     "Data defect", rule("eligible_not_completed", "uncompleted installations are marked eligible"), log)
        inst.at[idx, "ineligible_reason"] = ""
        inst.at[idx, "expected_rebate_recorded"] = float(rate_value)

    dup_rows, next_n = [], len(inst) + 1
    for idx in pick(inst, "transaction_id", R["duplicate_installation"], t, used, lambda q: q["is_eligible"] == 1):
        row = inst.loc[idx].to_dict()
        original_id = row["transaction_id"]
        row["transaction_id"] = f"T{next_n:06d}"
        next_n += 1
        log.add(t, row["transaction_id"], "Duplicate installation (same property_ref)", "Data defect",
                original_id, row["property_ref"], rule("duplicate_installation", "installations are entered twice for the same property"))
        dup_rows.append(row)
    if dup_rows:
        inst = pd.concat([inst, pd.DataFrame(dup_rows)], ignore_index=True)

    # ---------------- PO lines ----------------
    t = "po_line"
    pol = po_line.copy()
    po_max = pol.groupby("po_id")["line_number"].max().to_dict()
    new_lines = []
    for idx in pick(pol, "po_line_id", R["duplicate_po_line"], t, used):
        row = pol.loc[idx].to_dict()
        original_id = row["po_line_id"]
        row["po_line_id"] = ids.new("POL")
        po_max[row["po_id"]] += 1
        row["line_number"] = po_max[row["po_id"]]
        log.add(t, row["po_line_id"], "Installation on two PO lines", "Data defect", original_id, row["transaction_id"],
                rule("duplicate_po_line", "PO lines repeat an installation already on a PO"))
        new_lines.append(row)
    if new_lines:
        pol = pd.concat([pol, pd.DataFrame(new_lines)], ignore_index=True)

    # ---------------- invoices ----------------
    ih, il = inv_header.copy(), inv_line.copy()
    po_dates = dict(zip(po_header["po_id"], po_header["po_date"]))

    t = "invoice_header"
    for idx in pick(ih, "invoice_id", R["missing_invoice_date"], t, used):
        apply_defect(ih, idx, "invoice_date", None, t, "invoice_id", "Missing invoice date", "Data defect",
                     rule("missing_invoice_date", "invoices have no invoice date"), log)

    for idx in pick(ih, "invoice_id", R["invoice_before_po"], t, used, lambda q: q["po_id"].isin(po_dates.keys())):
        new_date = po_dates[ih.at[idx, "po_id"]] - timedelta(days=random.randint(3, 10))
        apply_defect(ih, idx, "invoice_date", new_date, t, "invoice_id", "Invoice dated before PO", "Data defect",
                     rule("invoice_before_po", "invoices are dated before their PO"), log)

    t = "invoice_line"
    for idx in pick(il, "invoice_line_id", R["negative_invoice_line"], t, used):
        apply_defect(il, idx, "invoice_line_value", -float(il.at[idx, "invoice_line_value"]), t, "invoice_line_id",
                     "Negative invoice line value", "Data defect",
                     rule("negative_invoice_line", "invoice lines have a negative value"), log)

    # ---------------- payments and allocations ----------------
    p, a = payments.copy(), allocs.copy()

    # Duplicate payments (copied BEFORE any amounts are changed)
    new_pay, new_alc = [], []
    for kind, key in (("confirmed", "dup_payment_confirmed"), ("potential", "dup_payment_potential")):
        for idx in pick(p, "payment_id", R[key], "payment", used, lambda q: q["payment_status"] == "Completed"):
            src = p.loc[idx].to_dict()
            new_id = ids.new("PAY")
            if kind == "confirmed":
                ref = src["payment_reference"]
                d = min(src["payment_date"] + timedelta(days=random.randint(0, 2)), REP)
            else:
                ref = f"RMT9{random.randint(0, 99999):05d}"
                d = min(src["payment_date"] + timedelta(days=random.randint(1, 3)), REP)
            new_pay.append({"payment_id": new_id, "vendor_id": src["vendor_id"], "payment_reference": ref,
                            "payment_date": d, "payment_amount": src["payment_amount"], "payment_status": "Completed"})
            for al in a[a["payment_id"] == src["payment_id"]].to_dict("records"):
                alc_id = ids.new("ALC")
                used["payment_allocation"].add(alc_id)
                new_alc.append({"allocation_id": alc_id, "payment_id": new_id, "invoice_id": al["invoice_id"],
                                "allocation_amount": al["allocation_amount"], "allocation_date": d})
            add_event(events, ids, "Payment", new_id, src["vendor_id"], "", "Initiated", ts(d, 8, 11))
            add_event(events, ids, "Payment", new_id, src["vendor_id"], "Initiated", "Completed", ts(d, 13, 17))
            used["payment"].add(new_id)
            if kind == "confirmed":
                log.add("payment", new_id, "Duplicate payment (same reference)", "Data defect", src["payment_id"], ref,
                        rule(key, "payments are repeated with the same reference"))
            else:
                log.add("payment", new_id, "Potential duplicate payment", "Data defect", src["payment_id"], ref,
                        rule(key, "payments are repeated with a new reference, same amount, within 3 days"))
    if new_pay:
        p = pd.concat([p, pd.DataFrame(new_pay)], ignore_index=True)
        a = pd.concat([a, pd.DataFrame(new_alc)], ignore_index=True)

    # Overpayment: allocation and payment both increase, so they stay consistent
    completed_ids = set(p.loc[p["payment_status"] == "Completed", "payment_id"])
    t = "payment_allocation"
    for idx in pick(a, "allocation_id", R["overpayment"], t, used,
                    lambda q: q["payment_id"].isin(completed_ids) & ~q["payment_id"].isin(used["payment"])):
        bump = random.choice([10, 25, 50])
        old = float(a.at[idx, "allocation_amount"])
        a.at[idx, "allocation_amount"] = round(old + bump, 2)
        pay_idx = p.index[p["payment_id"] == a.at[idx, "payment_id"]][0]
        p.at[pay_idx, "payment_amount"] = round(float(p.at[pay_idx, "payment_amount"]) + bump, 2)
        used["payment"].add(a.at[idx, "payment_id"])
        log.add(t, a.at[idx, "allocation_id"], "Overpayment", "Business exception", old, round(old + bump, 2),
                rule("overpayment", "allocations pay more than the invoice"))

    for idx in pick(a, "allocation_id", R["orphan_allocation"], t, used):
        apply_defect(a, idx, "invoice_id", f"INV9{random.randint(0, 99999):05d}", t, "allocation_id",
                     "Allocation to a non-existent invoice", "Data defect",
                     rule("orphan_allocation", "allocations point to an invoice that does not exist"), log)

    for idx in pick(a, "allocation_id", R["negative_allocation"], t, used):
        apply_defect(a, idx, "allocation_amount", -float(a.at[idx, "allocation_amount"]), t, "allocation_id",
                     "Negative allocation amount", "Data defect",
                     rule("negative_allocation", "allocations have a negative amount"), log)

    t = "payment"
    for idx in pick(p, "payment_id", R["payment_amount_mismatch"], t, used):
        old = float(p.at[idx, "payment_amount"])
        new = round(max(1.0, old + random.choice([-25, 15, 40])), 2)
        apply_defect(p, idx, "payment_amount", new, t, "payment_id", "Payment amount differs from allocations",
                     "Data defect", rule("payment_amount_mismatch", "payments do not equal the sum of their allocations"), log)

    # ---------------- workflow events ----------------
    ev = pd.DataFrame(events)
    submitted_at = ev[(ev["entity_type"] == "Invoice") & (ev["to_status"] == "Submitted")] \
        .set_index("entity_id")["event_timestamp"].to_dict()
    t = "workflow_event"
    for idx in pick(ev, "event_id", R["invalid_transition"], t, used,
                    lambda q: (q["entity_type"] == "Invoice") & (q["to_status"] == "Approved")):
        new_ts = submitted_at[ev.at[idx, "entity_id"]] - timedelta(days=2)
        apply_defect(ev, idx, "event_timestamp", new_ts, t, "event_id", "Invoice approved before submission",
                     "Data defect", rule("invalid_transition", "events have an invalid status order"), log)

    return inst, pol, ih, il, p, a, ev


# =====================================================================
# SECTION 8: Build, check and export
# =====================================================================
def build_dataset():
    set_seeds()
    ids, log, events = IdFactory(), DefectLog(), []

    vendors = generate_vendors()
    dates = generate_dates()
    rules = generate_business_rules()

    installs = generate_installations(vendors)
    generate_installation_events(installs, ids, events)
    po_header, po_line = generate_purchase_orders(installs, ids, events, log)
    inv_header, inv_line, payable = generate_invoices(po_header, po_line, ids, events, log)
    payments, allocs = generate_payments(payable, ids, events, log)
    po_header = close_purchase_orders(po_header, po_line, inv_header, inv_line, payments, allocs, ids, events)

    installs, po_line, inv_header, inv_line, payments, allocs, events_df = inject_defects(
        installs, po_header, po_line, inv_header, inv_line, payments, allocs, events, ids, log)

    tables = {
        "dim_vendor": vendors,
        "dim_date": dates,
        "business_rules": rules,
        "installation_transaction": installs,
        "po_header": po_header,
        "po_line": po_line,
        "invoice_header": inv_header,
        "invoice_line": inv_line,
        "payment": payments,
        "payment_allocation": allocs,
        "workflow_event": events_df,
        "defect_injection_log": log.to_frame(),
    }
    return tables


PRIMARY_KEYS = {
    "dim_vendor": "vendor_id", "dim_date": "date_key", "business_rules": "rule_id",
    "installation_transaction": "transaction_id", "po_header": "po_id", "po_line": "po_line_id",
    "invoice_header": "invoice_id", "invoice_line": "invoice_line_id", "payment": "payment_id",
    "payment_allocation": "allocation_id", "workflow_event": "event_id", "defect_injection_log": "defect_id",
}


def check_primary_keys(tables):
    print("PRIMARY KEY CHECK")
    for name, key in PRIMARY_KEYS.items():
        dupes = int(tables[name][key].duplicated().sum())
        print(f"  {name:26s} {key:16s} duplicates: {dupes}  {'OK' if dupes == 0 else 'PROBLEM'}")
    print()


def export_tables(tables):
    settings.RAW_DATA_DIR.mkdir(parents=True, exist_ok=True)
    for name, df in tables.items():
        df.to_csv(settings.RAW_DATA_DIR / f"{name}.csv", index=False, float_format="%.2f")


def verify_exports(tables):
    print("ROW COUNT CHECK (memory vs CSV file)")
    for name, df in tables.items():
        n_csv = len(pd.read_csv(settings.RAW_DATA_DIR / f"{name}.csv"))
        print(f"  {name:26s} memory: {len(df):6d}   csv: {n_csv:6d}   {'OK' if n_csv == len(df) else 'MISMATCH'}")
    print()


def print_summary(tables):
    inst = tables["installation_transaction"]
    pol = tables["po_line"]
    inl = tables["invoice_line"]
    comp = tables["payment_allocation"].merge(tables["payment"][["payment_id", "payment_status"]], on="payment_id")
    comp = comp[comp["payment_status"] == "Completed"]

    print("MONEY CHAIN (GBP, raw totals before any cleaning)")
    print(f"  Expected rebate recorded : {inst['expected_rebate_recorded'].sum():12,.2f}")
    print(f"  PO line value            : {pol['po_line_value'].sum():12,.2f}")
    print(f"  Invoice line value (all) : {inl['invoice_line_value'].sum():12,.2f}")
    print(f"  Completed allocations    : {comp['allocation_amount'].sum():12,.2f}")
    print()

    per_vendor = inst[inst["vendor_id"] != ""].groupby("vendor_id").size()
    print(f"Vendors with fewer than {settings.MIN_VENDOR_TRANSACTIONS} installations: "
          f"{int((per_vendor < settings.MIN_VENDOR_TRANSACTIONS).sum())} of {len(per_vendor)}")
    print(f"Smallest vendor: {int(per_vendor.min())} | Largest vendor: {int(per_vendor.max())}")
    print()

    print("DEFECTS PLANTED (defect_injection_log)")
    log_df = tables["defect_injection_log"]
    print(log_df.groupby(["defect_class", "defect_type"]).size().to_string())
    print(f"\nTotal defect log rows: {len(log_df)}")


if __name__ == "__main__":
    data = build_dataset()
    check_primary_keys(data)
    export_tables(data)
    verify_exports(data)
    print_summary(data)
    print(f"\nCSV files written to: {settings.RAW_DATA_DIR}")