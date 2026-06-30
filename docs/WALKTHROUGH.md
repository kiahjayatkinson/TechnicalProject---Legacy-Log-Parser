# Build Walkthrough

The story behind the parser — the decisions, the failure modes, and how each one
maps to a transferable security-analysis skill. A clean script is easy to show;
the *reasoning* is what's worth reading.

## 1. Reading an unfamiliar format

The export claimed to be `.txt` but was really RTF. The first instinct — write a
fragile rule per line — was wrong. Instead: find the one invariant shape every
record shares (`(id) ... N Jobs ... value`) and anchor a single regex to it. Noise
(RTF codes, page headers, the summary footer) is excluded *by construction*, not
by a growing pile of special cases.

> **Transfer:** the same instinct applies to any new log source — find the stable
> grammar of a record before writing extraction rules, so a banner or a blank line
> never derails the parse.

## 2. Trust, but verify — the reconciliation gate

The key design decision. The report prints its own grand total. Rather than assume
the parse caught everything, the script **sums the parsed values and compares them
to that declared total.** Match → green, proceed. Mismatch → red, non-zero exit.

This catches the most dangerous failure mode in any parser: the **silent drop**. A
parser that quietly misses one record looks like it worked and hands you confidently
wrong data. In a SOC context, that's a hunt built on incomplete logs or an alert
that never fires because the relevant line was skipped.

> **Transfer:** validate parsed/ingested data against an independent control before
> trusting it. Detection quality is bounded by data integrity.

## 3. Type safety

IDs are cast to `int`, values to `decimal`/`float`. Without this, a downstream
match or threshold can silently fail when "11" (text) doesn't equal 11 (number) —
a class of bug that's invisible until it produces a wrong result.

> **Transfer:** the same string-vs-number trap appears in correlation logic and
> detection thresholds; explicit typing closes it.

## 4. Safe automation around a system of record

The full production version writes its output into a shared, structured workbook
that other people depend on. That raised real safety questions, handled the way a
SOAR playbook should:

- **Guard clauses first** — refuse to run if the target file is open/locked or the
  input is missing, *before* touching anything.
- **Fail loud, fail safe** — surface errors plainly and keep a human in the loop at
  the one irreversible step (the write into the shared record), rather than
  automating blindly into a system of record.
- **Idempotent runs** — each run clears and rebuilds its working area, so a re-run
  never double-writes or leaves stale state.

> **Transfer:** these are the exact properties that make an automated response
> action safe to deploy — preconditions, observability, and a controlled blast
> radius.

## 5. Data handling / OPSEC

The parser was built on live operational data. Nothing real ships here: names and
figures are synthetic, internal identifiers and the downstream record are excluded.
Defaulting to "treat the source as sensitive, publish only the technique" is part
of the security mindset, not an afterthought.

---

### Skills demonstrated

`Regex extraction` · `Data-integrity validation` · `Type safety` ·
`PowerShell` · `Python` · `Safe automation design` · `Idempotency` ·
`Fail-loud error handling` · `OPSEC / data minimisation`
