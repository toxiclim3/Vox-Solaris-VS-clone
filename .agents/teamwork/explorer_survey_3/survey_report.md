# Comprehensive Survey Report: R3 Antigravity Skills Suite & Project Systems

**Explorer**: Skills Localization Explorer (`explorer_survey_3`)  
**Date**: 2026-10-06  
**Target Milestone**: R3 (Project-Specific Antigravity Skills Suite)  
**Project**: SurvivorsClone (Godot 4.6, Antigravity 2.0 modernization)

---

## Executive Summary

This report surveys the technical requirements, directory layout, code patterns, data integrity, and mathematical balance models required to author the **Project-Specific Antigravity Skills Suite** (R3). The suite comprises four specialized Antigravity skills:
1. `weapon-scaffolder`: Standardized creation of weapons adhering to Godot 4.6 spawner patterns, `UpgradeDb` registration, SwarmManager collision contracts, and `PhasedAnimator` requirements.
2. `localization-validator`: Audit and validation of `translations.csv` across EN, RU, and UA, accompanied by a standalone CLI script to catch structural corruptions, missing keys, and translation leakages.
3. `tech-debt-auditor`: Audit workflow and synchronization system for `tech_debt.md` adhering to Rule 10 and YAGNI.
4. `game-balance-eval`: Mathematical simulation engine modeling player DPS, stat modifiers, enemy health curves, wave density, and difficulty progression across run timelines.

---

## 1. Antigravity Skills Directory & Specification Standards

### 1.1 Canonical Directory Layout
In accordance with Antigravity conventions and the existing workspace structure:
- **Canonical Skill Directory**: `.agents/skills/<skill-name>/`
  - Workspace root `.agents/` is already established (holding `.agents/teamwork/` for multi-agent coordination).
  - Placing skills under `.agents/skills/` maintains strict separation between agent runtime metadata (`.agents/teamwork/`) and reusable agent capabilities (`.agents/skills/`).
  - An alias / symlink or mirror at `.agent/skills/<skill-name>/` ensures compatibility across Antigravity runtime versions.
- **Rules on Agent Workspace Hygiene**:
  - `GEMINI.md` and agent rules strictly forbid placing source code, tests, or run data inside `.agents/teamwork/`.
  - Skill scripts (such as Python validation or evaluation CLI tools) must reside within their respective skill folders (`.agents/skills/<skill-name>/scripts/` or `.agents/skills/<skill-name>/<script>.py`), or in a dedicated top-level `scripts/` directory if meant for general developer CLI use.

### 1.2 Standard `SKILL.md` Specification
Every Antigravity skill directory must contain a `SKILL.md` file featuring standard YAML frontmatter:

```markdown
---
name: <skill-name>
description: <Concise 1-2 sentence description detailing what the skill achieves and when an agent should invoke it>
---

# <Skill Title>

## Overview
Brief contextual summary of the skill's purpose in the SurvivorsClone project.

## Triggers & When to Use
Exact conditions, user requests, or development tasks that invoke this skill.

## Prerequisites & Dependencies
Engine requirements (Godot 4.6), Python 3.x, singletons, and file dependencies.

## Step-by-Step Execution Workflow
Numbered, deterministic procedure guiding the agent from input to verified deliverable.

## Code Templates & Standard Contracts
Verbatim code patterns, boilerplate scenes, and dictionary schemas.

## Verification & Acceptance Checklist
Executable CLI commands and checks to validate skill output.
```

---

## 2. Skill Survey: `weapon-scaffolder`

### 2.1 Weapon Architecture & Directory Structure
Weapons reside under `res://Player/Attack/<weapon_folder_name>/`. Each weapon requires three core files:
1. `<weapon>_spawner.gd`: Node2D spawner script managing attack timers, burst queues, player stat scaling, and upgrade tiers.
2. `<weapon>.tscn`: PackedScene containing the root `Area2D` projectile or AOE node, visual sprites, collision geometry, and audio.
3. `<weapon>.gd`: Behavior script defining movement, piercing/hp, lifetime, damage application, and swarm collision.

Existing weapon references in `Player/Attack/`:
- `icespear` (Ice Spear - multi-pierce projectile)
- `javelin` (Javelin - circling orbiting spear)
- `tornado` (Tornado - directional pulsing AOE)
- `poisonbottle` (Poison Bottle / Poison Gas - lingering puddle with `PhasedAnimator`)
- `ritualcircle` (Ritual Chalk - ground tracking burst with `PhasedAnimator`)
- `glasslash` (Glass Lash - melee sweep with shard burst)
- `vampireknives` (Vampire Knives - fan-shot lifesteal projectiles)
- `whip` (Leather Whip - 3-slice shader melee sweep)
- `lightningrod` (Lightning Rod - chain lightning)
- `relicdrone` (Relic Drone - companion drone spawning rockets)

