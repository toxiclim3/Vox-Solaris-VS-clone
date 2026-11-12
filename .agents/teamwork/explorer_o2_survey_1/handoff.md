# Handoff Report: R1 Design Guidelines & Backlog Update Investigation

## 1. Observation

### 1.1 Cooldown Safety Floor & Weapon Spawner Timers
- **`design_guidelines.md:170-172`**:
  ```markdown
  ### 2. Attack Cooldown
  Weapons determine their firing interval as:
  $$t_{\text{wait}} = t_{\text{base}} \times (1.0 - \text{player.spell\_cooldown})$$
  ```
  *Finding:* No minimum safety floor is currently specified in the design formula.
- **Weapon Spawner Code**:
  - `Player/Attack/icespear/icespear_spawner.gd:43`: `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
  - `Player/Attack/tornado/tornado_spawner.gd:44`: `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
  - `Player/Attack/whip/whip_spawner.gd:44, 75`: `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)`
  - `Player/Attack/vampireknives/vampireknives_spawner.gd:55, 62`: `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)`
  - `Player/Attack/poisonbottle/poisonbottle_spawner.gd:40`: `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
  - `Player/Attack/glasslash/glasslash_spawner.gd:50, 80`: `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)`
  - `Player/Attack/ritualcircle/ritualcircle_spawner.gd:42`: `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
  - `Player/Attack/lightningrod/lightningrod_spawner.gd:35, 44`: `var actual_cooldown = max(0.1, base_cooldown * (1.0 - player.spell_cooldown))`
  *Finding:* Only `lightningrod_spawner.gd` enforces a lower bound (`0.1s`). All other spawners risk setting `timer.wait_time <= 0` or micro-delays (< 0.05s) when high CDR from scrolls/endless stacks combines with attack speed buffs (e.g., Frenzy Charm +30% attack speed).

### 1.2 Universal Proc Coefficients & On-Hit Mechanics
- **`design_guidelines.md:182-189`**:
  Currently only defines proc coefficient usage in relation to lifesteal:
  $$\text{Heal} = \text{Damage} \times \text{Lifesteal} \times \text{proc\_coefficient}$$
  Lacks contracts for on-hit accessory trigger probabilities, duration scaling, and loop suppression.
- **Signal & Attack Integration**:
  - `Utility/global_events.gd:14`: `signal player_dealt_damage(amount: float, target_node: Object, proc_coefficient: float)`
  - `Enemy/Base/enemy_body.gd:167`: Emits `player_dealt_damage(damage, self, proc_coefficient)`
  - `Utility/swarm_manager.gd:278`: Emits `player_dealt_damage(atk.damage, enemy, proc_co)`
  - `Player/Attack/relicdrone/RelicRocket.gd:12`: `var proc_coefficient = 0.0 # Proc items shouldn't proc themselves`
  - `Player/Attack/willowisp/willowisp_explosion.gd:9`: `var proc_coefficient = 0.1`
  - `Player/Attack/tornado/tornado.gd:10`: `var proc_coefficient = 0.5`
  - `Player/Attack/vampireknives/vampireknife.gd:9`: `var proc_coefficient = 0.5`
  - `Player/Attack/poisonbottle/poison_gas.gd:60`: `damage_box.proc_coefficient = 0.2`

### 1.3 Conditional Buffs & Signal Architecture
- **`Player/player.gd`**:
  - HP modifications occur in `_on_hurt_box_hurt` (lines 256), `_on_regen_timer_timeout` (line 222), `_on_player_dealt_damage` (line 816), and `apply_stat_modifiers` (lines 518-522).
  - There is currently no `health_ratio_changed` signal.
  - Adding polling inside `_physics_process` or `_process` for health items (Glass Talisman, Frenzy Charm, Impact Buckler) would violate Rule 19 (YAGNI) and degrade frame time.

### 1.4 Terraria-Inspired Internal Cooldown (ICD) Structures
- **`Utility/hurt_box.gd:3, 16-18`**:
  - `HurtBox` has `Cooldown` mode using a `DisableTimer` to temporarily disable its `CollisionShape2D`.
  - When the player is damaged, a shared invulnerability buffer protects against frame-level shotgunning from swarms.
  - However, defensive items (e.g. Impact Buckler emergency blast cooldown, Warding Brooch 10s recharge) must operate on autonomous local ICDs independent of player hurtbox state.

