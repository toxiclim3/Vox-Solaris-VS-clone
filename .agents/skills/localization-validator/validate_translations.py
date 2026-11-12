#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2024-2026 SurvivorsClone Contributors
"""
Localization Validation CLI Tool for SurvivorsClone.

Validates translations.csv for:
- CSV structure and RFC 4180 compliance
- Column count consistency across all rows (keys, en, ru, ua)
- Key uniqueness and formatting
- Missing or untranslated entries
- Codebase key coverage against .gd and .tscn source files
- Alphabet integrity / character leakage between languages
"""

import argparse
import csv
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple


REQUIRED_COLUMNS = ["keys", "en", "ru", "ua"]

# Cyrillic characters exclusive to Ukrainian
UKRAINIAN_EXCLUSIVE = set("іїєґІЇЄҐ")
# Cyrillic characters exclusive to Russian
RUSSIAN_EXCLUSIVE = set("ыэъёЫЭЪЁ")


class LocalizationValidator:
    def __init__(self, csv_path: str, code_dir: str = None, strict_leakage: bool = False):
        self.csv_path = Path(csv_path)
        self.code_dir = Path(code_dir) if code_dir else None
        self.strict_leakage = strict_leakage
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.keys_in_csv: Set[str] = set()
        self.row_count = 0

    def validate_csv_structure(self) -> bool:
        if not self.csv_path.exists():
            self.errors.append(f"CSV file not found: {self.csv_path}")
            return False

        try:
            with open(self.csv_path, mode="r", encoding="utf-8-sig", newline="") as f:
                reader = csv.reader(f)
                header = next(reader, None)

                if not header:
                    self.errors.append("CSV file is empty.")
                    return False

                header_normalized = [c.strip().lower() for c in header]
                if header_normalized != REQUIRED_COLUMNS:
                    self.errors.append(
                        f"Header mismatch. Expected {REQUIRED_COLUMNS}, got {header_normalized}"
                    )

                seen_keys: Dict[str, int] = {}
                line_idx = 1  # 1-based, header was line 1

                for row in reader:
                    line_idx += 1
                    self.row_count += 1

                    # Ignore trailing completely empty lines
                    if not row or (len(row) == 1 and not row[0].strip()):
                        continue

                    if len(row) != len(REQUIRED_COLUMNS):
                        self.errors.append(
                            f"Line {line_idx}: Column count mismatch. "
                            f"Expected {len(REQUIRED_COLUMNS)} columns, got {len(row)}: {row}"
                        )
                        continue

                    key = row[0].strip()
                    if not key:
                        self.errors.append(f"Line {line_idx}: Empty localization key.")
                        continue

                    if key in seen_keys:
                        self.errors.append(
                            f"Line {line_idx}: Duplicate key '{key}' (previously defined on line {seen_keys[key]})."
                        )
                    else:
                        seen_keys[key] = line_idx
                        self.keys_in_csv.add(key)

                    en_val = row[1].strip()
                    ru_val = row[2].strip()
                    ua_val = row[3].strip()

                    # Check for empty or placeholder translations
                    if not en_val:
                        self.errors.append(f"Line {line_idx} (key '{key}'): Missing English translation.")
                    if not ru_val:
                        self.errors.append(f"Line {line_idx} (key '{key}'): Missing Russian translation.")
                    if not ua_val:
                        self.errors.append(f"Line {line_idx} (key '{key}'): Missing Ukrainian translation.")

                    for col_name, val in [("en", en_val), ("ru", ru_val), ("ua", ua_val)]:
                        if val.upper() in ["TODO", "FIXME", "UNTRANSLATED", "TBD"]:
                            self.warnings.append(
                                f"Line {line_idx} (key '{key}'): Column '{col_name}' contains placeholder '{val}'."
                            )

                    # Alphabet leakage checks (warnings by default, errors if strict)
                    if any(c in RUSSIAN_EXCLUSIVE for c in ua_val):
                        msg = f"Line {line_idx} (key '{key}'): Ukrainian translation contains Russian-exclusive character(s): '{ua_val}'"
                        if self.strict_leakage:
                            self.errors.append(msg)
                        else:
                            self.warnings.append(msg)

                    if any(c in UKRAINIAN_EXCLUSIVE for c in ru_val):
                        msg = f"Line {line_idx} (key '{key}'): Russian translation contains Ukrainian-exclusive character(s): '{ru_val}'"
                        if self.strict_leakage:
                            self.errors.append(msg)
                        else:
                            self.warnings.append(msg)

        except Exception as e:
            self.errors.append(f"Failed to read CSV: {str(e)}")
            return False

        return len(self.errors) == 0

    def scan_codebase_keys(self) -> None:
        if not self.code_dir or not self.code_dir.exists():
            return

        code_keys: Set[str] = set()
        key_pattern = re.compile(r'tr\(\s*["\']([a-zA-Z0-9_]+)["\']\s*\)')
        upgrade_key_pattern = re.compile(r'["\'](?:displayname|details|level)["\']\s*:\s*["\']([a-zA-Z0-9_]+)["\']')

        for root, dirs, files in os.walk(self.code_dir):
            # Skip VCS and agent metadata folders
            dirs[:] = [d for d in dirs if d not in [".git", ".godot", ".agents", "addons", ".import"]]
            for fname in files:
                if fname.endswith((".gd", ".tscn")):
                    fpath = Path(root) / fname
                    try:
                        content = fpath.read_text(encoding="utf-8", errors="ignore")
                        for match in key_pattern.finditer(content):
                            code_keys.add(match.group(1))
                        for match in upgrade_key_pattern.finditer(content):
                            val = match.group(1)
                            # Filter out non-translation strings (like direct weapon names if not keys)
                            if val.startswith(("item_", "ItemDesc_", "char_", "ui_")):
                                code_keys.add(val)
                    except Exception as e:
                        self.warnings.append(f"Could not read {fpath}: {e}")

        # Check for code keys missing from CSV
        # Note: dynamically constructed keys (e.g. "warning_boss_" + name) may need prefix matching
        missing_in_csv = []
        for k in sorted(code_keys):
            if k not in self.keys_in_csv:
                missing_in_csv.append(k)

        if missing_in_csv:
            # Report missing code keys as warnings or errors
            for k in missing_in_csv:
                self.warnings.append(f"Key '{k}' is referenced in codebase but missing from translations.csv.")

    def run(self) -> Tuple[bool, Dict]:
        self.validate_csv_structure()
        if self.code_dir:
            self.scan_codebase_keys()

        passed = len(self.errors) == 0
        summary = {
            "passed": passed,
            "total_rows": self.row_count,
            "total_unique_keys": len(self.keys_in_csv),
            "errors_count": len(self.errors),
            "warnings_count": len(self.warnings),
            "errors": self.errors,
            "warnings": self.warnings,
        }
        return passed, summary