### 2.2 Dynamic Spawner Pattern & Player Integration
In `res://Player/player.gd` (lines 548–563):
```gdscript
elif type == "weapon" or (type == "bossitem" and boss_weapons_with_spawner.has(upgrade.rstrip("0123456789"))) or (upgrade.begins_with("occult_medallion") and type != "endless"):
    var base_name = upgrade.rstrip("0123456789")
    var folder_name = base_name.to_lower()
    var file_name = base_name.to_lower()
    
    var weapon_spawner = weapons.get_node_or_null(base_name)
    if weapon_spawner == null:
        var spawner_scene = load("res://Player/Attack/" + folder_name + "/" + file_name + "_spawner.gd")
        if spawner_scene:
            weapon_spawner = Node2D.new()
            weapon_spawner.set_script(spawner_scene)
            weapon_spawner.name = base_name
            weapons.add_child(weapon_spawner)
    if weapon_spawner:
        weapon_spawner.upgrade(upgrade)
```

**Key Spawner Requirements:**
- Must extend `Node2D`.
- Must implement `upgrade(upgrade_id: String)` handling levels 1 to 4 and `<weapon>_endless`.
- Must instantiate a main cooldown `Timer` and a burst `attackTimer` (for multi-projectile bursts).
- Cooldown scaling: `timer.wait_time = attackspeed * (1.0 - player.spell_cooldown)`.
- Projectile count scaling:
  ```gdscript
  var extra_attacks = int(player.additional_attacks)
  if randf() < (player.additional_attacks - extra_attacks):
      extra_attacks += 1
  var attack_burst = baseammo + extra_attacks
  ```
- Spawn parentage: Projectiles must be added to `player.get_parent().add_child(proj)` (or a projectiles layer), NOT as children of the player, so projectile movement is in world space.

### 2.3 Projectile Scene & SwarmManager Contracts
To ensure 100% compatibility with Godot physics and the high-performance `SwarmManager` (`res://Utility/swarm_manager.gd`):
1. **Collision Layer & Mask (Rule 16)**:
   - Root node: `Area2D` with `top_level = true`.
   - `collision_layer = 4` (Layer 3 / Bit 2: Value 4 = player attack layer).
   - `collision_mask = 0` (SwarmManager and enemy `HurtBox` detect the attack area; attacks do not detect enemies).
   - Node group: must be added to group `"attack"`.
2. **Child Naming (Rule 17)**:
   - Must contain an active child named explicitly `"CollisionShape2D"`.
   - Area2D must export/provide `damage` and `knockback_amount` properties.
3. **Hit Filtering & Piercing**:
   - `hit_once_array = []` to prevent dealing damage multiple times to the same enemy in a single tick.
   - Piercing tracked by `hp` property; decremented in `enemy_hit(charge = 1)`. When `hp <= 0`, emit `remove_from_array(self)` and call `queue_free()`.
4. **Size Scaling**:
   - `attack_size = 1.0 * (1.0 + player.spell_size)`. Scale smoothly via Tween on ready.

### 2.4 Persistent / Timed AOE & `PhasedAnimator` (Rule 11)
Any persistent or timed AOE effect (e.g. gas puddles, ground circles) must follow the Start -> Loop -> End lifecycle using `PhasedAnimator` (`res://Utility/phased_animator.gd`):
- `animator = PhasedAnimator.new(); add_child(animator)`
- Spritesheet mapped with `hframes`, `vframes`, `setup_variant(row, col)`.
- On animation tick: `animator.advance(is_expiring)` where `is_expiring = duration_timer.time_left < duration_timer.wait_time * 0.2`.
- On duration end: Tween opacity to 0.0 before `queue_free()` to eliminate visual popping.

### 2.5 Flexible Weapon Rendering (Rule 13)
Whips, chains, or flexible Line2D weapons must use the 3-slice shader `res://Utility/whip_3slice.gdshader` to preserve handle and tip aspect ratios while stretching the body.