### 1.5 Enemy Tenacity & Crowd Control
- **`Utility/swarm_manager.gd:273, 298-299`**:
  - Swarms receive raw knockback (`enemy.knockback = angle * atk.knockback_amount`) and damp toward zero with step 3.5.
- **`Enemy/Base/enemy_body.gd:82, 125, 165`**:
  - `EnemyBody` receives raw knockback without tenacity dampening unless customized per subclass.
- **`Enemy/Boss/boss.gd` & `Enemy/Boss/dr_franklin.gd`**:
  - Bosses inherit from `EnemyBody` and have state machines and telegraphs. Displacing them disrupts visual alignments and arena bounds.

### 1.6 The Punished Character Status
- **`Utility/global_events.gd:65-75`**:
  ```gdscript
  "punished": {
      "displayname": "char_punished",
      "icon": "res://Textures/Player/player_sprite.png",
      "icon_color": Color(0.2, 0.2, 0.2), # Dark grey
      "starting_weapon": "whip1",
      "details": "char_punished_desc",
      "base_stats": {},
      "scaling_stats": {},
      "scaling_max_level": 20,
      "shader_config": {"mix_hue": true, "mix_saturation": true}
  }
  ```
- **`design_guidelines.md:34-36`**: Caution box warning about the historical failure mode of giving him dual passives (Thorns + Regen).
- **`todo.md:30-39`**: Marked as "Deferred until supporting item/weapon pool exists".
- **`Player/player.gd:460-474`**:
  `apply_stat_modifiers()` parses `base_stats` for:
  `armor`, `movement_speed_percent`, `spell_cooldown`, `spell_size`, `additional_attacks`, `max_hp_percent`, `regen`, `xp_range_percent`, `lifesteal`, `armor_multiplier`, `reflected_damage`.
  *Notice:* `base_stats` currently does NOT match `"maxhp"`. Line 4 defines `var base_maxhp = 80`. If `"maxhp": 100` is placed in `base_stats`, `player.gd` needs to support setting `base_maxhp = val` or adding a `"maxhp"` handler.

### 1.7 Long-Term Horizons in `todo.md`
- `todo.md` contains open explorations for maps/pathfinding, item variety (RoR journal style), and optimization.
- RoR2-style pre-run loadouts, 1 reroll per 3 levels draft economy, and environmental wall collisions are not yet formalized.

---

## 2. Logic Chain

1. **Cooldown Safety Floor ($t_{\text{wait}} \ge 0.05\text{s}$)**:
   - *Premise:* Frenzy Charm reduces wait time by up to 30%, while Mage has -15% CDR, and endless scrolls provide stacking CDR.
   - *Inference:* As $1.0 - \text{spell\_cooldown}$ approaches 0, $t_{\text{wait}}$ can drop below a single physics frame (0.016s) or reach $\le 0$. Godot timers fail or lock the frame loop when wait time $\le 0$.
   - *Requirement:* Codify $t_{\text{wait}} = \max(0.05, t_{\text{base}} \times (1.0 - \text{spell\_cooldown}) \times \text{cooldown\_mult})$ as a non-negotiable architectural rule.

2. **Universal Proc Coefficients**:
   - *Premise:* On-hit items (e.g. chance to zap, chance to bleed, lifesteal) trigger on hits.
   - *Inference:* Without proc coefficients, weapons with 10 hits/sec (Poison Gas, Tornado) proc items 10x more often than Ice Spear. Furthermore, if secondary procs (e.g. Relic Rocket) have proc coefficients $> 0$, they trigger recursive proc loops.
   - *Requirement:* Define the on-hit trigger formula $P_{\text{trigger}} = P_{\text{base}} \times \text{proc\_coefficient}$, the duration scaling formula, the standard archetype coefficient table, and the zero-proc rule for sub-munitions (`proc_coefficient = 0.0`).

