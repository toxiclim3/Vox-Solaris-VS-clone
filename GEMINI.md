# Project Context & Rules

This project is a **Vampire Survivors clone** built in **Godot 4.6**, featuring **Risk of Rain-style progressive difficulty and scaling**. The game title is **Inritus** (v1.0.4). It supports three languages: **English, Russian, Ukrainian**.

## Core Architecture

### Autoload Singletons (always available globally)
| Singleton | File | Purpose |
|---|---|---|
| `UpgradeDb` | `res://Utility/upgrade_db.tscn` | Database of all items/weapons/upgrades, prerequisites, and endless scaling |
| `GlobalEvents` | `res://Utility/global_events.gd` | Central signal hub, difficulty system, timer, combat events, and run management |
| `MusicController` | `res://Utility/music_controller.gd` | Dual-player crossfade music system with Normal/Boss/Extra track types |
| `SettingsManager` | `res://Utility/SettingsManager.gd` | Persistent settings (audio profiles, language, controls) via ConfigFile |
| `StatsManager` | `res://Utility/StatsManager.gd` | Persistent run statistics (kills, wins, deaths, best runs) via ConfigFile |

*Note*: In `project.godot`, `GlobalEvents`, `MusicController`, and `SettingsManager` are bound via UIDs, while `UpgradeDb` and `StatsManager` are bound via paths.

### Core Mechanics Map
- **Player & Damage**: `res://Player/player.gd` — stats, level-up logic, stat modifiers, upgrade application, reward queue system.
- **Upgrades & Items**: `res://Utility/upgrade_db.gd` — the database of all items (`UPGRADES` dict). Types: `weapon`, `upgrade`, `item`, `bossitem`. Includes endless tiers (`_endless`) with recursive stat stacking.
- **Enemy Spawner**: `res://Utility/enemy_spawner.gd` — wave spawning with easy/normal/hard pools, boss spawn scheduling (with 1-minute warnings), FPS-based soft limit, difficulty-scaled spawn intensity.
- **Enemy Base**: `res://Enemy/Base/enemy_body.gd` (`class_name EnemyBody`) — movement, knockback, hurt/death logic, XP gem + magnet drops (1% magnet chance).
- **Boss AI (Ancient Amoeba)**: `res://Enemy/Boss/boss.gd` (extends `EnemyBody`) — state machine: CHASE → DISSOLVING → TELEGRAPHING → REAPPEARING. Uses circular telegraph zones and teleport mechanics.
- **Boss AI (Dr. Franklin)**: `res://Enemy/Boss/dr_franklin.gd` (extends `EnemyBody`) — state machine: CHASE → TELEGRAPHING → RECOVERING → CHASE. Uses rectangular telegraph beam, angular offset variance, and disabled contact HitBox during firing.
- **Global Events**: `res://Utility/global_events.gd` — central signal hub, difficulty enum (EASY/NORMAL/HARD/CUSTOM), all difficulty modifier getters.
- **GUI Controller**: `res://Player/gui.gd` — the master GUI script. Manages: level-up panels, boss reward panels, pause/settings menus, death panel, debug menus, timer, XP bar, collected items display.
- **Boss UI**: `res://Player/boss_ui.gd` — dedicated boss health bar, warning banners, particle effects.
- **Pickups**: `res://Objects/pickup.gd` — handles both XP gems (tiered: green/blue/red) and XP magnets (collects all gems on map).
- **Tech Debt**: `res://tech_debt.md` — central tracker for known visual quirks, deferred fixes, and engine-level limitations.
- **Design Guidelines**: `res://design_guidelines.md` — authoritative design specifications for characters, items, weapons, stat budgets, and batch implementation workflows.

### Key Utility Systems
- **Shader Prewarmer**: `res://Utility/shader_prewarmer.gd` — handles background shader compilation to prevent runtime micro-stuttering.
- **Phased Animator**: `res://Utility/phased_animator.gd` — standardized state machine for "Start -> Loop -> End" animation sequences used in timed effects.
- **Swarm Manager**: `res://Utility/swarm_manager.gd` — high-performance MultiMesh-based system for mass enemies. Uses manual distance-based collision instead of standard physics signals. Requires attackers to be in the "attack" group and have a child named "CollisionShape2D".
- **Swarm Wave Routing**: In `res://Utility/enemy_spawner.gd:203`, 100% of Easy and Normal pool spawns are routed directly to `SwarmManager` (`is_swarm = (pool_type == "easy" or pool_type == "normal")`). They are rendered as MultiMesh instances and are never instantiated as individual scene nodes. Standard node instantiation is reserved for Hard (elites) and Super (bosses).

