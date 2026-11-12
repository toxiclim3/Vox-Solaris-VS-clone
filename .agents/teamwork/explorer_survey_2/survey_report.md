# Survey Report: Documentation, Tech Debt, YAGNI Standard & Repository Compliance (R2 & R4)

**Explorer**: Docs TechDebt Explorer (`explorer_survey_2`)  
**Date**: 2026-10-06  
**Scope**: Project Documentation, Architecture Alignment, Tech Debt, YAGNI Principle, GPL-3.0 Licensing, Repository Hygiene.

---

## 1. Executive Summary

A comprehensive read-only survey of the codebase was conducted to evaluate **R2** (Documentation, Tech Debt & YAGNI Standard in `GEMINI.md` / `README.md` / `tech_debt.md`) and **R4** (Repository & License Compliance).

The investigation revealed that while the core game systems are functional and well-architected:
1. **Existing Documentation is Severely Out of Date**: `GEMINI.md` reflects an early snapshot (v0.7.0, named "SurvivorsClone", listing only 4 weapons and incorrect file paths), whereas `project.godot` specifies **"Inritus" v1.0.4** with **12 attack systems**, endless progression tiers, and two distinct boss AI state machines. `README.md` is an informal university draft devoid of architecture or developer workflows.
2. **Significant Undocumented Tech Debt Exists**: Beyond the 4 quirks tracked in `tech_debt.md`, the codebase contains undocumented engine workarounds (MultiMesh uniform caching bypass via dynamically constructed shader code), audio channel starvation workarounds (swarm enemies lack hit audio), ghost test characters exposed in the character select UI (`punished_backup`), a malformed CSV translation entry (`ui_gameTitle`), and deeply brittle node paths in UI scripts.
3. **Severe Licensing Incompatibilities Require Immediate Remediation**: While the repository includes a root GPL-3.0 `LICENSE`, **zero** source files carry license or copyright headers. Furthermore, the repository commits proprietary assets ripped directly from *Terraria* and *Risk of Rain Returns*, and the local working directory contains copyrighted *Risk of Rain 2* music tracks.
4. **Repository Hygiene Needs Cleanup**: Stale Godot temp files (`menu.tscn117201879.tmp`), Windows OS junk (`desktop.ini`), generated binary translation files, and build artifacts reside in the project tree.

---

## 2. Audit of Existing Documentation vs. Codebase Reality

### 2.1 Project Metadata
| Field | `GEMINI.md` | `README.md` | Actual (`project.godot`) |
|---|---|---|---|
| **Project Title** | `SurvivorsClone` | `Inritus` ("~~still without a name~~ now called Inritus!") | `Inritus` (`config/name="Inritus"`) |
| **Version** | `v0.7.0` | Not stated | `1.0.4` (`config/version="1.0.4"`) |
| **Engine** | Godot 4.6 | Godot 4.6 | Godot 4.6 Mobile (`config/features=["4.6", "Mobile"]`) |
| **Default Scene**| Not specified | Not specified | `res://TitleScreen/menu.tscn` |

### 2.2 Autoload Singletons
All 5 singletons listed in `GEMINI.md` match `project.godot`:
1. `UpgradeDb` (`*res://Utility/upgrade_db.tscn`)
2. `GlobalEvents` (`*uid://cfmtka6m73iiv` -> `res://Utility/global_events.gd`)
3. `MusicController` (`*uid://b8x5a6sgnm38g` -> `res://Utility/music_controller.gd`)
4. `SettingsManager` (`*uid://dafqqanwiwjho` -> `res://Utility/SettingsManager.gd`)
5. `StatsManager` (`*res://Utility/StatsManager.gd`)

*Note*: In `project.godot`, `GlobalEvents`, `MusicController`, and `SettingsManager` are bound via Godot UIDs, whereas `UpgradeDb` and `StatsManager` are bound via file paths.

