# Project: SurvivorsClone (Inritus) Modernization & Antigravity 2.0 Upgrade

## Architecture
- **Engine**: Godot 4.6 (Mobile profile / Compatibility), Headless CLI capable.
- **Autoload Singletons**:
  - `UpgradeDb` (`res://Utility/upgrade_db.tscn` / `upgrade_db.gd`): Database of all weapons, passives, and upgrades.
  - `GlobalEvents` (`res://Utility/global_events.gd`): Event hub, difficulty scaling enum, character definitions, run stats.
  - `MusicController` (`res://Utility/music_controller.gd`): Dual-player crossfade music system.
  - `SettingsManager` (`res://Utility/SettingsManager.gd`): Persistent configuration management.
  - `StatsManager` (`res://Utility/StatsManager.gd`): Run statistics tracker.
- **Core Systems**:
  - `Player` (`res://Player/player.gd`): Stat calculation, modifier stacking, leveling curve, armor diminishing returns.
  - `EnemySpawner` (`res://Utility/enemy_spawner.gd`): Wave management, difficulty scaling formulas, boss HP exponentiation.
  - `SwarmManager` (`res://Utility/swarm_manager.gd`): MultiMesh mass enemy renderer handling easy/normal pools; requires Layer 3 / Bit 2 (value 4) and child `CollisionShape2D` for attacker compatibility.
  - `EnemyBase` (`res://Enemy/Base/enemy_body.gd`): Elites and single-node enemy behaviors.
  - `BossAI` (`res://Enemy/Boss/boss.gd`, `res://Enemy/Boss/dr_franklin.gd`): Boss state machines.
- **Test Architecture (`res://Tests/`)**:
  - Zero-dependency, YAGNI-compliant test framework extending `SceneTree`.
  - Headless execution via `godot --headless -s res://Tests/test_runner.gd`.
  - Return code 0 on all tests pass, 1 on any test failure.
- **Antigravity Skills Suite (`.agents/skills/`)**:
  - Modular skills following `SKILL.md` specifications with YAML frontmatter.
  - Accompanying Python CLI validation and simulation tools (`validate_translations.py`, `balance_eval.py`).

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R1-F1: Headless Test Runner CLI | `test_runner.gd` extending `SceneTree` running all suites with 0/1 exit codes | M1 | explorer_survey_1 |
| 2 | R1-F2: Test Base Assertion Suite | `test_base.gd` providing assertions (`assert_eq`, `assert_true`, `assert_almost_eq`, `assert_has`) | M1 | explorer_survey_1 |
| 3 | R1-F3: UpgradeDb Integrity Tests | `test_upgrade_db.gd` testing schema, 12 weapons, passives, endless tiers, prerequisites | M1 | explorer_survey_1 |
| 4 | R1-F4: Player Stat Calculation Tests | `test_player_stats.gd` testing XP curves, level rollover, stat modifiers, armor DR, endless items | M1 | explorer_survey_1 |
| 5 | R1-F5: Difficulty & Scaling Tests | `test_difficulty_scaling.gd` testing difficulty enum, spawn/HP/XP multipliers, slot constraints, boss HP curve | M1 | explorer_survey_1 |
| 6 | R2-F1: Enshrine YAGNI in GEMINI.md | Explicit Rule 19 defining YAGNI, anti-over-engineering, and pragmatic design | M2 | explorer_survey_2 |
| 7 | R2-F2: Modernize GEMINI.md | Update title to Inritus v1.0.4, correct paths (`Enemy/Base/`, `Enemy/Boss/`), document 12 weapons and SwarmManager | M2 | explorer_survey_2 |
| 8 | R2-F3: Professional README.md | Rewrite README to detail architecture, singletons, swarm system, testing CLI, and Antigravity standards | M2 | explorer_survey_2 |
| 9 | R2-F4: Synchronize tech_debt.md | Document 5+ uncovered debts (MultiMesh shader injection, audio starvation, ghost character, CSV line 30, RTX 10fps, spawner discontinuity) | M2 | explorer_survey_2 |
| 10 | R3-F1: Skill weapon-scaffolder | `weapon-scaffolder/SKILL.md` + templates conforming to Layer 3, CollisionShape2D, PhasedAnimator | M3 | explorer_survey_3 |
| 11 | R3-F2: Skill localization-validator | `localization-validator/SKILL.md` + Python CLI `validate_translations.py` validating CSV columns/keys | M3 | explorer_survey_3 |
| 12 | R3-F3: Fix translations.csv Defect | Correct line 30 missing columns, missing `lang_ukrainian`, ensure clean validator exit | M3 | explorer_survey_3 |
| 13 | R3-F4: Skill tech-debt-auditor | `tech-debt-auditor/SKILL.md` codifying systematic debt verification | M3 | explorer_survey_3 |
| 14 | R3-F5: Skill game-balance-eval | `game-balance-eval/SKILL.md` + Python CLI `balance_eval.py` modeling DPS and HP scaling | M3 | explorer_survey_3 |
| 15 | R4-F1: Repository Clutter Cleanup | Remove `menu.tscn117201879.tmp`, `Audio/desktop.ini`, `Textures/desktop.ini` | M4 | explorer_survey_2 |
| 16 | R4-F2: GPL-3.0 License Compliance | Ensure SPDX license headers on new code, document asset licenses | M4 | explorer_survey_2 |
| 17 | E2E-F1: Full CLI Verification & Gate | Run test runner headlessly, run localization validator, verify balance eval, verify repo hygiene | M5 | orchestrator_1 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Headless Godot 4.6 Unit Testing Suite (R1) | R1-F1, R1-F2, R1-F3, R1-F4, R1-F5 | none | DONE (35 tests, 2171 assertions pass, exit 0) |
| M2 | Documentation, Tech Debt & YAGNI Standard (R2) | R2-F1, R2-F2, R2-F3, R2-F4 | none | DONE (GEMINI.md Rule 19 YAGNI, README, tech_debt) |
| M3 | Project-Specific Antigravity Skills Suite (R3) | R3-F1, R3-F2, R3-F3, R3-F4, R3-F5 | none | DONE (4 skills, translations.csv fix, exit 0) |
| M4 | Repository & License Compliance (R4) | R4-F1, R4-F2 | none | DONE (Clutter purged, ATTRIBUTION.md, GPL-3.0) |
| M5 | E2E CLI Acceptance & Verification Suite | E2E-F1 (Run all CLI suites, verify exit codes, audit integrity) | M1, M2, M3, M4 | DONE (Gate passed, auditor CLEAN) |