### 2.6 Registration in `UpgradeDb` (`res://Utility/upgrade_db.gd`)
Every weapon must have exactly 5 entries in `UpgradeDb.UPGRADES`:
- `<weapon>1` to `<weapon>4`: Levels 1 through 4.
  - Required keys: `icon`, `displayname` (key), `details` (key), `level` (`item_level1`..`4`), `prerequisite` (`[]` for 1, previous level for 2..4), `type` (`"weapon"` or `"bossitem"`).
- `<weapon>_endless`: Endless progression.
  - Keys: `icon`, `displayname`, `details` (`item_level_endless_details`), `level` (`item_level_endless`), `prerequisite` (`["<weapon>4"]`), `type` (`"endless"`), `stat_modifiers` (`{"damage": 1}`).
- **Integration Warning**: If `type == "bossitem"`, the weapon name MUST also be registered in `player.gd`'s `boss_weapons_with_spawner` list (lines 548 & 849).

---

## 3. Skill Survey: `localization-validator`

### 3.1 `translations.csv` Specifications
- **File Location**: `res://translations/translations.csv`
- **Format**: Comma-Separated Values (RFC 4180), UTF-8 encoding.
- **Header Structure**: `"keys","en","ru","ua"` (4 columns).
- **Import Configuration**: Godot compiles `translations.csv` into `translations.en.translation`, `translations.ru.translation`, `translations.ua.translation` via `translations.csv.import`.

### 3.2 Audit Findings & Detected Anomalies
A comprehensive line-by-line inspection of `translations.csv` revealed the following defects:
1. **Critical Column Count Mismatch**:
   - **Line 30**: `"ui_gameTitle","Inritus"` contains only 2 columns instead of 4. Godot expects all 4 columns (`keys`, `en`, `ru`, `ua`).
   - Fix: `"ui_gameTitle","Inritus","Inritus","Inritus"`.
2. **Missing Key**:
   - Line 87 contains `"lang_russian","Русский","Русский","Українська"`. There is no `"lang_ukrainian"` entry, resulting in missing localization for language selection in settings.
3. **Russian Leakage into Ukrainian Column (`ua`)**:
   - Line 40 (`ui_max_fps`): UA is `"Лимит кадров"` (Russian) instead of `"Ліміт кадрів"`.
   - Line 159–161 (`ItemDesc_Speed2..4`): Contains Russian `"еще"` and typo `"Швідкість"` instead of Ukrainian `"ще"` and `"Швидкість"`.
   - Line 193 (`ItemDesc_Whip4`): UA contains Russian clause `"скорость атаки теперь 0.8 сек."`.
   - Line 209 (`result_lose`): UA has `"Вы програли"` (Russian `"Вы"` instead of Ukrainian `"Ви"`).
   - Line 212 (`tips_armor`): UA has Russian spelling `"эффективна"` (character `э` does not exist in Ukrainian).
   - Line 222 (`tips_redgems`): UA has Russian pronoun `"их"` instead of Ukrainian `"їх"`.
   - Line 232 (`tips_meme_vibecoded`): UA has Russian verb `"был"` instead of Ukrainian `"був"`.
   - Line 271 (`debug_unpauseMusic`): UA has Russian word `"музыку"` instead of Ukrainian `"музику"`.
4. **Copy-Paste String Mismatches**:
   - Line 230–231 (`tips_meme_try_terraria`): RU is `"Также попробуйте Minecraft!"`, UA is `"Також спробуйте Minecraft!"` (erroneously duplicated from the Minecraft tip line).
5. **Stale Auxiliary Scripts**:
   - `translations/restore_translations.py` contains a hardcoded snapshot from earlier versions with concatenated lines at line 174. It should be deprecated or replaced by the validator CLI tool.

### 3.3 Validator CLI Tool Architecture (`validate_translations.py`)
Alongside the `localization-validator` skill, a standalone Python 3 CLI script must be provided:
- **Location**: `.agents/skills/localization-validator/scripts/validate_translations.py` (executable directly with host Python).
- **Core Checks**:
  1. `check_csv_integrity()`: Validates that header is exactly `keys,en,ru,ua`, every row has 4 columns, quotes are correctly balanced, and UTF-8 encoding is valid.
  2. `check_duplicate_keys()`: Enforces key uniqueness.
  3. `check_empty_cells()`: Flags empty or whitespace-only translation strings.
  4. `check_alphabet_leakage()`: Flags forbidden Russian characters (`ы`, `э`, `ъ`, `ё`) in Ukrainian strings, and forbidden Ukrainian characters (`і`, `ї`, `є`, `ґ`) in Russian strings.
  5. `check_codebase_keys()`: Scans all `.gd` and `.tscn` files for `tr("...")`, `displayname`, `details`, `level`, `warning_boss_*`, and compares against `translations.csv` to flag:
     - Missing keys (used in code, missing in CSV).
     - Orphan keys (present in CSV, never used in project).
