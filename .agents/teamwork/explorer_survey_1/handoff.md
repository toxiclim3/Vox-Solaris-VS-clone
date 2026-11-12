# Handoff Report: Codebase Testing Architecture Survey (R1)

**Agent**: `explorer_survey_1` (Codebase Testing Explorer)  
**Recipient**: `orchestrator_1` / Implementer Agent  
**Date**: 2026-10-06  
**Milestone**: Architecture Survey (R1 Headless Godot 4.6 Unit Testing Suite)

---

## 1. Observation

1. **Godot Configuration & Executable**:
   - `project.godot`: Lines 18-20 specify `config/version="1.0.4"`, `config/features=PackedStringArray("4.6", "Mobile")`.
   - `GEMINI.md`: Rule 9 specifies `Python is available: Python is installed on the host machine, and so is pillow, ffmpeg, and godot (as in, added to PATH)`.
   - Autoload singletons in `project.godot` (lines 28-32):
     ```ini
     UpgradeDb="*res://Utility/upgrade_db.tscn"
     GlobalEvents="*uid://cfmtka6m73iiv"
     MusicController="*uid://b8x5a6sgnm38g"
     SettingsManager="*uid://dafqqanwiwjho"
     StatsManager="*res://Utility/StatsManager.gd"
     ```
2. **Player Math & Stat Formulas (`res://Player/player.gd`)**:
   - Base stats: `base_maxhp = 80` (line 4), `base_movement_speed = 75.0` (line 38), `base_armor = 0` (line 36), `base_spell_cooldown = 0.0` (line 40), `base_spell_size = 0.0` (line 42), `base_additional_attacks = 0.0` (line 44), `base_regenPerSecond = 0.5 / 100` (line 7), `BASE_GRAB_RADIUS = 50.0` (line 48).
   - Experience curve in `calculate_experiencecap()` (lines 348-366):
     ```gdscript
     func calculate_experiencecap():
         var lvl = experience_level
         if lvl == 1: return 5
         elif lvl == 2: return 10
         elif lvl == 3: return 15
         elif lvl == 4: return 30
         elif lvl == 5: return 50
         elif lvl == 6: return 75
         elif lvl == 7: return 110
         elif lvl == 8: return 130
         elif lvl == 9: return 150
         elif lvl == 10: return 200
         elif lvl < 20:
             return 200 + (lvl - 10) * 250
         else:
             return 2700 + (lvl - 20) * 400
     ```
   - Armor Diminishing Returns damage reduction formula in `_on_hurt_box_hurt()` (lines 241-242):
     ```gdscript
     var dr = float(armor) / (armor + 40.0)
     var actual_damage = damage * (1.0 - dr)
     ```
   - Stat modifier formula in `apply_stat_modifiers()` (lines 426-530):
     - `movement_speed = base_movement_speed * (1.0 + movement_speed_percent_total)`
     - `armor = int(armor * (1.0 + armor_multiplier))`
     - `new_maxhp = int(base_maxhp * (1.0 + max_hp_percent_total))`
     - `grab_shape.shape.radius = BASE_GRAB_RADIUS * (1.0 + xp_range_percent_total)`
   - Node references in `apply_stat_modifiers()`:
     - `healthBar.max_value = maxhp`, `healthBar.value = hp` (lines 523-524)
     - `grab_shape.shape.radius = ...` (line 527)
     - `attack()` invokes `for weapon in weapons.get_children()` (lines 214-217)
3. **Upgrade Database Structure (`res://Utility/upgrade_db.gd`)**:
   - Schema defined as `const UPGRADES: Dictionary` (lines 6-870). Contains zero functions.
   - Types used across entries: `"weapon"`, `"upgrade"`, `"bossitem"`, `"item"`, `"endless"`.
   - Every entry has keys `"icon"`, `"displayname"`, `"details"`, `"level"`, `"prerequisite"`, `"type"`, and optional `"stat_modifiers"`.
4. **Global Events & Progression (`res://Utility/global_events.gd` & `res://Utility/enemy_spawner.gd`)**:
   - `Difficulty` enum (line 95): `enum Difficulty { EASY, NORMAL, HARD, CUSTOM }`.
   - Modifiers in `global_events.gd` (lines 128-177):
     - Spawn modifier: EASY=0.8, NORMAL=1.0, HARD=1.2
     - Enemy HP modifier: EASY=0.8, NORMAL=1.0, HARD=1.2
     - Boss HP modifier: EASY=0.8, NORMAL=1.0, HARD=1.2
     - Player regen modifier: EASY=1.5, NORMAL=1.0, HARD=1.0
     - XP gain modifier: EASY=1.2, NORMAL=1.0, HARD=0.8
     - Weapon slots: HARD=5, default=6
     - Upgrade slots: HARD=6, default=8
   - Boss HP multiplier formula (`enemy_spawner.gd` lines 262-264):
     $$\text{pow}(1.05, \text{minutes}) \times \text{GlobalEvents.get\_boss\_hp\_modifier()}$$
   - Enemy Intensity formula (`enemy_spawner.gd` lines 186-193):
     - $t \le 1.0$: $3.0$
     - $1.0 < t \le 3.0$: $3.0 + 0.75 \times t^2$
     - $t > 3.0$: $4.5 + 1.5 \times t$
