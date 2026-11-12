# Handoff Report: Docs & Tech Debt Explorer (R2 & R4)

**Agent ID**: `explorer_survey_2`  
**Recipient**: `parent` (`d9b112ba-138b-4790-94eb-e038999c5027`)  
**Mission**: Codebase Survey for R2 (Documentation, Tech Debt & YAGNI Standard) and R4 (Repository & License Compliance)

---

## 1. Observation

1. **Project Metadata Discrepancy**:
   - `project.godot:17-20`:
     ```ini
     config/name="Inritus"
     config/version="1.0.4"
     run/main_scene="res://TitleScreen/menu.tscn"
     config/features=PackedStringArray("4.6", "Mobile")
     ```
   - `GEMINI.md:3`:
     ```markdown
     This project is a Vampire Survivors clone built in Godot 4.6... The game title is SurvivorsClone (v0.7.0).
     ```
   - `README.md:3`:
     ```markdown
     This is a Vampire Survivors inspired game, ~~still without a name~~ now called Inritus!
     ```

2. **File Path Discrepancies in `GEMINI.md`**:
   - `GEMINI.md:20`: Lists `Enemy Base` as `res://Enemy/enemy_body.gd`. Attempting to view this path failed: `The system cannot find the file specified`. The actual file is at `res://Enemy/Base/enemy_body.gd:3` (`class_name EnemyBody`).
   - `GEMINI.md:21`: Lists `Boss AI` as `res://Enemy/boss.gd`. Viewing this path failed. The actual file is at `res://Enemy/Boss/boss.gd:1` (`extends EnemyBody`).
   - A second boss exists at `res://Enemy/Boss/dr_franklin.gd:1` (`Dr. Franklin`), completely omitted from `GEMINI.md`.

3. **Attack / Weapon Systems Count & Patterns**:
   - `GEMINI.md:39`:
     ```markdown
     Current weapons: Ice Spear, Javelin, Tornado, Poison Bottle (each with 4 levels).
     ```
   - Inspection of `res://Player/Attack/` revealed 12 subdirectories:
     `glasslash`, `icespear`, `javelin`, `lightningrod`, `occult_medallion`, `poisonbottle`, `relicdrone`, `ritualcircle`, `tornado`, `vampireknives`, `whip`, `willowisp`.
   - Inspection of `Utility/upgrade_db.gd` confirmed weapon/item entries for all 12:
     - Standard spawners: `icespear`, `javelin`, `tornado`, `poisonbottle`, `lightningrod`, `ritualcircle`, `whip`.
     - Boss weapons: `glasslash`, `vampireknives`.
     - Companion node: `relicdrone` (`player.gd:542-543` preloads `res://Player/Attack/relicdrone/relicdrone.tscn` and adds to `player` node).
     - Curse/aura weapon: `occult_medallion` (`occult_medallion_spawner.gd:46-60` applies debuff directly to candidate enemies).
     - On-kill trigger: `willowisp` (`player.gd:789-809` instantiates `willowisp_explosion.tscn` on kill).
     - Endless upgrades: Every weapon and passive item has an `_endless` entry in `upgrade_db.gd` (e.g. `icespear_endless:673`, `armor_endless:763`).

4. **Enemy Spawner Routing to SwarmManager**:
   - `Utility/enemy_spawner.gd:203`:
     ```gdscript
     var is_swarm = (pool_type == "easy" or pool_type == "normal")
     ```
   - Lines 214-243: For `easy` and `normal` pools, enemy templates are read for texture and stats, and spawned exclusively via `swarm_manager.add_enemy(...)`. They are never instantiated as individual scene nodes. Standard node instantiation is reserved for `hard` (elites) and `super` (bosses).

5. **Undocumented Technical Debt Markers in Code**:
   - `Utility/swarm_manager.gd:57`:
     ```gdscript
     # Sound might need a pool, but for now we skip hit sounds for swarms to save audio channels, or play them globally rarely.
     ```
   - `Utility/swarm_manager.gd:98`:
     ```gdscript
     # This shader tightly controls animation by hardcoding the generated sizes, bypassing uniform caching issues
     ```
   - `Utility/global_events.gd:76-86`: `"punished_backup"` has `"starting_weapon": ""`. `TitleScreen/play_menu.gd:24` iterates over all `GlobalEvents.CHARACTERS.keys()`, displaying this incomplete test character to users.
   - `translations/translations.csv:30`:
     ```csv
     "ui_gameTitle","Inritus"
     ```
     Only 2 fields exist on line 30, whereas header has 4 columns (`"keys","en","ru","ua"`).
   - `Utility/SettingsManager.gd:135-140`:
     ```gdscript
     if raytracing_enabled:
         if unlimit_rtx:
             apply_max_fps(max_fps)
         else:
             Engine.max_fps = 10 # Cinematic 10fps
     ```

6. **Licensing & Copyright Observations**:
   - `LICENSE` in root is standard GPL-3.0 (35,149 bytes).
   - A search for `SPDX` across all `.gd` files returned 0 results. No `.gd` file has copyright headers.
   - `Audio/SoundEffect/BackgroundNoise/LICENSE.txt` contains CC-BY 4.0 license for Helton Yan.
   - `Textures/rorr/` contains sprite assets from *Risk of Rain Returns* (`sAlienHead.png`, `sBottled.png`, etc.).
   - `Textures/Items/Weapons/` contains weapon sprites from *Terraria* (`Vampire_Knives.webp`, `Kaleidoscope.webp`, `Leather_Whip.webp`).
   - `Audio/Music/Normal/` and `Audio/Music/Boss/` contain OST tracks from *Risk of Rain 2* by Chris Christodoulou (e.g. `04. Thermodynamic Equilibrium.mp3`). `.gitignore:42-46` ignores these audio files, but they reside in the local tree.

