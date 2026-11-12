# Project: Inritus (SurvivorsClone) v2 Balance Framework & Health-Based Items

## Architecture
- **Engine**: Godot 4.6 (Mobile / Compatibility profile, Headless CLI capable).
- **Core Singletons**:
  - `UpgradeDb` (`res://Utility/upgrade_db.gd`): Item database; registration of Glass Talisman, Warding Brooch, Frenzy Charm, Impact Buckler.
  - `GlobalEvents` (`res://Utility/global_events.gd`): Signal hub, combat events (`player_dealt_damage`, `player_took_damage`).
- **Player & Damage Pipeline**:
  - `Player` (`res://Player/player.gd`): Health mutator `_set_hp`, signal `health_ratio_changed(current_ratio, previous_ratio)`.
  - Autonomous item listeners: Glass Talisman (+damage bonus at >=95% HP), Warding Brooch (10s out-of-combat 5% max HP shield at >=90% HP, Tier 2 speed boost on break), Frenzy Charm (+attack speed at <30% HP), Impact Buckler (emergency shockwave on HP drop <20% with 60/40/20s cooldown).
  - Safety floor: Weapons enforce $t_{\text{wait}} \ge 0.05\text{s}$.
- **Enemy Tenacity & Crowd Control**:
  - `SwarmManager` (`res://Utility/swarm_manager.gd`): Swarms (0% tenacity, full displacement from shockwave).
  - `EnemyBody` (`res://Enemy/Base/enemy_body.gd`): Elites (stagger/moderate knockback); Bosses (`isBoss != 0` or in group `"boss"`, 100% displacement immunity).
- **Assets & Localization**:
  - Icons: Use existing placeholder textures in `res://Textures/Items/Upgrades/` (e.g. `boots_4_green.png`, `thick_new.png`, `scroll_old.png`, `helmet_1.png` or other existing item textures) to avoid null texture crashes. Per user update, DO NOT generate new textures.
  - Localization: RFC 4180 4-column format (`keys,en,ru,ua`) in `translations/translations.csv`.
- **Testing Architecture**:
  - GUT CLI headless shim: `res://addons/gut/gut_cmdln.gd`.
  - Unit test suite: `res://test/unit/test_health_items.gd` extending `res://Tests/test_base.gd`.
  - Integration with existing `res://Tests/test_runner.gd`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | R1-F1: Cooldown Safety Floor | Codify $t_{\text{wait}} \ge 0.05\text{s}$ in `design_guidelines.md` and spawner audit in `todo.md` | M1 | explorer_o2_survey_1 |