3. **Decentralized Signal-Driven Conditional Buffs (`health_ratio_changed`)**:
   - *Premise:* Glass Talisman, Warding Brooch, Frenzy Charm, and Impact Buckler activate based on health thresholds ($\ge 95\%$, $\ge 90\%$, $< 30\%$, $< 20\%$).
   - *Inference:* Polling in `_process` wastes CPU and creates monolithic player spaghetti. Central state machines violate Rule 19 (YAGNI).
   - *Requirement:* The player emits `health_ratio_changed(current_ratio: float, old_ratio: float)` whenever HP or max HP changes. Items subscribe and manage their own local active state and hysteresis.

4. **Terraria-Inspired ICD Architecture**:
   - *Premise:* High-density horde combat creates situations where dozens of enemies touch the player simultaneously.
   - *Inference:* Without a Shared Defensive Buffer, players get instant-killed in 1 frame. Without Local Item ICDs, triggering one item locks out other items, or global enemy invulnerability causes piercing weapons to cancel other player weapons' damage.
   - *Requirement:* Document the two-layer ICD architecture: Local Item ICD (autonomous item timers) vs. Shared Defensive Buffer (player hurt i-frames) and enemy local hit registration (`hit_once_array`).

5. **Enemy Tenacity & Crowd Control Standards**:
   - *Premise:* Impact Buckler releases a radial shockwave pushing enemies away.
   - *Inference:* If this shockwave moves bosses, it breaks boss state machine animations, telegraph alignment, and arena pacing. If it doesn't move swarms, it fails its panic-button design intent.
   - *Requirement:* Establish a 3-tier tenacity hierarchy: Swarm (0% tenacity, full displacement), Elite (60-75% tenacity, stagger interrupt), Boss (100% tenacity, total displacement immunity).

6. **The Punished Resolution**:
   - *Premise:* The Punished was deferred because pure Thorns without sustain was suicidal and dual passives broke character parity.
   - *Inference:* The v2 item pool introduces Warding Brooch (high-HP barrier), Frenzy Charm (low-HP attack speed), Impact Buckler (panic knockback), and Thorn Ring. The Punished can now be given a tanky baseline (`armor: 3`, `maxhp: 100`) and a single scaling passive (`reflected_damage: 40`), achieving strict parity with other characters while letting the item pool supply the synergy.
   - *Requirement:* Update `design_guidelines.md` and `todo.md` marking The Punished as resolved and cataloging his exact stats.

7. **Long-Term Horizons**:
   - *Premise:* The project roadmap requires clear guidelines for upcoming systemic expansions.
   - *Requirement:* Formulate pre-run weapon loadouts (RoR2 style), draft economy (1 reroll per 3 levels), and environmental wall collision rules in `design_guidelines.md` and `todo.md`.

---

## 3. Caveats

1. **`player.gd` `base_stats` parsing for `"maxhp"`**:
   Currently, `player.gd:460-474` matches stats like `armor`, `movement_speed_percent`, etc., but does not match `"maxhp"`. When implementing The Punished in R2/engine tasks, the developer must ensure `base_maxhp` is updated when `"maxhp"` is present in `base_stats` (e.g. `base_maxhp = val` or adding `maxhp` to the match block).
2. **Headless Test Runner Command**:
   While `ORIGINAL_REQUEST.md:103` references `addons/gut/gut_cmdln.gd`, the repository adheres strictly to YAGNI with a custom headless SceneTree runner at `res://Tests/test_runner.gd`. All tests should be authored under `Tests/Unit/` extending `res://Tests/test_base.gd` and registered in `test_runner.gd`.
3. **Existing Spawner Cooldown Safety Floor**:
   Existing spawners (like `icespear_spawner.gd`, `tornado_spawner.gd`) do not currently have `max(0.05, ...)`. This is documented in the design guidelines as a mandatory standard and added to `todo.md` as an audit task.

---

## 4. Conclusion & Actionable Recommendations

Below are the exact additions, sections, and modifications to be applied to `design_guidelines.md` and `todo.md`.

### 4.1 Modifications for `design_guidelines.md`

#### A. Section 2: Update The Punished Case Study & Add Canonical Profiles
Replace lines 33-36 in `design_guidelines.md` with:

```markdown
### Canonical Character Profiles & The Punished Resolution
| Character | Starting Weapon | Base Stats (`base_stats`) | Scaling Passive (`scaling_stats` @ Lvl 20) | Archetype / Tactical Niche |
|---|---|---|---|---|
| **Mage** | `icespear1` | `{}` | `spell_cooldown: -0.15` (-15% CDR) | High-cadence spellcaster, rapid projectile barrage. |
| **Plague Doctor** | `poisonbottle1` | `{}` | `spell_size: +0.50` (+50% Size) | Massive zone denial, lingering area control. |
| **Occultist** | `ritualcircle1` | `{}` | `lifesteal: +0.02` (+2% Lifesteal) | Active offensive sustain, aggressive close-range presence. |
| **The Punished** | `whip1` | `{"armor": 3, "maxhp": 100}` | `reflected_damage: +40` (+40 Flat Retaliation) | Tanky counter-attacker; converts incoming aggression into lethal retaliatory strikes. |

> [!NOTE]
> **Resolution of The Punished Design:**  
> The previous dilemma—where The Punished risked having dual passives (Thorns + Regen) or suicidal gameplay without sustain—is resolved through the v2 item ecosystem:
> 1. **Baseline Durability:** High starting armor (`armor: 3`) and elevated health (`maxhp: 100`, $+25\%$ over standard 80 HP) provide the physical bulk to absorb hits safely.
> 2. **Single Clean Scaling Passive:** Exactly one scaling passive (`reflected_damage: 40` at Level 20) strictly honors the "One Core Scaling Passive" Law and Rule 19 (YAGNI).
> 3. **Item Pool Synergy:** Instead of baking complex sustain or AoE reflection into his character kit, The Punished naturally completes his build loop using the expanded item roster: Warding Brooch (protective barrier at high HP), Frenzy Charm (retaliatory attack speed surge at low HP), Impact Buckler (emergency shockwave), and Thorn Ring (+reflected damage).
```

#### B. Section 4.2: Update Attack Cooldown with Safety Floor
Replace Section 4.2 with:

```markdown
### 2. Attack Cooldown & Safety Floor
Weapons determine their firing interval as:
$$t_{\text{wait}} = \max\left(0.05, t_{\text{base}} \times (1.0 - \text{player.spell\_cooldown}) \times \text{cooldown\_multiplier}\right)$$

- **Cooldown Safety Floor ($t_{\text{wait}} \ge 0.05\text{s}$):**  
  Under no circumstances may a weapon's firing interval or timer wait time drop below $0.05\text{s}$ (equivalent to a hard ceiling of 20 activations per second).
- **Rationale & Engine Stability:**  
  Godot timers throw engine-level errors if `wait_time <= 0.0`. Even with micro-delays (< 0.016s / 1 frame at 60 FPS), weapon spawners flood the physics pipeline and node tree with unbounded projectile instances, causing catastrophic FPS collapses or audio channel starvation.
- **Combined Stacking Guardrail:**  
  When high CDR (e.g. Mage passive $-15\%$, Tome/Scroll passives, endless scroll stacks) stacks with low-health attack speed surges (e.g. Frenzy Charm $+30\%$ attack speed / $\times 0.7$ wait time), the $\max(0.05, \dots)$ safety floor guarantees engine responsiveness and deterministic physics.
- **Mandatory Spawner Contract:**  
  All `<weapon>_spawner.gd` and projectile timer scripts must wrap their wait time calculation in `max(0.05, ...)`.
```

#### C. Section 4.4: Expand Universal Proc Coefficients & On-Hit Mechanics
Replace Section 4.4 with:

```markdown
### 4. Universal Proc Coefficients & On-Hit Mechanics

Proc coefficients (inspired by *Risk of Rain 2*) govern how individual weapon hit events scale secondary item effects (lifesteal, on-hit procs, debuff application, chain reactions). Without proc coefficients, high-fire-rate and broad-AOE weapons disproportionately dominate on-hit accessories.

#### Mathematical Proc Contracts:
1. **On-Hit Trigger Probability:**  
   For any accessory with a base trigger percentage $P_{\text{base}}$:
   $$P_{\text{trigger}} = P_{\text{base}} \times \text{proc\_coefficient}$$
   Evaluated in GDScript as:
   ```gdscript
   if randf() < (base_chance * proc_coefficient):
       trigger_effect()
   ```

2. **Guaranteed Scaling (Lifesteal & Magnitude):**  
   For guaranteed on-hit triggers, the magnitude or healing is scaled linearly:
   $$\text{Heal} = \text{Damage} \times \text{Lifesteal} \times \text{proc\_coefficient}$$
   $$\text{Duration} = \text{Base Duration} \times \text{proc\_coefficient}$$

3. **Zero-Proc Feedback Loop Prevention Rule (Strict Contract):**  
   Any attack, projectile, explosion, or chain damage spawned as a secondary proc from an item (e.g. Relic Rocket, chain lightning accessory, retaliation shockwaves, Will-o'-Wisp explosions) **MUST explicitly set `proc_coefficient = 0.0`** (or $\le 0.1$ with strict chain dampening).  
   - *Rationale:* If Proc A can trigger Proc B, and Proc B has a proc coefficient $> 0$, enemies clustered in swarms trigger infinite recursive cascades ($A \to B \to A$), crashing the frame rate and trivializing combat.

#### Standard Proc Coefficient Baseline by Archetype:
| Archetype | Benchmark Weapons | Proc Coeff | Balance Rationale |
|---|---|---|---|
| **Heavy Single Target / Precision Projectile** | `icespear`, `javelin`, `lightningrod` | `1.0` | High commitment, low frequency; full value on every hit. |
| **Direct Melee / Frontal Slash** | `whip`, `glasslash` | `1.0` | Close-range danger; rewards positioning. |
| **Piercing / Fan Projectiles** | `tornado`, `vampireknives` | `0.5` | Multiple hits per cast; halved to prevent runaway proc volume. |
| **Persistent AOE Hazard / Gas / Aura** | `poison_gas`, `ritualcircle` | `0.1` – `0.2` | High tick frequency in dense swarms; prevents infinite sustain. |
| **On-Kill Secondary Explosion** | `willowisp` | `0.1` | Dampens chain reaction explosions from clearing the entire screen. |
| **Item-Spawned Munitions / Procs** | `RelicRocket`, procs | `0.0` | Strict loop prevention: procs never proc items. |
```

#### D. Section 4: Add New Subsections 6, 7, and 8

