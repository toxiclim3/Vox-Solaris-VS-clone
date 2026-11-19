# Technical Debt

This file tracks known bugs, mathematical quirks, architectural compromises, or engine-level limitations that are acceptable to ship with but should be revisited in the future for a comprehensive fix.

---

## Visual & Rendering

### Line2D Pixel Crushing (Whip/Glass Lash)
- **Status:** Known Issue
- **Location:** `Player/Attack/whip/whip.tscn`, `Player/Attack/glasslash/`
- **Description:** When the `Line2D` used for weapon cords bends or curves rapidly, the inner edge of the arc "pinches." Because Godot is rasterizing this polygon with Nearest Neighbor filtering (`texture_filter = 1`), this pinching forces the renderer to mathematically drop a row of pixels to fit the mesh. For the Leather Whip, which has a 3-pixel-thick cord, dropping exactly the center physical pixel makes it look "squished," leaving only the top and bottom outlines touching.
- **Why it was deferred:** Fixing this requires either:
  1. Turning on Linear filtering (`texture_filter = 2`), which makes the cord look blurry in a pixel-art game.
  2. Writing a specialized multi-sample pixel-perfect UV vertex shader.
  3. Generating a custom mesh instead of using `Line2D`.
- **Current Mitigation:** The scales are mathematically consistent (`0.7` and `0.5`), keeping it as aligned as theoretically possible while maintaining sharpness.

### Camera Subpixel Moiré vs. Integer Jitter
- **Status:** Known Issue
- **Location:** `Player/player.tscn` (`Camera2D`)
- **Description:** Moving the camera causes a slight Moiré / shimmering effect on the background tilemap and sprite edges. This happens because the game uses `canvas_items` stretch mode and renders natively at screen resolution. When the float-based `Camera2D` moves, Godot's Nearest Neighbor filtering has to rasterize non-integer positions, causing sprite pixels to shift in width on the physical monitor.
- **Why it was deferred:** Fixing this requires forcing the camera rendering offset to an integer (which causes a violently noticeable 1-to-2 pixel jitter between the player sprite and background at high refresh rates like 144Hz), or implementing a strict `SubViewport` architecture. However, utilizing a `SubViewport` inherently breaks our pristine infinitely-scaling MSDF text in the UI by locking scaling logic inside the viewport's low internal resolution. Furthermore, fractional Camera Zoom guarantees Moiré regardless of architecture when filtering is set to nearest.
- **Current Mitigation:** The moiré is accepted as a necessary evil to retain flawlessly crisp UI scaling and smooth player motion.

### Ray Tracing Joke Setting Limiting Engine FPS
- **Status:** Undocumented Easter Egg / Testing Hazard
- **Location:** `Utility/SettingsManager.gd:135-140`
- **Description:** In the video settings menu, enabling "Ray Tracing" does not engage any actual raytraced shader pipeline. Instead, it secretly executes `Engine.max_fps = 10` ("cinematic 10 FPS") unless a secret developer string buffer matches `"frames"` to unlock `unlimit_rtx`.
- **Why it was deferred:** Implemented as a humorous in-team Easter egg during development.
- **Current Mitigation:** Retained as an Easter egg, but documented here to prevent QA testers and automated performance benchmarks from flagging the intentional 10 FPS cap as an engine crash or rendering pipeline stall. A future UI pass should append a comedic disclaimer to the toggle button.

### Lightning Rod Global Transform Distortion & Freed Target Crash
- **Status:** Resolved
- **Location:** `Player/Attack/lightningrod/lightningrod.gd`, `Player/player.gd`
- **Description:** Lightning Rod strike paths previously suffered from global transform scaling distortion away from the world origin, used a 20px spatial exclusion cutoff that prematurely blocked dense swarm chains, and risked `<Freed Object>` runtime crashes on typed target validity helpers when targets were freed mid-frame.
- **Why it was deferred:** Initially surfaced as an intermittent targeting and visual misalignment artifact under dense swarm packs.
- **Current Mitigation:** Resolved. `lightningrod.gd` now converts `_draw()` points via `to_local()`, chains use `hit_targets` instance tracking instead of spatial exclusion, and `_is_enemy_valid_target(body)` / `_is_target_valid(body)` use untyped parameters with `is_instance_valid(body)` guards (verified by the `test_weapon_fixes.gd` suite).