| 2 | R1-F2: Universal Proc Coefficients | Codify on-hit trigger probabilities, duration scaling, standard table, and zero-proc loop rule | M1 | explorer_o2_survey_1 |
| 3 | R1-F3: Signal Buffs Framework | Codify decentralized `health_ratio_changed` signal pattern and YAGNI compliance in `design_guidelines.md` | M1 | explorer_o2_survey_1 |
| 4 | R1-F4: Terraria ICD Architecture | Codify Local Item ICD vs Shared Defensive Buffer vs Enemy Local Immunity | M1 | explorer_o2_survey_1 |
| 5 | R1-F5: Enemy Tenacity Standards | Codify 3-tier crowd control hierarchy (Swarm 0%, Elite 60-75%, Boss 100% immune) | M1 | explorer_o2_survey_1 |
| 6 | R1-F6: Long-term Horizons | Add pre-run loadouts, 1 reroll / 3 levels draft economy, wall collision / flow-field rules to guidelines & todo | M1 | explorer_o2_survey_1 |
| 7 | R1-F7: The Punished Resolution | Resolve character specs (`whip1`, `armor: 3`, `maxhp: 100`, `reflected_damage: 40`) and item pool synergies | M1 | explorer_o2_survey_1 |
| 8 | R2-F1: Glass Talisman Implementation | 4 tiers + endless (+2%/stack) in `UpgradeDb`; damage bonus at >=95% HP in `player.gd` | M2 | explorer_o2_survey_2 |
| 9 | R2-F2: Warding Brooch Implementation | 2 tiers in `UpgradeDb`; 10s out-of-combat 5% max HP shield at >=90% HP, spillover, Tier 2 speed boost in `player.gd` | M2 | explorer_o2_survey_2 |
| 10 | R2-F3: Frenzy Charm Implementation | 3 tiers in `UpgradeDb`; +10%/+20%/+30% attack speed at <30% HP in `player.gd` with safety floor | M2 | explorer_o2_survey_2 |
| 11 | R2-F4: Impact Buckler & Shockwave | 3 tiers in `UpgradeDb`; trigger on <20% HP with 60/40/20s cooldown; radial Area2D Layer 3 shockwave; boss displacement guard | M2 | explorer_o2_survey_2 |
| 12 | R2-F5: Decentralized Signal Hook | Add `health_ratio_changed(current_ratio, previous_ratio)` in `player.gd` emitted on HP/maxhp updates | M2 | explorer_o2_survey_2 |
| 13 | R3-F1: 4-Column RFC 4180 Localization | 16 translation rows for the 4 items (EN, RU, UA) in `translations/translations.csv` | M2 | explorer_o2_survey_2 |
| 14 | R3-F2: Item Icon Mapping | Map existing valid repository textures to the 4 items in `UpgradeDb` (no AI generation per user instruction) | M2 | user_update |
| 15 | R4-F1: GUT CLI Runner Shim | Author `res://addons/gut/gut_cmdln.gd` to execute unit tests via `godot --headless -s addons/gut/gut_cmdln.gd` | M3 | explorer_o2_survey_3 |
| 16 | R4-F2: Unit Test Suite | Author `res://test/unit/test_health_items.gd` with 22 tests validating thresholds, math, cooldowns, immunity, DAG | M3 | explorer_o2_survey_3 |
| 17 | R4-F3: Test Runner Synchronization | Register `test_health_items.gd` in both `test_runner.gd` and `gut_cmdln.gd` | M3 | explorer_o2_survey_3 |
| 18 | E2E-F1: Full CLI Verification & Gate | Run `validate_translations.py`, `balance_eval.py`, GUT runner, 2 Reviewers, 2 Challengers, Forensic Auditor | M4 | orchestrator_2 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Design Guidelines & Backlog Update (R1) | R1-F1 through R1-F7 | none | DONE (Guidelines updated, todo.md synchronized) |
| M2 | Health-Based Items & Localization (R2, R3) | R2-F1 through R2-F5, R3-F1, R3-F2 | M1 | DONE (UpgradeDb, player.gd, shockwave, translations) |
| M3 | Automated Testing & Verification Suite (R4) | R4-F1 through R4-F3 | M2 | IN_PROGRESS |
| M4 | E2E Acceptance Verification & Gate | E2E-F1 (Full test runs, review, challenge, forensic audit) | M1, M2, M3 | PLANNED |

## Interface Contracts
### Player ↔ Health Items
- Signal: `signal health_ratio_changed(current_ratio: float, previous_ratio: float)`
- HP Accessor: HP mutations trigger `_set_hp(new_hp: float)` which computes ratio and emits signal if changed.
- Damage Bonus: `player.damage_multiplier` or `player.get_damage_bonus()` dynamically polled/applied to damage output.
- Brooch Charge: Absorbs up to `0.05 * maxhp` post-armor damage, excess spills over to HP.
- Shockwave: Radial `Area2D` on Layer 3 (bit 2, value 4) in group `"attack"` with `CollisionShape2D` child, `damage = 0.0`, `knockback_amount = 400.0`.

### Enemy ↔ Shockwave Crowd Control
- Swarm: 100% displacement via `swarm_manager.gd` knockback logic.
- Elite: Knockback / stagger via `enemy_body.gd`.
- Boss: Displacement immunity via `if not isBoss and not is_in_group("boss"): knockback = angle * knockback_amount`.

### CLI Verification Contracts
1. `python .agents/skills/localization-validator/validate_translations.py` -> 0 errors, exit 0.
2. `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal` -> cleanly completes, exit 0.
3. `godot --headless -s addons/gut/gut_cmdln.gd` -> all tests pass, 0 failures, exit 0.

## Code Layout
- Documentation & Backlog:
  - `design_guidelines.md` (Sections 2, 4.2, 4.4, 4.6, 4.7, 4.8, 5, 8)
  - `todo.md` (Health items status, The Punished resolution, long-term horizons)
- Item Database & Game Engine:
  - `res://Utility/upgrade_db.gd` (Entries for `glasstalisman1..4`, `glasstalisman_endless`, `wardingbrooch1..2`, `frenzycharm1..3`, `impactbuckler1..3` using valid placeholder textures)
  - `res://Player/player.gd` (`health_ratio_changed`, `_set_hp`, item mechanics, cooldown safety floor)
  - `res://Enemy/Base/enemy_body.gd` (Boss displacement immunity guard)
  - `res://Player/Attack/impact_buckler/` (Shockwave scene and script)
- Localization:
  - `translations/translations.csv` (16 RFC 4180 rows)
- Test Suites:
  - `res://addons/gut/gut_cmdln.gd` (GUT CLI headless runner shim)
  - `res://test/unit/test_health_items.gd` (22 unit test cases)
  - `res://Tests/test_runner.gd` (Updated suite registration)
