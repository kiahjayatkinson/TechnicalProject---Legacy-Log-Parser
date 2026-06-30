#!/usr/bin/env python3
"""
Extract structured records from an unstructured legacy terminal report and emit
a clean, validated CSV.

Legacy systems often expose data only as fixed-width "green screen" print dumps
wrapped in RTF control codes - structurally identical to many appliance,
mainframe, and network-device logs a SOC analyst must normalise before the data
can be searched, correlated, or fed into a SIEM.

Core pattern demonstrated here:
  1. Isolate signal from noise with one anchored regex (capture groups).
  2. Type-cast fields so downstream maths/correlation is safe.
  3. RECONCILE the parsed result against the source's own declared total, so the
     output can be trusted before anything acts on it.

Usage:
    python parse_report.py report_sample.txt [output.csv]
"""

import csv
import re
import sys
from pathlib import Path

# (\d+) ID in parens | "N Jobs" count we skip | ([\d.]+) numeric value
RECORD_RE = re.compile(r"\((\d+)\)\s+\d+ Jobs\s+([\d.]+)")
TOTAL_RE = re.compile(r"Total pay out:\s*\$\s*([\d.]+)")


def parse(text: str):
    """Return a list of (id:int, value:float) records found in the dump."""
    return [(int(m.group(1)), float(m.group(2))) for m in RECORD_RE.finditer(text)]


def reconcile(records, text: str):
    """
    Integrity check: does the sum of parsed values match the total the report
    declares for itself? Returns (ok: bool, message: str).

    This is the line between 'scraped some numbers' and 'data I can stand behind'.
    """
    parsed_total = round(sum(v for _, v in records), 2)
    m = TOTAL_RE.search(text)
    if not m:
        return True, f"No declared total in source; parsed total = {parsed_total:.2f}"
    declared = round(float(m.group(1)), 2)
    if abs(parsed_total - declared) < 0.01:
        return True, f"RECONCILED  parsed {parsed_total:.2f} == source {declared:.2f}"
    return False, f"MISMATCH  parsed {parsed_total:.2f} vs source {declared:.2f}"


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_report.py <input> [output.csv]")
        sys.exit(1)

    in_path = Path(sys.argv[1])
    out_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("parsed_output.csv")

    if not in_path.exists():
        print(f"Input file not found: {in_path}")
        sys.exit(1)

    text = in_path.read_text(encoding="utf-8", errors="replace")
    records = parse(text)
    if not records:
        print("No records matched. Wrong file or a format change?")
        sys.exit(1)

    with out_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["ID", "Value"])
        w.writerows(records)

    ok, msg = reconcile(records, text)
    print(f"Parsed {len(records)} records -> {out_path}")
    print(msg)
    sys.exit(0 if ok else 2)


if __name__ == "__main__":
    main()
