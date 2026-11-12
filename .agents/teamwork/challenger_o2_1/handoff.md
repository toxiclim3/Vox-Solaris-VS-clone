# Health Items Adversarial Stress-Test Report

**Agent:** Empirical Challenger (`challenger_o2_1`)  
**Verdict:** **DEFECT_FOUND**

---

## 1. Observation

### O1. Glass Talisman Boundary & Endless Stacking Formula
- **Implementation:** `res://Player/player.gd:263-272`
  ```gdscript
  func get_damage_bonus() -> float:
      var cur_ratio = float(hp) / float(maxhp) if maxhp > 0 else 0.0
      if cur_ratio >= 0.95 and glass_talisman_level > 0:
          var endless_count = collected_endless.get("glasstalisman", 0)
          return GLASS_TALISMAN_BONUSES[clamp(glass_talisman_level, 0, 4)] + (0.02 * endless_count)
      return 0.0

  func get_damage_modifier() -> float:
      return 1.0 + get_damage_bonus()
  ```
- **Empirical Test:** In `test/unit/test_health_items_stress.gd`:
  - `test_glass_talisman_floating_point_boundaries_around_95_percent`:
    - HP ratio 0.9499 -> bonus = 0.0, modifier = 1.0 (PASS).
    - HP ratio 0.9500 -> bonus = 0.25, modifier = 1.25 (PASS).
    - HP ratio 0.9501 -> bonus = 0.25, modifier = 1.25 (PASS).
    - Tested on `maxhp = 80` (75.99 vs 76.00) and `maxhp = 137` (130.14 vs 130.15) (PASS).
  - `test_glass_talisman_10_plus_endless_stacking_and_formula`:
    - 10 endless stacks: `0.25 + 10 * 0.02 = 0.45` bonus, `1.45` modifier (PASS).
    - 15 endless stacks: `0.25 + 15 * 0.02 = 0.55` bonus, `1.55` modifier (PASS).
    - 25 endless stacks: `0.25 + 25 * 0.02 = 0.75` bonus, `1.75` modifier (PASS).
    - 50 endless stacks: `0.25 + 50 * 0.02 = 1.25` bonus, `2.25` modifier (PASS).
    - Below 95% HP: bonus drops strictly to 0.0, modifier to 1.0 even at 50 stacks (PASS).
    - Restoration to 95.00% HP: restores the full stacked bonus (PASS).

### O2. Critical Defect: Glass Talisman Damage Ignored by SwarmManager
- **Elite/Boss Damage Implementation:** `res://Enemy/Base/enemy_body.gd:164-167`
  ```gdscript
  var damage_multiplier = 1.0 + get_debuff_value("curse")
  var p_dmg_mod = GlobalEvents.get_player_damage_modifier()
  if player != null and player.has_method("get_damage_modifier"):
      p_dmg_mod *= player.get_damage_modifier()
  hp -= (damage * damage_multiplier * p_dmg_mod)
  ```
- **Swarm Damage Implementation:** `res://Utility/swarm_manager.gd:264-265`
  ```gdscript
  var damage_multiplier = 1.0 + enemy.get_debuff_value("curse")
  enemy.hp -= (atk.damage * damage_multiplier * GlobalEvents.get_player_damage_modifier())
  ```
- **Routing:** In `res://Utility/enemy_spawner.gd:203`, 100% of Easy and Normal pool spawns are routed to `SwarmManager`.
- **Finding:** `SwarmManager` never checks `player.get_damage_modifier()`. Glass Talisman bonus damage (+5% to +25% + endless) is completely ignored against all swarm enemies, affecting 100% of standard wave mobs.

