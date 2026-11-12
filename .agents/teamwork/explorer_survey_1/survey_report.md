# Codebase Testing Survey Report (R1: Headless Godot 4.6 Unit Testing Suite)

**Author**: `explorer_survey_1` (Codebase Testing Explorer)  
**Date**: 2026-10-06  
**Target Project**: SurvivorsClone (v0.7.0, Godot 4.6, Mobile/Desktop)  
**Reference Document**: `.agents/teamwork/ORIGINAL_REQUEST.md`

---

## 1. Executive Summary

This survey evaluates the codebase architecture for implementing **R1 (Headless Godot 4.6 Unit Testing Suite)** under Antigravity 2.0 standards, adhering strictly to the **YAGNI (You Aren't Gonna Need It)** principle.

### Key Conclusions:
1. **Engine & CLI Environment**: The project runs on **Godot 4.6** (`config/features=PackedStringArray("4.6", "Mobile")`). Godot is installed in the host's `PATH`. Running tests headlessly is natively supported via `godot --headless -s <script.gd>` or `godot --headless <scene.tscn>`.
2. **Third-Party Framework Evaluation**: GUT (Godot Unit Test) is currently NOT installed in the project. Installing GUT would introduce 50+ scripts, UI scenes, and overhead contrary to YAGNI. A lightweight, pure-GDScript test runner (~120 lines) inheriting from `SceneTree` achieves zero-dependency, sub-second execution with deterministic CLI exit codes (`0` on pass, `1` on fail).
3. **Target Systems Decoupling**:
   - `UpgradeDb` (`res://Utility/upgrade_db.gd`): 100% pure data dictionary (`const UPGRADES`). Zero scene tree or visual dependencies. Fully testable via static analysis and GDScript validation.
   - `GlobalEvents` (`res://Utility/global_events.gd`): Difficulty enum, scaling modifiers, character dictionary, and progression getters are fully isolated and do not require external singletons.
   - `Player` (`res://Player/player.gd`): Core mathematical routines (`calculate_experiencecap`, XP rollover, DR armor formula $DR = \frac{\text{Armor}}{\text{Armor} + 40}$, stat modifiers application, and endless stacking) can be tested cleanly headlessly by mocking or stubbing three `@onready` properties (`healthBar`, `grab_shape`, `weapons`) without invoking `_ready()` or spawning visual/audio nodes.

---

## 2. Headless Godot 4.6 CLI Execution Mechanics

### 2.1 CLI Syntax & Behavior
In Godot 4.6, running headless scripts from the terminal works via:
```powershell
godot --headless -s res://Tests/test_runner.gd
```
Optional argument passing:
```powershell
godot --headless -s res://Tests/test_runner.gd -- --suite=player
```

### 2.2 MainLoop vs SceneTree vs Scene Execution
- **`MainLoop`**: Low-level abstract C++ engine interface. Requires manual implementation of `_initialize()`, `_process()`, and loop lifecycle. Over-engineered for testing.
- **`SceneTree` (Recommended)**: Inherits from `MainLoop`.
  - Scripts passed to `-s` that inherit from `SceneTree` are instantiated by Godot as the root tree.
  - In `_init()`, test suites can execute synchronously and immediately invoke `quit(0)` (success) or `quit(1)` (failure).
  - Built-in `quit(exit_code: int)` sets the process exit code, which integrates seamlessly with CI/CD and terminal runners.
  - Zero rendering overhead, zero window allocation in `--headless` mode.
- **Scene Execution (`test_runner.tscn`)**:
  - Running `godot --headless res://Tests/test_runner.tscn` boots the engine's default `SceneTree`.
  - Autoload singletons (`UpgradeDb`, `GlobalEvents`, `MusicController`, etc.) defined in `project.godot` are automatically instantiated in `/root` before `_ready()` runs.
  - A lightweight root script in `_ready()` can trigger the test runner and call `get_tree().quit(exit_code)`.
  - **Pragmatic Dual-Mode Recommendation**: The test runner script `res://Tests/test_runner.gd` can be designed to extend `SceneTree` for direct CLI `-s` invocation, while dynamically ensuring any necessary autoload references exist.

---

## 3. Core System Analysis

### 3.1 Player System (`res://Player/player.gd`)

#### Base Stats (Lines 3-46)
| Stat | Base Variable | Default Value | Notes |
|---|---|---|---|
| Max HP | `base_maxhp` | `80` | Exported `maxhp = 80` |
| Health Regen | `base_regenPerSecond` | `0.005` | `0.5 / 100` (0.5% max HP/sec) |
| Armor | `base_armor` | `0` | Flat reduction base |
| Movement Speed | `base_movement_speed` | `75.0` | Base player velocity |
| Spell Cooldown | `base_spell_cooldown` | `0.0` | Additive CDR |
| Spell Size | `base_spell_size` | `0.0` | Additive AOE scale |
| Additional Attacks | `base_additional_attacks` | `0.0` | Extra projectile count |
| Grab Radius | `BASE_GRAB_RADIUS` | `50.0` | Base pickup radius (pixels) |

#### Stat Calculations & Formulae (`apply_stat_modifiers()`, Lines 426-530)
1. **Movement Speed**:
   $$\text{movement\_speed} = \text{base\_movement\_speed} \times (1.0 + \sum \text{movement\_speed\_percent})$$
2. **Armor & Armor Multiplier**:
   $$\text{armor} = \text{int}((\text{base\_armor} + \sum \text{armor\_flat}) \times (1.0 + \sum \text{armor\_multiplier}))$$
3. **Damage Reduction (DR) Formula** (Line 241 in `_on_hurt_box_hurt`):
   $$DR = \frac{\text{armor}}{\text{armor} + 40.0}$$
   $$\text{Damage Taken} = \text{damage} \times (1.0 - DR)$$
   - Armor = 0 $\rightarrow DR = 0\%$
   - Armor = 40 $\rightarrow DR = 50\%$
   - Armor = 120 $\rightarrow DR = 75\%$
4. **Max HP Scaling**:
   $$\text{new\_maxhp} = \text{int}(\text{base\_maxhp} \times (1.0 + \sum \text{max\_hp\_percent}))$$
   Maintains HP ratio: $\text{hp} = \text{clamp}(\text{int}(\frac{\text{hp}}{\text{maxhp}} \times \text{new\_maxhp}), 1, \text{new\_maxhp})$.
5. **Grab Range**:
   $$\text{radius} = \text{BASE\_GRAB\_RADIUS} \times (1.0 + \sum \text{xp\_range\_percent})$$
6. **Character Progression Scaling** (Lines 476-495):
   For characters with `scaling_stats`:
   $$\text{Progress} = \frac{\min(\text{experience\_level}, \text{scaling\_max\_level}) - 1}{\text{scaling\_max\_level} - 1}$$
   - Level 1: Progress = 0.0 (no scaling bonus)
   - Level 20: Progress = 1.0 (100% of scaling stat applied)
   - Example (`mage`): `spell_cooldown: -0.15` at level 20.
7. **Endless Stacking Modifiers** (Lines 497-509):
   - `speed`: $+0.02 \times \text{count}$ (+2% speed/stack)
   - `tome`: $+0.02 \times \text{count}$ (+2% spell size/stack)
   - `scroll`: $+0.02 \times \text{count}$ (+2% spell cooldown/stack)
   - `armor`: $+1 \times \text{count}$ (+1 armor/stack)
   - `ringofaffinity`: $+0.05 \times \text{count}$ (+5% grab range/stack)
   - `ring`: $+0.05 \times \text{count}$ (+5% additional attacks/stack)
   - `thornring`: $+5 \times \text{count}$ (+5 reflected damage/stack)
   - `ringofrejuvenation`: $+0.05 \times \text{count}$ (+5% max HP/stack)

#### Experience & Reward Queue Logic
1. **Experience Cap Curve** (`calculate_experiencecap()`, Lines 348-366):
   - Level 1: 5 XP
   - Level 2: 10 XP
   - Level 3: 15 XP
   - Level 4: 30 XP
   - Level 5: 50 XP
   - Level 6: 75 XP
   - Level 7: 110 XP
   - Level 8: 130 XP
   - Level 9: 150 XP
   - Level 10: 200 XP
   - Levels 11–19: $200 + (\text{lvl} - 10) \times 250$
   - Levels 20+: $2700 + (\text{lvl} - 20) \times 400$
2. **Rollover & Multiple Level-Ups** (`calculate_experience()`, Lines 324-346):
   - Excess XP carries over cleanly into the next level.
   - If a large XP drop covers multiple levels, a `while` loop decrements XP, increments `experience_level`, and increments `pending_levelups`.
3. **Queue Prioritization** (`_show_next_reward()`, Lines 370-377):
   - Level-ups are prioritized first (`pending_levelups > 0`).
   - Boss rewards are processed once pending level-ups are cleared (`pending_boss_rewards > 0`).

---

### 3.2 Upgrade Database (`res://Utility/upgrade_db.gd`)

#### Structure & Schema
`upgrade_db.gd` is purely a dictionary `const UPGRADES: Dictionary`. It has no script functions or runtime state.

#### Schema Fields per Entry:
```gdscript
{
    "icon": String,          # e.g., WEAPON_PATH + "ice_spear.png"
    "displayname": String,   # Translation key, e.g. "item_icespear"
    "details": String,       # Translation key, e.g. "ItemDesc_IceSpear1"
    "level": String,         # "item_level1" ... "item_level4", "item_levelNA", "item_level_endless"
    "prerequisite": Array,   # Array of upgrade key strings
    "type": String,          # "weapon", "upgrade", "bossitem", "item", "endless"
    # Optional:
    "stat_modifiers": Dictionary # { String: float/int }
}
```

#### Inventory of Registered Families:
- **Standard Weapons** (Levels 1–4 + endless): `icespear`, `javelin`, `tornado`, `poisonbottle`, `ritualcircle`, `lightningrod`, `whip`.
- **Boss Weapons** (Levels 1–4 + endless): `glasslash`, `vampireknives` (type: `"bossitem"` for 1-4, `"endless"` for endless).
- **Passive Upgrades** (Levels 1–4 + endless): `armor`, `speed`, `tome`, `scroll`, `thornring`, `occult_medallion`.
- **2-Tier Passive Upgrades** (Levels 1–2 + endless): `ringofrejuvenation`, `ringofaffinity`.
- **Non-Endless Passive**: `willowisp` (Levels 1–4).
- **Boss Items**: `ring` (1, 2, endless), `relicdrone` (1, 2).
- **Consumable Items**: `food` (level `item_levelNA`, type `item`, stat_modifiers: `{"hp": 20}`).

#### High-Value Integrity Tests to Implement:
1. **Schema Compliance**: Every entry contains all 6 required keys.
2. **Prerequisite Resolution**: Every string in `prerequisite` matches an existing key in `UPGRADES` (zero dead/dangling references).
3. **DAG (Directed Acyclic Graph) Check**: No cycles in prerequisite chains.
4. **Tier Consistency**:
   - Level 1 items must have `prerequisite == []`.
   - Level $N$ items ($N > 1$) must have `prerequisite == [base + str(N - 1)]`.
   - Endless items must have prerequisite pointing to the max tier of that item.
5. **Stat Modifiers Sanity**: All keys in `stat_modifiers` are known stats, values are numeric, and no negative unintentional modifiers exist.
6. **Translation Key Check**: `displayname` and `details` keys exist in `translations/translations.csv`.

---

### 3.3 Difficulty & Progression (`res://Utility/global_events.gd` & `res://Utility/enemy_spawner.gd`)

#### Difficulty Enum & Cycle
- `enum Difficulty { EASY, NORMAL, HARD, CUSTOM }`
- `next_difficulty()` cycles: `EASY` $\rightarrow$ `NORMAL` $\rightarrow$ `HARD` $\rightarrow$ `CUSTOM` $\rightarrow$ `EASY`.

#### Difficulty Modifiers Matrix:
| Difficulty | Enemy Spawn Rate | Enemy HP | Boss HP | Player Regen | XP Gain | Weapon Slots | Upgrade Slots |
|---|---|---|---|---|---|---|---|
| **EASY** | 0.8 | 0.8 | 0.8 | 1.5 | 1.2 | 6 | 8 |
| **NORMAL** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 6 | 8 |
| **HARD** | 1.2 | 1.2 | 1.2 | 1.0 | 0.8 | 5 | 6 |
| **CUSTOM** | custom | custom | custom | custom | custom | 6 | 8 |

#### Enemy & Boss Scaling Formulas (`enemy_spawner.gd`):
1. **Boss HP Multiplier**:
   $$\text{Multiplier}(t) = (1.05)^{\text{minutes}} \times \text{GlobalEvents.get\_boss\_hp\_modifier()}$$
   - At $t = 0\text{m}$: $1.05^0 = 1.0$
   - At $t = 5\text{m}$: $1.05^5 \approx 1.276$
   - At $t = 10\text{m}$: $1.05^{10} \approx 1.629$
2. **Spawn Intensity Multiplier** (base $= 3.0$, multiplier $= 1.5$):
   - $t \le 1.0\text{m}$: $3.0$
   - $1.0\text{m} < t \le 3.0\text{m}$: $3.0 + 0.75 \times t^2$
   - $t > 3.0\text{m}$: $4.5 + 1.5 \times t$

---

## 4. Dependencies & Isolation in Headless Mode

### Autoload Singleton Inspection:
From `project.godot`:
```ini
[autoload]
UpgradeDb="*res://Utility/upgrade_db.tscn"
GlobalEvents="*uid://cfmtka6m73iiv"
MusicController="*uid://b8x5a6sgnm38g"
SettingsManager="*uid://dafqqanwiwjho"
StatsManager="*res://Utility/StatsManager.gd"
```

### Script Coupling & Mocking Strategy:
| Component | Dependencies | Headless Strategy |
|---|---|---|
| `upgrade_db.gd` | None | Direct load: `preload("res://Utility/upgrade_db.gd").UPGRADES` |
| `global_events.gd` | GlobalEvents singleton (or `Node.new()`) | Direct instantiation of `preload("res://Utility/global_events.gd").new()` |
| `player.gd` | `@onready var healthBar`, `@onready var grab_shape`, `@onready var weapons`, `gui`, `MusicController` | Instantiate `Player.new()`. Do **not** call `_ready()`. Populate dummy instances for `healthBar`, `grab_shape`, and `weapons`. Run stat/math methods directly. |

---

## 5. Pragmatic, YAGNI-Compliant Unit Test Architecture

### 5.1 Architecture Design

```
res://Tests/
├── test_runner.gd                 # Test runner script (extends SceneTree), CLI entry point
├── test_base.gd                   # Lightweight assertion class (assert_eq, assert_true, etc.)
└── Unit/
    ├── test_upgrade_db.gd         # Database integrity, schema validation, DAG check
    ├── test_player_stats.gd       # Exp curves, rollover, modifiers, armor DR, scaling
    └── test_difficulty_scaling.gd # Difficulty enum, modifiers matrix, boss/wave formulas
```

### 5.2 Core Components Specification

#### 1. `test_base.gd`
A zero-dependency `RefCounted` class providing essential assertion helpers:
- `assert_true(cond: bool, msg: String = "")`
- `assert_false(cond: bool, msg: String = "")`
- `assert_eq(actual: Variant, expected: Variant, msg: String = "")`
- `assert_ne(actual: Variant, expected: Variant, msg: String = "")`
- `assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, msg: String = "")`
- `assert_has(container: Variant, key: Variant, msg: String = "")`
- Tracks assertion count, test failures, and failure descriptions.

#### 2. `test_runner.gd`
A `SceneTree` script that:
1. Instantiates each test suite.
2. Discovers and runs all methods starting with `test_`.
3. Pretty-prints test names, durations, and pass/fail statuses with standard terminal formatting.
4. Aggregates results: Total tests, Passed, Failed, Assertions.
5. Invokes `quit(0)` if all tests pass; invokes `quit(1)` if any test fails.

#### 3. Execution Command:
```powershell
godot --headless -s res://Tests/test_runner.gd
```
- Exit Code `0`: All tests passed.
- Exit Code `1`: Test failure detected.

---

## 6. Verification & Implementation Roadmap for Implementer

1. **Step 1**: Create `res://Tests/test_base.gd` with clean, self-contained assertion methods.
2. **Step 2**: Create `res://Tests/Unit/test_upgrade_db.gd` with schema, prerequisite, DAG, and translation checks.
3. **Step 3**: Create `res://Tests/Unit/test_player_stats.gd` with XP curve, rollover, stat modifier formulas, and character scaling tests.
4. **Step 4**: Create `res://Tests/Unit/test_difficulty_scaling.gd` with difficulty cycling, modifier getters, and wave/boss formulas.
5. **Step 5**: Create `res://Tests/test_runner.gd` inheriting from `SceneTree`, aggregating all suites and exiting with appropriate code.
6. **Step 6**: Execute the CLI runner via `godot --headless -s res://Tests/test_runner.gd` and verify that all tests pass cleanly.
