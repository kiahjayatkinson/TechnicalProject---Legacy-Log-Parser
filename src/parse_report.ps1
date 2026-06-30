<#
.SYNOPSIS
    Extracts structured records from an unstructured legacy terminal report
    and emits a clean, validated CSV.

.DESCRIPTION
    Legacy systems frequently expose data only as fixed-width "green screen"
    print dumps wrapped in RTF control codes - the same shape as many appliance,
    mainframe, and network-device logs a SOC analyst must normalise before it can
    be searched, correlated, or fed into a SIEM.

    This script demonstrates the core pattern: isolate the signal (one regex with
    capture groups) from the noise (RTF markup, headers, pagination), type-cast the
    fields, and - critically - RECONCILE the parsed result against the source's own
    stated total so the output can be trusted before anything downstream relies on it.

.PARAMETER InputFile
    Path to the exported report. Defaults to report.txt in the script folder.

.PARAMETER OutputFile
    Path for the clean CSV. Defaults to parsed_output.csv.

.EXAMPLE
    .\parse_report.ps1 -InputFile report_sample.txt
#>

param(
    [string]$InputFile  = "report.txt",
    [string]$OutputFile = "parsed_output.csv"
)

if (-not (Test-Path $InputFile)) {
    Write-Host "Input file not found: $InputFile" -ForegroundColor Red
    exit 1
}

# --- 1. Read the whole dump as one blob (records may be noisy / multi-page) ---
$text = Get-Content $InputFile -Raw

# --- 2. Isolate records with a single anchored pattern ---
#   (\d+)        -> the record's ID, inside parentheses        [capture group 1]
#   \s+\d+ Jobs  -> a count field we don't need
#   ([\d.]+)     -> the numeric value                          [capture group 2]
# Everything else (RTF codes, banners, page breaks) is ignored by construction.
$pattern = '\((\d+)\)\s+\d+ Jobs\s+([\d.]+)'
$matches = [regex]::Matches($text, $pattern)

if ($matches.Count -eq 0) {
    Write-Host "No records matched. Wrong file or format change?" -ForegroundColor Red
    exit 1
}

# --- 3. Build typed objects (strings -> int / decimal) so downstream maths is safe ---
$records = foreach ($m in $matches) {
    [PSCustomObject]@{
        ID    = [int]$m.Groups[1].Value
        Value = [decimal]$m.Groups[2].Value
    }
}

# --- 4. INTEGRITY CHECK: reconcile against the source's own declared total -------
# The report prints its own grand total. If our parsed sum doesn't match it, the
# parse is not trustworthy - a record was dropped, duplicated, or misread. This is
# the difference between "I scraped some numbers" and "I can stand behind this data".
$parsedTotal = ($records.Value | Measure-Object -Sum).Sum
$declared = [regex]::Match($text, 'Total pay out:\s*\$\s*([\d.]+)')
$reconcileMsg = ""
if ($declared.Success) {
    $declaredTotal = [decimal]$declared.Groups[1].Value
    $delta = [Math]::Abs($parsedTotal - $declaredTotal)
    if ($delta -lt 0.01) {
        $reconcileMsg = "RECONCILED  parsed total $parsedTotal == source total $declaredTotal"
        $ok = $true
    } else {
        $reconcileMsg = "MISMATCH  parsed $parsedTotal vs source $declaredTotal (delta $delta)"
        $ok = $false
    }
} else {
    $reconcileMsg = "No declared total found in source - cannot reconcile."
    $ok = $true   # don't block, but flag
}

# --- 5. Emit the clean CSV ---
$records | Export-Csv $OutputFile -NoTypeInformation

# --- 6. Report outcome (colour-coded, scriptable exit) ---
Write-Host ("Parsed {0} records -> {1}" -f $records.Count, $OutputFile) -ForegroundColor Cyan
if ($ok) { Write-Host $reconcileMsg -ForegroundColor Green }
else     { Write-Host $reconcileMsg -ForegroundColor Red; exit 2 }
