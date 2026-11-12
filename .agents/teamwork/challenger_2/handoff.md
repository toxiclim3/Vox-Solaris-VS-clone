# Handoff Report: Skills Suite & Tooling Adversarial Challenge

**Author**: Skills and Tooling Challenger (`challenger_2`)  
**Date**: 2026-10-06  
**Type**: Hard (Task Complete)  
**Milestone**: Milestone 3 / R3 Skills Suite Adversarial Review  
**Verdict**: **REJECT (Conditional)** — `balance_eval.py` has a confirmed defect rejecting `--difficulty custom`; `validate_translations.py` and `scaffold_weapon.py` are **CONFIRMED ROBUST**.

---

## 1. Observation

### Obs 1: `validate_translations.py` Empirical Verification
Executed against current production translation CSV:
```powershell
python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv
```
**Result**: Exit code `0`. Output:
```text
=== Localization Validation Report ===
CSV Path: translations\translations.csv
Total Entries: 295
Errors: 0
Warnings: 0

[OK] Status: CLEAN - Translations validation passed successfully.
```
Executed with codebase scanning and JSON output:
```powershell
python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv --code-dir . --json
```
**Result**: Exit code `0`. Output:
```json
{
  "passed": true,
  "total_rows": 295,
  "total_unique_keys": 295,
  "errors_count": 0,
  "warnings_count": 0,
  "errors": [],
  "warnings": []
}
```

### Obs 2: `validate_translations.py` Synthetic Negative Testing
Tested with 11 synthetic corrupt CSV scenarios generated in memory:
1. **Missing column (3 cols)**: Output contains `"Line 2: Column count mismatch. Expected 4 columns, got 3: ['item_test', 'Test', 'Тест']"`, Exit code `1`.
2. **Extra column (5 cols)**: Output contains `"Line 2: Column count mismatch. Expected 4 columns, got 5"`, Exit code `1`.
3. **Empty localization key**: Output contains `"Line 2: Empty localization key."`, Exit code `1`.
4. **Missing Russian translation**: Output contains `"Line 2 (key 'item_test'): Missing Russian translation."`, Exit code `1`.
5. **Missing Ukrainian translation**: Output contains `"Line 2 (key 'item_test'): Missing Ukrainian translation."`, Exit code `1`.
6. **Missing English translation**: Output contains `"Line 2 (key 'item_test'): Missing English translation."`, Exit code `1`.
7. **Duplicate key**: Output contains `"Line 3: Duplicate key 'item_test' (previously defined on line 2)."`, Exit code `1`.
8. **Empty CSV (0 bytes)**: Output contains `"CSV file is empty."`, Exit code `1`.
9. **Header mismatch**: Output contains `"Header mismatch. Expected ['keys', 'en', 'ru', 'ua'], got ['key', 'english', 'russian', 'ukrainian']"`, Exit code `1`.
10. **Unquoted comma in field**: Output contains `"Line 2: Column count mismatch. Expected 4 columns, got 5"`, Exit code `1`.
11. **Ukrainian text with Russian Cyrillic `ы` + `--strict-leakage`**: Output contains `"Line 2 (key 'item_test'): Ukrainian translation contains Russian-exclusive character(s): 'Текст с ы'"`, Exit code `1`.
12. **Ukrainian text with Russian Cyrillic `ы` without `--strict-leakage`**: Output contains warning, Exit code `0`.

### Obs 3: `balance_eval.py` Defect with Custom Difficulty
Tested all difficulty options:
- `python .agents/skills/game-balance-eval/balance_eval.py --difficulty easy` -> Exit code `0`.
- `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal` -> Exit code `0`.
- `python .agents/skills/game-balance-eval/balance_eval.py --difficulty hard` -> Exit code `0`.
- `python .agents/skills/game-balance-eval/balance_eval.py --difficulty custom` -> **Exit code `2` (FAILURE)**.
  **Verbatim stderr**:
  ```text
  usage: balance_eval.py [-h] [--difficulty {easy,normal,hard}]
                         [--character {mage,occultist,plague_doctor,punished}]
                         [--weapons WEAPONS] [--minutes MINUTES] [--json]
  balance_eval.py: error: argument --difficulty: invalid choice: 'custom' (choose from 'easy', 'normal', 'hard')
  ```