### Weapon & Attack Systems
Weapons and attack abilities live in `res://Player/Attack/<WeaponName>/` across 12 distinct implementations and 5 architectural patterns:

| Attack System | Folder | Architectural Pattern | Progression |
|---|---|---|---|
| **Ice Spear** | `Player/Attack/icespear/` | Standard Projectile Spawner (`icespear_spawner.gd` -> `icespear.tscn`) | Levels 1–4 + Endless |
| **Javelin** | `Player/Attack/javelin/` | Standard Projectile Spawner (`javelin_spawner.gd` -> `javelin.tscn`) | Levels 1–4 + Endless |
| **Tornado** | `Player/Attack/tornado/` | Standard Projectile Spawner (`tornado_spawner.gd` -> `tornado.tscn`) | Levels 1–4 + Endless |
| **Poison Bottle** | `Player/Attack/poisonbottle/` | Two-Stage AOE (`poisonbottle_spawner.gd` -> bottle -> `poison_gas.tscn` via `PhasedAnimator`) | Levels 1–4 + Endless |
| **Lightning Rod** | `Player/Attack/lightningrod/` | Instant Hitscan Chain (`lightningrod_spawner.gd` -> `lightningrod.tscn`) | Levels 1–4 + Endless |
| **Ritual Circle** | `Player/Attack/ritualcircle/` | Persistent AOE Aura (`ritualcircle_spawner.gd` -> `ritualcircle.tscn` + `ritual_hitbox.gd`) | Levels 1–4 + Endless |
| **Leather Whip** | `Player/Attack/whip/` | Flexible 3-Slice Line2D Melee (`whip_spawner.gd` -> `whip.tscn`) | Levels 1–4 + Endless |
| **Glass Lash** | `Player/Attack/glasslash/` | Boss Weapon / Shard Projectile Spawner (`glasslash_spawner.gd` -> `glassshard.tscn`) | Levels 1–4 + Endless |
| **Vampire Knives** | `Player/Attack/vampireknives/` | Boss Weapon / Fan Projectile Spawner (`vampireknives_spawner.gd` -> `vampireknife.tscn`) | Levels 1–4 + Endless |
| **Relic Drone** | `Player/Attack/relicdrone/` | Companion Node dynamically attached directly to Player (`player.gd:542`), fires `relicrocket.tscn` | Levels 1–2 |
| **Occult Medallion** | `Player/Attack/occult_medallion/` | Debuff Spawner (`occult_medallion_spawner.gd`), periodically curses enemies/swarm without projectile | Levels 1–4 + Endless |
| **Will o' Wisp** | `Player/Attack/willowisp/` | On-Kill Proc Trigger in `player.gd:789-809`, spawns `willowisp_explosion.tscn` on enemy death | Levels 1–4 |

When `upgrade_character()` is called with a weapon or spawner-based boss item, it dynamically loads `res://Player/Attack/<Folder>/<base>_spawner.gd`, attaches it to a new `Node2D`, and adds it under `%Weapons`.

## Signal Architecture (GlobalEvents)
Key signals to be aware of:
- `advanceBackground` — triggers background tile progression
- `enableSpawns` / `disableSpawns` — toggle enemy spawning (debug)
- `boss_defeated` — triggers victory, boss reward queue, music unlock, boss bar hide
- `boss_spawned(boss: EnemyBody)` — triggers boss bar show + tracking
- `show_boss_warning(warning_text_key: String)` — triggers warning banner 1 min before boss
- `queue_boss(boss_path: String)` — force-spawn a boss immediately (debug)
- `camera_shake(intensity, duration)` — screen shake effect
- `enemy_died(death_position: Vector2, enemy_max_hp: float, killer_source: String)` — combat event emitted on enemy death
- `player_took_damage(amount: float, attacker_node: Node)` — emitted when player takes damage
- `player_dealt_damage(amount: float, target_node: Object, proc_coefficient: float)` — emitted when player deals damage

