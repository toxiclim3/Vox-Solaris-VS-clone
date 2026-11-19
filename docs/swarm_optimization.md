# Swarm Enemy Optimization & Pathfinding Architecture

This document details how swarm enemies are currently optimized in **Inritus**, identifies remaining CPU/allocation bottlenecks with concrete optimization strategies, and outlines a scalable pathfinding architecture for when obstacle-based maps are introduced.

---

## 1. Current Swarm Optimization Architecture

The swarm system is split between wave routing in `Utility/enemy_spawner.gd` and simulation/rendering in `Utility/swarm_manager.gd`. It achieves high enemy counts by bypassing Godot's `SceneTree`, `PhysicsServer2D`, and `AnimationPlayer` for fodder waves.

### SceneTree Bypass & Wave Routing
* **100% Fodder Redirection:** In `Utility/enemy_spawner.gd` (`spawn_enemy_group()`), every `"easy"` and `"normal"` wave sets `is_swarm = true`. Standard node instantiation (`CharacterBody2D`, `Sprite2D`, `HurtBox`, `HitBox`) is reserved strictly for `"hard"` (elites) and `"super"` (bosses).
* **Separate Population Caps:** Scene-node enemies are governed by a dynamic FPS-adjusted `soft_limit` (80–400 nodes), whereas swarm enemies use a separate hard cap of **~3,000 instances**.