### 2.3 Script Path Discrepancies in `GEMINI.md`
- **Enemy Base**:
  - `GEMINI.md` states: `res://Enemy/enemy_body.gd`
  - **Actual Path**: `res://Enemy/Base/enemy_body.gd` (`Enemy/enemy_body.gd` does not exist).
- **Boss AI**:
  - `GEMINI.md` states: `res://Enemy/boss.gd`
  - **Actual Path**: `res://Enemy/Boss/boss.gd` (`Enemy/boss.gd` does not exist).
  - **Missing Boss**: `res://Enemy/Boss/dr_franklin.gd` is completely omitted from documentation.

### 2.4 Weapon & Attack Systems Architecture
`GEMINI.md` claims:
> *"Current weapons: Ice Spear, Javelin, Tornado, Poison Bottle (each with 4 levels)."*
> *"When upgrade_character() is called with a weapon type, it dynamically loads res://Player/Attack/<Folder>/<base>_spawner.gd, attaches it to a new Node2D, and adds it under %Weapons."*

**Actual Codebase Reality**:
There are **12 attack/weapon systems** in `Player/Attack/`, which implement 5 distinct architectural patterns:

| Attack System | Folder | Pattern / Architecture | Levels |
|---|---|---|---|
| **Ice Spear** | `Player/Attack/icespear/` | Standard Projectile Spawner (`icespear_spawner.gd` -> `icespear.tscn`) | 1–4 + Endless |
| **Javelin** | `Player/Attack/javelin/` | Standard Projectile Spawner (`javelin_spawner.gd` -> `javelin.tscn`) | 1–4 + Endless |
| **Tornado** | `Player/Attack/tornado/` | Standard Projectile Spawner (`tornado_spawner.gd` -> `tornado.tscn`) | 1–4 + Endless |
| **Poison Bottle** | `Player/Attack/poisonbottle/` | Two-Stage AOE (`poisonbottle_spawner.gd` -> bottle -> `poison_gas.tscn` using `PhasedAnimator`) | 1–4 + Endless |
| **Lightning Rod** | `Player/Attack/lightningrod/` | Instant Hitscan Chain (`lightningrod_spawner.gd` -> `lightningrod.tscn`) | 1–4 + Endless |
| **Ritual Circle** | `Player/Attack/ritualcircle/` | Persistent AOE Aura (`ritualcircle_spawner.gd` -> `ritualcircle.tscn` + `ritual_hitbox.gd`) | 1–4 + Endless |
| **Leather Whip** | `Player/Attack/whip/` | Flexible 3-Slice Line2D Melee (`whip_spawner.gd` -> `whip.tscn`) | 1–4 + Endless |
| **Glass Lash** | `Player/Attack/glasslash/` | Boss Weapon / Shard Projectile Spawner (`glasslash_spawner.gd` -> `glassshard.tscn`) | 1–4 + Endless |
| **Vampire Knives** | `Player/Attack/vampireknives/` | Boss Weapon / Fan Projectile Spawner (`vampireknives_spawner.gd` -> `vampireknife.tscn`) | 1–4 + Endless |
| **Relic Drone** | `Player/Attack/relicdrone/` | **Companion Node**: Directly parented to `Player` (`player.gd:542`), fires `relicrocket.tscn`. | 1–2 (No endless) |
| **Occult Medallion** | `Player/Attack/occult_medallion/` | **Debuff Spawner**: No projectile scene; periodically applies "curse" (+damage taken) directly to enemies and swarm. | 1–4 + Endless |
| **Will o' Wisp** | `Player/Attack/willowisp/` | **On-Kill Trigger**: No spawner; tracked via `willowisp_level` in `player.gd:789-809`, spawns `willowisp_explosion.tscn` on enemy death. | 1–4 (No endless) |