## Interface Contracts
### Test Runner CLI ↔ Operating System / CI
- **Invocation**: `godot --headless -s res://Tests/test_runner.gd`
- **Output**: Formatted standard output with test names, assertion counts, execution duration.
- **Exit Code**: `0` if all tests pass; `1` if any test fails.

### Antigravity Skills ↔ Workspace
- **Directory**: `.agents/skills/<skill-name>/`
- **Entry point**: `SKILL.md` with YAML frontmatter (`name`, `description`, `tags`, `tools`).
- **CLI Utilities**:
  - `.agents/skills/localization-validator/validate_translations.py` executed via `python .agents/skills/localization-validator/validate_translations.py --csv translations/translations.csv`
  - `.agents/skills/game-balance-eval/balance_eval.py` executed via `python .agents/skills/game-balance-eval/balance_eval.py`

### Weapon Scaffolder ↔ Engine Rules
- Collision Layer: `4` (Layer 3 / Bit 2, Value 4).
- Collision Mask: `0`.
- Group: `["attack"]`.
- Required Child Node: `CollisionShape2D`.
- Spawner: `res://Player/Attack/<name>/<name>_spawner.gd` extending `Node2D`.
- Upgrades: 4 normal tiers + 1 endless tier registered in `UpgradeDb.UPGRADES`.

## Code Layout
- `res://Tests/`:
  - `test_runner.gd` (SceneTree runner)
  - `test_base.gd` (minimal assertion base)
  - `Unit/test_upgrade_db.gd`
  - `Unit/test_player_stats.gd`
  - `Unit/test_difficulty_scaling.gd`
- `.agents/skills/`:
  - `weapon-scaffolder/SKILL.md`
  - `localization-validator/SKILL.md`, `localization-validator/validate_translations.py`
  - `tech-debt-auditor/SKILL.md`
  - `game-balance-eval/SKILL.md`, `game-balance-eval/balance_eval.py`
- Root & Documentation:
  - `GEMINI.md`: Enshrined Rule 19 (YAGNI), corrected paths and weapon counts
  - `README.md`: Comprehensive modernization
  - `tech_debt.md`: Updated debt items
  - `translations/translations.csv`: Corrected line 30 and missing keys
