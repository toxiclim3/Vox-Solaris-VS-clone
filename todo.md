# Project Task List

## Performance Optimization: The Hybrid Enemy System
**Goal:** Restructure the enemy spawning and handling architecture to bypass Godot's physics-engine lag threshold, expanding swarm capacities from ~300 to 3,000+ entities onscreen.

### Phase 1: Architecture Split
Separate the active enemy types into the modern rogue-lite three-tier system:
1. **The Fodder (Swarm)**: Basic melee mobs (e.g., Slimes, Bats) that walk directly at the player. These will be stripped of Nodes and converted to raw data.
2. **The Tacticians (Specials/Elites)**: Ranged attackers, complex pathfinders, or dodging enemies. These will deliberately remain as `CharacterBody2D` Nodes to leverage Godot's built-in tools.
3. **The Spectacles (Bosses)**: Existing complex Boss Nodes representing massive bespoke events.

### Phase 2: Building the SwarmManager Data Pipeline
- Create a `SwarmManager.gd` node to handle all basic fodder.
- Enemies inside the SwarmManager exist entirely as subarrays/structs: `[x, y, max_hp, current_hp, speed, sprite_frame]`.
- Loop through the array every frame applying basic math-based movement: `velocity = global_position.direction_to(player.global_position) * speed`.

### Phase 3: MultiMesh Rendering
- Delete the `Sprite2D` nodes for typical swarm enemies.
- Attach a `MultiMeshInstance2D` to the `SwarmManager` to batch-draw thousands of sprites natively in a single GPU draw call using the X/Y coordinates fed directly from the Data Array.

### Phase 4: Data-Oriented Damage & Collisions
- Remove all `Area2D` and `CollisionShape2D` tracking for swarm logic.
- Weapons and the player should interact with the Swarm mathematically by querying the manager array using squared distance limits (`dist_sq < attack_radius_sq`) instead of relying on the physics broadphase.
- Apply basic radius-push math inside the array loop to prevent sprites perfectly overlapping.
