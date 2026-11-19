# Inritus — Movement-Coupled Combat & Item Group Ponderings

> **Status:** Design Exploration & Architecture Ponderings (Pre-Implementation)  
> **Context:** Expands on [`docs/todo.md`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/docs/todo.md) (*Future Variance & Core Gameplay Pillars -> C. Velocity / Stance-Coupled Combat*) and aligns with [`docs/design_guidelines.md`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/docs/design_guidelines.md).  
> **Core Constraint:** *Inritus* uses **crisp, zero-inertia top-down movement** (`velocity = mov.normalized() * movement_speed`). Movement-coupled combat must feel snappy and deliberate—**not** like a momentum/inertia "roller-skates" physics game.

---

## 1. Current State Diagnosis: Why Combat & Movement Feel Decoupled

An audit of [`Player/player.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Player/player.gd), [`Utility/upgrade_db.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Utility/upgrade_db.gd), weapon spawners, and [`.agents/skills/game-balance-eval/balance_eval.py`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/.agents/skills/game-balance-eval/balance_eval.py) explains why the game currently *"feels too slow"* and why movement rarely shapes how builds fight:

### 1.1 Player vs. Enemy Speed Compression
In [`Player/player.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Player/player.gd#L39-L40), `base_movement_speed` is **`75.0 px/s`**. Compare that against enemy speeds defined in `ENEMY_SPECS` ([`balance_eval.py`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/.agents/skills/game-balance-eval/balance_eval.py#L64-L70)):

| Entity | Speed (`px/s`) | % of Base Player Speed (`75.0`) | Practical Kiting Feel |
|---|---:|---:|---|
| `kobold_weak` | `45.0` | `60.0%` | Easy to outrun, but crowds compress space quickly. |
| `kobold_strong` | `57.0` | `76.0%` | Only `18 px/s` slower; diagonal weaving barely gains separation. |
| `cyclops` | `39.0` | `52.0%` | Slow tank, acts as a moving wall. |
| `juggernaut` | `68.0` | **`90.7%`** | Practically matches player pace (`7 px/s` margin); hard to shake without `speed` upgrades. |
| `boss_base` | `68.0` | **`90.7%`** | Forces near-continuous kiting if player has 0 speed passives. |

Because the speed margin over `kobold_strong`, `juggernaut`, and bosses is razor-thin, moving feels heavy and defensive, and `speed` (`boots_4_green.png`) feels like a mandatory tax rather than an offensive stat.

### 1.2 Wall-Clock Timer Autonomy
Every weapon spawner in `Player/Attack/` runs on an autonomous wall-clock `Timer` (`attackspeed * (1.0 - player.spell_cooldown)`). Only three weapons read `player.last_movement` (`icespear` and `vampireknives` via `get_frontal_target()`, and `tornado` for initial travel direction). Zero weapons change their cadence, behavior, or output based on **whether you are moving, standing your ground, or pushing into vs. kiting away from threats**.

### 1.3 Why Inertia / Momentum Ramps Don't Fit *Inritus*
Continuous `momentum_ratio` ramps and angular drift/turn-rate meters belong to a **momentum-physics / "roller-skates" game** where carrying speed and carving arcs is the core physics loop. *Inritus* has instant, pixel-crisp 8-way/analog movement—and Mouse Control ([`player.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Player/player.gd#L334)) even has an instant LMB-hold brake (`not Input.is_action_pressed("click")`).
Instead of forcing slippery ramp-up timers onto crisp controls, movement mechanics in *Inritus* should be **immediate, spatial, and character-expressive**:
- **Distance as fuel** (actual pixels walked, zero acceleration lag).
- **Deliberate stance & asymmetric transitions** (anchoring takes slightly longer to build up than to drop out, rewarding commitment without punishing relocation).
- **Heading & spacing** (walking *toward* vs. *away from* threats).
- **One character-specific mobility move** on `Spacebar`.

---

## 2. Core Architecture: Kinematic Substrate + Character Mobility (`mobility_type`)

Both layers below preserve **100% crisp, zero-inertia normal walking** (`velocity = mov.normalized() * movement_speed`):

### Layer 1 (Substrate): Instant Stance, Distance-Fuel & Heading
Tracks three simple signals in `Player.movement(delta)` with **no roller-skate inertia**:
1. **Distance Traveled ($\Delta d = \|\text{get\_real\_velocity}()\| \cdot \Delta t$):**
   - Every pixel actually displaced feeds `stride_distance` (used to shave cooldowns or charge stacks).
   - No warm-up ramp: the moment you walk, you generate Stride; the moment you stop (or hit a wall), Stride pauses.
2. **Anchored State (`is_anchored: bool` + `bastion_charge: float`):**
   - Triggered when standing still (or holding `Spacebar` with `rock_stance`, or holding LMB in Mouse mode).
   - **Asymmetric Transition:** Rather than snapping instantaneously or needing a sluggish physics ramp, `bastion_charge` ($\in [0.0, 1.0]$) uses **slower build-up (`~0.45s` transition in)** and **snappier drop-off (`~0.20s` transition out)** for gradual Bastion effects like Ritual Circle, preventing micro-stutter cheese while feeling responsive when repositioning.
3. **Relative Heading (`mov.dot(dir_to_target)`):**
   - Evaluated **only when a weapon fires** (zero per-frame polling): distinguishes **Advancing** (pushing into a target), **Retreating** (kiting away), and **Strafing** (moving perpendicular).

### Layer 2 (Selected Active Architecture): Character-Specific Mobility Ability on `Spacebar` (`mobility_type`)
Layered on top of the Layer 1 substrate, each character in [`GlobalEvents.CHARACTERS`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Utility/global_events.gd#L35-L77) is assigned a **`mobility_type`** triggered by `Spacebar` (or a matching gamepad/mouse binding). This keeps the controls to **one single mobility button** while giving character groups distinct physical feel:

1. **`sidestep` (Evade Step — With I-Frames):**
   - **Behavior:** A short, snappy directional hop (`~75–90 px` over `0.12s`, cooldown `~2.5s`) that **grants i-frames** during the step.
   - **Direction:** **Not fixed**—steps in the player's current movement input direction (or toward/away from aim/last movement if neutral), making it both a precision **dodge** (through projectiles, beams, or tight pack gaps) and a tool for **making distance**.
2. **`forward_dash` (Forward Burst — Speed Lines, No I-Frames):**
   - **Behavior:** A fast **forward dash** (`~130–150 px`, cooldown `~3.5–4.0s`) rendered with **speed lines** as its visual effect.
   - **Trade-Off:** **No i-frames**—balanced because it grants **two offensive bonuses** at once: instant `stride` distance credit across the dash path **plus** triggering `impulse` stance-transition bonuses upon landing. High risk, high reward positioning tool.
3. **`rock_stance` (Sudden Rock-Solid Stance — Fixate, Turn & Fire-Rate Burst):**
   - **Behavior:** Holding `Spacebar` immediately locks the character's position (`velocity = Vector2.ZERO`, `is_anchored = true` with `0.0s` initial anchor lock), granting immediate Bastion poise/bonus Armor.
   - **Turning While Fixated:** Unlike a rigid freeze, **directional inputs still rotate facing (`last_movement` and `sprite.flip_h`)** while rooted, so frontal weapons (`icespear`, `vampireknives`, `whip`) stay aimed where the player wants.
   - **Fire-Rate Burst:** Entering `rock_stance` triggers a **temporary fire-rate burst** (e.g. `1.25s–1.5s` of boosted attack speed, gated by a `~4.0s` local ICD so rapid `Spacebar` tapping cannot maintain permanent uptime).

---

## 3. Item Group Taxonomy (`movement_group`)

Assigning every weapon and passive upgrade a `movement_group` tag in [`UpgradeDb.UPGRADES`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Utility/upgrade_db.gd#L6) keeps the system readable. Players learn **4 crisp movement archetypes** (plus `neutral` for consumables):

| `movement_group` | Archetype Identity | Crisp Trigger | Core Player Fantasy |
|---|---|---|---|
| **`stride`** | *The Sprinter's Arsenal* | **Distance traveled ($\Delta d$)** | *"Keep moving to fuel your barrage; speed is fire rate."* |
| **`bastion`** | *The Anchor's Arsenal* | **Standing still / `rock_stance` (`bastion_charge`)** | *"Plant your feet to fortify defenses and supercharge zones."* |
| **`vector`** | *The Skirmisher's Arsenal* | **Heading vs. Target** (Advancing vs. Retreating vs. Strafing) | *"Your footwork shapes your attack: dive in to focus, kite back to zone."* |
| **`impulse`** | *The Rhythm Arsenal* | **Stance & Mobility Transitions** (Landing a `forward_dash`, dodging with `sidestep`, or snapping into/out of anchor) | *"Turn every burst, step, or sudden stop into an offensive spike."* |
| **`neutral`** | *Utility / Consumable* | None | Instant recovery (`food`) or pure stat identity. |

### Anti-Lock-In Design Rules
1. **80–85% Floor, 125–140% Ceiling:** Every weapon still functions at ~80–85% of current vanilla strength regardless of how you move. Matching its `movement_group` unlocks overdrive (~125–140%), never a binary 0%-to-100% gate.
2. **Natural Hybrid Loops:** A player carrying both `stride` and `bastion` (or `impulse`) items alternates naturally between **kiting across the arena** (charging `stride` and priming `impulse`) and **triggering their `Spacebar` mobility move** (`sidestep` dodge, `forward_dash` surge, or `rock_stance` burst).

---

## 4. Holistic Stat Rebalance & Item-by-Item Adjustments

### 4.1 Global Player Movement Baseline ([`Player/player.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Player/player.gd))
1. **Base Movement Speed:** Raise `base_movement_speed` from **`75.0 px/s` $\to$ `85.0 px/s`** (`+13.3%`).
   - *Why:* Creates a clean `17 px/s` (`25%`) margin over `juggernaut` / `boss_base` (`68.0 px/s`), immediately fixing the sluggish early-game feel without needing `speed` passives just to survive.
2. **`Spacebar` Mobility Binding (`mobility` / `brake` Input Action):**
   - Triggers the active character's `mobility_type` (`sidestep`, `forward_dash`, or `rock_stance`). All characters can still enter `bastion` naturally by stopping movement (or holding LMB in Mouse mode), while `rock_stance` additionally enables turning-in-place and the temporary fire-rate burst.
3. **Asymmetric Bastion Transition Timing:**
   - Expose configurable `bastion_ramp_in = 0.45` (`s`) and `bastion_ramp_out = 0.20` (`s`) so gaining stationary channeling effects takes slight commitment while losing them feels clean and fair.
4. **Cooldown Floor Contract:** All distance-accelerated, stance-accelerated, or fire-rate-burst timers MUST still enforce the [`design_guidelines.md`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/docs/design_guidelines.md#L183) safety floor:
   $$t_{\text{effective}} = \max\left(0.05, \, t_{\text{base}} \times (1.0 - \text{spell\_cooldown}) \times \text{movement\_cd\_mult}\right)$$

### 4.2 The "Baseline Pivot" Balance Principle
Per [`.agents/skills/game-balance-eval/balance_eval.py`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/.agents/skills/game-balance-eval/balance_eval.py), target **Boss TTK** is `10s–30s`. Rather than piling buffs on top of current numbers, un-synergized baseline weapon stats step down ~10–15%, while active group execution pushes output ~25–40% above baseline.

---

### 4.3 Weapon Adjustments Matrix (All 9 Weapons)

> [!TIP]
> **Modularity & Live A/B Testing Architecture:**  
> To support easy iteration and A/B testing of these numbers, keep all movement-coupled rules **data-driven and toggleable** without creating speculative manager hierarchies (Rule 19):
> - Centralize numerical coefficients (e.g., `bastion_in_time = 0.45`, `bastion_out_time = 0.20`, per-weapon `stride_px_per_sec`, `vector_dot_thresholds`, `mobility_cooldowns`) in a single plain `MOVEMENT_CONFIG: Dictionary` (or `@export` tuning resource/struct on `Player` / `GlobalEvents`).
> - Add a simple **Profile / Toggle** in the Debug Build Workbench (e.g., `Vanilla Timers` vs. `Movement-Coupled` + live sliders/overrides for the active coefficients) so changes can be A/B tested mid-run in the Proving Grounds or Boss & Stress Lab.
> - Keep each weapon's movement hook isolated to its own `<weapon>_spawner.gd` / `<weapon>.gd` reading `player.get_movement_bonus(group)` or `player.bastion_charge`, so individual weapons can be toggled or reverted independently.

All "Current" values below are verified from the weapon scripts in `Player/Attack/`.

| Weapon (`ID`) | `movement_group` | Current Baseline Stats (L1 $\to$ L4) | Proposed Baseline Stat Adjustments | Proposed Crisp Movement Mechanic |
|---|---|---|---|---|
| **Ice Spear** (`icespear`) | **`stride`** | CD `1.5s`, Ammo `1,2,2,4`, Pierce `1,2,2,4`, Dmg `8,8,12,15`, Speed `150` | CD `1.8s`, Speed `175`, Dmg `7,8,11,14` | **Distance-Fed Cooldown:** While moving, each `100 px` traveled shaves `0.45s` off the active cooldown timer (faster `movement_speed` = faster fire rate, clamped to `0.05s` floor). Works from step one. |
| **Javelin** (`javelin`) | **`stride`** | Orbiting entity; CD `5.0s`, Paths `1,2,3,3`, Dmg `10,10,10,15`, Speed `300`, KB `100..120` | Base CD `5.5s`, Dmg `9,10,11,14` | **Marching Charge:** Every `80 px` walked reduces `AttackTimer` by `0.3s` and empowers the next strike with **`+25%` damage** and **`+25%` dash speed** (`375 px/s`). |
| **Lightning Rod** (`lightningrod`) | **`bastion`** | CD `3.0,2.5,2.0,2.0s`, Chains `1,1,3,4`, Dmg `10,15,15,20`, Range `300px` | Base CD `3.2,2.7,2.3,2.3s`, Dmg `9,13,14,18` | **Grounded Conduit:** Scales with `bastion_charge` (`0.45s` in / `0.20s` out): at full Bastion, cooldown ticks **`1.5x` faster** (`~1.5s` at L4), strikes gain **`+1` chain jump**, and deal **`+25%` damage** (`+35%` to Elites/Bosses). |
| **Ritual Circle** (`ritualcircle`) | **`bastion`** | CD `10s`, Ammo `1,1,1,2`, Draw `1.0s`, Burst `1.5..2.5s`, Dmg `15,15,20,20`, Slow steer | Base CD `10.0s`, Dmg `13,14,18,18`, Draw `1.1s` | **Anchored Channeling (Asymmetric `0.45s` In / `0.20s` Out):** `bastion_charge` ramps in over **`0.45s`** while anchored and decays over **`0.20s`** when moving. At peak charge: draw time completes **`2x` faster** (`0.55s`), active circles pulse every **`0.35s`** instead of `0.5s`, and radius scales **`+25%`**. |
| **Tornado** (`tornado`) | **`bastion`** *(or `impulse`)* | CD `3.0,3.0,2.5,2.5s`, Ammo `1,2,2,3`, Dmg `5`, Pulse `0.2s`, KB `100..125`, Swerve path | Base Ammo `1,2,2,3`, Dmg `4.5`, Speed `145` | **Eye of the Storm:** Casting while anchored (`bastion_charge >= 0.6`) launches tornadoes in a protective **outward spiral** around your position (`+25%` `attack_size`, `+20%` pulse damage). Moving fires the standard directional swerve. |
| **Poison Bottle** (`poisonbottle`) | **`vector`** | CD `3.0s`, Gas Dmg `2.5..7.5`, Slow `0%/0%/20%/45%`, Dur `2.0..3.0s`, `target_crowd` | Base CD `3.2s`, Gas Dmg `2.5..6.5` | **Advancing Throw vs. Retreat Wake:** Checks `mov.dot(dir_to_target)` at cast time. **Retreating** ($\text{dot} < -0.3$) drops an extra quick-shatter **Alchemical Wake** puddle behind you (`60%` radius, heavy slow). **Advancing / Neutral** throws into crowds with `+20%` gas damage. |
| **Vampire Knives** (`vampireknives`) | **`vector`** *(Boss)* | CD `2.0,1.8,1.5,1.2s`, Count `5,7,9,12`, Dmg `10,12,14,15`, Heal `1..2`, Spread `60°` | Base Dmg `9,11,13,14`, Base Spread `60°` | **Dive Focus vs. Kite Fan:** **Advancing** toward the frontal target ($\text{dot} > 0.4$) narrows the fan to **`25°`** with **`+1` pierce** and `+20%` knife speed (single-target burst + lifesteal). **Retreating** ($\text{dot} < -0.3$) widens the fan to **`100°`** with `+30%` knockback. |
| **Leather Whip** (`whip`) | **`impulse`** | CD `1.3,1.1,1.0,0.8s`, Dmg `8,12,16,20`, Sweep `PI` (`180°`), KB `50` | Base CD `1.4,1.2,1.1,0.9s`, Dmg `7,11,14,18`, Sweep `180°` | **Snap-Stop Lash:** Walking `120 px` (or landing a `forward_dash` / `sidestep`) primes a **Snap Charge**. Triggering a mobility move or anchoring unleashes the charged lash with **`240°` arc**, **`+35%` damage**, and **`1.5x` knockback**. |
| **Glass Lash** (`glasslash`) | **`impulse`** *(Boss)* | CD `3.0,2.0,1.2,1.0s`, Dmg `30,45,65,90`, 6 shards on kill (`20%` enemy max HP) | Base CD `3.1,2.1,1.35,1.15s`, Dmg `26,40,58,80` | **Shatter Break:** Triggering `Spacebar` mobility or anchoring after walking `150 px` immediately triggers a ready Glass Lash strike (gated by `0.4s` internal floor) and boosts shard burst count on kill from `6` $\to$ `9`. |

> [!NOTE]
> **Ritual Circle Visual Rework (Geometric Drawing Replacing Explosion):**  
> Currently [`Player/Attack/ritualcircle/ritualcircle.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Player/Attack/ritualcircle/ritualcircle.gd#L70-L79) switches from `_draw()` arc progress during `State.DRAWING` to an explosion-like `PhasedAnimator` spritesheet during `State.BURSTING`. Replace that explosion animation with an **inscribed geometric ritual drawing inside the circle** (e.g., rotating star/polygon sigils, concentric chalk glyphs, or a dedicated geometric shader/spritesheet) whose line intensity and rotation speed visually reflect `bastion_charge` (`0.45s` fade-in / `0.20s` fade-out) while staying cleanly dark-fantasy themed.

---

### 4.4 Passive Upgrades, Relics & Companion Adjustments (All 15 Non-Consumables + `food`)

| Item (`ID`) | `movement_group` | Current Stats / Behavior | Proposed Stat Adjustment | Proposed Crisp Movement Behavior |
|---|---|---|---|---|
| **Speed** (`speed`) | **`stride`** | `+20% / +10% / +10% / +10%` move speed (`+50%` total; `+2%` endless) | Adjust to `+15% / +10% / +10% / +10%` (`+45%` total on `85.0` base = `123.25 px/s`; `+2%` endless) | **Distance Engine:** Higher speed directly generates more `px/s` for all `stride` and `impulse` distance counters. Also boosts `stride` cooldown-per-pixel efficiency by **`+5%` per tier** (`+20%` at L4). |
| **Glass Talisman** (`glasstalisman`) | **`vector`** | HP $\ge 95\%$ $\to$ `+5%/10%/15%/25%` dmg (`+2%` endless) | Base `+4%/8%/12%/20%` at HP $\ge 95\%$ (`+2%` endless) | **Glass-Cannon Dive (Primary Pick):** While HP $\ge 95\%$ **and** advancing toward the nearest target (`mov.dot(dir_to_target) > 0.3`), gain an extra **`+5%/8%/12%/15%` damage**. Rewards reckless forward pressure while fragile instead of passive safe kiting (and can still be A/B tested against pure HP `neutral`). |
| **Relic Drone** (`relicdrone`) | **`stride`** *(Boss)* | L1–L2: `10%/15%` on-hit proc $\to$ `2.0x/3.0x` rocket | Base proc `10%/15%`, mult `1.8x / 2.6x` | **Patrol Overcharge:** Every `250 px` walked primes the drone's next rocket for **`1.35x` overloaded damage** (`proc_coefficient = 0.0` preserved) and scales `follow_speed` cleanly with player speed. |
| **Scroll** (`scroll`) | **`stride`** | `+5%` `spell_cooldown` per tier (`+20%` at L4; `+2%` endless) | `+4%` flat `spell_cooldown` per tier (`+16%` at L4; `+2%` endless) | **Swift Cadence:** Reduces distance thresholds required by `stride` weapons and `impulse` primes by **`5%` per tier** (`-20%` distance needed at L4). |
| **Armor** (`armor`) | **`bastion`** | `+1` Armor per tier (`+4` total; `+1` endless) | Keep `+1` Armor per tier (`+1` endless) | **Fortified Stance:** While `bastion_charge >= 0.6`, gain **`+2 / +4 / +6 / +8` bonus Armor** (instant incentive to hold ground or engage `rock_stance` when bracing for impact). |
| **Thorn Ring** (`thornring`) | **`bastion`** | T1: `+20%` armor mult, `+10` reflect; T2–4: `+10/+10/+15` reflect (`+5` endless) | Keep base stats (`+45` reflect at T4, `+20%` armor mult) | **Iron Anchor:** While anchored (`bastion_charge >= 0.6`), `reflected_damage` is multiplied by **`1.5x` (`2.0x` at T4)** and reduces contact knockback disruption. |
| **Ring of Rejuvenation** (`ringofrejuvenation`) | **`bastion`** | T1: `+30%` max HP; T2: `+0.001` regen; Endless: `+5%` max HP in `player.gd` | T1: `+25%` max HP; T2: `+0.0015` base regen | **Rooted Recovery:** While anchored (`bastion_charge >= 0.8`), passive HP regeneration runs at **`2.5x` speed** (`3.0x` at T2), letting stationary builds recover inside safe pockets. |
| **Occult Medallion** (`occult_medallion`) | **`bastion`** | Applies `curse` (`+5%..15%` dmg taken) to `1–2` highest-HP enemies every `2.0..0.5s` | Keep base curse values (`5%..15%`) | **Anchored Hex:** While anchored (`bastion_charge >= 0.6`), curse pulses trigger **`2x` faster** and hit **`+1` extra target**. |
| **Ring of Affinity** (`ringofaffinity`) | **`vector`** | `+20% / +40%` XP grab radius (`+60%` total; `+5%` endless) | `+20% / +35%` (`+55%` total; `+5%` endless) | **Forward Sweep:** While moving, projects an extra **`+35%` grab radius** in front of your heading (`last_movement`), letting aggressive movers scoop gems ahead of them. |
| **Tome** (`tome`) | **`vector`** | `+10%` `spell_size` per tier (`+40%` total; `+2%` endless) | `+8%` flat `spell_size` per tier (`+32%` total; `+2%` endless) | **Stance Reach:** Grants an extra **`+15%` bonus `spell_size`** while anchored (`bastion_charge >= 0.8`) **or** while advancing toward the nearest target. |
| **Frenzy Charm** (`frenzycharm`) | **`vector`** | HP $< 30\%$ $\to$ `+10%/20%/30%` `spell_cooldown` | Keep `+10%/20%/30%` `spell_cooldown` below `30%` HP | **Cornered Surge:** While active (HP $< 30\%$), also grants **`+10%/15%/20%` movement speed** when moving *away* from the nearest threat. |
| **Will o' Wisp** (`willowisp`) | **`impulse`** | On kill: `15%/20%` chance for `5/5/8/(10 + 5% maxHP)` blast | Base chance `12%/16%/16%/16%`, base damage unchanged | **Spark Step:** For `1.5s` after using `Spacebar` mobility or transitioning stance, `willowisp` proc chance gains **`+10%` flat bonus** and `+25%` blast radius. |
| **Ring** (`ring`) | **`impulse`** *(Boss)* | `+1` `additional_attacks` per tier (`+0.05` endless) | Keep `+1` per tier | **Echo Step:** Upon using `Spacebar` mobility or switching stance, the next weapon volley within `1.0s` gains **`+1` bonus projectile** (`3s` local ICD). |
| **Warding Brooch** (`wardingbrooch`) | **`impulse`** | HP $\ge 90\%$ + `10s` no dmg $\to$ block `5%` maxHP; T2: `+15%` speed for `3s` on break | Reduce recharge to **`8s`**, bump T2 speed boost to **`+25%` for `3.5s`** | **Breakaway:** At Tier 2, shield break immediately grants `+25%` movement speed, **`+100 px` instant `stride` credit**, and resets `Spacebar` mobility cooldown by `50%`. |
| **Impact Buckler** (`impactbuckler`) | **`impulse`** | HP drops $< 20\%$ $\to$ radial knockback blast (`60s/40s/20s` CD) | Keep `60s/40s/20s` CD and boss displacement immunity | **Brake Slam:** Triggering `rock_stance` or planting feet after walking `150+ px` while an enemy is within `45 px` triggers a `50%`-radius knockback pulse on a separate `10s` local ICD. |
| **Food** (`food`) | **`neutral`** | Instant `+20` HP | Keep `+20` HP (`neutral`) | Unchanged instant heal consumable. |

> [!NOTE]
> **`ringofrejuvenation_endless` Multiplier Confirmed:** Yes—it is intended to be a **`+5%` (`0.05`) Max HP multiplier**. [`Player/player.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Player/player.gd#L773) already applies `max_hp_percent_total += 0.05 * count` and [`translations/translations.csv`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/translations/translations.csv#L279) already defines `stat_max_hp`. Only [`UpgradeDb.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Utility/upgrade_db.gd#L866) still holds stale display metadata (`"stat_modifiers": {"hp": 5}` instead of `{"max_hp_percent": 0.05}`), which causes [`item_option.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Utility/item_option.gd#L72-L88) to print `"+5 Health"` instead of `"+5% Max HP"`. Fixing that one line aligns the UI card with the actual runtime multiplier.

---

## 5. Character Archetype Synergies (Preserving "One Core Scaling Passive")

Per [`docs/design_guidelines.md`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/docs/design_guidelines.md#L27-L39), each character in [`GlobalEvents.CHARACTERS`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Utility/global_events.gd#L35-L77) keeps **exactly one clean scaling passive** (Rule 19 / YAGNI), paired with a single `"mobility_type"` key defining their `Spacebar` action:

| Character | Starting Weapon | Scaling Passive | `mobility_type` (`Spacebar`) | Gameplay Feel |
|---|---|---|---|---|
| **Mage** | `icespear1` | `spell_cooldown` *(note: currently `-0.15` in `global_events.gd:43`, which increases wait time in `1.0 - spell_cooldown`; flip to `+0.15`)* | **`sidestep`** *(i-frames, free direction)* | Crisp evade-skirmisher: steps along any movement direction with i-frames to dodge beams or make space while walking fuels `icespear`. |
| **Plague Doctor** | `poisonbottle1` | `spell_size: +0.50` | **`forward_dash`** *(speed lines, no i-frames, double bonus)* | High-tempo zone dasher: dashes forward with speed lines to leap ahead of packs, generating `stride` credit + triggering `impulse` procs while dropping `Alchemical Wake` behind. |
| **Occultist** | `ritualcircle1` | `lifesteal: +0.02` | **`rock_stance`** *(fixate, turn-in-place, fire-rate burst)* | Channeling anchor: slams into `rock_stance` to ramp `ritualcircle` over `0.45s`, rotate frontal aim while rooted, and burst attack speed while `lifesteal` covers chip damage. |
| **The Punished** | `whip1` | `reflected_damage: +40` *(with `armor: 3, maxhp: 100`)* | **`rock_stance`** *(fixate, turn-in-place, fire-rate burst)* | Immovable counter-brawler: marches to prime `whip`, then locks into `rock_stance` to spin and lash `240°` while Armor + Thorn Ring punish contact. |

---

## 6. Engine Guardrails, UI Readability & Vertical Item Cards

### 6.1 Engine & Performance Constraints
- **Zero Per-Swarm-Unit Loops:** For `vector` weapons (`poisonbottle`, `vampireknives`), compute `var target := player.get_frontal_target()` (or `get_crowd_target()`) **once per fire event** in `<weapon>_spawner.gd` and evaluate `mov.dot(dir_to_target)`. Never iterate over `SwarmManager.swarm_data` for relative vectors in `_physics_process`.
- **Wall-Collision Anti-Cheese:** Use `get_real_velocity().length() * delta` (not raw input `mov`) for `stride` distance so walking nose-first into walls (once closed maps arrive) grants zero distance fuel.
- **Single-Pass Player State:** Keep `is_anchored`, `bastion_charge`, `stride_distance_delta`, and `mobility_cooldown` directly on `Player`. No new autoload singletons or bloated state-machine frameworks (Rule 19).
- **Unit Test Compatibility:** Adding `"movement_group"` (`"stride"`, `"bastion"`, `"vector"`, `"impulse"`, `"neutral"`) to `UpgradeDb.UPGRADES` passes existing [`test_upgrade_db.gd`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Tests/Unit/test_upgrade_db.gd#L17-L36) checks cleanly.

### 6.2 Visual Readability & Graphic Badges (`Textures/GUI/Badges/`)
- **In-World Cues:**
  - **`sidestep`:** Subtle ghost afterimage during the `0.12s` i-frame window.
  - **`forward_dash`:** Crisp directional **speed lines** behind the player along the dash trajectory.
  - **`rock_stance` / `bastion_charge`:** Faint geometric anchor ring under the player's feet that scales/brightens over the `0.45s` transition-in (and fades over `0.20s` out), plus brief fire-rate burst aura.
  - **`impulse` / `stride` primed:** Brief subtle glint on the character/weapon when a distance threshold is met.
- **Graphic Badges on Upgrade Cards (`item_option.tscn`):**
  Instead of text brackets like `[Frontal]` in `lbl_targeting`, both **Targeting Mode** and **Movement Group** should render as crisp `16x16` pixel-art **graphic badges** with hover tooltips explaining their localized name and effect. Ten `16x16` RGBA placeholder badges (zero outer transparent padding, ready for custom pixel art) have been created under `res://Textures/GUI/Badges/`:

| Category | Key | Placeholder Asset (`res://Textures/GUI/Badges/...`) | Visual Cue (Placeholder) |
|---|---|---|---|
| **Movement Group** | `stride` | [`badge_movement_stride.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_movement_stride.png) | Cyan badge with `>>` double chevron |
| **Movement Group** | `bastion` | [`badge_movement_bastion.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_movement_bastion.png) | Amber badge with shield silhouette |
| **Movement Group** | `vector` | [`badge_movement_vector.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_movement_vector.png) | Emerald badge with `<->` opposing arrows |
| **Movement Group** | `impulse` | [`badge_movement_impulse.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_movement_impulse.png) | Crimson badge with 4-point spark burst |
| **Targeting Mode** | `target_closest` | [`badge_target_closest.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_target_closest.png) | Gold/bronze crosshair with center dot |
| **Targeting Mode** | `target_frontal` | [`badge_target_frontal.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_target_frontal.png) | Ice-blue forward cone wedge |
| **Targeting Mode** | `target_crowd` | [`badge_target_crowd.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_target_crowd.png) | Orange badge with 3 clustered dots |
| **Targeting Mode** | `target_strongest` | [`badge_target_strongest.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_target_strongest.png) | Purple badge with gold crown |
| **Targeting Mode** | `target_direction` | [`badge_target_direction.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_target_direction.png) | Teal badge with single directional arrow |
| **Targeting Mode** | `target_random` | [`badge_target_random.png`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/Textures/GUI/Badges/badge_target_random.png) | Lavender die face (5 pips) |

### 6.3 Vertical Item Card Readability & "Simplified Descriptions" Toggle
With expanded movement mechanics, keeping level-up cards readable without overwhelming casual players pairs directly with the planned vertical card migration in [`docs/todo.md`](file:///d:/Школа/Сезон%206/Group%20project/Vampire%20survivors%20clone%20100%/docs/todo.md#L31-L32) (`UpgradeOptions` / `BossUpgradeOptions` switching to `HBoxContainer`):

1. **Vertical Card Structure (`item_option.tscn`):**
   - **Header Zone:** Item Icon (`ItemIcon`) + Localized Name (`lbl_name`) + Level Badge (`lbl_level`).
   - **Badge Row (New):** Side-by-side `16x16` `TextureRect` badges (`TargetingBadge` + `MovementGroupBadge`) with `tooltip_text` showing the localized mode/group explanation on hover.
   - **Description Zone (`lbl_description`):** Expanded vertical height allows clean multi-line wrapping separating **Base Effect** from **Movement Synergy** (subtle color accent or divider line).
2. **"Simplified Descriptions" Toggle:**
   - **Settings Persistence:** Add `simplified_descriptions: bool = false` (or default `true` for newcomers, switchable in Gameplay Settings) to `SettingsManager` via `ConfigFile`, plus a compact **"Simple / Detailed"** toggle button (or hold-key hint like `Shift` / `Alt`) directly on the level-up overlay so players can inspect exact numbers anytime without leaving a draft.
   - **Simplified Mode:** 1–2 crisp lines summarizing feel (e.g., *"Fires piercing ice spears. Moving recharges faster."*), relying on the graphic badges for group/targeting identity.
   - **Detailed Mode:** Full numeric breakdown (e.g., *"CD 1.8s (-0.45s per 100px moved) | Dmg 7 -> 8 | Pierce 1. Group: Stride."*).
   - **Localization Schema (Rule 5):** Keep `ItemDesc_<Item><Tier>` as the detailed key in `translations/translations.csv` and add `ItemDesc_<Item><Tier>_simple` for simplified strings (with `item_option.gd` falling back to `details` automatically if a `_simple` key doesn't exist yet).


---

## 7. Empirical Run Progression & Draft Economy Diagnostics

> Merged from the Nov 14 codebase audits (`Utility/enemy_spawner.gd`, `Utility/upgrade_db.gd`, `Utility/global_events.gd`, `Player/player.gd`) and 10,000-run Monte Carlo draft simulations.

### 7.1 Run Timeline & Spawn Pool Schedule (`0:00–30:00`)
* **`0:00` — Easy Pool (`spawns_easy`):** `enemy_kobold_weak` (`10 HP`, `45 px/s`, `1 dmg`, `1 XP`). Base intensity $I(t) = 3.0$.
* **`1:00` — Normal Pool (`spawns_normal`):** `enemy_kobold_strong` (`20 HP`, `57 px/s`, `2 dmg`, `1 XP`). Quadratic ramp begins: $I(t) = 3.0 + 0.75t^2$ for $1.0 < t \le 3.0$.
* **`3:00` — Hard Pool (`spawns_hard`):** `enemy_cyclops` (`100 HP`, `39 px/s`, `5 dmg`, `5 XP`) and `enemy_juggernaut` (`300 HP`, `68 px/s`, `8 dmg`, `100 XP`). Linear ramp begins: $I(t) = 4.5 + 1.5t$.
  * **Terminal Roster Bottleneck:** After Minute 3:00, **no new enemy pools unlock** across the remainder of a 30-minute run.
  * **Minute 3.0 Discontinuity:** At $t = 3.0$, $I(t)$ suffers a $-7.69\%$ step drop ($9.75 \to 9.00$) and a $-66.67\%$ derivative drop ($dI/dt: 4.5 \to 1.5$ units/min) because the `elif minutes > 3.0` branch ignores the quadratic term (tracked in [`docs/tech_debt.md`](tech_debt.md)).
* **Every `5:00` (Warnings at `4:00, 9:00, 14:00, ...`) — Super Pool (`spawns_super`):** Bosses (*Ancient Amoeba*, *Dr. Franklin*) spawn with exponential HP scaling:
  $$\text{Boss HP Multiplier} = 1.05^{\text{minutes}} \times \text{GlobalEvents.get\_boss\_hp\_modifier}()$$
  - `5m`: `1.28x` | `10m`: `1.63x` | `15m`: `2.08x` | `20m`: `2.65x` | `30m`: `4.32x` (`+332.19%`).

### 7.2 Minion vs. Boss Health Decoupling
Non-boss minions use static HP (`final_hp = int(template.hp * hp_mod)`) with **zero elapsed time scaling**: a `kobold_weak` at Minute 29 has the exact same 10 base HP as at 0:15, while player DPS climbs $500\%–1000\%$ and bosses scale exponentially ($4.32\times$ at 30m). As a result, late-game swarms evaporate instantly while boss fights turn into prolonged kiting checks.

### 7.3 Slot-to-Pool Saturation & Combinatorial Build Space
| Pool Category | Catalog Size | Normal/Easy Slots | Normal Saturation | Hard Slots | Hard Saturation |
|---|---:|---:|---:|---:|---:|
| **Regular Weapons** | `7` (`icespear`, `javelin`, `tornado`, `poisonbottle`, `ritualcircle`, `lightningrod`, `whip`) | `6` | **`85.71%`** | `5` | `71.43%` |
| **Regular Passives** | `13` (`armor`, `speed`, `tome`, `scroll`, `ringofrejuvenation`, `ringofaffinity`, `thornring`, `occult_medallion`, `willowisp`, `glasstalisman`, `wardingbrooch`, `frenzycharm`, `impactbuckler`) | `8` | **`61.54%`** | `6` | `46.15%` |
| **Boss Items** | `4` (`ring`, `glasslash`, `vampireknives`, `relicdrone`) | — | 3 options per boss kill | — | 3 options per boss kill |

* **Combinatorial Consequence:** On Normal difficulty, there are only $\binom{7}{6} = 7$ distinct 6-weapon loadouts globally (and $\binom{6}{5} = 6$ per character with a fixed starter). Every run converges onto almost the entire catalog by Level 45–50 (Minute 12–15, ~48 total upgrades).
* **Endless Plateau:** Once slots fill around Minute 15, `player.gd` routes 100% of offerings into `_endless` stat-sticks (mostly `+1` damage).

### 7.4 Draft Agency & Monte Carlo Simulation Findings
Currently, `Player/player.gd` (`levelup()`) offers 3 random eligible cards with **no Reroll, Skip, or Banish**.
* **10,000-Run Monte Carlo Baseline:** Without draft agency, early unwanted weapon rolls permanently consume open slots, and targeted Tier 4 weapon completion sits at `35.2%` by Level 15, `59.7%` by Level 20, and `90.6%` by Level 30 (dropping to `24.9% / 38.3% / 51.6%` if pools are expanded with terminal choices).
* **Canonical Solution (`docs/design_guidelines.md`):** Grant **1 Reroll charge every 3 character levels** (Levels `3, 6, 9, 12, ...`, starting at `0`), paired with optional soft-tagging (`Offense`, `Defense`, `Utility`) so players can steer out of dead draws without fishing endlessly in late runs. In Monte Carlo testing (2 Rerolls + 2 Banishes), targeted acquisition climbs to `38.2% / 51.8% / 63.3%` while delaying passive saturation from Level `20.1` to `23.4`.

### 7.5 The "Phantom Win" Disconnect
Defeating the first boss at Minute 5:00 sets `hasWon = true` in `Player/player.gd`, yet the run continues indefinitely with no extraction portal, timer goal, or victory screen—meaning dying at Minute 28 still shows the Death Screen despite `hasWon == true`.

---

## 8. Curated Future Variance Pillars & Map Interaction Notes

> Prioritized design directions from [`docs/todo.md`](todo.md) (superseding the discarded Nov 14 proposals such as Tier 4 weapon bifurcations, Leyline Rifts, Blood Crucibles, and GPU-tinted fodder mutagens).

1. **Complex Enemy Behaviors & Per-Type Population Caps:**
   * Move beyond pure linear chasers by introducing dedicated behavioral enemies (chargers, ranged/zoners, shielders).
   * Pair further swarm optimizations ([`docs/swarm_optimization.md`](swarm_optimization.md)) with **per-type population caps** in `Utility/enemy_spawner.gd`, capping complex node/state-driven enemy types independently of the general swarm soft limit.
2. **Closed Maps, Environmental Hazards & Boss Interactions:**
   * Once walled arenas (`TileMapLayer` Layer 1) and environmental hazards are implemented, knocking or luring bosses into hazards can provide a rewarding skill-shot payoff—provided it deals **bounded bonus damage or a temporary debuff/stagger** rather than instant-kills (preventing displacement builds from becoming mandatory meta).
   * Requires fixing *Dr. Franklin*'s detached telegraph node (`dr_franklin.gd`) by parenting the telegraph to his pivot or syncing position on displacement (see [`docs/tech_debt.md`](tech_debt.md)).
3. **Unconventional Variance Mechanics (With Guardrails):**
   * **A. Empty-Slot Resonance (Weapon Slot Locking):** Allow sacrificing/locking empty weapon slots to supercharge equipped weapons. *Caveat:* Must **not** be toggleable on-demand; requires a dedicated commitment point (e.g., between stages, post-boss, or at a stage transition shrine).
   * **B. Stage-Driven World/Arena Rule Shifts:** Evolve `GlobalEvents.advanceBackground` into full stage/map transitions with distinct environmental rules. *Caveat:* Tie transitions to structured stage progression (such as defeating a boss) and actual map design rather than an arbitrary player level counter.
   * **C. Velocity / Stance-Coupled Combat:** The kinematic + `Spacebar` mobility framework detailed in Sections 1–6 of this document.
   * **D. XP Gem Ground Ecology:** Use uncollected floor XP gems passively as combat fuel or enemy targets. *Caveat:* Must be used sparingly (since consuming gems taxes XP progression) and strictly without active-use item buttons (triggering passively via weapon/enemy behaviors).