```markdown
### 6. Decentralized Signal-Driven Conditional Buffs (`health_ratio_changed`)

Conditional buffs and threshold-based accessories (e.g., Glass Talisman dealt damage bonus at $\ge 95\%$ HP, Frenzy Charm attack speed at $< 30\%$ HP, Impact Buckler kinetic blast at $< 20\%$ HP) must adhere strictly to Rule 19 (YAGNI) and decentralized signal architecture.

#### Architecture Rules:
1. **The Anti-Pattern (Centralized Polling):**  
   Never implement central state machines, polling loops in `_process` or `_physics_process`, or monolithic `if/elif` ladders in `player.gd` checking health thresholds every frame. Polling consumes unnecessary CPU cycles and tightly couples unrelated item mechanics to the player core script.
2. **The Decentralized Contract:**  
   `Player` exposes a dedicated signal:
   ```gdscript
   signal health_ratio_changed(current_ratio: float, old_ratio: float)
   ```
   - Emitted whenever `hp` or `maxhp` changes (clamped to $[0.0, 1.0]$).
   - Items or upgrade handlers listen to `player.health_ratio_changed`.
3. **Local State & Hysteresis Handling:**  
   Each conditional item maintains its own local state (`is_active: bool`, `cooldown_ready: bool`):
   - **Glass Talisman ($\ge 95\%$ HP):** Toggles active state when crossing 0.95.
   - **Frenzy Charm ($< 30\%$ HP):** Toggles active state when crossing 0.30.
   - **Impact Buckler ($< 20\%$ HP Emergency Trigger):** Fires when `current < 0.20 and old >= 0.20` and cooldown is ready.
   - *State Transition Integrity:* By checking boundary transitions (`current < threshold and old >= threshold`), audio cues, shockwaves, and particle triggers fire exactly once upon crossing the threshold rather than every damage tick.

---

### 7. Terraria-Inspired Internal Cooldown (ICD) Architecture

To reconcile rapid multi-hit combat with emergency defensives and on-hit accessories, *Inritus* implements a dual-layer internal cooldown model inspired by *Terraria*:

#### 1. Local Item ICD (Autonomous Cooldowns)
- Every accessory with a triggered effect (e.g., Impact Buckler shockwave: 60s / 40s / 20s, Warding Brooch recharge: 10s out of combat) tracks its own internal cooldown timer.
- **Strict Independence:** Triggering Item A never locks out, postpones, or resets Item B. Items operate as fully isolated state actors.
- Implementation: Managed via a child `Timer` node or cached millisecond timestamp (`Time.get_ticks_msec() >= next_available_msec`).

#### 2. Shared Defensive Buffer (Player Invulnerability Window)
- To eliminate horde "shotgunning" (where 50 swarm enemies overlapping the player deliver simultaneous lethal hits in a single 16ms physics tick), the player entity utilizes a brief Shared Defensive Buffer ($0.2\text{s} - 0.4\text{s}$ via `HurtBox` Cooldown mode).
- When an emergency defensive item triggers (e.g., Impact Buckler radial shockwave), the shockwave physically clears the immediate perimeter while the player is covered by the defensive buffer, preventing instant retaliation hits before enemies are displaced.
- The Shared Defensive Buffer manages damage intake gating only; it **never halts or freezes Local Item ICD countdowns**.

#### 3. Enemy-Side Local Immunity vs. Global Lockout
- In classic combat engines, hitting an enemy with a piercing weapon frequently granted the enemy global invincibility frames, causing rapid piercing attacks to "eat" other weapons' hits.
- In *Inritus*, weapons damaging enemies must either utilize instance-specific hit tracking (`hit_once_array` inside the projectile or `SwarmManager.spatial_grid`) or dedicated Local Weapon ICDs. One player weapon hitting an enemy must NEVER prevent other player weapons from hitting that same enemy on the same frame.

---

### 8. Enemy Tenacity & Crowd Control Hierarchy

Crowd control (knockback, stagger, freeze/slow, and displacement) must respect a strict 3-tier tenacity hierarchy across enemy categories to preserve encounter pacing and prevent boss exploits:

| Hierarchy Tier | Target Systems | Tenacity (Displacement Resistance) | Allowed CC Mechanics | Forbidden CC Mechanics |
|---|---|---|---|---|
| **Tier 1: Swarm** | `SwarmManager` (Easy & Normal pools) | **`0%` (Tenacity = 0.0)** | 100% displacement from knockback, mass radial shockwaves (Impact Buckler), gravity pulls, freezes, full slows. | None. |
| **Tier 2: Elite** | `EnemyBody` nodes (Hard pool: Cyclops, Juggernaut) | **`60%`–`75%`** | Short directional knockback, **Stagger** (brief 0.3s–0.5s movement/attack interruption), status slows up to 40%. | Long-distance flinging, perma-freeze, continuous vortex lock. |
| **Tier 3: Boss** | `boss.gd`, `dr_franklin.gd` (Super pool) | **`100%` (Immune)** | Soft utility debuffs (slow capped at max 20% movement speed reduction), visual markers, damage amplification curses. | **All knockback, displacement, pulls, teleports, and hard staggers are strictly prohibited.** |

#### Boss Displacement Immunity Contract:
- Bosses must never be displaced by player weapon knockbacks, explosions, or panic buttons (Impact Buckler shockwave).
- Mechanics that apply displacement must explicitly check:
  ```gdscript
  if enemy.is_in_group("boss") or (enemy.get("is_boss") == true) or (enemy is EnemyBody and "Boss" in enemy.name):
      return # Bypass displacement entirely
  ```
- *Rationale:* Displacing bosses breaks telegraph alignment (e.g. Dr. Franklin's directional beam), pushes bosses outside camera boundaries, and invalidates choreographed bullet-hell encounter phases.
```

#### E. Section 5: Add Conditional Buff Pattern to Architectural Patterns Table
Add row to table in Section 5:
`| **Conditional / Threshold Buff** | Signal Listener (`health_ratio_changed`) | Autonomous item component listens to health ratio transitions; toggles local modifiers without polling. |`