Furthermore, `UpgradeDb` defines:
- **Passive Upgrades**: `armor` (1–4), `speed` (1–4), `tome` (1–4), `scroll` (1–4), `ring` (1–2), `ringofrejuvenation` (1–2), `ringofaffinity` (1–2), `thornring` (1–4).
- **Consumable Items**: `food` (instant +20 HP restore).
- **Endless Tiers**: Every weapon and passive item (except `willowisp` and `relicdrone`) has an `_endless` upgrade level with recursive stat stacking.

### 2.5 Enemy Spawner & Swarm Integration
In `GEMINI.md`, `SwarmManager` is described as a high-performance MultiMesh system, but its interaction with `enemy_spawner.gd` is missing:
- In `Utility/enemy_spawner.gd:203`, `is_swarm = (pool_type == "easy" or pool_type == "normal")`.
- **Key Discovery**: **100% of Easy and Normal pool enemies are never instantiated as individual nodes!** They are registered and rendered exclusively as MultiMesh instances inside `SwarmManager`.
- Only `hard` (elites) and `super` (bosses) spawn as full `EnemyBody` nodes in the scene tree.

### 2.6 Boss AI State Machines
`GEMINI.md` only documents one boss AI (`CHASE -> DISSOLVING -> TELEGRAPHING -> REAPPEARING`).
Codebase reality has two distinct boss encounters:
1. **Ancient Amoeba (`Enemy/Boss/boss.gd`)**:
   - Scene: `res://Enemy/Boss/enemy_super.tscn`
   - State machine: `CHASE -> DISSOLVING -> TELEGRAPHING -> REAPPEARING`.
   - Mechanics: Dissolves into particles, displays circular telegraph zone, teleports to new location near player.
2. **Dr. Franklin (`Enemy/Boss/dr_franklin.gd`)**:
   - Scene: `res://Enemy/Boss/dr_franklin.tscn`
   - State machine: `CHASE -> TELEGRAPHING -> RECOVERING -> CHASE`.
   - Mechanics: Stationary directional beam charge using rectangular telegraph (`franklin_telegraph_rect.tscn`), with randomized rotation offset (`angle_offset_max = 10.0`). Disables contact HitBox during beam firing.

### 2.7 GlobalEvents Signal Architecture
`GEMINI.md` omits several core signals and has parameter omissions:
- `queue_boss(boss_path: String)` (documented in `GEMINI.md` without the `boss_path` parameter).
- `enemy_died(death_position: Vector2, enemy_max_hp: float, killer_source: String)` (undocumented).
- `player_took_damage(amount: float, attacker_node: Node)` (undocumented).
- `player_dealt_damage(amount: float, target_node: Object, proc_coefficient: float)` (undocumented).

---

## 3. Technical Debt Audit (`tech_debt.md` vs. Codebase)

### 3.1 Currently Documented Tech Debt (in `tech_debt.md`)
1. **Line2D Pixel Crushing (Whip/Glass Lash)**: Nearest-neighbor filtering drops middle rows on tight arcs.
2. **Camera Subpixel Moiré vs. Integer Jitter**: Native resolution canvas_items stretch causing sprite shimmer vs. jarring 1-2px jitter when rounded.
3. **Settings & Play Menu Focus (Keyboard/Controller Support)**: Brittle `focus_neighbor` graphs and navigation ghosting.
4. **Scene Transition & Instantiation Hitches**: 2-4 second thread stall when instantiating `world.tscn`.

### 3.2 Undocumented Technical Debt & Engine Limitations Identified

#### TD-01: MultiMesh Dynamic Shader Code Injection (Engine Limitation)
- **Location**: `Utility/swarm_manager.gd:97-126`
- **Issue**: Godot 4.6 (Mobile renderer) suffers from MultiMesh material uniform caching bugs where uniform updates fail across instance pools or cause pipeline stalls.
- **Workaround**: The script programmatically formats and compiles raw shader strings containing hardcoded frame dimensions (`shader.code = """..."""`) rather than updating uniform parameters via `set_shader_parameter()`.
- **Status**: Undocumented engine workaround. Should be formally logged in `tech_debt.md`.