def main():
    parser = argparse.ArgumentParser(
        description="Validate translations.csv for SurvivorsClone Godot project."
    )
    parser.add_argument(
        "--csv",
        type=str,
        default="translations/translations.csv",
        help="Path to translations.csv (default: translations/translations.csv)",
    )
    parser.add_argument(
        "--code-dir",
        type=str,
        default=None,
        help="Optional path to source directory to check key references in .gd and .tscn files.",
    )
    parser.add_argument(
        "--strict-leakage",
        action="store_true",
        help="Treat character set / alphabet leakages as fatal errors instead of warnings.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results in JSON format.",
    )

    # Ensure utf-8 output in Windows terminals
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    args = parser.parse_args()

    # Normalize path relative to repo root if possible
    csv_path = Path(args.csv)
    if not csv_path.exists():
        # Try resolving relative to workspace root
        script_dir = Path(__file__).resolve().parent
        repo_root = script_dir.parents[2]  # .agents/skills/localization-validator -> repo root
        candidate = repo_root / args.csv
        if candidate.exists():
            csv_path = candidate

    validator = LocalizationValidator(
        csv_path=str(csv_path),
        code_dir=args.code_dir,
        strict_leakage=args.strict_leakage,
    )

    passed, summary = validator.run()

    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
    else:
        print("=== Localization Validation Report ===")
        print(f"CSV Path: {csv_path}")
        print(f"Total Entries: {summary['total_unique_keys']}")
        print(f"Errors: {summary['errors_count']}")
        print(f"Warnings: {summary['warnings_count']}")

        if summary["errors"]:
            print("\n[ERRORS]")
            for err in summary["errors"]:
                print(f"  [X] {err}")

        if summary["warnings"]:
            print("\n[WARNINGS]")
            for warn in summary["warnings"]:
                print(f"  [!] {warn}")

        if passed:
            print("\n[OK] Status: CLEAN - Translations validation passed successfully.")
        else:
            print("\n[FAIL] Status: FAILED - Translation errors must be corrected.")

    sys.exit(0 if passed else 1)


if __name__ == "__main__":
    main()
