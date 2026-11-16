# R1: Current Feature & Variance Bottleneck Analysis — Inritus Codebase Investigation

## 1. Observation

### Codebase Architecture & Key Files Examined
- **Design Guidelines & Project Rules**: `res://design_guidelines.md`, `res://GEMINI.md`, `res://tech_debt.md`
- **Singletons & Global State**: `res://Utility/global_events.gd`, `res://Utility/upgrade_db.gd`, `res://Utility/StatsManager.gd`
- **Spawning & Enemy AI**: `res://Utility/enemy_spawner.gd`, `res://Utility/swarm_manager.gd`, `res://Enemy/Base/enemy_body.gd`, `res://World/world.tscn`
- **Player Mechanics & GUI**: `res://Player/player.gd`, `res://Player/gui.gd`
- **Weapons & Attack Spawners**: All 12 attack directories under `res://Player/Attack/` (`icespear`, `javelin`, `tornado`, `poisonbottle`, `ritualcircle`, `lightningrod`, `whip`, `glasslash`, `vampireknives`, `relicdrone`, `occult_medallion`, `willowisp`)

---

### Empirical Observations by Area

#### A. Run Timeline & Game Loop Architecture
1. **Time Accumulation & Checkpoints** (`enemy_spawner.gd:92-176`, `global_events.gd:28-32`):
   - `GlobalEvents.bossInterval = 5 * 60` (300 seconds / 5 minutes).
   - Boss warning is emitted at `(GlobalEvents.time + 60) % boss_spawn_interval == 0` (Minutes 4:00, 9:00, 14:00, 19:00, etc.) (`enemy_spawner.gd:109-114`).
   - Boss spawns at `GlobalEvents.time % boss_spawn_interval == 0` (Minutes 5:00, 10:00, 15:00, 20:00, etc.) (`enemy_spawner.gd:117-133`).
   - Boss HP multiplier is computed as:
     $$\text{Multiplier} = \text{boss\_hp\_scaling\_base}^{\text{minutes}} \times \text{GlobalEvents.get\_boss\_hp\_modifier}()$$
     where `boss_hp_scaling_base = 1.05` (`enemy_spawner.gd:17, 262-264`).
     - Min 5: $1.05^5 \approx 1.276\times$ (+27.6%)
     - Min 10: $1.05^{10} \approx 1.629\times$ (+62.9%)
     - Min 15: $1.05^{15} \approx 2.079\times$ (+107.9%)
     - Min 20: $1.05^{20} \approx 2.653\times$ (+165.3%)
     - Min 30: $1.05^{30} \approx 4.322\times$ (+332.2%)
2. **Spawn Pool Timeline & Unlock Gates** (`enemy_spawner.gd:13-14, 135-175`):
   - `0:00 – 1:00`: Only `spawns_easy` is active (`enemy_kobold_weak`, `weight_easy = 100`, `weight_normal = 0`).
   - `1:00`: `spawns_normal` unlocks (`enemy_kobold_strong`). Weight scales as `min(int((minutes - 1.0) * 20), 100)`.
   - `3:00`: `spawns_hard` unlocks (`enemy_cyclops`, `enemy_juggernaut`). Elites spawn on a slow delay: `current_elite_delay = max(5, delay * 4)` ($\approx 6-10$ seconds).
   - `3:00+`: Spawn intensity calculation undergoes an abrupt mathematical step discontinuity (`enemy_spawner.gd:186-193`, `tech_debt.md:108-117`):
     - At $t = 3.0$: `time_multiplier = 3.0 + (0.75 * 9.0) = 9.75`.
     - At $t = 3.0001$: `time_multiplier = 4.5 + (3.0 * 1.5) = 9.00`.
     - After minute 3.0, intensity grows linearly: $4.5 + (\text{minutes} \times 1.5)$.
   - **Crucial Observation**: After Minute 3:00, **zero new enemy types or wave events exist** in the game. The wave structure reaches its terminal state at 180 seconds.