#### TD-02: Swarm Hit Sound Starvation (Audio System Debt)
- **Location**: `Utility/swarm_manager.gd:57`
- **Issue**: Source code comment states: `# Sound might need a pool, but for now we skip hit sounds for swarms to save audio channels, or play them globally rarely.`
- **Consequence**: Swarm enemies provide zero audio feedback upon taking damage.
- **Why Deferred**: Implementing per-hit sounds on 2,000+ simultaneous enemies without a prioritized voice-stealing audio pool would exhaust the Godot AudioServer channels and create severe audio distortion.

#### TD-03: Zombie/Test Character Exposed in Production Menu (`punished_backup`)
- **Location**: `Utility/global_events.gd:76-86`, `TitleScreen/play_menu.gd:24`
- **Issue**: `GlobalEvents.CHARACTERS` defines a duplicate/backup character `"punished_backup"` with an empty starting weapon (`starting_weapon: ""`). Because `play_menu.gd` iterates over `GlobalEvents.CHARACTERS.keys()` directly without checking `INACTIVE_CHARACTERS`, players can select this broken character in the main menu.
- **Status**: Logic bug / configuration debt.

#### TD-04: Malformed CSV Row in `translations.csv`
- **Location**: `translations/translations.csv:30`
- **Issue**: Line 30 contains `"ui_gameTitle","Inritus"` with only 2 columns, omitting RU and UA columns.
- **Consequence**: Any strict CSV parser expecting 4 columns (`keys,en,ru,ua`) will fail or throw an index out-of-range error on this line. (Note: `translations/restore_translations.py` also mirrors this malformed row).

#### TD-05: Hardcoded YouTube IDs in Music Controller Paths
- **Location**: `Utility/music_controller.gd:70-71`
- **Issue**: Music file paths contain raw YouTube video ID suffixes in filenames:
  - `"res://Audio/Music/Extra/i finally found my voice as an artist [FsTc4TCRHy8].mp3"`
  - `"res://Audio/Music/Extra/checkpoint (day) [sOZNRzxwJXA].mp3"`
- **Consequence**: Tight coupling to raw downloaded file names; fragile if audio assets are renamed or cleaned up.

#### TD-06: Brittle Container Path Traversal in `gui.gd`
- **Location**: `Player/gui.gd:39-40`
- **Issue**: Code uses deep, brittle relative node paths instead of unique names (`%`):
  - `@onready var btnResume = get_node("PauseMenu/MarginContainer/PanelContainer/VBoxContainer2/VBoxContainer/btn_resume_run")`
  - `@onready var btnSettings = get_node("PauseMenu/MarginContainer/PanelContainer/VBoxContainer2/VBoxContainer/btn_settings")`
- **Consequence**: Any UI reorganization of the pause menu container breaks the script at runtime.

#### TD-07: Inconsistent Parameter Types in `music_controller.gd`
- **Location**: `Utility/music_controller.gd:93, 189`
- **Issue**: `func playSpecificTrack(filePath: String, crossfade: bool = 1)` and `func _crossfadeTo(newStream: AudioStream, immediate: bool = 1)` specify `bool` type hints but assign integer default values (`1`).
- **Consequence**: Minor static typing smell that can trigger warnings in strict GDScript linting.

#### TD-08: Undocumented "Ray Tracing" Joke Setting Limiting Engine FPS
- **Location**: `Utility/SettingsManager.gd:135-140`
- **Issue**: Enabling "Ray Tracing" secretly forces `Engine.max_fps = 10` (cinematic 10 FPS joke) unless a secret keyword `frames` is typed into the input buffer.
- **Consequence**: While an intentional Easter egg, it is completely undocumented in `tech_debt.md` and could be mistaken for an engine bug by testers.

---

## 4. Formulation of the YAGNI Principle for `GEMINI.md`