- **CLI Options**:
  - `--csv <path>`: Path to `translations.csv`.
  - `--code <path>`: Path to workspace root to scan for keys.
  - `--check`: Returns exit code 0 if passing, 1 if any issues found.
  - `--fix`: Automatically repairs common formatting anomalies (such as row 30 missing columns).
  - `--json`: Outputs structured JSON report for Antigravity subagent consumption.

---

## 4. Skill Survey: `tech-debt-auditor`

### 4.1 Structure of `tech_debt.md`
`tech_debt.md` is structured into high-level categories:
- `## Visual & Rendering` (e.g. Line2D pixel crushing, subpixel Moiré)
- `## UI & Navigation` (e.g. Focus trapping, controller navigation)
- `## Performance & Loading` (e.g. Scene transition main thread instantiation freezes)

Each entry follows this strict schema:
```markdown
### <Issue Name>
- **Status:** <Known Issue | Partially Fixed / Haunted | Partially Optimized | Deferred | Investigating>
- **Description:** <Clear explanation of the technical quirk, visual artifact, or performance bottleneck>
- **Why it was deferred:** <Concrete rationale explaining why an immediate fix is prohibitive, architectural trade-offs, or Godot engine constraints>
- **Current Mitigation:** <Workarounds currently implemented in production>
```

### 4.2 Undocumented Technical Debt Identified
During the survey, several undocumented quirks and architectural debts were identified:
1. **Hardcoded Boss Weapon Spawner List in `player.gd`**:
   - In `Player/player.gd` lines 548 and 849, `boss_weapons_with_spawner = ["glasslash", "vampireknives"]` is hardcoded. Adding new boss weapons requires modifying multiple conditionals in `player.gd` rather than reading weapon traits from `UpgradeDb`.
2. **Spawn Intensity Curve Discontinuity at Minute 3.0**:
   - In `Utility/enemy_spawner.gd` lines 186–193, spawn intensity uses a quadratic formula ($3.0 + 0.75 t^2$) up to $t=3.0$, yielding 9.75. For $t > 3.0$, it transitions to $4.5 + 1.5 t$, which evaluates to 9.0 at $t=3.0$. This creates an unintended negative step in enemy spawn density at the 3-minute mark.
3. **Manual Frame-Hit Tracking Arrays**:
   - Projectiles rely on script-level `hit_once_array` arrays and deferred collision disabling rather than an automated engine-level hit-frequency or tick-interval system.
4. **Dual Enemy System Split**:
   - `SwarmManager` (MultiMesh) vs `EnemyBody` (`CharacterBody2D`) requires weapons to conform to strict Layer 3 and child naming rules, creating an ongoing risk of silent weapon-swarm interaction bugs.

### 4.3 Auditing Workflow & Synchronization Rules
The `tech-debt-auditor` skill workflow must follow these principles:
1. **Codebase Scan**:
   - Grep for `TODO`, `FIXME`, `HACK`, `WORKAROUND`, and `push_warning`.
   - Inspect Godot 4.6 deprecation notices and UID integrity.
2. **Accountability Check (Rule 10 & YAGNI)**:
   - Before attempting any fix for known issues in `tech_debt.md`, verify if the cost/benefit justifies it.
   - If a proposed fix requires speculative abstractions, defer it and document rationale in `tech_debt.md` in adherence to YAGNI.
3. **Synchronization**:
   - Keep `tech_debt.md` in sync whenever workarounds are added, modified, or resolved.
   - Update entry status and record resolution commit/version when resolved.

---

## 5. Skill Survey: `game-balance-eval`

### 5.1 Project Balance Architecture & Mathematical Formulas

#### Player Stat Scaling Formulas
Located in `Player/player.gd`:
- **Damage Reduction (Armor Rework)**:
  $$\text{DR} = \frac{\text{armor}}{\text{armor} + 40.0}$$
  Incoming damage is reduced to:
  $$\text{Actual Damage} = \text{Damage} \times (1.0 - \text{DR})$$
- **Movement Speed**:
  $$\text{movement\_speed} = \text{base\_movement\_speed} \times (1.0 + \text{movement\_speed\_percent\_total})$$
  (Base: 60.0).