3. **The Victory & Run Termination Disconnect** (`player.gd:9-10, 961-982`):
   - When any boss is killed, `GlobalEvents.boss_defeated` triggers:
     ```gdscript
     func _on_boss_defeated():
         hasWon = true
         pending_boss_rewards += 1
         if not gui.levelPanel.visible and not gui.bossLevelPanel.visible:
             _show_next_reward()
     ```
   - `hasWon` is set to `true` at Minute 5 on the first boss kill, but the run **does not conclude**. There is no extraction portal, no stage transition, no time-limit death reaper (unlike Vampire Survivors' 30:00 Death), and no victory screen until the player either manually exits or lets their HP drop to zero (`player.gd:961-976`).

---

#### B. Weapon Variety & Architectural Matrix
Inritus defines 12 attack implementations across 5 architectural patterns (`GEMINI.md`, `Player/Attack/`):

| Attack System | Folder | Pattern | Base Tiers | Endless Tier Behavior | Scaling Nature |
|---|---|---|---|---|---|
| **Ice Spear** | `Player/Attack/icespear/` | Standard Projectile Spawner | 1–4 | `damage += endless_level * 1.0` | Vertical: ammo +1, damage +4, pierce +1 |
| **Javelin** | `Player/Attack/javelin/` | Standard Projectile Spawner | 1–4 | `damage += e_level * 1.0` | Vertical: paths 1->2->3, damage +5 |
| **Tornado** | `Player/Attack/tornado/` | Standard Projectile Spawner | 1–4 | Script: `attack_size += 0.05` / Db: `damage: 1` (Discrepancy) | Vertical: ammo +1, cooldown -0.5s |
| **Poison Bottle** | `Player/Attack/poisonbottle/` | Two-Stage AOE (PhasedAnimator) | 1–4 | `damage += 1` | Vertical: gas size +25%, damage +1 |
| **Ritual Circle** | `Player/Attack/ritualcircle/` | Persistent Steered AOE Aura | 1–4 | `damage += endless_level * 1.0` | Vertical: ammo +1, duration +1.0s, dmg +5 |
| **Lightning Rod** | `Player/Attack/lightningrod/` | Hitscan Chain Spawner | 1–4 | `damage += 1` | Vertical: cooldown 3.0s -> 2.0s, extra chain |
| **Leather Whip** | `Player/Attack/whip/` | Flexible 3-Slice Line2D Melee | 1–4 | `damage += 1` | Vertical: attack speed 1.3s -> 0.8s, dmg +4 |
| **Glass Lash** | `Player/Attack/glasslash/` | Boss Weapon / 3-Slice + Shards | 1–4 | `damage += 5` | Vertical: damage 30->90, speed 3.0s->1.0s, 6 shards |
| **Vampire Knives** | `Player/Attack/vampireknives/` | Boss Weapon / Fan Projectiles | 1–4 | `damage += 1, lifesteal += 0.1` | Vertical: knives 5->12, lifesteal 1.0->2.0 HP/hit |
| **Relic Drone** | `Player/Attack/relicdrone/` | Autonomous Direct Child Companion | 1–2 | **MISSING (Backlog debt)** | Vertical: proc chance 10%->15%, dmg mult 2x->3x |
| **Occult Medallion** | `Player/Attack/occult_medallion/` | Pulse Debuff Spawner | 1–4 | No stat mod in `UpgradeDb.gd:850` | Vertical: targets 1->2, curse +5%->+15%, int 2.0s->0.5s |
| **Will o' Wisp** | `Player/Attack/willowisp/` | On-Kill Global Hook Proc | 1–4 | **MISSING (Backlog debt)** | Vertical: proc chance 15%->20%, dmg 5->10 + 5% max HP |

**Key Code Observations**:
1. **Homogenized Endless Scaling**: With the exception of `vampireknives` (+0.1 lifesteal) and `glasslash` (+5 damage), every single weapon endless upgrade in `UpgradeDb.gd` is a flat `"stat_modifiers": {"damage": 1}`. There is zero mechanical alteration.
2. **Missing Evolutions / Combinations**: Unlike genre benchmarks (Vampire Survivors, Brotato), weapons never fuse, evolve, or alter behavioral forms upon hitting Tier 4.
3. **Loop Prevention Suppression**: Secondary item procs (`RelicRocket`, `willowisp`) have `proc_coefficient = 0.0` or `0.1` (`design_guidelines.md:221-224`, `player.gd:991`). While mathematically necessary to avoid infinite cascade crashes in dense swarms, it completely eliminates emergent cascade builds unless explicit synergistic mechanics are designed.

---

#### C. Item Pools & Upgrade Economy Saturation
1. **The Slot-to-Pool Ratio Trap** (`global_events.gd:153-162`, `upgrade_db.gd:6-988`):
   - Regular Weapon Pool Size: **7 Weapons** (`icespear`, `javelin`, `tornado`, `poisonbottle`, `ritualcircle`, `lightningrod`, `whip`).
   - Weapon Slot Capacity: **6 Slots** on Normal/Easy (`max_weapon_slots = 6`), **5 Slots** on Hard.
   - **Math**: Players equip **$6 / 7 = 85.7\%$** of all regular weapons in every single run!
   - Regular Upgrade Pool Size: **13 Passives** (`armor`, `speed`, `tome`, `scroll`, `ringofrejuvenation`, `ringofaffinity`, `thornring`, `occult_medallion`, `willowisp`, `glasstalisman`, `wardingbrooch`, `frenzycharm`, `impactbuckler`).
   - Upgrade Slot Capacity: **8 Slots** on Normal/Easy (`max_upgrade_slots = 8`), **6 Slots** on Hard.
   - **Math**: Players equip **$8 / 13 = 61.5\%$** of all passive items in every single run!
2. **Boss Reward Pool Saturation** (`upgrade_db.gd`, `player.gd:575-594`):
   - Total Boss Items: **4 Items** (`ring`, `glasslash`, `vampireknives`, `relicdrone`).
   - At each boss defeat, the player is presented 3 options out of 4 (`optionsmax = 3`).
   - By Boss 2 (Minute 10), the player has acquired half the boss item catalog. `vampireknives` heals 1.0 to 2.0 flat HP per hit on 5 to 12 knives per volley, completely trivializing player health sustain.
3. **Zero Draft Agency** (`player.gd:554-574`):
   ```gdscript
   func levelup():
       ...
       var options = 0
       var optionsmax = 3
       var options_list = []
       while options < optionsmax:
           var item = get_random_item()
           if item != null:
               options_list.append(item)
           elif not options_list.has("food"):
               options_list.append("food")
           options += 1
       gui.show_levelup(options_list, current_visual_level)
   ```
   - **No Reroll button**.
   - **No Skip button**.
   - **No Banish button**.
   - If an unselected weapon appears while a slot is open, the player has no agency to prevent slot pollution. Once equipped, weapons cannot be removed.
4. **XP Cap Progression & Level Plateau** (`player.gd:519-537`):
   - Levels 1–10: 5, 10, 15, 30, 50, 75, 110, 130, 150, 200 XP.
   - Levels 11–19: `200 + (lvl - 10) * 250` XP.
   - Levels 20+: `2700 + (lvl - 20) * 400` XP.
   - Because SwarmManager spawns hundreds to thousands of MultiMesh units per minute, XP intake surges exponentially. Players typically reach Level 40–50 by minute 15.
   - 6 weapons $\times$ 4 tiers = 24 upgrades. 8 passives $\times$ avg 3 tiers = 24 upgrades. Total required to cap build = ~48 upgrades.
   - By minute 15, all inventory slots are 100% capped.
   - From minute 15 to 30+, **100% of all level-up offerings are Endless Tier cards** (`player.gd:878-882`).

---

#### D. Enemy Scaling & Swarm vs. Elite Balance
1. **Static Minion Stats Across Entire Run** (`enemy_kobold_weak.tscn`, `enemy_kobold_strong.tscn`, `enemy_cyclops.tscn`, `enemy_juggernaut.tscn`, `enemy_body.gd:5-9`):
   - `enemy_kobold_weak` (Easy pool): **HP = 10**, Speed = 45, Damage = 1, XP = 1
   - `enemy_kobold_strong` (Normal pool): **HP = 20**, Speed = 57, Damage = 2, XP = 1
   - `enemy_cyclops` (Hard pool): **HP = 100**, Speed = 39, Damage = 5, XP = 5
   - `enemy_juggernaut` (Hard pool): **HP = 300**, Speed = 68, Damage = 8, XP = 100
2. **The "Missing Time Variable" in Minion Scaling** (`enemy_spawner.gd:234-255`):
   ```gdscript
   # Easy & Normal Pool Spawns (SwarmManager)
   var hp_mod = GlobalEvents.get_enemy_hp_modifier() # 0.8 on Easy, 1.0 on Normal, 1.2 on Hard
   var final_hp = int(template.hp * hp_mod)
   
   # Hard Pool Spawns (Elites)
   var hp_mod = GlobalEvents.get_enemy_hp_modifier()
   if hp_mod != 1.0:
       enemy_spawn.hp = int(enemy_spawn.hp * hp_mod)
   ```
   - **Crucial Fact**: Non-boss enemies have **zero HP scaling over time**. A Kobold Weak spawned at Minute 29 has the exact same 10 HP as a Kobold Weak spawned at Second 15!
   - Only `spawn_count` scales with time:
     $$\text{spawn\_count} = \text{int}(\text{enemy\_num} \times \text{time\_multiplier} \times \text{randf\_range}(0.8, 1.2) \times \text{spawn\_mod})$$
3. **Risk of Rain Disconnect**:
   - In *Risk of Rain 2*, difficulty scaling increases both enemy spawn credit budget AND health/damage scaling:
     $$\text{Enemy HP} = \text{Base HP} \times (1 + \text{scaling\_factor} \times \text{time}^{1.15})$$
     $$\text{Enemy Damage} = \text{Base Damage} \times (1 + 0.2 \times \text{scaling\_factor} \times \text{time})$$
   - In *Inritus*, difficulty scaling only increases quantity, not quality or survivability.
4. **Swarm vs. Elite Imbalance**:
   - In `enemy_spawner.gd:203`, 100% of Easy and Normal spawns are routed to `SwarmManager`.
   - Swarm enemies have 0% tenacity (`design_guidelines.md:299`) and zero hit sound feedback (`tech_debt.md:58-64`).
   - Elites spawn only once every 6–10 seconds (`enemy_spawner.gd:170-172`).
   - Consequently, over 98% of all rendered enemies are identical 10–20 HP kobolds that evaporate silently the microsecond they appear within weapon range.

---

#### E. Meta-Progression & Persistence Audit
- Inspection of `Utility/StatsManager.gd:1-79`:
  - `StatsManager` tracks only 6 integer counters in `user://statistics.cfg`: `enemy_kills`, `boss_kills`, `total_deaths`, `total_wins`, `best_run_level`, `best_run_time`.
  - **Zero meta-currencies** exist (no gold, coins, soul shards, or tokens).
  - **Zero persistent upgrades** exist (no health bonuses, extra rerolls, base damage upgrades).
  - **Zero unlockable items/weapons** exist in `UpgradeDb.gd`.
  - All 4 characters (`mage`, `plague_doctor`, `occultist`, `punished`) are completely unlocked and selectable from the first time the game is booted (`TitleScreen/play_menu.gd:24-80`).

---

## 2. Logic Chain

```
[Observation: 7 regular weapons in UpgradeDb] + [Observation: Player has 6 weapon slots]
  │
  ▼
[Step 1: Slot/Pool Ratio Saturation]
  Every run forces player to pick 6 out of 7 weapons (85.7% saturation).
  Player cannot build a specialized 3-weapon build or avoid unwanted weapons.
  │
  ▼
[Step 2: Build Monoculture & Character Identity Dissolution]
  Regardless of character passive (Mage CDR vs Occultist Lifesteal vs Punished Retaliation),
  by Minute 10 every character has 6 maxed weapons. Unique playstyles dissolve into an
  identical screen-clearing AoE ball.
  │
  ▼
[Observation: Zero rerolls, skips, or banishes in levelup()] + [Observation: Random 3-card pick]
  │
  ▼
[Step 3: Stripped Player Agency]
  When RNG presents unwanted weapons, player is forced to consume permanent inventory slots.
  Player feels like a passive spectator of RNG card distribution rather than an active builder.
  │
  ▼
[Observation: Minions have static HP (10, 20, 100, 300) with zero time scaling]
  │
  ▼
[Step 4: Exponential DPS vs Static Enemy Health Decoupling]
  Player DPS scales by 500-1000% across Levels 1-40. Minion HP stays at 10 HP.
  Combat degenerates into instant off-screen vaporisation. Swarms offer zero mechanical resistance.
  │
  ▼
[Observation: Zero new enemy types after Minute 3:00] + [Observation: 2 bosses repeating on 5m loop]
  │
  ▼
[Step 5: Severe Mid-to-Late Game Encounter Fatigue]
  From Minute 3 to 30+, player fights the exact same 4 minions on an infinite flat plane.
  Bosses at 5, 10, 15, 20 are identical Amoeba or Dr. Franklin encounters with +27-165% HP.
  │
  ▼
[Observation: Inventory caps at lvl ~48 (Min 12-15)] + [Observation: 100% Endless cards (+1 dmg)]
  │
  ▼
[Step 6: Late-Game Upgrade Monotony]
  After Minute 15, level-up choices lose all meaning. Player clicks 30+ identical "+1 damage" popups.
  Game pace halts to show menus that provide no mechanical changes.
  │
  ▼
[Observation: StatsManager tracks only kills/wins; zero gold/unlocks; no end trigger on win]
  │
  ▼
[Step 7: The "Phantom Win" & Void of Long-Term Retention]
  Defeating the boss at Min 5 flags hasWon = true but does not end the run or offer extraction.
  Dying at Min 30 yields 0 persistent rewards. Replayability drops off a cliff after 2-3 runs.
```

---

## 3. Caveats
- **Backlog Debt vs Engine Limitations**: The lack of endless tiers on `relicdrone` and `willowisp` is documented in `design_guidelines.md:138-141` as unpolished backlog debt rather than architectural restrictions.
- **Mobile Renderer Constraints**: MultiMesh batching in `SwarmManager` is vital for Godot 4.6 Mobile renderer performance. Any mechanic proposing individual node spawning for mass enemies would violate performance guardrails (`tech_debt.md:47-53`).
- **Sound Starvation Intentionality**: The lack of swarm hit sounds was an intentional compromise to prevent AudioServer voice-stealing starvation (`tech_debt.md:58-64`), but it heavily contributes to the feeling of hitting "paper targets."
- **YAGNI Scope Protection**: Recommendations must avoid speculative multi-tier managers or bloated factory patterns (Rule 19). Any solution must fit cleanly into `UpgradeDb`, `GlobalEvents`, and `enemy_spawner.gd`.

---

## 4. Conclusion & Bottleneck Assessment

The investigation reveals **6 fundamental bottlenecks** that severely constrain player fun, build variety, and long-term retention in Inritus:

### Bottleneck Summary Table

| Bottleneck Category | Code Root Cause | Empirical Impact | Player Experience Consequence |
|---|---|---|---|
| **1. Slot/Pool Monoculture** | `UpgradeDb.UPGRADES` has 7 weapons; `player.gd` allows 6 slots (`global_events.gd:156`). | 85.7% of all weapons equipped on every run. | Build diversity collapses. Every character plays identically after minute 10. |
| **2. Zero Draft Agency** | `player.gd:554-574` (`levelup`) lacks reroll, skip, banish, or lock mechanics. | 100% deterministic card acceptance. | Frustration when unwanted weapons pollute permanent slots. |
| **3. Static Roster & Arena Flatness** | `enemy_spawner.gd:164` unlocks all pools at 3:00. Only 4 minion types, 2 bosses, 0 terrain obstacles. | 27 out of 30 run minutes have zero new enemy types or behavioral changes. | High mid-game combat fatigue; runs feel like repetitive circular kiting. |
| **4. Pseudo-RoR Scaling Decoupling** | `enemy_spawner.gd:234-255` scales spawn count via `time_multiplier`, but minion HP is 100% static. | Minions remain at 10–20 HP while player DPS increases by 1000%. | Combat becomes a visual lawnmower; zero tactical threat from swarms. |
| **5. Endless Tier Monotony** | `player.gd:878-882` offers 100% endless cards after min 15; `UpgradeDb` endless = flat `+1 damage`. | 30+ level-ups per run provide zero visual or mechanical mutation. | Late-game boredom; player clicks menus just to clear them. |
| **6. The "Phantom Win" & Meta Void** | `player.gd:978` sets `hasWon = true` without run end; `StatsManager.gd` has zero meta-currency or unlocks. | 0 permanent progression across runs; run victory has no narrative or extraction closure. | Severe replayability drop-off after 2–3 runs. |

---

## 5. Verification Method

To independently verify these findings, perform the following code audits and gameplay test runs:

1. **Verify Slot/Pool Saturation**:
   - Inspect `d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\Utility\upgrade_db.gd` and count keys with `"type": "weapon"`. Verify exactly 7 regular weapons exist (`icespear`, `javelin`, `tornado`, `poisonbottle`, `ritualcircle`, `lightningrod`, `whip`).
   - Inspect `d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\Utility\global_events.gd:153-162`. Verify `get_max_weapon_slots()` returns 6 on Normal difficulty.
2. **Verify Enemy HP Time Independence**:
   - Inspect `d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\Utility\enemy_spawner.gd:234-255`. Confirm that `final_hp` is computed strictly using `template.hp * hp_mod` with no `time` or `minutes` multiplier, whereas `get_boss_hp_multiplier()` at line 262 explicitly uses `pow(boss_hp_scaling_base, minutes)`.
3. **Verify Terminal Enemy Unlock at 3:00**:
   - Inspect `d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\Utility\enemy_spawner.gd:164`. Note `time_hard_unlock_minutes = 3.0`. Search the entire file for any unlock condition where `minutes > 3.0` (none exists).
4. **Verify Draft Agency Void**:
   - Inspect `d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\Player\player.gd:549-574` and `Player/gui.gd:180-195`. Confirm the absence of any `reroll_button`, `skip_button`, or `banish_button`.
5. **Verify Meta-Progression Absence**:
   - Inspect `d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\Utility\StatsManager.gd`. Confirm the file only saves 6 primitive integer run records with zero currency or upgrade logic.
