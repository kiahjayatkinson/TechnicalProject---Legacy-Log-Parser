# Legacy Report Parser & Validation Pipeline

Automating the extraction of structured data from an unstructured legacy terminal
dump, with a built-in **integrity check** that reconciles the parsed output
against the source's own declared totals before the data is trusted.

> **Why this is in a security portfolio:** the work a SOC analyst does every day
> starts with exactly this problem — taking noisy, semi-structured machine output
> (appliance logs, mainframe exports, EDR dumps, firewall syslog) and turning it
> into clean, *trustworthy* records that can be searched, correlated, or fed into
> a SIEM. This project is that pattern, end to end, on a real-world data source.

---

## The problem

A legacy operations system only exposes its data as a fixed-width "green screen"
print job, exported as a `.txt` file that is actually **RTF** — the real records
are buried inside control codes, page banners, and pagination noise:

```
   M. AMSEL               (11)        7 Jobs                  518.24      \par
   K. BRANNT              (13)        4 Jobs                  360.96      \par
```

Extracting these by hand was slow and error-prone. The goal: parse every record
reliably, and **prove the parse is correct** rather than hoping it is.

## The approach

| Step | What it does | Why it matters in security work |
|------|--------------|----------------------------------|
| **Isolate** | One anchored regex with capture groups pulls each record out of the RTF noise | Signal-vs-noise extraction is the heart of log parsing |
| **Type-cast** | Fields are cast to `int` / `decimal` | Prevents silent string-vs-number bugs downstream (e.g. in correlation or thresholds) |
| **Reconcile** | Parsed total is compared to the total the source declares for itself | **Data integrity** — the difference between "scraped some numbers" and "data I can stand behind in an investigation" |
| **Emit** | Clean CSV, colour-coded status, scriptable exit codes | Output is pipeline-ready and automatable |

The reconciliation step is the core idea. A parser that silently drops a record
is worse than no parser — it gives you false confidence. By checking the parsed
sum against the report's own stated grand total, the script **fails loudly** if a
single record is missed, duplicated, or misread.

## SOC / security relevance

- **Log normalisation** — legacy/appliance logs rarely arrive SIEM-ready; this is
  the pre-ingest cleanup an analyst automates instead of doing by hand.
- **Detection-data integrity** — a detection is only as good as the data under it.
  Reconciling parsed output against a known control catches the silent-drop failure
  mode that would otherwise corrupt a hunt or an alert.
- **Automation / SOAR mindset** — guard clauses, validation gates, exit codes, and
  fail-loud behaviour are the building blocks of any safe automated playbook.
- **Cross-language fluency** — the same logic is implemented in **PowerShell**
  (native on Windows endpoints / no install needed) and **Python** (the lingua
  franca of SOC tooling), showing the pattern transfers across the analyst stack.

## Repo contents

```
src/
  parse_report.ps1     # PowerShell implementation (Windows-native)
  parse_report.py      # Python implementation (same logic, SOC-standard tooling)
sample-data/
  report_sample.txt    # synthetic legacy dump in the real format (no real data)
  parsed_output_sample.csv  # example clean output
docs/
  WALKTHROUGH.md       # the full build story: debugging, integrity, safe-handling
```

## Run it

**Python:**
```bash
python src/parse_report.py sample-data/report_sample.txt output.csv
```

**PowerShell:**
```powershell
.\src\parse_report.ps1 -InputFile sample-data\report_sample.txt -OutputFile output.csv
```

Expected result:
```
Parsed 78 records -> output.csv
RECONCILED  parsed 30795.57 == source 30795.57
```

If a record were dropped or the format changed, the reconciliation line turns red
and the script exits non-zero — so it can gate an automated pipeline.

## Notes on data handling

All names and figures in this repository are **synthetic**. The parser was
originally built against a live operational system; the real data, internal
identifiers, and the downstream system of record have been deliberately excluded
and replaced with generated samples. Treating source data as sensitive by default
— and shipping only what's needed to demonstrate the technique — is itself part of
the discipline.

---

*Built as a real automation project and adapted here to illustrate the log-parsing,
data-integrity, and safe-automation skills that underpin SOC analysis.*