### 4.1 Problem Analysis
In `todo.md` and previous development notes, there is a marked tendency toward speculative complexity:
- Proposing complex Warframe-style item modding cards before item variety is stabilized.
- Planning complex A* grid pathfinding algorithms with "pathfinding groups" optimization for an open-arena horde game where direct vector steering is superior.
- Retaining placeholder characters (`punished_backup`) and empty dictionaries (`INACTIVE_CHARACTERS`) "just in case".

### 4.2 Proposed Rule for `GEMINI.md`

Add **Rule 19** to `GEMINI.md` under **AI Behavior Rules**:

```markdown
19. **The YAGNI (You Aren't Gonna Need It) Principle**:
    - **No Speculative Abstractions**: Implement only what is required by current, explicit gameplay requirements. Never create generic wrappers, multi-tiered manager hierarchies, event bus signals, or configuration fields for hypothetical future features.
    - **Rule of Three for Generalization**: Do not extract a shared base class, manager, or generic helper until at least three concrete systems actively require the exact same logic.
    - **Dead Code Discipline**: Remove obsolete, backup, or placeholder code (e.g., test characters, dead functions, unused dictionaries) rather than keeping them in production dictionaries or scripts.
    - **Pragmatic Testing**: Unit tests must validate actual runtime calculations (stat formulas, prerequisite logic, difficulty multipliers), not verify speculative edge cases or test frameworks for non-existent components.
    - **Direct Solutions Over Factory Patterns**: For weapons, items, and UI elements, follow the established, direct node-instantiation patterns rather than introducing speculative factory or reflection mechanisms.
```

---

## 5. GPL-3.0 Licensing & Legal Compliance Audit (R4)

### 5.1 Repository License Status
- **Root License**: `LICENSE` is present in the workspace root and contains the full text of GNU General Public License v3.0 (29 June 2007).
- **Source File Headers**:
  - **Audit Result**: Out of all `.gd` and `.gdshader` files across the repository, **0% carry license headers or SPDX identifiers**.
  - **GPL-3.0 Requirement**: Each source file should include a copyright notice and a pointer to the GNU General Public License (e.g., `SPDX-License-Identifier: GPL-3.0-or-later`, `Copyright (C) 2026 Team Vox Solaris`).

### 5.2 Third-Party Asset Compliance Audit

| Asset Category | Location | Identified Origin | License / Status | Compliance Risk |
|---|---|---|---|---|
| **Weapon Sprites** | `Textures/Items/Weapons/Vampire_Knives.webp` | *Terraria* (Re-Logic) | Proprietary / Copyrighted | **HIGH**: Direct game asset rip. Incompatible with GPL-3.0. |
| **Weapon Sprites** | `Textures/Items/Weapons/Kaleidoscope.webp` | *Terraria* (Re-Logic) | Proprietary / Copyrighted | **HIGH**: Direct game asset rip. Incompatible with GPL-3.0. |
| **Weapon Sprites** | `Textures/Items/Weapons/Leather_Whip.webp` | *Terraria* (Re-Logic) | Proprietary / Copyrighted | **HIGH**: Direct game asset rip. Incompatible with GPL-3.0. |
| **RoRR Sprites** | `Textures/rorr/*` (`sAlienHead`, `sBottled`, `sChaos`, etc.) | *Risk of Rain Returns* (Hopoo Games / Gearbox) | Proprietary / Copyrighted | **HIGH**: Committed directly to repository. Incompatible with GPL-3.0. |
| **Music Tracks** | `Audio/Music/Normal/*`, `Audio/Music/Boss/*` | *Risk of Rain 2* OST by Chris Christodoulou | Proprietary / Copyrighted | **MEDIUM**: Excluded from git via `.gitignore`, but present locally. Release builds must never bundle these. |
| **Weather Sound Effects** | `Audio/SoundEffect/BackgroundNoise/` | Helton Yan (`itch.io/weatherelements`) | CC-BY 4.0 | **CLEAN**: `LICENSE.txt` is present and compliant. |
| **Fonts** | `Font/*.ttf` (`Palitura`, `OpenSans`, `GreatVibes`, `NotoColorEmoji`) | Google Fonts / OFL / Apache 2.0 | SIL OFL 1.1 / Apache 2.0 | **LOW**: Permissive, but license text files should be co-located in `Font/`. |
| **Title Screen Art** | `Textures/Titlescreen/*` | Generative AI | AI-generated | **LOW**: Legal in open source, but transparency disclosure should be documented. |

