# Inritus (v1.0.4)

[![Engine](https://img.shields.io/badge/Godot-4.6%20Mobile-blue.svg)](https://godotengine.org/)
[![License](https://img.shields.io/badge/License-GPL--3.0-green.svg)](LICENSE)
[![Standards](https://img.shields.io/badge/Antigravity-2.0%20Compliant-purple.svg)]()

> A high-performance roguelike arena survival game built in **Godot 4.6**, blending *Vampire Survivors* horde combat with *Risk of Rain*-style progressive difficulty scaling and dynamic swarming.

Developed by **Team Vox Solaris**.

---

## Table of Contents
- [1. Overview](#1-overview)
- [2. System Architecture](#2-system-architecture)
  - [Autoload Singletons](#autoload-singletons)
  - [Decoupled Event Bus (`GlobalEvents`)](#decoupled-event-bus-globalevents)
- [3. Swarm & Enemy Management](#3-swarm--enemy-management)
  - [MultiMesh Swarm Manager](#multimesh-swarm-manager)
  - [Dynamic Spawner & FPS Soft Limiting](#dynamic-spawner--fps-soft-limiting)
  - [Boss Encounters](#boss-encounters)
- [4. Weapon & Upgrade System](#4-weapon--upgrade-system)
  - [Dynamic Spawner Pattern](#dynamic-spawner-pattern)
  - [Attack Catalog (12 Systems)](#attack-catalog-12-systems)
  - [Endless Tiers](#endless-tiers)
- [5. Headless Automated Testing](#5-headless-automated-testing)
- [6. Configuration & Localization](#6-configuration--localization)
- [7. Licensing, Credits & Asset Disclosures](#7-licensing-credits--asset-disclosures)

---

## 1. Overview

**Inritus** places the player in an expansive, hostile arena against escalating waves of enemies. As time progresses, difficulty multipliers ramp up enemy speed, health, and spawn frequencies. Players collect experience gems to unlock weapons, passive items, and endless stat upgrades.

### Key Highlights
- **60 FPS Swarm Simulation**: Capable of handling thousands of concurrent enemies on screen using custom MultiMesh rendering and manual grid/distance-based collision.
- **12 Unique Attack Systems**: Ranging from projectile volleys and phased area-of-effect zones to chained hitscans, whip physics, and autonomous companion drones.
- **Progressive Difficulty**: Dynamic difficulty curves (Easy, Normal, Hard, Custom) modifying enemy density and boss encounters over survival time.
- **Trilingual Support**: Full localized interface in English (`en`), Russian (`ru`), and Ukrainian (`ua`).

---

## 2. System Architecture

The project adheres to strict separation of concerns, the **YAGNI (You Aren't Gonna Need It)** principle, and Antigravity 2.0 engineering standards.

```
res://
├── Audio/              # Sound effects and music categories (Normal, Boss, Extra)
├── Enemy/
│   ├── Base/           # EnemyBody base class (movement, knockback, hurtbox)
│   └── Boss/           # Dedicated boss state machines (Amoeba, Dr. Franklin)
├── Objects/            # Pickups (XP gems, magnets)
├── Player/
│   ├── Attack/         # 12 modular weapon/attack systems (spawners + scenes)
│   ├── GUI/            # HUD, level up, boss rewards, debug overlays
│   └── player.gd       # Player state machine, stats, upgrade inventory
├── TitleScreen/        # Main menu, character selection, settings
└── Utility/            # Autoloads, swarm manager, shader prewarmer, upgrade DB
```

### Autoload Singletons

The game utilizes five dedicated autoload singletons registered in `project.godot`:

| Singleton | Path / UID | Responsibility |
|---|---|---|
| `UpgradeDb` | `res://Utility/upgrade_db.tscn` | Central catalog of all items, weapons, passive upgrades, prerequisite trees, and endless scaling coefficients. |
| `GlobalEvents` | `uid://cfmtka6m73iiv` (`res://Utility/global_events.gd`) | Central signal bus, run timer, difficulty formulas, character definitions, and global combat notifications. |
| `MusicController` | `uid://b8x5a6sgnm38g` (`res://Utility/music_controller.gd`) | Dual-player audio crossfading system across Normal, Boss, and Extra categories. |
| `SettingsManager` | `uid://dafqqanwiwjho` (`res://Utility/SettingsManager.gd`) | Persistent player settings (audio profiles, controls, resolution, language) backed by `ConfigFile`. |
| `StatsManager` | `res://Utility/StatsManager.gd` | Persistent run and career metrics (enemies killed, gold, runs won/lost, personal bests). |

### Decoupled Event Bus (`GlobalEvents`)

Systems communicate via signals rather than direct node couplings:
- `boss_spawned(boss: EnemyBody)` / `boss_defeated`: Synchronizes the boss UI health bar and triggers musical transitions.
- `show_boss_warning(warning_text_key: String)`: Dispatches a 60-second advance telegraph banner before boss spawns.
- `queue_boss(boss_path: String)`: Allows programmatic or debug-triggered boss instantiations.
- `enemy_died(death_position, max_hp, killer)`: Feeds kill-proc mechanics (such as Will o' Wisp explosions).
- `player_took_damage(amount, attacker)` / `player_dealt_damage(amount, target, proc_coeff)`: Powers damage-reflection rings and combat statistics.

---

## 3. Swarm & Enemy Management

### MultiMesh Swarm Manager
Standard Godot scene trees struggle when instantiating thousands of individual `Area2D` or `CharacterBody2D` nodes simultaneously. Inritus solves this with `SwarmManager` (`res://Utility/swarm_manager.gd`):
- **100% Wave Routing for Fodder**: In `enemy_spawner.gd`, 100% of spawns from the **Easy** and **Normal** pools are routed directly to `SwarmManager.add_enemy()`. They exist purely as instances within a `MultiMeshInstance2D`.
- **Manual Collision Filtering**: Collision detection is performed manually using spatial proximity checks against nodes in the `"attack"` group on Layer 3 (bit 2 / value 4) containing a child named `"CollisionShape2D"`.
- **Node-Based Elites & Bosses**: Only **Hard** (elite enemies) and **Super** (bosses) are instantiated as full `EnemyBody` nodes in the scene tree.

### Dynamic Spawner & FPS Soft Limiting
The spawner dynamically modulates wave density:
- **FPS Soft Limit**: If rendering drops below 30 FPS, the maximum concurrent enemy cap decreases by 5 per frame down to `min_soft_limit` (80). If FPS recovers above 55 FPS, the cap increases up to `max_soft_limit` (400).
- **Time Intensity Curve**: Enemy numbers scale quadratically from minute 1 to minute 3, transitioning to linear scaling in late-game stages.

### Boss Encounters
- **Ancient Amoeba** (`Enemy/Boss/boss.gd`): Cycles through `CHASE -> DISSOLVING -> TELEGRAPHING -> REAPPEARING`, teleporting across the arena via circular telegraph indicators.
- **Dr. Franklin** (`Enemy/Boss/dr_franklin.gd`): Cycles through `CHASE -> TELEGRAPHING -> RECOVERING`, firing a high-damage directional laser beam using a rectangular telegraph marker (`franklin_telegraph_rect.tscn`).

---

## 4. Weapon & Upgrade System

### Dynamic Spawner Pattern
Every player weapon follows a modular architecture inside `res://Player/Attack/<WeaponName>/`:
1. `<weapon>_spawner.gd`: Manages weapon cooldown, projectile counts, target acquisition, and upgrade level transitions.
2. `<weapon>.gd` & `<weapon>.tscn`: The visual and physical projectile, beam, or area effect.
3. Registration in `UpgradeDb.gd`: Defines base stats, prerequisite level chains, display names, and localization keys.

### Attack Catalog (12 Systems)

| Weapon System | Folder | Architectural Pattern | Special Mechanics |
|---|---|---|---|
| **Ice Spear** | `icespear/` | Projectile Spawner | High-velocity piercing spear targeting random or near enemies. |
| **Javelin** | `javelin/` | Projectile Spawner | High-damage arcing trajectory with bouncing properties. |
| **Tornado** | `tornado/` | Projectile Spawner | Drifting vortex that damages enemies continuously along its path. |
| **Poison Bottle** | `poisonbottle/` | Two-Stage AOE | Shatters on impact into persistent gas following the `PhasedAnimator` pattern. |
| **Lightning Rod** | `lightningrod/` | Hitscan Chain | Instant beam striking nearby targets with multi-target branch chain. |
| **Ritual Circle** | `ritualcircle/` | Persistent AOE Aura | Rotating glyph aura centered on the player damaging all enclosed swarms. |
| **Leather Whip** | `whip/` | 3-Slice Line2D Melee | Horizontal sweep using a 3-slice shader preserving handle and tip geometry. |
| **Glass Lash** | `glasslash/` | Boss Shard Spawner | Rapid whip unleashing crystalline piercing shards upon impact. |
| **Vampire Knives** | `vampireknives/` | Boss Fan Spawner | Fires a spread fan of 5–12 life-stealing projectiles that heal the player. |
| **Relic Drone** | `relicdrone/` | Companion Node | Autonomous drone orbiting the player and launching guided micro-rockets. |
| **Occult Medallion** | `occult_medallion/` | Direct Debuff Spawner | Spawner without projectiles; periodically curses enemies to take +vulnerability damage. |
| **Will o' Wisp** | `willowisp/` | On-Kill Proc Trigger | Event-driven trigger in `player.gd`; triggers fiery chain explosions when enemies die. |

### Endless Tiers
Once an attack or passive item reaches maximum tier (e.g., Level 4), players can continue investing in `_endless` upgrades. These apply mathematical multipliers recursively (e.g., +10% base damage, +5% cooldown reduction per endless level), allowing builds to scale indefinitely.

---

## 5. Headless Automated Testing

Inritus features an automated, headless unit testing framework that runs in continuous integration or via developer terminal without opening a GUI window.

### Executing Tests via CLI
Execute the automated test suite directly using Godot's headless CLI:

```powershell
# From the project root:
godot --headless -s res://Tests/test_runner.gd
```

### Exit Codes & CI Integration
- **`0`**: All test suites passed successfully.
- **`Non-zero` (`1`)**: One or more test assertions failed.

### Test Coverage Areas
The testing suite verifies critical game calculations and data integrity:
1. **Player Stat Calculations**: Base stats, stat modifier formulas, level-up XP requirement progression, and passive item applications.
2. **UpgradeDb Catalog Integrity**: Verifies that all weapon, passive, and boss item levels (1–4 and endless) have valid prerequisites, icons, types, and localization keys.
3. **Difficulty & Wave Scaling**: Validates `GlobalEvents` difficulty multipliers across Easy, Normal, Hard, and Custom presets.

---

## 6. Configuration & Localization

### Localization (`translations.csv`)
All strings presented to players are referenced via translation keys resolved at runtime.
- Supported Languages: English (`en`), Russian (`ru`), Ukrainian (`ua`).
- Key file: `res://translations/translations.csv` (RFC 4180 standard 4-column format: `"keys","en","ru","ua"`).

### Settings Profiles
Configurations are stored in `user://settings.cfg` via `SettingsManager`:
- **Audio**: Separate volume sliders and mute toggles for Master, Music, and SFX.
- **Video**: Fullscreen toggles, VSync, GUI Scaling, and Camera Zoom options.
- **Controls**: Custom keyboard and gamepad remapping for 8 directional axes and action keys.

---

## 7. Licensing, Credits & Asset Disclosures

### Software License
The source code of Inritus is licensed under the **GNU General Public License v3.0** (`GPL-3.0-or-later`). See [LICENSE](LICENSE) for the full license text.

```text
Inritus — A Vampire Survivors style horde survival game
Copyright (C) 2026 Team Vox Solaris

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
```

### Third-Party Assets & Attribution
- **Sound Effects**:
  - Background weather audio by Helton Yan ([itch.io/weatherelements](https://heltonyan.itch.io/weatherelements)), licensed under [Creative Commons Attribution 4.0 (CC-BY 4.0)](Audio/SoundEffect/BackgroundNoise/LICENSE.txt).
- **Typography**:
  - `Palitura`, `OpenSans`, `GreatVibes`, `NotoColorEmoji` licensed under SIL Open Font License (OFL 1.1) and Apache 2.0.
- **Placeholder Assets & Future Replacement Notice**:
  - During early development, certain placeholder sprites (*Terraria* by Re-Logic, *Risk of Rain Returns* by Hopoo Games/Gearbox) and reference music tracks were used for prototyping.
  - In accordance with our open-source commitment, all placeholder assets are strictly designated for replacement with original CC0/custom assets prior to commercial or public standalone distribution.
- **Generative AI Disclosure**:
  - Generative AI was utilized for early title screen parallax background textures and assisted code prototyping under academic guidelines.