7. **Repository Hygiene**:
   - `TitleScreen/menu.tscn117201879.tmp` (7,125 bytes) is an uncleaned temporary file.
   - `Audio/desktop.ini` and `Textures/desktop.ini` are Windows Explorer metadata files.
   - `debug.keystore` is in root despite `*.keystore` in `.gitignore:22`.
   - `translations/translations.{en,ru,ua}.translation` are present in directory despite `*.translation` in `.gitignore:34`.

---

## 2. Logic Chain

1. **Documentation vs Codebase**:
   - Observations 1, 2, 3, and 4 establish that `GEMINI.md` was drafted when the project had only 4 basic weapons and early placeholder paths.
   - Since the project was updated to `Inritus v1.0.4`, 8 additional attack systems, Endless tiers, secondary boss AI (`dr_franklin.gd`), and SwarmManager wave routing were added without updating `GEMINI.md` or `README.md`.
   - Therefore, `GEMINI.md` and `README.md` must be comprehensively updated to reflect the true architecture.

2. **Technical Debt State**:
   - Observation 5 identifies 5 distinct undocumented issues directly in source comments and logic (MultiMesh uniform caching bypass, audio starvation on swarms, exposed ghost character, malformed translation line, and hidden 10 FPS cap).
   - `tech_debt.md` currently lists only 4 visual/UI quirks.
   - Therefore, `tech_debt.md` must be expanded to track these engine limitations and systemic compromises.

3. **YAGNI Standard Formulation**:
   - The existence of dead/backup configurations (e.g. `punished_backup`, empty `INACTIVE_CHARACTERS`) and past speculative proposals in `todo.md` (over-engineered pathfinding grids for a simple arena horde game) demonstrates the need for a strict anti-over-engineering guideline.
   - Therefore, enshrining YAGNI as an explicit AI rule (Rule 19) in `GEMINI.md` is necessary and directly addresses the prompt's core requirement.

4. **GPL-3.0 and Repository Compliance**:
   - Observations 6 and 7 show that while GPL-3.0 is declared via `LICENSE`, the codebase lacks source file header notices, commits ripped commercial assets (*Terraria*, *Risk of Rain Returns*), and contains local copyrighted audio.
   - Therefore, full compliance requires adding SPDX headers to code, tracking third-party asset licenses, deleting temp/OS clutter, and ensuring proprietary assets are marked for replacement before public release.

---

## 3. Caveats

1. **Dynamic Execution & Headless Testing**:
   - `run_command` timed out waiting for user permission prompt; all exploration was conducted strictly read-only via built-in filesystem inspection tools (`list_dir`, `view_file`, `grep_search`, `find_by_name`).
   - Headless execution of Godot unit tests was not executed during this survey turn.
2. **Binary Sprite Content**:
   - Exact sprite pixel comparison was verified via metadata, names, and explicit author credits in `README.md:23` ("Everyone who developed Vampire survivors, Brotato, Warframe, Risk of rain, Terraria...").

---

## 4. Conclusion

1. **`GEMINI.md` requires major modernization**:
   - Correct game title (`Inritus`) and version (`1.0.4`).
   - Fix script paths for Enemy Base and Bosses; document Dr. Franklin.
   - Document all 12 attack systems, Endless upgrade tiers, and companion/aura/trigger patterns.
   - Document SwarmManager wave routing for Easy/Normal pools.
   - Add **Rule 19: The YAGNI Standard**.
2. **`README.md` requires professional rewrite**:
   - Transition from informal university note to clean Antigravity 2.0-compliant documentation detailing architecture, singletons, testing, and licensing.
3. **`tech_debt.md` requires 5 new entries**:
   - TD-01 (MultiMesh dynamic shader string injection), TD-02 (Swarm hit audio starvation), TD-03 (Ghost character in UI), TD-04 (Malformed CSV line 30), and TD-08 (Raytracing 10 FPS cap).
4. **Repository & License Compliance**:
   - Delete `menu.tscn117201879.tmp`, `Audio/desktop.ini`, `Textures/desktop.ini`.
   - Fix `translations.csv:30` (`"ui_gameTitle","Inritus","Inritus","Inritus"`).
   - Ensure all future additions carry `SPDX-License-Identifier: GPL-3.0-or-later`.

Full detailed findings are documented in `.agents/teamwork/explorer_survey_2/survey_report.md`.

---

## 5. Verification Method

To independently verify these findings:

1. **Verify Project Metadata**:
   - `view_file` on `res://project.godot:17-20` confirms `name="Inritus"`, `version="1.0.4"`.
2. **Verify Correct File Paths**:
   - `view_file` on `res://Enemy/Base/enemy_body.gd` and `res://Enemy/Boss/boss.gd` (confirm they exist).
   - Attempt `view_file` on `res://Enemy/enemy_body.gd` (confirms it does not exist).
3. **Verify 12 Attack Folders**:
   - `list_dir` on `res://Player/Attack/` reveals 12 child directories.
4. **Verify Malformed Translation Line 30**:
   - `view_file` on `res://translations/translations.csv` lines 29-32 shows line 30 has only 2 fields.
5. **Verify Clutter Files**:
   - `view_file` on `res://TitleScreen/menu.tscn117201879.tmp` and `res://Audio/desktop.ini`.