Inspection of `.agents/skills/game-balance-eval/balance_eval.py`:
- Line 307:
  ```python
  parser.add_argument(
      "--difficulty",
      choices=["easy", "normal", "hard"],
      default="normal",
      help="Difficulty tier to evaluate (default: normal)",
  )
  ```
- Lines 24–52: `DIFFICULTY_MODS` contains only `"easy"`, `"normal"`, and `"hard"`. No `"custom"` key exists.
Inspection of `res://Utility/global_events.gd`:
- Line 95: `enum Difficulty { EASY, NORMAL, HARD, CUSTOM }`
- Lines 98–104:
  ```gdscript
  # Custom Difficulty Modifiers
  var custom_enemy_spawn_modifier: float = 1.0
  var custom_enemy_hp_modifier: float = 1.0
  var custom_boss_hp_modifier: float = 1.0
  var custom_player_regen_modifier: float = 1.0
  var custom_player_damage_modifier: float = 1.0
  var custom_xp_gain_modifier: float = 1.0
  ```

### Obs 4: `balance_eval.py` Character Classes and JSON Mode
- `python .agents/skills/game-balance-eval/balance_eval.py --character mage` -> Exit code `0`.
- `python .agents/skills/game-balance-eval/balance_eval.py --character occultist` -> Exit code `0`.
- `python .agents/skills/game-balance-eval/balance_eval.py --character plague_doctor` -> Exit code `0`.
- `python .agents/skills/game-balance-eval/balance_eval.py --character punished` -> Exit code `0`.
- `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal --json` -> Exit code `0`, produced valid JSON with keys `["difficulty", "character", "weapons", "total_minutes", "timeline", "alerts"]`.

### Obs 5: `scaffold_weapon.py` Dry-Run and Contract Verification
- Projectile dry-run (`python .agents/skills/weapon-scaffolder/scaffold_weapon.py test_proj --dry-run`):
  - Exit code `0`.
  - Collision layer: `collision_layer = 4` (Layer 3 / Bit 2 / Value 4) verified in scene and script.
  - Collision mask: `collision_mask = 0` verified.
  - Group: `groups=["attack"]` verified.
  - Swarm child node: `[node name="CollisionShape2D" type="CollisionShape2D" parent="."]` verified.
  - Exposed properties: `var damage: float = 15.0`, `var knockback_amount: float = 50.0` verified.
  - World space instantiation: `player.get_parent().add_child(proj)` verified.
  - Dynamic spawner cooldown: `timer.wait_time = attackspeed * (1.0 - player.spell_cooldown)` verified.
  - Burst ammo formula: includes Bernoulli check for fractional attacks (`randf() < (player.additional_attacks - extra_attacks)`).
  - 5-Tier UpgradeDb snippet: includes `test_proj1` through `test_proj4` and `test_proj_endless` with `type: "endless"` and prerequisites sequentially chained.
  - Translations snippet: 4 columns, RFC 4180 compliant.
- AOE dry-run (`python .agents/skills/weapon-scaffolder/scaffold_weapon.py test_aoe --type aoe --dry-run`):
  - Exit code `0`.
  - PhasedAnimator lifecycle (Rule 11):
    - `animator = PhasedAnimator.new()`
    - `animator.setup_phases(3, 4, 3)`
    - `animator.advance(is_expiring)`
    - Fade tween to avoid popping: `tween.tween_property(self, "modulate:a", 0.0, 0.2)`
- Custom CLI arguments:
  - Custom `--damage 88.5 --knockback 120.0 --speed 500.0 --cooldown 2.75 --ammo 3 --title "Heavy Cannon"` correctly mapped into generated files.

---

## 2. Logic Chain