- **Max Health**:
  $$\text{maxhp} = \lfloor\text{base\_maxhp} \times (1.0 + \text{max\_hp\_percent\_total})\rfloor$$
  (Base: 80).
- **Spell Cooldown**:
  $$t_{\text{cooldown}} = t_{\text{base\_attackspeed}} \times (1.0 - \text{spell\_cooldown})$$
- **Spell Size**:
  $$\text{size} = 1.0 \times (1.0 + \text{spell\_size})$$
- **Attack Count (Burst)**:
  $$\text{ammo\_burst} = \text{base\_ammo} + \lfloor\text{additional\_attacks}\rfloor + \text{Bernoulli}(\text{additional\_attacks} - \lfloor\text{additional\_attacks}\rfloor)$$
- **Level Scaling (Character Passives)**:
  $$\text{progress} = \frac{\min(\text{level}, \text{scaling\_max\_level}) - 1}{\text{scaling\_max\_level} - 1}$$
  - Mage: CDR up to $-15\%$ at level 20.
  - Plague Doctor: Spell Size up to $+50\%$ at level 20.
  - Occultist: Lifesteal up to $+2\%$ at level 20.
  - Punished: Flat stats, no passive scaling.
- **Experience Requirement Curve**:
  $$\text{XP}_{\text{cap}}(\text{lvl}) = \begin{cases}
  5, 10, 15, 30, 50, 75, 110, 130, 150, 200 & \text{for } \text{lvl} \in [1, 10] \\
  200 + (\text{lvl} - 10) \times 250 & \text{for } \text{lvl} \in [11, 19] \\
  2700 + (\text{lvl} - 20) \times 400 & \text{for } \text{lvl} \ge 20
  \end{cases}$$
  XP gained per gem is modified by `GlobalEvents.get_xp_gain_modifier()` (Easy: 1.2, Normal: 1.0, Hard: 0.8).

#### Enemy Health & Spawn Scaling Formulas
Located in `Utility/global_events.gd` and `Utility/enemy_spawner.gd`:
- **Difficulty Multipliers**:
  | Parameter | Easy | Normal | Hard |
  |---|---|---|---|
  | Enemy Spawn Modifier | 0.8 | 1.0 | 1.2 |
  | Enemy HP Modifier | 0.8 | 1.0 | 1.2 |
  | Boss HP Modifier | 0.8 | 1.0 | 1.2 |
  | Player Regen Modifier | 1.5 | 1.0 | 1.0 |
  | XP Gain Modifier | 1.2 | 1.0 | 0.8 |
  | Weapon Slot Limit | 6 | 6 | 5 |
  | Upgrade Slot Limit | 8 | 8 | 6 |
- **Enemy Health Pools**:
  - Kobold Weak: 10 HP, 45 speed, 1 XP, 1 dmg (Easy/Normal swarm)
  - Kobold Strong: 20 HP, 57 speed, 1 XP, 2 dmg (Normal swarm)
  - Cyclops: 100 HP, 39 speed, 5 XP, 5 dmg (Hard minion)
  - Juggernaut: 300 HP, 68 speed, 100 XP, 8 dmg (Hard elite)
  - Ancient Amoeba (Boss): 500 HP base, 68 speed, 100 XP, 30 dmg
  - Dr. Franklin (Boss): 500 HP base, 68 speed, 100 XP, 30 dmg
- **Boss HP Multiplier**:
  $$\text{Boss Multiplier}(t) = (1.05)^t \times \text{Difficulty Boss HP Mod}$$
  where $t$ is elapsed minutes ($t = \text{time} / 60.0$).
  - At minute 5 (First Boss): $1.05^5 \approx 1.276 \implies 638 \text{ HP (Normal)}$, $766 \text{ HP (Hard)}$.
  - At minute 10 (Second Boss): $1.05^{10} \approx 1.629 \implies 814 \text{ HP (Normal)}$, $977 \text{ HP (Hard)}$.
  - At minute 15: $1.05^{15} \approx 2.079 \implies 1039 \text{ HP (Normal)}$, $1247 \text{ HP (Hard)}$.
  - At minute 20: $1.05^{20} \approx 2.653 \implies 1327 \text{ HP (Normal)}$, $1592 \text{ HP (Hard)}$.