### O3. Warding Brooch Capacity, Spillover, Timers & Buff
- **Implementation:** `res://Player/player.gd:285-303`, `242-256`, `388-393`
- **Empirical Test:** In `test/unit/test_health_items_stress.gd`:
  - `test_warding_brooch_exact_5_percent_capacity_absorption`:
    - 100 max HP (capacity 5.0): 5.0 damage -> absorbed 5.0, spillover 0.0 (PASS).
    - 250 max HP (capacity 12.5): 12.5 damage -> absorbed 12.5, spillover 0.0 (PASS).
    - 250 max HP: 12.5001 damage -> absorbed 12.5, spillover 0.0001 (PASS).
  - `test_warding_brooch_massive_damage_spillover_1000`:
    - Direct: 1000 damage on 100 max HP -> absorbed 5.0, spillover 995.0, charge consumed, timer reset (PASS).
    - Pipeline: 1000 damage clamped to 999 max by armor formula -> absorbed 5.0, spillover 994.0, player fatal hit (PASS).
  - `test_warding_brooch_out_of_combat_recharge_and_interruption`:
    - 9.9s -> no charge; taking damage resets timer to 0.0s (PASS).
    - 10.01s out of combat -> charge granted (PASS).
  - `test_warding_brooch_no_charge_gained_when_hp_below_90_percent`:
    - HP at 89.9%: 10s and 60s out of combat -> charge is never gained (PASS).
    - Healing to 90.0% while timer >= 10.0s -> charge granted immediately (PASS).
  - `test_warding_brooch_tier_2_speed_boost_duration_and_reversion`:
    - Break charge: speed increases by +15% (100 -> 115) for exactly 3.0s (PASS).
    - Reverts cleanly to 100.0 base speed after duration expires (PASS).
    - Tier 1 grants no speed boost on break (PASS).

### O4. Critical Defect: Weapon Spawners Bypass Cooldown Safety Floor & Error on CDR >= 100%
- **Player Cooldown Floor Implementation:** `res://Player/player.gd:279-284`
  ```gdscript
  func calculate_cooldown(base_time: float) -> float:
      return max(0.05, base_time * (1.0 - spell_cooldown))
  ```
- **Weapon Spawner Implementations:**
  - `res://Player/Attack/whip/whip_spawner.gd:75`:
    `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)`
  - `res://Player/Attack/glasslash/glasslash_spawner.gd:80`:
    `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)`
  - `res://Player/Attack/vampireknives/vampireknives_spawner.gd:62`:
    `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)`
  - `res://Player/Attack/poisonbottle/poisonbottle_spawner.gd:40`:
    `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
  - `res://Player/Attack/tornado/tornado_spawner.gd:44`:
    `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
  - `res://Player/Attack/ritualcircle/ritualcircle_spawner.gd:42`:
    `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
  - `res://Player/Attack/icespear/icespear_spawner.gd:43`:
    `timer.wait_time = attackspeed * (1 - player.spell_cooldown)`
- **Finding:**
  1. Spawners bypass `player.calculate_cooldown()` during runtime `_on_timer_timeout()`. When `player.spell_cooldown` is 0.98 (e.g. Frenzy Charm 3 at 20% HP + high CDR build), `timer.wait_time` drops to `1.3 * 0.02 = 0.026s < 0.05s`, violating the safety floor requirement.
  2. When `player.spell_cooldown >= 1.0` (100%+ CDR), `timer.wait_time` is assigned `<= 0.0`, triggering Godot Engine error:
     `ERROR: Time should be greater than zero. at: set_wait_time (scene/main/timer.cpp:93)`.

### O5. Frenzy Charm Attack Speed Scaling
- **Implementation:** `res://Player/player.gd:273-277`
- **Empirical Test:** In `test/unit/test_health_items_stress.gd`:
  - `test_frenzy_charm_attack_speed_scaling_at_30_percent_boundary`:
    - HP at 30.00% -> bonus 0.0, inactive (PASS).
    - HP at 30.01% -> bonus 0.0, inactive (PASS).
    - HP at 29.99% -> bonus 0.30 (Tier 3), active (PASS).
    - HP at 29.90% -> bonus 0.10 (T1), 0.20 (T2), 0.30 (T3) (PASS).

### O6. Impact Buckler Low-HP Trigger, Cooldown Lock & Re-Arm
- **Implementation:** `res://Player/player.gd:236-241`, `305-322`
- **Empirical Test:** In `test/unit/test_health_items_stress.gd`:
  - `test_impact_buckler_threshold_trigger_and_cooldown_lock`:
    - HP at 20.00% -> does not trigger (PASS).
    - HP drop from 50% to 19.99% -> triggers shockwave, cooldown set to 60s (Tier 1) (PASS).
    - Consecutive hits during cooldown (18%, 15%, 10%, 5% HP) -> cooldown lock strictly enforced, no re-trigger (PASS).
  - `test_impact_buckler_rearm_after_cooldown_expiration`:
    - Cooldown expires -> heal above 20% (30%) -> drop below 20% (12%) -> triggers cleanly (PASS).
  - `test_impact_buckler_boss_displacement_immunity`:
    - Normal enemy displaced by 400.0 knockback (PASS).
    - Boss (`isBoss == 1` or in group `"boss"`) displacement immune (knockback is Vector2.ZERO) (PASS).
  - `test_impact_buckler_continuous_low_hp_behavior_adversarial`:
    - Documented behavior: In `player.gd:238`, `if current_ratio < 0.20 and previous_ratio >= 0.20:`. If player remains continuously below 20% HP (e.g. at 15%) after cooldown expires and takes a further hit to 10%, the shockwave does NOT re-trigger because `previous_ratio` was already below 0.20. Player must heal to >= 20% to re-prime the drop trigger.