---

## Performance & Engine Workarounds

### Scene Transition & Instantiation Hitches
- **Status:** Partially Optimized
- **Location:** `TitleScreen/menu.gd`, `world.gd`
- **Description:** Significant freezes (2s–4s) occur when transitioning between the Title Screen and the World. While bidirectional background preloading and lazy-loading for audio/textures have been implemented, the absolute scale of the `world.tscn` tree and its internal dependencies causes a bottleneck during the `instantiate()` phase, which always runs on the main thread in Godot 4.
- **Why it was deferred:** Resolving this requires a massive structural overhaul, such as partitioning the world into smaller chunks or implementing a dedicated loading state machine that spreads instantiation over multiple frames. Additionally, the first-time preloading of the world scene while in the menu can compete for I/O and CPU resources with the shader pre-warming process, occasionally making the initial run-start feel slower than subsequent ones.
- **Current Mitigation:**
  1. **Bidirectional Preloading:** The Menu preloads the World and vice versa.
  2. **Lazy Assets:** Music and Level Backgrounds are loaded on-demand or background-cached.
  3. **UI LoD:** Heavy UI elements like the "How To Play" menu are loaded on-demand only.

### MultiMesh Dynamic Shader Code Injection
- **Status:** Engine Workaround in Place
- **Location:** `Utility/swarm_manager.gd:97-126`
- **Description:** In Godot 4.6 (Mobile renderer), MultiMesh materials exhibit a bug where uniform updates passed via `material.set_shader_parameter()` fail to propagate cleanly across instance pools or trigger shader pipeline recompilations during intense combat. To work around this, `swarm_manager.gd` dynamically constructs raw shader code as a string, injecting sprite atlas dimensions and frame counts directly into the GLSL string (`shader.code = """..."""`) at runtime initialization.
- **Why it was deferred:** Fixing this upstream requires an engine fix in Godot's Vulkan/Mobile uniform buffer binding. Standard uniform setting causes MultiMesh enemy animation frames to desync or freeze under heavy load.
- **Current Mitigation:** Shader code is generated and compiled once upon SwarmManager instantiation. While this incurs a minor startup compilation overhead, it completely avoids uniform caching desynchronization at runtime.

### Synchronous Disk I/O in `StatsManager.register_kill()`
- **Status:** Resolved
- **Location:** `Utility/StatsManager.gd:51-58`
- **Description:** `StatsManager.register_kill()` previously invoked `save_stats()` (`config.save("user://statistics.cfg")`) synchronously on every individual enemy kill, causing 50–100 synchronous main-thread disk writes per second during AoE swarm clears.
- **Why it was deferred:** Originally implemented for simplicity when enemy counts were low before `SwarmManager` scaled hordes to thousands of enemies.
- **Current Mitigation:** Resolved. `save_stats()` was removed from `register_kill()` and deferred to `register_end_run()`, with `is_run_tainted` sandbox protection preventing debug runs from corrupting saved stats.

---

## Audio Systems

### Swarm Hit Sound Starvation
- **Status:** Intentional Limitation / Backlog
- **Location:** `Utility/swarm_manager.gd:57`
- **Description:** Swarm enemies produce zero audio feedback when hit by player projectiles or AOE fields (`# Sound might need a pool, but for now we skip hit sounds for swarms to save audio channels, or play them globally rarely.`).
- **Why it was deferred:** During intense horde moments, 1,000–2,000 active swarm instances can collide with piercing attacks across dozens of frames. Spawning audio players or requesting playback without a voice-stealing SFX pool immediately starves Godot's AudioServer channels (polyphony limits), causing severe audio clipping, crackling, and main-thread hitching.
- **Current Mitigation:** Hit audio is suppressed for all MultiMesh swarm enemies, playing exclusively on elite (`hard`) and boss (`super`) hits. A future improvement should implement a prioritized spatial voice-stealing audio pool capped at 4 concurrent hit voices with a 50ms rate limit.

---

## UI, Navigation & Data Integrity

