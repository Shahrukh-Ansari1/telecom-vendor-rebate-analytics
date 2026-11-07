"""
Load the 12 raw CSV files into the MySQL database telecom_rebate.

DISCLAIMER: This project is an independent telecom operations analytics
case study developed using synthetic data and illustrative business rules.
It is not an official BT project and does not contain BT operational or
confidential data.

Run:  python src\\load_to_mysql.py
The password is typed when asked. It is never stored in a file.
"""

import getpass
import sys
from pathlib import Path

import mysql.connector
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "config"))
import settings

DB_NAME = "telecom_rebate"

# Parents first, children after (this order respects the foreign keys)
LOAD_ORDER = [
    "dim_vendor", "dim_date", "business_rules",
    "installation_transaction", "po_header", "po_line",
    "invoice_header", "invoice_line", "payment",
    "payment_allocation", "workflow_event", "defect_injection_log",
]

BATCH_SIZE = 1000


def read_csv_rows(table):
    """Read a CSV as text and turn empty cells into None (SQL NULL)."""
    df = pd.read_csv(settings.RAW_DATA_DIR / f"{table}.csv", dtype=str, keep_default_na=False)
    rows = [
        tuple(None if value == "" else value for value in row)
        for row in df.itertuples(index=False, name=None)
    ]
    return list(df.columns), rows


def load_table(cursor, table):
    """Insert every CSV row in batches (tables are emptied earlier in main)."""
    columns, rows = read_csv_rows(table)

    col_list = ", ".join(f"`{c}`" for c in columns)
    placeholders = ", ".join(["%s"] * len(columns))
    sql = f"INSERT INTO `{table}` ({col_list}) VALUES ({placeholders})"

    for start in range(0, len(rows), BATCH_SIZE):
        cursor.executemany(sql, rows[start:start + BATCH_SIZE])
    return len(rows)


def main():
    user = input("MySQL user [root]: ").strip() or "root"
    password = getpass.getpass("MySQL password (typing is hidden): ")

    conn = mysql.connector.connect(
        host="localhost", port=3306, user=user, password=password, database=DB_NAME
    )
    cursor = conn.cursor()

    # Allow TRUNCATE on tables that other tables point to
    cursor.execute("SET FOREIGN_KEY_CHECKS = 0")
    for table in LOAD_ORDER:
        cursor.execute(f"TRUNCATE TABLE `{table}`")
    cursor.execute("SET FOREIGN_KEY_CHECKS = 1")

    print("\nLOADING")
    csv_counts = {}
    for table in LOAD_ORDER:
        csv_counts[table] = load_table(cursor, table)
        print(f"  {table:26s} {csv_counts[table]:6d} rows inserted")
    conn.commit()

    print("\nROW COUNT CHECK (CSV vs database)")
    all_ok = True
    for table in LOAD_ORDER:
        cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
        db_count = cursor.fetchone()[0]
        ok = db_count == csv_counts[table]
        all_ok = all_ok and ok
        print(f"  {table:26s} csv: {csv_counts[table]:6d}   db: {db_count:6d}   {'OK' if ok else 'MISMATCH'}")

    cursor.close()
    conn.close()
    print("\nAll tables loaded and counts match." if all_ok else "\nPROBLEM: see MISMATCH above.")


if __name__ == "__main__":
    main()