### 5.3 Recommendations for Full Compliance
1. Add standard SPDX header to all scripts:
   ```gdscript
   # SPDX-License-Identifier: GPL-3.0-or-later
   # Copyright (C) 2026 Team Vox Solaris
   ```
2. Replace third-party game assets (*Terraria*, *Risk of Rain Returns*) with CC0/original pixel art before any public release.
3. Keep `.gitignore` strictly preventing `Audio/Music` audio files from being tracked.

---

## 6. Repository Hygiene & Clutter Analysis

### 6.1 Unnecessary Files & Artifacts Found

1. **Stale Godot Temporary Scene**:
   - `TitleScreen/menu.tscn117201879.tmp` (7.1 KB) — Leftover file from an interrupted Godot scene save. Safe to delete.
2. **Windows Desktop Configuration Metadata**:
   - `Audio/desktop.ini`
   - `Textures/desktop.ini`
   - Clutter generated by Windows File Explorer. Safe to delete and add to `.gitignore`.
3. **Ignored Binaries Present in Working Tree**:
   - `debug.keystore` — In repository root, even though `*.keystore` is in `.gitignore`.
   - `translations/*.translation` — `translations.en.translation`, `translations.ru.translation`, `translations.ua.translation` are present even though `*.translation` is in `.gitignore`.
4. **Android Build Intermediate Artifacts**:
   - `android/build/build/intermediates/...` — Intermediate Gradle build files that should be cleaned.
5. **Unstructured Task / Scratchpad File**:
   - `todo.md` in repository root — Contains uncurated brainstorm notes. Should be integrated into structured roadmaps or removed.

### 6.2 Recommended `.gitignore` Additions
Ensure `.gitignore` includes:
```gitignore
# Windows system files
desktop.ini
Thumbs.db

# Godot temp files
*.tmp

# IDE / Editor clutter
.vscode/
.vs/
```

---

## 7. Actionable Implementation Roadmap for Downstream Agents

1. **For Documentation Implementer (`GEMINI.md` / `README.md`)**:
   - Update `GEMINI.md`:
     - Update name and version: `Inritus` (v1.0.4).
     - Fix script paths: `Enemy/Base/enemy_body.gd`, `Enemy/Boss/boss.gd`, add `Enemy/Boss/dr_franklin.gd`.
     - Update weapon map: Document all 12 attack systems, Endless tiers, and non-projectile patterns (Relic Drone, Occult Medallion, Will o' Wisp).
     - Update signal bus signatures (`queue_boss(boss_path: String)`, damage/kill signals).
     - Enshrine Rule 19: The YAGNI Principle.
   - Modernize `README.md`:
     - Provide professional Antigravity 2.0-compliant overview.
     - Document architecture (Autoloads, SwarmManager, Weapons).
     - Document headless testing commands (`godot --headless -s ...`).
     - Clarify GPL-3.0 licensing and asset placeholders.
2. **For Tech Debt Maintainer (`tech_debt.md`)**:
   - Add entries for TD-01 (MultiMesh dynamic shader string injection), TD-02 (Swarm hit sound starvation), TD-03 (Ghost character in UI), TD-04 (Malformed CSV line 30), and TD-08 (Raytracing 10 FPS cap).
3. **For Repository Compliance / Cleanup Agent**:
   - Remove `menu.tscn117201879.tmp`, `Audio/desktop.ini`, `Textures/desktop.ini`.
   - Fix line 30 in `translations.csv` (`"ui_gameTitle","Inritus","Inritus","Inritus"`).
   - Ensure proper SPDX headers on newly added files.
