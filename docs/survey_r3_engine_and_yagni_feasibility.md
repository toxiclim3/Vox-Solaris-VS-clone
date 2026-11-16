# Handoff Report: Feasibility, Godot 4.6 Engine Compliance & YAGNI Review (R3)

## 1. Observation

### 1.1 SwarmManager Architecture & MultiMesh Constraints
- **MultiMesh Fodder Routing (`res://Utility/enemy_spawner.gd:203-244`)**:
  ```gdscript
  203: var is_swarm = (pool_type == "easy" or pool_type == "normal")
  ...
  214: if is_swarm and swarm_manager:
  ...
  220:     var template = enemy_info.enemy.instantiate()
  ...
  232:     var type_id = swarm_manager.register_enemy_type(tex, radius, hframes, vframes)
  ...
  240:     swarm_manager.add_enemy(get_random_position(), final_hp, final_hp, spd, template.experience, template.enemy_damage, type_id)
  243:     template.queue_free()
  ```
  100% of Easy and Normal enemies are instantiated once as a template to register atlas textures and frame data, after which the node template is immediately destroyed (`template.queue_free()`). The active combat units exist solely as lightweight GDScript data objects (`SwarmEnemy` in `res://Utility/swarm_manager.gd:3-44`) drawn via `MultiMeshInstance2D`. Only `spawns_hard` (Elites) and `spawns_super` (Bosses) exist as live nodes in the Godot SceneTree (`EnemySpawner.gd:244-258`).

- **Attack Collision Filtering (`res://Utility/swarm_manager.gd:189-245`)**:
  SwarmManager performs manual distance-based collision queries across `get_tree().get_nodes_in_group("attack")` every physics frame. An attack is strictly filtered out unless:
  1. It possesses a child node named `"CollisionShape2D"` (`atk.get_node_or_null("CollisionShape2D")`).
  2. Its collision layer has bit 2 (value 4) enabled (`atk.collision_layer & 4 != 0`).
  3. Its `CollisionShape2D.shape` is explicitly either `CircleShape2D` (`shape_type = 1`) or `RectangleShape2D` (`shape_type = 2`). Any attack using `CapsuleShape2D`, `ConvexPolygonShape2D`, `SegmentShape2D`, or a compound shape resolves to `shape_type = 0` and is completely ignored by SwarmManager.
  4. It provides `damage` and `knockback_amount` properties.
  5. It passes `killer_source` and supports `enemy_hit(1)` and `on_hit_enemy(enemy)`.

- **Swarm Enemy Structure & Lack of HurtBoxes (`res://Utility/swarm_manager.gd:3-23`)**:
  `SwarmEnemy` has no Godot Node identity, no `HurtBox` area, and no `Area2D` signal callbacks. Standard area signals (such as `_on_area_entered(area)` in `res://Player/Attack/poisonbottle/poison_gas.gd:88-98`) check `if area.name == "HurtBox"`: this check completely ignores all swarm enemies and fires solely on Elites and Bosses.

- **Spatial Grid Caching & Large Area Fallback (`res://Utility/swarm_manager.gd:179-188, 256-281`)**:
  The spatial grid partitions the world into 40x40 pixel cells. When an attack bounding circle/box radius (`search_r`) exceeds the spatial grid threshold such that `cell_count >= swarm_data.size()`, SwarmManager aborts the grid query and executes an $O(N)$ brute-force loop over the entire `swarm_data` array (up to 3,000 instances).

- **MultiMesh Rendering & Custom Data (`res://Utility/swarm_manager.gd:80-134, 465-509`)**:
  Each enemy type uses a single `MultiMeshInstance2D` with an unshaded GLSL canvas item shader. The vertex shader maps UVs using `INSTANCE_CUSTOM.r` for animation frame offsets. The G, B, and A channels of `INSTANCE_CUSTOM` are currently unused (`Color(enemy.anim_offset, 0, 0, 0)`). Per-instance color (`mm.set_instance_color`) is used for death flashes (`Color(1, 0, 0, 0.5)`) and curse debuffs (`Color(0.8, 0.4, 1.0)`).

### 1.2 State Management & Autoload Singletons
- **Disk I/O Hazard in `StatsManager` (`res://Utility/StatsManager.gd:37-43`)**:
  ```gdscript
  37: func register_kill(is_boss: bool) -> void:
  38:     if is_boss:
  39:         boss_kills += 1
  40:     else:
  41:         enemy_kills += 1
  42:     save_stats()
  ```
  `StatsManager.register_kill()` is called by `SwarmManager._handle_death()` on line 463 and by `EnemyBody.death()` on line 159. `save_stats()` invokes `config.save(SAVE_PATH)` synchronously to `"user://statistics.cfg"`. Under heavy AoE attacks destroying 50–100 swarm enemies per second, this triggers dozens of synchronous disk I/O operations per second on the main thread.