### Settings & Play Menu Focus (Keyboard/Controller Support)
- **Status:** Partially Fixed / Haunted
- **Location:** `TitleScreen/play_menu.gd`, `TitleScreen/settings_menu.gd`
- **Description:** Keyboard and controller navigation in the Settings and Play menus is inconsistent. Issues include focus trapping in grids (Character Selection), broken directional logic on sliders (volume adjustment vs. tab switching), and visual focus indicator visibility. Explicit `focus_neighbor` paths proved brittle, and Godot's natural spatial navigation is prone to "ghosting" or trapping due to layout overlaps and dynamic scene instantiation.
- **Why it was deferred:** Resolving this definitively requires a full UI architecture review, potentially flattening the container hierarchy or implementing a custom FocusManager to handle state transitions (like escaping from sliders back to tabs) without breaking native control behavior.
- **Current Mitigation:**
  1. Play Menu width was increased to minimize bounding box overlaps.
  2. Character grid buttons have themes manually assigned for visual feedback.
  3. Strict `_input` overrides catch `ui_cancel` (B/Escape) to facilitate navigation back to categories.

### Exposed `punished_backup` Ghost Character
- **Status:** Resolved
- **Location:** `Utility/global_events.gd`, `TitleScreen/play_menu.gd`
- **Description:** `GlobalEvents.CHARACTERS` previously defined a duplicate/backup character entry `"punished_backup"` configured with an empty starting weapon (`starting_weapon: ""`), exposing an unplayable test character on the character select grid.
- **Why it was deferred:** Retained as a developer backup during early character system refactoring.
- **Current Mitigation:** Resolved. Purged `punished_backup` and unused `INACTIVE_CHARACTERS` from `Utility/global_events.gd`, along with orphan translation keys, adhering to Rule 19 Dead Code Discipline.

### Malformed CSV Row in `translations.csv`
- **Status:** Resolved
- **Location:** `translations/translations.csv:30`
- **Description:** Line 30 of `translations.csv` previously contained `"ui_gameTitle","Inritus"`, providing only 2 columns instead of the required 4 (`keys,en,ru,ua`), failing strict RFC 4180 localization validation.
- **Why it was deferred:** Godot's built-in CSV importer treated missing trailing fields as empty strings without crashing.
- **Current Mitigation:** Resolved. Normalized line 30 to `"ui_gameTitle","Inritus","Inritus","Inritus"` for full 4-column RFC 4180 compliance.

---

## Architecture & Code Design

### Hardcoded Boss Weapons Array in `player.gd`
- **Status:** Architecture Debt / Code Duplication
- **Location:** `Player/player.gd:814`, `Player/player.gd:1132`
- **Description:** The array `var boss_weapons_with_spawner = ["glasslash", "vampireknives"]` is hardcoded verbatim in two separate functions (`upgrade_character` and `_is_spawner_item`).
- **Why it was deferred:** `UpgradeDb` classifies both passive boss items (like rings) and active weapons as `type: "bossitem"`. Because the database schema lacks a flag differentiating passive relics from weapons that require weapon spawner instantiation, `player.gd` was forced to maintain a hardcoded whitelist.
- **Current Mitigation:** The local string arrays are duplicated in both functions. Adding new boss weapons requires updating both arrays manually. The proper architectural solution is adding `"has_spawner": true` or `"is_weapon": true` directly to item entries in `UpgradeDb.gd`.

### Detached Boss Telegraph Node in Dr. Franklin
- **Status:** Known Issue
- **Location:** `Enemy/Boss/dr_franklin.gd`, `Enemy/Base/franklin_telegraph_rect.gd`
- **Description:** `_start_attack()` instantiates `franklin_telegraph_rect.tscn` into `get_parent()` (`World`) without parenting it to Dr. Franklin's pivot or storing a node reference on the boss script, and the telegraph manages its own independent countdown timer (`current_time`) to call `execute_attack()`.
- **Why it was deferred:** Under current Boss 100% displacement immunity (`design_guidelines.md`), Dr. Franklin cannot be knocked back or stunned while charging a beam, so the detached telegraph remains aligned with his standing position.
- **Current Mitigation:** Boss displacement immunity prevents desynchronization today. Must be refactored (parented/synced to pivot + tracked via reference) before adding boss stuns or map-hazard displacement interactions (`docs/todo.md`).