- **Wave Spawn Intensity**:
  $$\text{Multiplier}(t) = \begin{cases}
  3.0 & t \le 1.0 \\
  3.0 + 0.75 t^2 & 1.0 < t \le 3.0 \\
  4.5 + 1.5 t & t > 3.0
  \end{cases}$$
  $$\text{Spawn Count} = \lfloor\text{enemy\_num} \times \text{Multiplier}(t) \times \text{Spawn Mod} \times (1.5 \text{ if easy pool})\rfloor$$

#### Weapon DPS Capabilities
| Weapon | Level 1 DPS | Level 2 DPS | Level 3 DPS | Level 4 DPS | Cleave / Mechanics |
|---|---|---|---|---|---|
| **Ice Spear** | 5.33 | 10.67 | 16.0 | 40.0 | Piercing (1 $\to$ 2 $\to$ 2 $\to$ 4 targets) |
| **Javelin** | 2.0 | 4.0 | 6.0 | 9.0 | Infinite pierce along straight path |
| **Tornado** | 25.0 / enemy | 50.0 / enemy | 60.0 / enemy | 75.0 / enemy | Ticks every 0.2s, 3 tornadoes at lvl 4 |
| **Poison Bottle** | 12.5 / enemy | 15.6 / enemy | 25.0 / enemy | 37.5 / enemy | Lingering puddle AOE + 20-45% slow |
| **Glass Lash** | 16.0 | 25.0 | 36.0 | 50.0 | Melee sweep + death shard explosions |
| **Ritual Circle** | 10.0 | 10.0 | 16.0 | 24.0 | High-damage delayed burst + steering |
| **Whip** | 5.33 | 10.0 | 16.0 | 25.0 | Targets closest enemy, fast swing |
| **Vampire Knives** | 12.5 | 21.0 | 30.0 | 45.0 | Fan of 5-12 projectiles + lifesteal |

### 5.2 Lightweight Simulation Tool Architecture (`balance_eval.py`)
To enable data-driven balance iteration, a Python simulation script will accompany the `game-balance-eval` skill:
- **Location**: `.agents/skills/game-balance-eval/scripts/balance_eval.py`
- **Simulation Capabilities**:
  1. **Run Progression Timeline (0–20 minutes)**:
     - Calculates estimated player level progression based on XP curve and enemy spawn rate.
     - Simulates stat points, CDR, spell size, and additional projectiles at each minute.
  2. **Single-Target & Cleave DPS**:
     - Computes single-target sustained DPS against bosses.
     - Computes total swarm burst DPS against dense hordes.
  3. **Time to Kill (TTK) Metrics**:
     - Fodder TTK: $\frac{\text{Kobold HP}}{\text{Weapon Single Hit Damage}}$
     - Elite TTK: $\frac{\text{Juggernaut HP}}{\text{Player DPS}}$
     - Boss TTK: $\frac{\text{Boss HP}(t)}{\text{Player Single Target DPS}}$
  4. **Balance Anomaly Detection**:
     - Flags **Swarm Overwhelm Risk**: when enemy HP spawn rate exceeds player DPS output by $> 25\%$.
     - Flags **Boss Sponginess Warning**: when Boss TTK exceeds 45 seconds at minute 5 or 60 seconds at minute 10+.
     - Flags **Difficulty Cliff**: when transitioning from minute 2 to minute 3 (due to Juggernaut 300 HP unlock).
- **Execution**:
  ```bash
  python .agents/skills/game-balance-eval/scripts/balance_eval.py --difficulty normal --character mage --weapons icespear,tornado
  ```

---

## 6. Synthesis & Recommendations for Implementation Track

1. **Skill Placement**:
   - Create skills in `.agents/skills/`:
     - `.agents/skills/weapon-scaffolder/SKILL.md`
     - `.agents/skills/localization-validator/SKILL.md` (and script `validate_translations.py`)
     - `.agents/skills/tech-debt-auditor/SKILL.md`
     - `.agents/skills/game-balance-eval/SKILL.md` (and script `balance_eval.py`)
2. **Immediate Localization Fix**:
   - Repair line 30 of `translations.csv` (`ui_gameTitle`) to include RU and UA columns.
   - Rectify Ukrainian language leakages and add `lang_ukrainian`.
3. **`tech_debt.md` Update**:
   - Document the newly identified debts: `player.gd` hardcoded boss weapon list, minute 3 spawner curve discontinuity, and SwarmManager collision contracts.
4. **YAGNI Adherence**:
   - Keep the CLI validation and balance tools lightweight, dependency-free (using standard library Python 3: `csv`, `math`, `argparse`, `json`, `re`), avoiding bloated third-party frameworks.

---
*End of Survey Report*