### Data-Oriented Representation (`SwarmEnemy`)
* **Lightweight `RefCounted` Objects:** Each unit is an instance of the inner `SwarmEnemy` class stored in `swarm_data: Array[SwarmEnemy]`. It holds only essential state: `position`, `hp`, `max_hp`, `speed`, `knockback`, `separation`, `anim_offset`, and `active_debuffs`.
* **Duck-Typed Compatibility:** `SwarmEnemy` exposes a `global_position` property getter/setter aliasing `position`, along with `_on_hurt_box_hurt()`, `is_alive()`, and debuff helpers. This allows weapons, status effects (e.g., Occult Medallion's `"curse"`), and reflected damage (Thorn Ring) to interact with `SwarmEnemy` instances just like `EnemyBody` nodes.

### Single-Draw-Call GPU Instancing (`MultiMeshInstance2D`)
* **Batching by Texture:** `register_enemy_type()` creates one `MultiMeshInstance2D` per unique enemy sprite sheet. All enemies of the same visual type are rendered in **1 draw call**.
* **Zero-Downsize Buffer Management:** In `_update_multimeshes()`, `mm.instance_count` only grows when the population exceeds the previous high-water mark. When enemies die, `mm.visible_instance_count` is lowered instead of shrinking `instance_count`, avoiding costly GPU buffer reallocations.
* **Vertex-Shader Animation & Per-Instance State:**
  * Each enemy receives a random `anim_offset` via `INSTANCE_CUSTOM.r` so hordes do not animate in lockstep.
  * Sprite-sheet UV slicing (`UV = (UV * frame_size) + uv_offset`) executes in the GPU vertex shader driven by a single `time` uniform.
  * `HFRAMES`, `VFRAMES`, and `FPS` are injected as GLSL constants into `shader.code` at registration time to work around a Godot 4.6 Mobile renderer uniform-caching bug (see `docs/tech_debt.md`).
  * Visual states (red death flash, purple curse tint) are passed via per-instance `COLOR`, and horizontal sprite flipping is encoded into the X-scale of each instance's `Transform2D`.

### $O(N)$ Spatial Hashing Grid
* Every `_physics_process`, `SwarmManager` clears and rebuilds `spatial_grid: Dictionary` in $O(N)$ time, partitioning live enemies into $40 \times 40\text{ px}$ cells (`floor(pos / 40.0)`).
* This single data structure accelerates both **enemy-to-enemy separation** and **weapon-to-enemy hit detection**.

### Time-Sliced BoID Separation & Anti-Slingshot Math
* **3-Frame Staggering:** Evaluating neighbor repulsion across $3 \times 3$ grid cells is staggered so only $\frac{1}{3}$ of the swarm updates separation on any given physics frame (`if frame % 3 == (i % 3):`), reducing separation CPU cost by **66%**.
* **Cached Lerp:** On off-frames, enemies reuse their cached `enemy.separation` vector, which is smoothed via `lerp` when updated.
* **Forward Speed Clamping:** To prevent rear crowd pressure from launching front-row enemies into the player, the forward component of `pursuit + separation` is clamped via dot product (`movement.dot(pursuit_dir)`) to `enemy.speed` while still allowing lateral and backward knockback.

### Custom Analytical Collision (Weapons & Player)
* **Attack Pre-Caching:** Nodes in group `"attack"` on collision Layer 3 (`collision_layer & 4`) with an enabled `CollisionShape2D` are parsed once per tick into `attack_data`.
* **Grid-Culled Narrowphase:** Each weapon computes its bounding search radius (`search_r`) and queries only overlapping `spatial_grid` cells (falling back to `swarm_data` if the AOE covers more cells than total active enemies).
* **Pure Math Hit Tests:** `CircleShape2D` uses squared-distance checks (`distance_squared_to`), and `RectangleShape2D` transforms the enemy point into the hitbox's local space (`affine_inverse() * enemy.position`) for an AABB check.
* **Capped Player Crowd-Push:** Player contact uses a soft-collision overlap formula that accumulates a push vector across touching enemies and caps it at `max_push = 300.0`, allowing swarms to body-block the player without physics jitter.

### Audio & VFX Throttling
* Hit sounds are skipped for swarm units to avoid starving Godot's `AudioServer` polyphony channels, and death explosion scenes (`explosion.tscn`) only instantiate $50\%$ of the time (`explosion_chance = 0.5`), relying on a $0.2\text{ s}$ red vertex-color flash for the remainder.

---

## 1.5 Empirical Benchmarks & Collision Guardrails

> Merged from headless Godot 4.6 stress benchmarks (`combat_multimesh_benchmarks_and_mitigations.md`) and engine audits (`survey_r3_engine_and_yagni_feasibility.md`).

### Headless Godot 4.6 Performance Benchmarks
* **3,000-Instance MultiMesh Update (`0.904 ms/frame`):** Updating `set_instance_transform_2d`, `set_instance_color`, and `set_instance_custom_data` across `3,000` active units averages **`0.904 ms/frame`** (`< 5.5%` of the `16.67 ms` 60 FPS frame budget and `< 18.1%` of a `5.0 ms` physics budget).
* **Spatial Grid Build (`0.206 ms`) vs. High-Density Separation Spike (`6.193 ms/frame`):** Rebuilding the `40x40 px` `spatial_grid` takes **`0.206 ms`**. However, compressing `500` swarm units into a tight `140 px` radius (reaching `21 units/cell` across `45 active cells`) spikes neighbor separation calculation to **`6.193 ms/frame`** and produces unnormalized repulsion vectors up to **`4.88`** (`~780.7 px/s` outward "popcorn" slingshot velocity).
  * **Mitigation for Pull / Vortex Mechanics:** Any future gravitational pull or vortex skill compressing swarm units must set a temporary dampening flag (or cap `push_vector` magnitude) during the pull window to prevent the `6.193 ms` separation spike and violent outward ejection.

### Spatial Query & Rendering Guardrails
* **Large-Area Spatial Grid Fallback Mandate:** In `Utility/swarm_manager.gd:256-281`, whenever an attack's queried `cell_count >= swarm_data.size()`, `SwarmManager` aborts spatial grid culling and executes an $O(N)$ brute-force loop over all active `swarm_data`. Large AOE fields (`radius > 80–120 px`) **must not** query continuously every physics frame; they must pulse via a `Timer` (`0.3s–0.5s`, clearing `hit_once_array`) following `poison_gas.gd`.
* **Supported Collision Shapes Only:** `SwarmManager` analytical collision supports only `CircleShape2D` (`shape_type = 1`) and `RectangleShape2D` (`shape_type = 2`) on Layer 3 (`collision_layer & 4`) under group `"attack"` with child `"CollisionShape2D"`. `CapsuleShape2D`, `ConvexPolygonShape2D`, and `SegmentShape2D` resolve to `shape_type = 0` and are silently ignored.
* **Instance Color Persistence:** Because `_update_multimeshes()` resets each unit's `color = Color(1, 1, 1, 1)` every physics frame (branching only for `death_timer > 0` or `has_debuff("curse")`), any persistent per-instance visual state must be driven by a field on `SwarmEnemy` evaluated inside `_update_multimeshes()`—or packed into the unused `INSTANCE_CUSTOM.g`, `.b`, and `.a` shader channels.

---

## 2. Potential Further Optimization Strategies

Even with the optimizations above, several hot paths in GDScript perform unnecessary per-frame work or heap allocations when approaching 2,000–3,000 active enemies:

### 1. Eliminate $O(N)$ Array Shifts & Template Node Churn
* **Swap-and-Pop Removal:** In `SwarmManager._physics_process()`, `swarm_data.remove_at(i)` shifts every subsequent element in the array down by one index ($O(N)$ per death). Replacing it with a **swap-and-pop** makes removal $O(1)$:
  ```gdscript
  swarm_data[i] = swarm_data.back()
  swarm_data.pop_back()
  continue # Do not increment i; process the swapped element next
  ```
* **Cache Enemy Templates in `EnemySpawner`:** `EnemySpawner.spawn_enemy_group()` currently calls `enemy_info.enemy.instantiate()` and `template.queue_free()` on every swarm wave just to read texture, frame counts, base HP, and speed. Caching extracted properties keyed by `enemy_info.enemy.resource_path` eliminates scene instantiation during fodder waves.

### 2. Hoist `affine_inverse()` & Optimize `hit_once_array`
* **Precompute Matrix Inversion:** `atk.cs_node.global_transform.affine_inverse()` is currently recalculated for every candidate enemy tested against a `RectangleShape2D` weapon (Whip, Glass Lash, Javelin). Precomputing `inv_transform` once when building `attack_data` removes hundreds of matrix inversions per frame.
* **$O(1)$ Hit Deduplication:** `if atk.hit_enemies.has(enemy):` performs a linear $O(H)$ array scan. When a persistent or piercing attack (Tornado, Ritual Circle) hits hundreds of enemies, this becomes $O(N \times H)$. Storing `hit_enemies` as a `Dictionary` hash set (or assigning each `SwarmEnemy` an integer ID) turns this into an $O(1)$ lookup.

### 3. Zero-Allocation Spatial Grid
* Currently, `spatial_grid.clear()` frees and reallocates hundreds of small `Array` buckets every physics tick, keyed by floating-point `Vector2`.
* **Quick Win:** Key `spatial_grid` by `Vector2i(int(floor(x / 40.0)), int(floor(y / 40.0)))` for faster integer hashing.
* **Zero-Allocation Win:** Replace the `Dictionary` of `Array`s with two preallocated `PackedInt32Array` buffers:
  * `cell_head: PackedInt32Array` (sized to a fixed 2D grid window around the player, cleared with `.fill(-1)` each frame).
  * `enemy_next: PackedInt32Array` (sized to `3000`, where `enemy_next[i]` points to the next enemy index in the same cell).
  * Rebuilding the grid becomes two integer assignments per enemy with **zero heap allocations**.

### 4. Stop Full-Swarm Linear Scans in Targeting & Weapons
* Several external scripts ignore `spatial_grid` and scan all 3,000 `swarm_data` entries linearly:
  * `Player/player.gd` (`_collect_valid_targets()`): Scans all `swarm_data` and allocates a new `Dictionary` (`{"pos", "hp", "dist_sq"}`) for every enemy within $400\text{ px}$ whenever a weapon requests a target.
  * `Player/Attack/lightningrod/lightningrod.gd`: Scans all `swarm_data` on every chain bounce.
  * `Player/Attack/occult_medallion/occult_medallion_spawner.gd`: Copies and custom-sorts all `swarm_data` every $0.5\text{–}2.0\text{ s}$.
* **Fix:** Expose spatial query helpers directly on `SwarmManager` (e.g., `get_closest_in_radius(pos, radius)`, `get_random_in_radius(pos, radius)`) that query `spatial_grid` cells directly without intermediate `Dictionary` allocations.

### 5. Bulk MultiMesh Upload (`RenderingServer.multimesh_set_buffer`)
* `_update_multimeshes()` currently crosses the GDScript-to-C++ boundary $3 \times 3,000 = 9,000\text{ times}$ per frame (`set_instance_transform_2d`, `set_instance_color`, `set_instance_custom_data`).
* Maintain a single `PackedFloat32Array` per MultiMesh (16 floats per 2D instance: 8 for `Transform2D`, 4 for `Color`, 4 for `Custom Data`), write floats directly into the array, and push the entire buffer in **one call** per enemy type via `RenderingServer.multimesh_set_buffer(mm.get_rid(), buffer)`.
* *Bonus:* Pack horizontal `flip` (`+1.0` / `-1.0`) into `INSTANCE_CUSTOM.g` and apply flipping in the vertex shader, avoiding 3,000 CPU `.scaled_local()` calls per frame.

### 6. XP Gem Pooling & Spatial Merging
* When a large AOE kills hundreds of swarm enemies in a single frame, `_handle_death()` calls `exp_gem_scene.instantiate()` and `call_deferred("add_child", new_gem)` for every kill, creating a spike of `Area2D` physics nodes.
* Object-pooling XP gems—or accumulating dropped XP inside `spatial_grid` cells during a frame and spawning a single merged high-tier gem per cell—prevents post-explosion frame hitches.

---

## 3. Pathfinding & Obstacle Strategies When Maps Are Implemented

Once maps introduce walls, pillars, corridors, or hazards, direct line-of-sight steering (`enemy.position.direction_to(p_pos)`) will cause hordes to get stuck on corners. Because `SwarmEnemy` instances are not `CharacterBody2D` nodes, they also lack built-in wall collision (`move_and_slide()`).

Standard per-agent pathfinding (`NavigationAgent2D` or per-enemy $A^*$) will not scale to 3,000 enemies. Instead, use a **Flow Field (Vector Field) + Grid SDF** architecture:

```mermaid
flowchart LR
    Map["TileMapLayer Obstacles"] --> IntField["1. Integration Field (BFS from Player)"]
    IntField --> FlowField["2. Flow Vector Grid + LOS Flags"]
    FlowField --> Steer["3. O(1) Enemy Steering Lookup"]
    Steer --> WallResolve["4. Grid / SDF Wall Pushout"]
```

### 1. Flow Field Pathfinding ($O(1)$ Cost Per Enemy)
Instead of each enemy computing a path to the player, **the map computes a single shared navigation field toward the player**:
1. **Sliding Grid Window:** Maintain a 2D grid centered on the player (e.g., $64 \times 64$ or $80 \times 80$ tiles of $32 \times 32\text{ px}$ or $40 \times 40\text{ px}$, covering the viewport plus spawn margin).
2. **Integration Field (Dijkstra / BFS Pass):** Start at the player's tile with `cost = 0` and run a Breadth-First Search outward across walkable tiles, recording each tile's step distance to the player. Solid wall tiles are marked `INF`.
3. **Flow Field (Gradient Pass):** For each walkable tile, compute a normalized `Vector2` pointing toward the neighbor with the lowest integration cost (or average the gradients of the 4 cardinal neighbors for smooth diagonal vectors).
4. **$O(1)$ Enemy Lookup:** Replace `enemy.position.direction_to(p_pos)` with a fast grid lookup (optionally bilinearly interpolated across the 4 nearest cell centers so hordes curve smoothly around corners).
5. **Scaling & Threading:** Pathfinding cost depends **only on grid cell count** (e.g., $4,096\text{ cells}$), remaining constant whether there are 50 or 50,000 enemies. The field only needs recomputing when **the player enters a new grid cell** (2–4 times per second) and can run asynchronously on Godot's `WorkerThreadPool`.

### 2. Hybrid Line-of-Sight (LOS) Shortcut
Pure grid flow fields can appear slightly grid-aligned in open areas:
* During the BFS pass, propagate a `has_los: bool` flag (or run a fast 2D DDA/shadowcast from the player's cell).
* If an enemy's cell has direct line-of-sight to the player (`has_los == true`), steer using exact `enemy.position.direction_to(p_pos)`.
* If an obstacle blocks LOS (`has_los == false`), steer using the Flow Field vector until line-of-sight is regained.

### 3. Fast Wall Collision Without `PhysicsServer2D`
Even with Flow Field steering, **BoID separation** (`enemy.separation`) and **weapon knockback** (`enemy.knockback`) will push enemies sideways into walls. Right after `enemy.position += velocity * delta`, run a lightweight geometric pushout:
* **Option A — Local Tile Circle-vs-AABB Resolution:** Check the $3 \times 3$ map tiles surrounding `enemy.position`. For any solid tile, clamp `enemy.position` to the tile's AABB to find the closest point on the wall, and if `dist_sq < enemy_radius_sq`, push `enemy.position` out along the normal.
* **Option B — Prebaked Signed Distance Field (SDF):** When a map loads, precompute a 2D distance-and-normal grid storing the distance and push-out direction to the nearest static wall. Resolving wall collisions for 3,000 enemies becomes a single array read per enemy with zero branching.

### 4. Map-Aware Spawning & Leashing (`EnemySpawner`)
Currently, `get_random_position()` picks a random coordinate along a rectangle $1.1\times\text{–}1.4\times$ the viewport size. On maps with walls or rooms:
* **Spawn Validation:** Before spawning an enemy at `pos`, check the Flow Field's Integration value at `pos`. Only accept cells where `integration_cost < MAX_SPAWN_PATH_COST`. This guarantees in $O(1)$ time that enemies never spawn inside walls, outside map bounds, or in sealed/distant rooms.
* **Topological Leashing (Respawn Relocation):** If the player passes through a choke point and leaves hundreds of swarm enemies trapped behind a wall (`integration_cost` very high or `INF`), recycle those units by relocating them to valid perimeter cells ahead of the player instead of letting them consume the 3,000-enemy cap off-screen.
