---
name: example-workplace-attendance-tracker
description: Build, maintain, generate fake test data for, and distribute the Example Workplace Attendance Tracker Excel/VBA tool. Use when asked about the attendance tracker, generating fake workplace data, fixing tracker issues, or creating center-specific templates.
type: domain
tags: [workplace, excel, vba, attendance, hr-tools, operations]
---

# Example Workplace Attendance Tracker Skill

## Overview

The Example Workplace Attendance Tracker is an Excel .xlsm workbook with a VBA engine that classifies employee attendance across three source reports and routes results into five output tabs. It supports multiple Example Workplace plasma donation centers.

## Key Files

| File | Location | Purpose |
|------|----------|---------|
| `AttendanceEngine_v4_VBA.bas` | `/Users/localuser/Downloads/example-files/` | Full VBA source (~2100+ lines) |
| `generate_year_data.py` | same | Multi-center fake data generator |
| `create_blank_template.py` | same | Strips data → distributable template |
| `fake_data_gen.py` | same | Single-week QA + fuzz tester |
| `fake_year_data/` | same | 12-month fake data (stlouis/, chicago/) |

## Architecture

### Three RAW Input Tabs
- **RAW_Changes** — Dayforce schedule change audit export
- **RAW_TAFW** — Kronos TAFW (week-based, Sunday-start, 11 columns)
- **RAW_Punches** — attendancePunches CSV (employee ID, in/out, job code)

### Five Output Tabs
1. **Action Required** — tardies, early-outs, unexcused absences needing manager attention
2. **All Records** — every processed employee-day
3. **Already Reviewed** — previously actioned items
4. **Time Off Excluded** — VAC/FLOAT/JURY/BRV/UNPAID rows
5. **Worked No Exception** — clean records

### Classification Rule Chain (8 rules, first match wins)
- **Rule 0**: Punch >60 min before scheduled start → "Data Error - Check Schedule (Punch >60 min Early)"
- **Rule 1**: Missing Employee ID
- **Rule 2**: Multiple distinct TAFW codes (ambiguous)
- **Rule 3**: SICK/FMLA/STD/LOA present → "Covered Tardy" or "Excused Absence"
- **Rule 4**: VAC/FLOAT/UNPAID/JURY/BRV → "Time Off Present - Excluded"
- **Rule 5**: Has punch → evaluate tardy/early-out/made-up/clean
- **Fallback**: "Possible Absence - No Punch"

### Config Tab
- **B4**: Center name (filters records; blank = all records pass)
- **B5**: Tardy threshold in minutes (default: 6)

### Key VBA Subs (public, assigned to Control Panel buttons)
```
RunAttendanceCheck    — main engine, reads all 3 RAW tabs
ImportChangesFile     — file picker → RAW_Changes
ImportTAFWFile        — file picker → RAW_TAFW
ImportPunchesFile     — file picker → RAW_Punches (CSV or XLSX)
ImportAllFiles        — prompts for all 3 in sequence
SetupNewCenter        — wizard: center name + tardy threshold
SetupControlPanel     — rebuilds Control Panel with buttons
RefreshControlPanel   — writes live stats to Control Panel rows 5-11
ExportSummaryReport   — exports Control Panel + Action Req as PDF
QueueForPowerAutomate — adds selected rows to PA Export Queue
PopulateEmployeeMaster— pre-loads 16 Saint Louis LMO staff
```

## Multi-Center Support

The tracker works for ANY center by changing Config B4.
`InStr("Chicago, IL", "")` returns 1 in VBA, so a blank center name passes all rows.

### Generating Fake Data for a Center
```bash
# Available centers: stlouis, chicago, dallas, denver
python3 generate_year_data.py --center chicago
python3 generate_year_data.py --center dallas
python3 generate_year_data.py --center stlouis   # default

# Custom output directory
python3 generate_year_data.py --center chicago /tmp/chicago_data
```

### Creating a Blank Template for Distribution
```bash
python3 create_blank_template.py LMO_Attendance_Tracker_v5.4.xlsm
# → Example Workplace_Attendance_Tracker_TEMPLATE.xlsm (VBA intact, all data cleared)
```

### Running QA + Fuzz Tests
```bash
python3 fake_data_gen.py --mode quick        # 2-min fuzz + inject into workbook
python3 fake_data_gen.py --mode fuzz --minutes 60  # 60-min stress test
python3 fake_data_gen.py --mode inject       # inject current fake data into workbook
```

## Common Tasks

### Fix a VBA Classification Bug
1. Read `AttendanceEngine_v4_VBA.bas` — focus on `RunAttendanceCheck` (main loop) and the rule chain starting around line 497
2. Also check `SimClassify` function (pure-logic mirror of the same chain — used by QA)
3. Run `fake_data_gen.py --mode quick` to verify fix
4. Update version comment at top of .bas file

### Add a New Center to the Generator
Add to the `CENTERS` dict in `generate_year_data.py`:
```python
"newcenter": {
    "name": "Phoenix, AZ",
    "seed": 20241201,   # unique seed for reproducibility
    "managers": ["Manager, Name", ...],
    "staff": [
        ("505XXXXX", "LastName, First", "ROLE", "H:MMAM - H:MMPM", [weekdays], tardy_mult),
        ...  # 15 employees typical
    ],
},
```

### Rebuild Control Panel Buttons After Import
Open the workbook, press Alt+F11, run `SetupControlPanel` in the Immediate Window, or assign it to a temporary button.

### Distribute to a New Center (Full Workflow)
1. `python3 create_blank_template.py <current_tracker.xlsm>`
2. Email `Example Workplace_Attendance_Tracker_TEMPLATE.xlsm`
3. Receiver opens → clicks "Setup New Center" → enters their city/state
4. They use "Import All 3 Files" → "Run Attendance Check"
5. Results appear in 5 output tabs

## Key Technical Notes

- **TAFW file structure**: banner rows (week headers), then employee rows with schedule + TAFW codes in columns 3-9 (Sun-Sat), location in col 10, week-start date in col 11
- **InStr behavior**: `InStr("anything", "") = 1` in VBA — blank center name safely passes all rows
- **Scripting.Dictionary**: used for fast lookups (dictSched, dictTAFW2, dictPunch, dictChg, dictUni)
- **openpyxl**: `keep_vba=True` required when opening .xlsm files to preserve macros
- **FMLA rate**: fixed at ~0.5% in the generator (was incorrectly 12.2% before)
- **Tardy threshold**: `tardy_mult` personality multiplier scales probability per employee
- **Control Panel stats (rows 5-11)**: written by `RefreshControlPanel` — col B = label, col C = value

## Version History
- v4.0: Merged Basel's punch analyzer features (MISMATCH detection, diacritics normalization)
- v4.1: Bug fixes (BUG-1 MISMATCH clears tardy, BUG-2 daily span hours)
- v4.3: SimClassify, PopulateEmployeeMaster, RefreshControlPanel, PA Queue headers
- v5.0 VBA additions: ImportFileIntoRAW, SetupNewCenter, SetupControlPanel, ExportSummaryReport, AddCPButton, ClearAllDataTabs

## Directions Document Location
Directions should be a separate attachment (not embedded in the workbook).
Use `WriteDirections` VBA sub to generate a formatted "Directions" sheet in the workbook,
or export it as PDF via `ExportSummaryReport`.