## AI Behavior Rules
1. **Be Honest & Direct**: If the user is wrong about something, state that directly and clarify why. The user is ready to learn.
2. **Prompt for Info**: Always insist on prompting the user for extra information or clarification when needed. Do not make assumptions for complex technical decisions.
3. **Engine-Specific Fixes**: If a problem seems related to Godot's internal engine systems (such as UID mismatches, scene dependency errors, or metadata corruption), suggest that the user try to fix it using the Godot Editor UI, as certain engine-level fixes are more reliably handled there than through raw text edits.
4. **Tooling Constraint**: **`grep` is NOT available** on this system. Assistants should use the built-in `grep_search` tool or Windows-native commands like `findstr` or PowerShell `Select-String` when searching through files. Avoid using `rg` or `grep` in `run_command`.
5. **Localization**: All user-facing strings use translation keys resolved via `translations.csv`. When adding new UI text, always add the translation key to the CSV for all three languages (EN, RU, UA).
6. **Theme Consistency**: The project uses a Nine-Patch-based global theme (`NinePatchUI.tres`). New UI elements should inherit from it. The debug menu uses a separate theme and must NOT be affected by global theme changes.
7. **Weapon Pattern**: When adding new weapons, follow the established spawner pattern: create `<weapon>_spawner.gd` + `<weapon>.gd` + `<weapon>.tscn` in `res://Player/Attack/<WeaponName>/`, and add all levels to `upgrade_db.gd`.
8. **GUI Split**: Player GUI logic lives in `gui.gd` (not `player.gd`). `player.gd` calls gui helper functions. Boss-specific UI is in `boss_ui.gd`. The `%HealthBar` stays under `player.gd` because it's physically parented to the player sprite.
9. **Python is available**: Python is installed on the host machine, and so is pillow, ffmpeg, and godot (as in, added to PATH). If you need any extra programs, tell the user.
10. **Technical Debt Accountability**: Before attempting a "fix" for a known visual or systemic quirk, check `res://tech_debt.md`. If a requested fix is deferred due to prohibitive complexity, document the rationale in that file.
11. **Start-Loop-End Animation Rule**: Any persistent or timed AOE effect (e.g., Poison Gas, Ritual Circle) must follow the `PhasedAnimator` pattern (Start -> Loop -> End) to ensure visual continuity and prevent "popping" upon weapon expiration.
12. **Asset Alignment Standards**: Always trim transparent padding from weapon and item sprites used in the UI. Alignment logic in `ItemOption` and `ItemContainer` assumes tight bounding boxes.
13. **Flexible Asset Rendering**: Whips, chains, or flexible Line2D-based weapons must use a 3-slice shader (similar to `res://Utility/whip_3slice.gdshader`) to preserve the integrity of the handle/tip while the body stretches.
14. **Focus & Navigation Hygiene**: Prevent automatic button highlighting when a menu opens to avoid unintended user interactions. Map `focus_neighbors` explicitly for complex grids, and ensure `ui_cancel` (Escape) returns focus to category tabs.
15. **HurtBox Attacker Integrity**: Any mechanic involving damage reflection or attacker-specific logic (e.g., Thorn Ring) requires the `HurtBox` to pass the `attacker` node in its signals.
16. **Swarm Attack Filtering**: Swarms ignore any node in the "attack" group that is not on Layer 3 (bit 2 / value 4). Only areas intended for player-to-enemy damage should use this layer.
17. **Swarm Collision Convention**: Any dynamic Area2D intended to damage swarms must contain a child node explicitly named "CollisionShape2D" and provide `damage` and `knockback_amount` properties.
18. **Alternate Solutions**: If you identify a better architectural or implementation approach to achieve the desired outcome, you must offer these alternate solutions alongside the requested one, explaining why they might be superior. This rule also applies to determining the outcome that should be implemented.
19. **The YAGNI (You Aren't Gonna Need It) Principle**:
    - **No Speculative Abstractions**: Implement only what is required by current, explicit gameplay requirements. Never create generic wrappers, multi-tiered manager hierarchies, event bus signals, or configuration fields for hypothetical future features.
    - **Rule of Three for Generalization**: Do not extract a shared base class, manager, or generic helper until at least three concrete systems actively require the exact same logic.
    - **Dead Code Discipline**: Remove obsolete, backup, or placeholder code (e.g., test characters, dead functions, unused dictionaries) rather than keeping them in production dictionaries or scripts.
    - **Pragmatic Testing**: Unit tests must validate actual runtime calculations (stat formulas, prerequisite logic, difficulty multipliers), not verify speculative edge cases or test frameworks for non-existent components.
    - **Direct Solutions Over Factory Patterns**: For weapons, items, and UI elements, follow established, direct node-instantiation patterns rather than introducing speculative factory or reflection mechanisms.