#### F. Add Section 8: Long-Term Architectural Horizons & Backlog Roadmap

```markdown
## 8. Long-Term Architectural Horizons & Backlog Roadmap

The following architectural initiatives represent planned long-term horizons to expand *Inritus* beyond early access while maintaining strict YAGNI adherence in current builds:

### 1. Pre-Run Weapon Loadouts (Risk of Rain 2 Style)
- **Concept:** Allow characters to unlock and select alternate starting primary weapons prior to starting a run (e.g. Mage selecting between Ice Spear or Lightning Rod; Plague Doctor selecting between Poison Bottle or Ritual Circle).
- **Architectural Guardrails:**
  - Loadouts alter ONLY the starting weapon (`starting_weapon`).
  - Base stats and the single scaling passive remain identical, preventing character balance fragmentation.
  - Selected loadout is saved in `SettingsManager` or a persistent profile.

### 2. Draft Economy (1 Reroll per 3 Levels)
- **Concept:** Introduce a structured level-up draft economy allowing players to reroll upgrade options.
- **Pacing Rules:**
  - Players start with 0 rerolls and earn 1 reroll charge for every 3 character levels achieved (e.g., at Levels 3, 6, 9, 12, ...).
  - Prevents early-game build bricking while preventing high-level runs from rolling infinite rerolls to fish for endless stacks.
  - Reroll charges are displayed on the level-up GUI card header.

### 3. Environmental Wall Collision Rules & Closed Maps
- **Concept:** Transition from infinite plane arenas to structured dungeon/map layouts (Enter the Gungeon / Soul Knight style) with solid boundary walls and obstacles.
- **Collision & Routing Contracts:**
  - **Layer 1 (World / Solid Obstacles):** Tilemap walls on Layer 1.
  - **Projectile Navigation:**
    - Standard projectiles (`icespear`, `relicrocket`) terminate upon impacting Layer 1 wall geometry.
    - Melee sweeps (`whip`) and ethereal auras (`ritualcircle`) pierce walls.
    - Bouncing projectiles (`javelin`) reflect across surface normals.
  - **Swarm Pathfinding:**
    - `SwarmManager` MultiMesh instances cannot use individual Godot NavigationAgents (CPU prohibitive for 1,000+ units).
    - Swarms must navigate using coarse flow-field / vector fields or cell-based potential fields generated per map chunk.
```

---

### 4.2 Modifications for `todo.md`

Update `todo.md` with:
1. **Health-Based Items**: Update status to active implementation (R2 in progress), listing the 4 items: Glass Talisman, Warding Brooch, Frenzy Charm, Impact Buckler.
2. **The Punished / Retaliation Archetype**: Update status from "Deferred" to "Resolved & Specified":
   - Starting Weapon: `whip1`
   - Base Stats: `armor: 3`, `maxhp: 100`
   - Single Scaling Passive: `reflected_damage: 40` (at level 20)
   - Synergies: Naturally completed through the v2 item pool (Warding Brooch, Frenzy Charm, Impact Buckler, Thorn Ring).
3. **Long-Term Horizons**:
   - Pre-run Weapon Loadouts (RoR2 style loadout selector in character select)
   - Draft Economy (1 reroll per 3 levels)
   - Environmental Wall Collision & Map Obstacle Navigation (flow-field for SwarmManager)
   - Weapon Spawner Audit for Cooldown Safety Floor ($t_{\text{wait}} \ge 0.05\text{s}$)
   - Universal Proc Coefficient Expansion for future on-hit accessories

---

## 5. Verification Method

To verify these changes after application:
1. **File Inspection**:
   - Confirm all 8 R1 items are present and accurately structured in `design_guidelines.md` and `todo.md`.
2. **Automated Balance Modeling**:
   - `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal`
   - Verify script exits with status code 0 and evaluates DPS curves cleanly.
3. **Localization Integrity**:
   - `python .agents/skills/localization-validator/validate_translations.py`
   - Verify translations CSV remains 100% compliant with 0 errors.
4. **Headless Unit Test Suite**:
   - `godot --headless -s res://Tests/test_runner.gd`
   - Verify all existing unit tests pass with exit code 0.