- **Weapon Upgrade Selection Contract (`res://Player/player.gd:717-750, 818-888`)**:
  1. `player.gd:735`: Extracts `var base_name = upgrade.rstrip("0123456789")` and attempts dynamic loading: `load("res://Player/Attack/" + folder_name + "/" + file_name + "_spawner.gd")`.
  2. `player.gd:826-831`: Unique weapon limits (`max_weapon_slots = 4` on Easy/Normal, `5` on Hard) are tracked via `displayname = UpgradeDb.UPGRADES[collected]["displayname"]`.
  3. `player.gd:845-855`: Prerequisites are verified via strict `Array.has()`:
     ```gdscript
     847: for n in UpgradeDb.UPGRADES[i]["prerequisite"]:
     848:     if not n in collected_upgrades:
     849:         to_add = false
     ```
  4. Non-endless items already collected are rejected (`if i in collected_upgrades: continue`).

- **Unit Test Integrity Suite (`res://Tests/Unit/test_upgrade_db.gd`)**:
  The automated headless test suite enforces strict invariants:
  - Line 18: `required_keys = ["icon", "displayname", "details", "level", "prerequisite", "type"]`.
  - Line 39: `allowed_types = ["weapon", "upgrade", "bossitem", "item", "endless"]`.
  - Line 46: `allowed_levels = ["item_level1", "item_level2", "item_level3", "item_level4", "item_levelNA", "item_level_endless"]`.
  - Line 101-115: `test_sequential_level_progression()` enforces that any `item_level4` item must specify a prerequisite whose level is `item_level3`.
  - Line 143-153: `test_core_weapon_families_exist()` asserts that keys `<prefix>1` through `<prefix>4` exist for `["icespear", "javelin", "tornado", "poisonbottle", "ritualcircle", "lightningrod", "whip"]`. Any change that deletes or renames `icespear4` breaks this test suite immediately.

### 1.3 Engine Architecture & Technical Debt
- **MultiMesh Uniform Binding Limitation (`res://tech_debt.md:47-53`)**:
  Godot 4.6 (Mobile renderer) uniform updates via `set_shader_parameter()` fail to propagate cleanly across instance pools or trigger shader recompilations. `SwarmManager` generates dynamic GLSL code once during initialization.
- **Line2D Coordinate Distortion (`res://tech_debt.md:9-18`)**:
  Line2D polygons with Nearest Neighbor filtering drop pixels during sharp bends.
- **Audio Channel Starvation (`res://tech_debt.md:58-65`)**:
  Swarm hit SFX are intentionally suppressed because hundreds of concurrent audio events starve AudioServer channels and trigger main-thread audio clipping.
- **PhasedAnimator Pattern (`res://Utility/phased_animator.gd:8-63`)**:
  Standardized START $\to$ LOOP $\to$ FINISH frame sequence on `Sprite2D`. Persistent AOE hazards must use this pattern or a tween-based fade out to comply with Rule 11.
- **Shader Prewarmer (`res://Utility/shader_prewarmer.gd:14-56`)**:
  Loads materials listed in `res://Utility/PreheatMaterials.tres` into a 2x2 hidden SubViewport on title screen load to force GPU driver shader pipeline compilation.

---

## 2. Logic Chain

```
[SwarmManager: 100% of Easy/Normal enemies are MultiMesh instances without HurtBoxes]
                                     │
      ┌──────────────────────────────┴──────────────────────────────┐
      ▼                                                             ▼
[Hazards MUST be Layer 3 Area2Ds with         [Complex AI / mutations CANNOT run on
 Circle/Rect shapes in group "attack";         Swarms; must be restricted to Elites /
 continuous checks in >40px radii degrade      Bosses or use INSTANCE_CUSTOM GPU data]
 O(N) spatial grid -> Timed pulses required]
```

```
[StatsManager.register_kill() calls config.save() on every kill]
                                     │
                                     ▼
[50-100 kills/sec from swarm AoE = 50-100 sync disk writes/sec]
                                     │
                                     ▼
[Must buffer/debounce disk saves to register_end_run() or run exit]
```

