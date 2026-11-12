---
name: localization-validator
description: Validates translations.csv for structural integrity, 4-column RFC 4180 compliance, missing keys, empty cells, and character set integrity across English, Russian, and Ukrainian.
---

# Localization Validator Skill

## Overview
The `localization-validator` skill provides automated and systematic validation of localization data in the SurvivorsClone Godot 4.6 project. The game supports three active languages:
- **English (`en`)**
- **Russian (`ru`)**
- **Ukrainian (`ua`)**

All user-facing strings are stored in `translations/translations.csv` with a 4-column schema (`"keys","en","ru","ua"`), imported and compiled into Godot binary translation tables (`.translation`).

This skill guarantees that:
1. Every row strictly adheres to the 4-column structure without column mismatches.
2. No duplicate keys exist.
3. No cells contain empty strings or placeholder tokens (`TODO`, `UNTRANSLATED`).
4. Cross-language leakage (e.g. Russian-exclusive characters in Ukrainian text) is detected and flagged.
5. All localization keys referenced in GDScript (`tr("...")`) or `UpgradeDb` exist in the CSV.

## Triggers & When to Use
Invoke this skill whenever:
- Adding a new weapon, character, item, or UI feature that introduces localization keys.
- Modifying `translations/translations.csv`.
- Preparing a release or running automated CI/pre-commit verification.
- Auditing the project for untranslated strings or formatting corruption.

## Prerequisites & Dependencies
- **Python 3.x** installed and accessible via CLI.
- No external Python dependencies required (pure standard library: `csv`, `re`, `argparse`, `sys`, `pathlib`, `json`).
- Path to translation file: `res://translations/translations.csv`.

## Step-by-Step Execution Workflow

### Step 1: Run Static CSV Integrity Validation
Run the validator CLI tool directly from the repository root:
```bash
python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv
```
Verify the output:
- `Total Entries`: Count of valid localized keys.
- `Errors`: Must be `0`.
- `Warnings`: Must be `0` for production-ready releases.
- Exit code must be `0`.

### Step 2: Codebase Reference Audit
To ensure no localization keys used in scripts are missing from the CSV, execute with codebase scanning enabled:
```bash
python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv --code-dir .
```

### Step 3: CI / Machine-Readable Mode
When running inside CI pipelines or multi-agent orchestrations, pass `--json` to receive structured JSON output:
```bash
python .agents/skills/localization-validator/validate_translations.py --json
```

### Step 4: Adding New Localization Entries
When adding a new key, append it to `translations/translations.csv` using double-quoted CSV RFC 4180 format:
```csv
"my_new_key","English text","Русский текст","Український текст"
```
Rules to maintain:
1. Always supply all 4 columns: `keys`, `en`, `ru`, `ua`.
2. Wrap each field in double quotes `""`. If the text contains quotation marks, escape them by doubling (`""`).
3. For Ukrainian strings, use proper Ukrainian orthography (`і`, `ї`, `є`, `ґ`). Do not copy Russian Cyrillic characters (`ы`, `э`, `ъ`, `ё`).
4. Verify with `validate_translations.py` immediately after editing.

## Script Architecture & CLI Flags
The companion script `validate_translations.py` exposes:
- `--csv <path>`: Specify custom path to CSV file.
- `--code-dir <path>`: Directory containing `.gd` and `.tscn` files to check against.
- `--strict-leakage`: Promote alphabet leakage warnings to fatal errors.
- `--json`: Format report as JSON.

## Verification & Acceptance Checklist
- [ ] Command exits cleanly with return code `0`.
- [ ] No column count errors reported.
- [ ] No empty translations or placeholder tags (`TODO`, `FIXME`).
- [ ] Godot imports `.translation` files without engine parser warnings.