1. From Obs 1 and Obs 2, `validate_translations.py` properly identifies the current `translations.csv` as clean (exit code 0), while correctly halting with exit code 1 across all 11 corruption modes (missing columns, unquoted commas, missing keys, empty values, duplicates, and alphabet leakage with `--strict-leakage`). The script demonstrates production-grade error handling.
2. From Obs 3, `GlobalEvents.gd` explicitly defines `Difficulty.CUSTOM` alongside `EASY`, `NORMAL`, and `HARD`. The dispatch instructions required: `"test with all difficulty levels (easy, normal, hard, custom)"`. Running `--difficulty custom` fails with exit code 2 because `balance_eval.py` restricts choices to `["easy", "normal", "hard"]` and lacks `"custom"` in `DIFFICULTY_MODS`. This represents an unhandled configuration edge case and an interface mismatch between the CLI simulator and engine architecture.
3. From Obs 4, character passives for all four classes (`mage`, `occultist`, `plague_doctor`, `punished`) evaluate cleanly, and `--json` outputs well-formed RFC 8259 JSON for CI pipelines.
4. From Obs 5, `scaffold_weapon.py` strictly complies with every project architecture contract: Rule 11 (PhasedAnimator for AOE), Rule 16 (Collision Layer 3 / Value 4), Rule 17 (named child node `CollisionShape2D`), SwarmManager damage/knockback properties, and 5-tier UpgradeDb registration.

---

## 3. Caveats

- In accordance with the Review-only constraint ("do NOT modify implementation code"), `balance_eval.py` was not patched directly. The required fix is documented below for the milestone worker.
- Dynamic boss warnings (e.g. `warning_boss_` string concatenations in GDScript) were accounted for in `validate_translations.py` warning filtering.

---

## 4. Conclusion & Verdict

**Overall Verdict**: **REJECT (Conditional)**

### Status Summary
| Component | Status | Verdict | Notes |
|---|---|---|---|
| `validate_translations.py` | 13/13 tests pass | **CONFIRM** | Robust against all synthetic corruption vectors |
| `balance_eval.py` | 8/9 tests pass | **REJECT** | **Bug**: `--difficulty custom` causes CLI error (exit code 2) |
| `scaffold_weapon.py` | 27/27 checks pass | **CONFIRM** | 100% compliant with Layer 3, CollisionShape2D, PhasedAnimator |
| Skills Documentation | 4/4 valid | **CONFIRM** | Valid YAML frontmatter and GPL-3.0 SPDX headers |

### Required Fix for `balance_eval.py`
In `.agents/skills/game-balance-eval/balance_eval.py`:
1. Add `"custom"` to `choices`:
   ```python
   parser.add_argument(
       "--difficulty",
       choices=["easy", "normal", "hard", "custom"],
       default="normal",
       help="Difficulty tier to evaluate (default: normal)",
   )
   ```
2. Add `"custom"` entry to `DIFFICULTY_MODS` (matching default 1.0 multipliers from `GlobalEvents.gd` lines 99–104):
   ```python
   "custom": {
       "enemy_hp": 1.0,
       "boss_hp": 1.0,
       "spawn_mod": 1.0,
       "xp_mod": 1.0,
       "player_regen": 1.0,
       "weapon_slots": 6,
       "upgrade_slots": 8,
   },
   ```

---

## 5. Verification Method

### Test 1: Reproduce Custom Difficulty Bug in `balance_eval.py`
```powershell
python .agents/skills/game-balance-eval/balance_eval.py --difficulty custom
```
*Current Result*: Exits with code 2 and error `invalid choice: 'custom'`.  
*Fix Invalidation Condition*: Exits with code 0 and displays simulation table or JSON output for custom difficulty.

### Test 2: Verify `validate_translations.py`
```powershell
python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv --code-dir . --json
```
*Expected Result*: Exit code 0, `errors_count: 0`.

### Test 3: Verify `scaffold_weapon.py` Dry-Run
```powershell
python .agents/skills/weapon-scaffolder/scaffold_weapon.py frost_orb --dry-run
python .agents/skills/weapon-scaffolder/scaffold_weapon.py poison_cloud --type aoe --dry-run
```
*Expected Result*: Exit code 0, outputs Layer 3 collision (4), `CollisionShape2D`, and `PhasedAnimator` lifecycle.