---

## 2. Logic Chain

1. From **O1**, `get_damage_bonus()` correctly evaluates `cur_ratio >= 0.95` across float boundary steps (0.9499 vs 0.9500 vs 0.9501) and scales endlessly by `+0.02 * count` up to 50+ stacks.
2. From **O2**, while `enemy_body.gd:166` applies `player.get_damage_modifier()`, `swarm_manager.gd:265` does NOT include it. Because all Easy and Normal enemies are routed to `SwarmManager`, Glass Talisman's damage bonus is non-functional against the vast majority of enemies in the game.
3. From **O3**, Warding Brooch adheres strictly to the 5% max HP capacity absorption, handles 1000-damage spillover, correctly resets and holds the 10s out-of-combat timer, suppresses charge when HP < 90%, and grants exactly 3.0s of +15% speed at Tier 2.
4. From **O4**, the mandated cooldown safety floor ($t_{\text{wait}} \ge 0.05\text{s}$) is implemented inside `player.calculate_cooldown()`, but weapon spawners (`whip`, `glasslash`, `vampireknives`, `poisonbottle`, `tornado`, `ritualcircle`, `icespear`) directly assign `timer.wait_time = attack_speed * (1.0 - player.spell_cooldown)` in `_on_timer_timeout()`. When CDR is high or exceeds 1.0 (easily achievable with Frenzy Charm and passives/scrolls), the safety floor is violated and Godot throws `Time should be greater than zero` errors.
5. From **O5**, Frenzy Charm toggles precisely across the 30.0% boundary and scales by tier (+10%/+20%/+30%).
6. From **O6**, Impact Buckler obeys the <20% trigger threshold, enforces the cooldown lock against multiple hits, cleanly re-arms upon healing above 20%, and boss displacement immunity is intact.
7. Combining 2 and 4, the health item system contains two functional/architectural defects requiring mitigation. Therefore, the verdict is **DEFECT_FOUND**.

---

## 3. Caveats

- In accordance with the prompt's `Review-only` constraint, this subagent did not modify production code in `res://Player/player.gd`, `res://Utility/swarm_manager.gd`, or the weapon spawners.
- Floating-point subtraction over time: depending on the exact sequence of variable `delta` values, `warding_brooch_speed_timer` may have a sub-epsilon residual ($~10^{-17}$) at the exact 3.000s boundary, resolving on the immediately succeeding frame.
- The continuous low-HP behavior of Impact Buckler (requiring healing to >= 20% to re-trigger after cooldown) matches the literal specification "triggers when HP drops below 20%", but should be verified with game design if repeated triggers while remaining low were intended.

---

## 4. Conclusion

- **Verdict:** **DEFECT_FOUND**
- **Actionable Defect 1:** Update `res://Utility/swarm_manager.gd:265` to include the player's damage modifier:
  ```gdscript
  var p_dmg_mod = GlobalEvents.get_player_damage_modifier()
  if player != null and player.has_method("get_damage_modifier"):
      p_dmg_mod *= player.get_damage_modifier()
  enemy.hp -= (atk.damage * damage_multiplier * p_dmg_mod)
  ```
- **Actionable Defect 2:** Refactor weapon spawners to use `player.calculate_cooldown(attack_speed)` (or `max(0.05, ...)` directly) in their `_on_timer_timeout()` methods to enforce the safety floor and prevent `timer.wait_time <= 0` errors under extreme CDR.

---

## 5. Verification Method

Execute the automated headless test runner:
```powershell
python -c "import subprocess; res = subprocess.run(['godot', '--headless', '-s', 'res://Tests/test_runner.gd'], capture_output=True, text=True); print(res.stdout); exit(res.returncode)"
```
Verify:
- 5 suites passed (including `res://test/unit/test_health_items_stress.gd`).
- 71 tests passed, 0 failed.
- 2640 assertions passed.

Execute localization validation:
```powershell
python .agents/skills/localization-validator/validate_translations.py
```
(Status: CLEAN, 0 errors, 0 warnings across 309 entries).