```
[test_upgrade_db.gd requires base 1-4 tiers + sequential levels + strict schema]
                                     │
                                     ▼
[Weapon branching CANNOT delete or rename `<weapon>4`; must use parallel terminal
 keys (e.g. icespear4_a) or branch off Tier 4 with "branch_group" mutual exclusion]
                                     │
                                     ▼
[Spawners already use match arms; same spawner node handles branches without new scripts]
```

1. **Environmental Hazards on Swarms**:
   - Because `SwarmManager` only scans nodes in `"attack"` on Layer 3 with child `"CollisionShape2D"`, an environmental hazard (e.g., magma fissure, electric trap) will completely fail to damage fodder enemies if implemented as a standard physics obstacle or Area2D without Layer 3.
   - Furthermore, because large shapes trigger the spatial hash fallback (`cell_count >= swarm_data.size()`), any hazard with a radius greater than ~120px checking every frame will iterate through 2,000+ data structs per frame, dropping FPS. Therefore, environmental hazards must pulse via a `Timer` (e.g. 0.5s interval, clearing `hit_once_array`), identical to `poison_gas.gd:71-81`.

2. **Enemy Mutations & Dynamic Modifiers**:
   - Since `SwarmEnemy` is a pure data struct, giving swarm enemies complex behaviors (such as shooting, dodging, or charging) would require rewriting the unrolled `_physics_process` loop in `swarm_manager.gd`, defeating its CPU-cache efficiency.
   - Visual mutations on swarms cannot attach sprites or aura scenes. They must either:
     a) Register a distinct `type_id` (new MultiMeshInstance2D).
     b) Use vertex color modulation (`set_instance_color`).
     c) Feed custom parameters into the unused `INSTANCE_CUSTOM.g` or `.b` channels in the shader.
   - Consequently, **complex mechanical mutations must be exclusive to Elites and Bosses (`EnemyBody`)**, while Swarm variance must be restricted to numeric scaling (speed, health, damage) or GPU shader tinting.

3. **Permanent Meta-Progression Persistence**:
   - Creating a new `SaveManager` or JSON/SQLite framework violates Rule 19 (No Speculative Abstractions).
   - `StatsManager.gd` already manages `ConfigFile` persistence at `"user://statistics.cfg"`.
   - Extending `StatsManager.gd` with a `[progression]` section (or a paired `"user://progression.cfg"`) to store meta-currency, unlocked loadouts, and pacts requires ~30 lines of code.
   - Removing the synchronous `config.save()` from `register_kill()` and moving it to `register_end_run()` eliminates the severe I/O bottleneck while maintaining data integrity.

4. **Weapon Branching Architecture in UpgradeDb**:
   - In `player.gd`, `var base_name = upgrade.rstrip("0123456789")` is used to load `res://Player/Attack/<folder>/<folder>_spawner.gd`.
   - If a branch is named `icespear_shatter`, it would search for `icespear_shatter_spawner.gd`, which violates the single-spawner architecture and would leave the original `icespear` spawner firing simultaneously.
   - If a branch is named `icespear4_shatter`, `rstrip("0123456789")` produces `"icespear4_shatter"`, which fails spawner lookup.
   - In `test_upgrade_db.gd`, `test_core_weapon_families_exist()` explicitly checks for `icespear4`.
   - **The Architecturally Sound Solution**:
     Keep `icespear4` as the base upgrade. Add terminal branch upgrades `icespear4_lance` and `icespear4_flurry` with:
     ```gdscript
     "prerequisite": ["icespear3"],
     "level": "item_level4",
     "type": "weapon",
     "displayname": "item_icespear",
     "branch_group": "icespear4"
     ```
     In `player.gd:get_random_item()`, add a 7-line check: if an item has `"branch_group"`, check if any collected upgrade already shares that `"branch_group"`; if so, skip it.
     In `player.gd:upgrade_character()`, resolve `base_name` using `UpgradeDb.UPGRADES[upgrade].get("base_weapon", upgrade.rstrip("0123456789"))`.
     In `<weapon>_spawner.gd`, the existing `match upgrade_id:` block matches the branch key and sets an internal `branch = "lance"` mode.
     For endless scaling:
     In `UpgradeDb.gd`, define:
     ```gdscript
     "icespear_endless": {
         "prerequisite": ["icespear4", "icespear4_lance", "icespear4_flurry"],
         "prerequisite_mode": "any",
         "type": "endless",
         ...
     }
     ```
     In `player.gd:get_random_item()`, evaluate `"prerequisite_mode": "any"` using logical OR.
     This fulfills all requirements with zero new classes, zero new scenes, and 100% test suite compatibility.

