# Implementation Plan: Design Guidelines Evolution & Balance Framework (v2)

This plan prepared the evolution of [`design_guidelines.md`](../design_guidelines.md) and [`todo.md`](../todo.md) from conversation `0d5af418-c831-4a81-a7cd94774259` ("Design Guidelines and Ideology Review"). It documents the rationale behind decentralized signal-driven conditional buffs, clarified proc coefficients, Terraria-inspired ICD structures, dark-fantasy thematic renames, refined single-stat passives for The Punished, the "1 reroll per 3 levels" draft pacing, and environmental collision rules.

---

## User Review & Alignment Summary

> [!IMPORTANT]
> **Key Decisions Refined With User Input:**
> 1. **Proc Coefficient Demystification:** Clarified that Inritus originally only applied proc coefficients to Lifesteal. The v2 guideline formally standardizes this for all future on-hit damage/chance procs so high-tick AOEs don't break the game.
> 2. **No Over-Engineered State Machines:** Dropped player-level threshold enums. Items independently listen to a unified `health_ratio_changed(current_hp, max_hp, ratio)` signal and toggle their own state/stat modifiers.
> 3. **Thematic Dark-Fantasy Item Naming:**
>    - *Repulsion Core* $\to$ **Impact Buckler** (or **Spike Vambrace**).
>    - *Desperation* $\to$ **Frenzy Charm** (or **Blooddrinker's Torque**).
>    - *Aegis Ward* $\to$ **Warding Brooch** (blocks up to $5\%$ max HP, spills excess).
>    - *Pristine Focus* $\to$ **Glass Talisman** (damage while $\ge 95\%$ HP).
> 4. **Terraria-Style ICD Classification:** Split item cooldowns into **Local Item ICD** (per-item timer) and **Shared Defensive ICD** (prevents simultaneous panic-button triggers).
> 5. **"The Punished" Kept Clean & Elegant:** Avoided complex multi-stage passives; aligned on a single clean scaling passive paired with defensive base stats.
> 6. **Item Draft Economy:** Added "1 Reroll earned every 3 character levels" to combat pool dilution.

---

## 1. Systemic Guidelines Additions

### A. Clarification on Proc Coefficients (What & Why)
- **Baseline State in Inritus:** Only `lifesteal` utilized `proc_coefficient` in `Player/player.gd` to prevent Poison Gas or Ritual Circle from granting infinite immortality.
- **The Guideline Rule Going Forward:** When creating any future item with an on-hit chance (e.g., "10% chance on hit to trigger Bleed/Chain"):
  $$\text{Effective Trigger Chance} = \text{Base Chance} \times \text{weapon.proc\_coefficient}$$
  - Slow single-target projectile (Ice Spear): `proc_coeff = 1.0` $\to$ full $10\%$ chance per hit.
  - Multi-tick cloud (Poison Gas): `proc_coeff = 0.1` $\to$ $1\%$ chance per tick.
  This preserves weapon parity without needing custom math for every new accessory.

### B. Cooldown Scaling (Preserving Crazy Nonsense Safely)
- Players can still achieve insane attack speeds in late runs.
- **Engine Safety Floor:** Firing wait times are clamped to a minimum of $0.05\text{s}$ ($20\text{ attacks/sec}$):
  $$t_{\text{wait}} = \max\left(0.05, \, t_{\text{base}} \times (1.0 - \text{spell\_cooldown})\right)$$
  Prevents division-by-zero, audio engine crackle, and physics thread locks while still feeling like a rapid-fire hose.

### C. Decentralized Conditional Item Architecture (Anti Over-Engineering)
- Rather than bloating `player.gd` with hardcoded thresholds, `Player` emits a single signal whenever health changes:
  ```gdscript
  signal health_ratio_changed(current_hp: float, max_hp: float, ratio: float)
  ```
- **Item Autonomy:** Any conditional item (or weapon spawner) connects directly to this signal:
  ```gdscript
  func _on_player_health_ratio_changed(current_hp, max_hp, ratio):
      var should_be_active = (ratio >= 0.95)
      if is_active != should_be_active:
          is_active = should_be_active
          _toggle_buff(is_active)
  ```
  Zero frame-by-frame checking in `_physics_process`, zero centralized enum bloat, and any item can define whatever threshold it wants (95%, 50%, 30%).

### D. Terraria-Inspired Internal Cooldown (ICD) Variants
To prevent messy timing bugs, two standard ICD patterns are defined:
1. **Local Item ICD (Default):** Cooldown tracked strictly by the item itself via timestamp comparison (`Time.get_ticks_msec() / 1000.0`). Example: *Impact Buckler* (20s CD).
2. **Shared Defensive Buffer (Protection Lockout):** When a major defensive life-saver triggers (e.g. panic explosion), it sets a global 0.5s brief invulnerability lockout (`player.i_frames = 0.5`) to prevent other defensive charges from vanishing simultaneously on the same frame.

### E. Enemy Tenacity & Crowd Control Standard
Standardizes how slows and knockbacks affect different enemy pools:
- **Swarm Enemies (Easy/Normal Pools):** $100\%$ knockback, $100\%$ slow potency.
- **Elite Enemies (Hard Pool):** $50\%$ knockback distance, $50\%$ slow potency.
- **Bosses (Super Pool):** **Immune to knockback**, slows capped at maximum $20\%$ reduction.

---

## 2. Health-Based Items Specification

### Item 1: Glass Talisman (High-HP Damage)
- **Condition:** Active while HP $\ge 95\%$.
- **Progression (4 Tiers + Endless):** $+5\% / +10\% / +15\% / +25\%$ Player Damage Multiplier ($+2\%$ per Endless stack).

### Item 2: Warding Brooch (Anti-Chip Protection Charge)
- **Condition:** When HP $\ge 90\%$, generate a charge after $10\text{s}$ without taking damage.
- **Mechanics:** Blocks 1 hit up to $5\%$ of player max HP; excess damage spills over onto player HP. (Shield-gating / one-shot protection remains a separate future item concept).
- **Progression (2 Tiers — Hard Capped, No Endless):** Tier 1 absorbs up to $5\%$ max HP; Tier 2 grants $+15\%$ Movement Speed for $3\text{s}$ on break.

### Item 3: Frenzy Charm (Low-HP Attack Speed)
- **Condition:** Active while HP $< 30\%$.
- **Progression (3 Tiers — No Endless):** $+10\% / +20\% / +30\%$ Attack Speed (Wait time $\times 0.90 / 0.80 / 0.70$, capped).

### Item 4: Impact Buckler (Emergency Blast)
- **Condition:** Triggers automatically when HP drops below $20\%$.
- **Mechanics:** Releases a radial shockwave pushing swarms far back and staggering elites (bosses are immune to displacement).
- **Progression (3 Tiers — Hard Capped, No Endless):** $60\text{s} / 40\text{s} / 20\text{s}$ Cooldown.

---

## 3. Resolving "The Punished" (The Retaliation Archetype)

### Why Complex Passives Were Dropped:
Tip-sweetspots (*Penitent Whiplash*), blood-sacrifice meters (*Controlled Blood Sacrifice / Sanguinomancer*), and vengeance counter-punch bars (*Stored Retaliation*) were rejected as too complex and violating the **"One Core Scaling Passive" Law**.

### The Clean, Symmetrical Solution:
1. **Starting Weapon:** Whip (mid-range spacing).
2. **Starting Stat Bias (`base_stats`):** `"armor": 3`, `"maxhp": 100`.
3. **Single Clean Scaling Passive:** `"scaling_stats": {"reflected_damage": 40}` (Scales linearly from 0 to 40 reflected damage at Level 20).
4. **Defensive Ecosystem Synergy:** Paired with **Warding Brooch** (chip absorption) and **Impact Buckler** (panic blast), supporting a tanky retaliation archetype without breaking character symmetry.

---

## 4. Long-Term Roadmap Items

### A. Pre-Run Loadouts (The RoR2 Model)
- Rather than Warframe-style in-run modding, allow selecting an **Alternate Starting Weapon Form** at character select once unlocked.

### B. Draft Economy & Reroll Pacing
- **Rule:** The player earns **1 Reroll every 3 character levels** (Levels 3, 6, 9, 12, etc.).
- **Tag Balancing:** Soft-tagging items (`Offense`, `Defense`, `Utility`) to avoid dead defensive draws when DPS is needed.

### C. Environmental Rules (Future Walled Maps / EtG-Style)
- **Projectiles:** Stop or despawn at walls (Layer 1).
- **Persistent AOE:** Clip/clamp against wall geometry.
- **Swarm Routing:** Retained as a research topic requiring a flow-field or sector-based grid before complex corridors can support 1,000+ MultiMesh enemies.