5. **No Existing Addons or Testing Frameworks**:
   - Directory search for `*gut*` and `addons/` returned 0 results. No test framework currently exists in the repository.

---

## 2. Logic Chain

1. **Premise 1 (Headless CLI Compatibility)**:
   - Godot 4.6 CLI supports executing scripts headlessly using the syntax `godot --headless -s <script.gd>`.
   - In Godot, a script passed to `-s` must inherit from `MainLoop` or `SceneTree`.
   - `SceneTree` includes the `quit(exit_code: int)` method, which directly sets the process return code (`0` for pass, `1` for fail).
   - *Inference*: A test runner script inheriting from `SceneTree` satisfies Acceptance Criterion R1 without external dependencies.
2. **Premise 2 (Zero-Dependency & YAGNI Principle)**:
   - Installing third-party frameworks like GUT brings unnecessary bloat (dozens of addon files, GUI plugins, configuration formats) that violate YAGNI.
   - The systems under test (`UpgradeDb`, `Player` formulas, `GlobalEvents` difficulty getters) are deterministic, non-visual, and synchronous.
   - *Inference*: A clean, lightweight test runner (`test_runner.gd`) and base test class (`test_base.gd`) totaling fewer than 200 lines of GDScript is fully sufficient, robust, and maintains repository cleanliness.
3. **Premise 3 (Isolation & Decoupling of Player Logic)**:
   - In `res://Player/player.gd`, math routines (`calculate_experiencecap`, `calculate_experience`, `apply_stat_modifiers`) are coupled to nodes via `@onready` properties (`healthBar`, `grab_shape`, `weapons`, `gui`).
   - If `Player.new()` is instantiated directly in GDScript without calling `add_child()`:
     - `_ready()` does not execute (avoiding GUI, audio, and raytracing crashes).
     - `@onready` fields can be assigned to lightweight mock nodes (`Range.new()`, `CollisionShape2D.new()`, `Node2D.new()`).
   - *Inference*: Player stat calculations, leveling, and modifier stacking can be tested headlessly with zero UI/audio dependencies and zero flakiness.
4. **Premise 4 (UpgradeDb Integrity Verification)**:
   - `UpgradeDb.UPGRADES` is a static constant dictionary.
   - All entries can be validated via programmatic assertions checking schema completeness, DAG properties (no prerequisite cycles), valid prerequisite keys, and translation key correspondence in `translations.csv`.
   - *Inference*: Complete database integrity verification can execute in under 50ms headlessly.

---

## 3. Caveats

1. **Terminal Command Interactive Approvals**: In this environment, interactive tool calls to `run_command` trigger interactive user permission prompts that time out if the user is unavailable. Headless CLI test execution must be verified when the user is available or by running the command in the background / interactive session.
2. **Discontinuity in Enemy Intensity Curve**: At exactly $t = 3.0$ minutes, the quadratic formula yields $3.0 + 0.75 \times 9 = 9.75$, while the linear formula yields $4.5 + 1.5 \times 3 = 9.0$. Tests should verify the formula as implemented in `enemy_spawner.gd` rather than assuming mathematical continuity.
3. **Endless Rejuvenation Ring Stat Key**: In `upgrade_db.gd` line 821, `ringofrejuvenation_endless` has `"stat_modifiers": {"hp": 5}`, whereas `player.gd` line 508 applies `max_hp_percent_total += 0.05 * count`. This inconsistency should be documented in `tech_debt.md` and handled gracefully in test assertions.

---

## 4. Conclusion

1. **Architecture Formulation**: The recommended unit test suite structure is:
   - `res://Tests/test_runner.gd`: CLI entry point extending `SceneTree`. Runs all suites, aggregates counts, exits with `quit(0)` or `quit(1)`.
   - `res://Tests/test_base.gd`: Minimal assertion helpers (`assert_eq`, `assert_true`, `assert_almost_eq`, `assert_has`).
   - `res://Tests/Unit/test_upgrade_db.gd`: Schema, prerequisites, types, and translation key validation.
   - `res://Tests/Unit/test_player_stats.gd`: XP cap curves, multi-level rollover, modifier formulas, armor DR diminishing returns, character scaling, and endless stacking.
   - `res://Tests/Unit/test_difficulty_scaling.gd`: Difficulty cycling, spawn/HP/XP modifiers, slot constraints, and boss/enemy scaling formulas.
2. **Pragmatism & Compliance**: This architecture is 100% YAGNI-compliant, GPL-3.0 compliant, requires zero external plugins or addons, and executes headlessly via standard Godot CLI syntax:
   `godot --headless -s res://Tests/test_runner.gd`.

---

## 5. Verification Method

1. **File Review**:
   - Inspect `.agents/teamwork/explorer_survey_1/survey_report.md` for complete formulas, line citations, and test plans.
   - Inspect `project.godot` to verify Godot 4.6 configuration and autoload setup.
2. **Test Suite Execution (Upon Implementation)**:
   - Run command:
     ```powershell
     godot --headless -s res://Tests/test_runner.gd
     ```
   - Check exit code in PowerShell:
     ```powershell
     $LASTEXITCODE
     ```
   - Invalidation condition: Exit code non-zero, unhandled exceptions on `@onready` variables, or missing prerequisite crashes.