5. **YAGNI Compliance Audit**:
   - Proposed variance systems must strictly avoid manager hierarchies (e.g., `HazardDirector`, `ProgressionTreeManager`, `EvolutionRegistry`).
   - All proposed mechanics can be delivered using:
     1. Existing Singletons (`StatsManager`, `UpgradeDb`, `GlobalEvents`).
     2. Standard `Area2D` scenes on Layer 3 for arena hazards.
     3. Dictionary metadata extensions in `UpgradeDb.UPGRADES`.

---

## 3. Caveats

1. **MultiMesh Shader Variant Limits**: While `INSTANCE_CUSTOM.g` and `.b` can pass numeric parameters to the MultiMesh vertex shader without recompilation, changes to the texture atlas itself (adding new enemy sprite frames) require calling `swarm_manager.register_enemy_type()` with the new texture.
2. **Godot 4.6 Compatibility**: In Godot 4.6 Mobile renderer, dynamically creating new `ShaderMaterial` instances at runtime can cause frame hitching. Any new shaders created for weapon branches or arena hazards must have their materials pre-registered in `res://Utility/PreheatMaterials.tres`.
3. **Headless Godot CLI**: In Windows PowerShell, the headless test runner must be executed with `--path` pointing to the project directory and piped to `Out-Default` or `Out-String` to capture standard output due to Windows console subsystem buffering.

---

## 4. Conclusion

The existing architecture in Inritus provides a high-performance, robust foundation that can fully accommodate permanent meta-progression, weapon branching, and emergent arena mechanics **provided the following strict implementation constraints are enforced**:

1. **Swarm Hazard Contract**: All arena hazards interacting with fodder swarms must be `Area2D` nodes in group `"attack"`, set to `collision_layer = 4` (Layer 3), with a child named `"CollisionShape2D"` restricted to `CircleShape2D` or `RectangleShape2D`. Hazards must pulse damage via a timer (clearing `hit_once_array`) rather than maintaining active continuous collision to prevent $O(N)$ spatial grid degradation.
2. **Elite-Only Behavioral Mutations**: Swarm enemies (`SwarmEnemy`) cannot run complex AI behaviors. Elite and Boss enemies (`EnemyBody`) must host all behavioral mutations, while swarms receive only global numeric modifiers or GPU shader tints via `INSTANCE_CUSTOM`.
3. **I/O Sanitization in StatsManager**: Synchronous disk writing in `StatsManager.register_kill()` must be removed. All persistent progression (meta-currency, unlocked character loadouts, pacts) must be stored in `user://statistics.cfg` (or `user://progression.cfg`) and flushed exclusively upon run completion (`register_end_run()`) or menu exit.
4. **Non-Destructive Weapon Branching**: Base weapon keys `icespear1` through `icespear4` must remain in `UpgradeDb.UPGRADES` to satisfy `test_upgrade_db.gd`. Branching is implemented by registering parallel Tier 4 options with `"branch_group"` metadata and `"prerequisite_mode": "any"` for endless scaling. Spawner logic is handled directly in the existing `<weapon>_spawner.gd` via pattern matching.
5. **Zero New Managers (Rule 19)**: No new manager classes, buses, or abstract factory hierarchies are permitted. All systems interface directly with `StatsManager`, `UpgradeDb`, `GlobalEvents`, and direct node instantiation.

---

## 5. Verification Method

### 5.1 Test Suite Execution
Run the automated test runner in headless mode from the project repository:
```powershell
godot --headless --path "d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%" -s "res://Tests/test_runner.gd" | Out-Default
```
**Expected Outcome**: 7 suites, 116 tests pass, 0 failures.

### 5.2 Specific Invalidation Conditions
A proposed implementation of variance mechanics is **INVALID** if:
1. `test_upgrade_db.gd` fails on `test_core_weapon_families_exist()` or `test_sequential_level_progression()`.
2. An environmental hazard fails to damage swarm enemies because it lacks group `"attack"`, Layer 3 (`collision_layer & 4`), or a child named `"CollisionShape2D"`.
3. An environmental hazard uses `CapsuleShape2D` or `ConvexPolygonShape2D` (which resolves to `shape_type = 0` in `swarm_manager.gd:206-215`).
4. `StatsManager.gd` executes synchronous disk writes on every kill during a swarm horde.
5. Weapon branching introduces duplicate weapon spawner nodes under `%Weapons` or consumes an extra weapon slot against `max_weapon_slots`.
6. New shaders trigger runtime compilation hitches because they were omitted from `res://Utility/PreheatMaterials.tres`.