---

## Game Balance & Simulation

### Minute 3 Spawner Curve Discontinuity
- **Status:** Mathematical Discontinuity
- **Location:** `Utility/enemy_spawner.gd:186-193`
- **Description:** The spawn intensity multiplier formula has an abrupt step discontinuity at minute 3.0:
  - For `1.0 < minutes <= 3.0`: `time_multiplier = base_enemy_intensity + (A * t * t)` where `A = enemy_intensity_time_multiplier / 2.0 = 0.75`. At `minutes = 3.0`, `time_multiplier = 3.0 + (0.75 * 9.0) = 9.75`.
  - For `minutes > 3.0`: The code computes `val_at_3 = base_enemy_intensity + enemy_intensity_time_multiplier` (`3.0 + 1.5 = 4.5`, erroneously neglecting the quadratic accumulation) and sets `time_multiplier = val_at_3 + minutes * enemy_intensity_time_multiplier`. At `minutes = 3.0001`, this evaluates to `4.5 + (3.0 * 1.5) = 9.00`.
  - Consequently, at the exact 3-minute threshold, spawn intensity suddenly plunges from 9.75 to 9.0 before resuming linear growth.
- **Why it was deferred:** The momentary dip in spawn pressure was not noticeable enough during casual playtesting to halt development before the difficulty system balance pass.
- **Current Mitigation:** Currently accepted as part of legacy wave pacing. The proposed fix is setting `val_at_3 = base_enemy_intensity + (A * 9.0)` (9.75) and adding `(minutes - 3.0) * enemy_intensity_time_multiplier` to achieve a seamless $C^0$ transition.

### Inverted Mage Cooldown Scaling Sign & Stale Rejuvenation Endless Metadata
- **Status:** Known Issue
- **Location:** `Utility/global_events.gd:43`, `Utility/upgrade_db.gd:866`
- **Description:** Two metadata sign/display mismatches exist in current definitions:
  1. `GlobalEvents.CHARACTERS["mage"]["scaling_stats"]` sets `{"spell_cooldown": -0.15}`. Because weapon spawners compute `t_wait = t_base * (1.0 - player.spell_cooldown)` and `Scroll` / `Frenzy Charm` add positive values to `spell_cooldown`, `-0.15` increases Mage's weapon cooldowns by 15% instead of reducing them.
  2. `UpgradeDb.UPGRADES["ringofrejuvenation_endless"]` defines `"stat_modifiers": {"hp": 5}`, causing `item_option.gd` to render `"+5 Health"` on endless level-up cards even though `Player/player.gd:773` actually applies `max_hp_percent_total += 0.05 * count` (`+5% Max HP`).
- **Why it was deferred:** Surfaced during the Nov 19 movement/combat audit (`docs/movement_combat_ponderings.md`) after earlier unit tests focused on schema integrity rather than sign polarity.
- **Current Mitigation:** Documented for the upcoming balance and metadata pass (`"spell_cooldown": 0.15` for Mage; `"stat_modifiers": {"max_hp_percent": 0.05}` for `ringofrejuvenation_endless`).

---

## Asset Attribution & Licensing

### Asset Provenance Tracking (OpenGameArt vs. Itch.io)
- **Status:** Attribution Debt / Backlog
- **Location:** `Textures/` (Items, Enemies, Pickups, Weapons)
- **Description:** A significant volume of 32x32 sprites is derived from the public domain Dungeon Crawl Stone Soup supplemental set on OpenGameArt (CC0), but various other sprites were imported from assorted itch.io community packs during early game prototyping without recording individual asset-to-pack origins.
- **Why it was deferred:** Prioritized fast gameplay feel, prototyping velocity, and academic milestones over per-file asset licensing records.
- **Current Mitigation:** Collective attribution and disclaimer documented in `ATTRIBUTION.md` (Sections 2.5 and 3.5). A systematic asset inventory is scheduled prior to any standalone or commercial distribution to catalogue every itch.io pack and confirm redistribution permissions.

