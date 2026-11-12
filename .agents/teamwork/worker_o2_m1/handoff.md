# Handoff Report: Milestone 1 (R1) Design Guidelines & Backlog Update

## 1. Observation

### 1.1 Scope & Directives
- **Authoritative Directive:** `ORIGINAL_REQUEST.md` (Dated 2026-10-08T19:53:32Z, R1: Design Guidelines & Backlog Update):
  - Cooldown safety floor ($t_{\text{wait}} \ge 0.05\text{s}$) in Section 4.2.
  - Universal proc coefficients for future on-hit accessories in Section 4.4 ($P_{\text{trigger}} = P_{\text{base}} \times \text{proc\_coefficient}$, duration scaling, standard baseline table, zero-proc rule for sub-munitions).
  - Decentralized signal-driven conditional buffs (`health_ratio_changed`) in Section 4.6 (Rule 19 YAGNI, anti-pattern of polling in `_process`, local state/hysteresis handling).
  - Terraria-inspired ICD structures in Section 4.7 (Local Item ICD vs. Shared Defensive Buffer vs. Enemy Local Immunity).
  - Enemy tenacity and crowd control standards in Section 4.8 (Swarm 0%, Elite 60-75%, Boss 100% displacement immunity).
  - Long-term horizons in Section 8: Pre-run weapon loadouts (RoR2 style), draft economy (1 reroll per 3 levels), and environmental wall collision rules / swarm flow-field navigation.
  - Resolution of "The Punished" character concept in Section 2 (Whip starter, tanky base stats `armor: 3`, `maxhp: 100`, clean single scaling passive `reflected_damage: 40`) and item ecosystem synergy.
  - Backlog update in `todo.md` with active status of health items, resolution of The Punished, and long-term backlog items.

### 1.2 File Modifications
- **`design_guidelines.md`**:
  - Section 2: Lines 33–46 updated with `Canonical Character Profiles & The Punished Resolution` table (Mage, Plague Doctor, Occultist, The Punished) and Note box detailing baseline durability (`armor: 3`, `maxhp: 100`), clean single scaling passive (`reflected_damage: 40`), and item ecosystem synergy (Warding Brooch, Frenzy Charm, Impact Buckler, Thorn Ring).
  - Section 4.2: Lines 181–193 updated to `Attack Cooldown & Safety Floor` enshrining $t_{\text{wait}} = \max\left(0.05, t_{\text{base}} \times (1.0 - \text{player.spell\_cooldown}) \times \text{cooldown\_multiplier}\right)$, detailing the $0.05\text{s}$ floor (max 20 activations/sec), engine stability rationale, and mandatory spawner contract.
  - Section 4.4: Lines 202–234 replaced with `Universal Proc Coefficients & On-Hit Mechanics`, detailing trigger probability $P_{\text{trigger}} = P_{\text{base}} \times \text{proc\_coefficient}$, guaranteed scaling, zero-proc loop suppression rule (`proc_coefficient = 0.0`), and standard baseline table by archetype.
  - Section 4.6: Lines 244–263 added specifying `Decentralized Signal-Driven Conditional Buffs (health_ratio_changed)`, Rule 19 YAGNI anti-polling rules, signal contract, and local hysteresis state handling.
  - Section 4.7: Lines 267–283 added specifying `Terraria-Inspired Internal Cooldown (ICD) Architecture` detailing Local Item ICD, Shared Defensive Buffer ($0.2\text{s}-0.4\text{s}$ HurtBox cooldown), and Enemy Local Immunity vs. Global Lockout.
  - Section 4.8: Lines 287–304 added specifying `Enemy Tenacity & Crowd Control Hierarchy` with 3-tier tenacity matrix (Swarm 0%, Elite 60–75%, Boss 100% displacement immune) and the code contract for boss displacement bypass.
  - Section 5: Line 321 added to Architectural Patterns table: `| **Conditional / Threshold Buff** | Signal Listener (health_ratio_changed) | Autonomous item component listens to health ratio transitions; toggles local modifiers without polling. |`.
  - Section 8: Lines 377–405 added specifying `Long-Term Architectural Horizons & Backlog Roadmap` detailing Pre-Run Weapon Loadouts (RoR2 style), Draft Economy (1 reroll per 3 levels), and Environmental Wall Collision Rules & Closed Maps (Layer 1 obstacles, projectile termination/pierce/bounce, swarm flow-fields).

- **`todo.md`**:
  - Lines 16–20: Updated `## Add health-based items` to `[ACTIVE - In Progress / Milestone 2 (R2) Implementation]` with canonical descriptions for Glass Talisman, Warding Brooch, Frenzy Charm, and Impact Buckler.
  - Lines 30–40: Updated `## Character Concept: The Punished / Retaliation Archetype` to `[RESOLVED & SPECIFIED]`, cataloging starter weapon `whip1`, base stats `{"armor": 3, "maxhp": 100}`, single scaling passive `reflected_damage: +40`, and synergy resolution via v2 item pool.
  - Lines 41–53: Added `## Long-Term Horizons (Backlog Roadmap)` cataloging Pre-run Weapon Loadouts, Draft Economy, Closed Maps & Environmental Wall Collision, Weapon Spawner Audit for Cooldown Safety Floor, and Universal Proc Coefficient Expansion.

### 1.3 Execution Tool Output
- **`validate_translations.py`**:
  ```
  === Localization Validation Report ===
  CSV Path: translations\translations.csv
  Total Entries: 293
  Errors: 0
  Warnings: 0
  [OK] Status: CLEAN - Translations validation passed successfully.
  ```
- **`balance_eval.py --difficulty normal`**:
  ```
  === Game Balance Simulation Report ===
  Difficulty: NORMAL | Character: Mage
  ...
  Execution completed with exit code 0.
  ```
- **`test_runner.gd` (Godot Headless)**:
  ```
  Godot Engine v4.6.1.stable.official.14d19694e
  Command exited with code 0.
  ```

---

## 2. Logic Chain

1. **Safety Floor Integration**:
   - *Observation:* Existing weapon spawners except `lightningrod_spawner.gd` did not enforce minimum wait times; high CDR plus Frenzy Charm (+30% attack speed) could produce $t_{\text{wait}} \le 0$, resulting in Godot timer errors.
   - *Logic:* Codifying $t_{\text{wait}} \ge 0.05\text{s}$ into Section 4.2 gives downstream implementers an unambiguous contract and prevents infinite frame execution loops.

2. **Universal Proc Coefficients & Loop Prevention**:
   - *Observation:* Secondary procs (e.g. Relic Rocket) could trigger cascades if given proc coefficients $> 0$.
   - *Logic:* Explicit mathematical contracts ($P_{\text{trigger}} = P_{\text{base}} \times \text{proc\_coefficient}$) and the strict zero-proc rule for sub-munitions guarantee that procs never trigger items recursively, safeguarding engine performance.

3. **Decentralized Signal Architecture (`health_ratio_changed`)**:
   - *Observation:* The v2 health items (Glass Talisman, Warding Brooch, Frenzy Charm, Impact Buckler) require HP state tracking. Central polling in `_process` or monolithic state machines in `player.gd` violates Rule 19 (YAGNI).
   - *Logic:* Section 4.6 establishes the `health_ratio_changed(current_ratio, old_ratio)` signal contract where items autonomously maintain local state and boundary hysteresis, decoupling item mechanics from the core player loop.

4. **Terraria-Inspired Dual-Layer ICD**:
   - *Observation:* Horde density causes simultaneous hits that would wipe out players without a shared defensive window, while items require independent cooldown timers.
   - *Logic:* Section 4.7 defines Local Item ICD (independent item cooldowns) vs. Shared Defensive Buffer ($0.2\text{s}-0.4\text{s}$ HurtBox i-frames), allowing emergency blasts (Impact Buckler) to execute cleanly while protecting against frame-level shotgunning.

5. **Tenacity & Boss CC Contract**:
   - *Observation:* Impact Buckler's knockback would disrupt boss telegraphs and state machines if applied unconditionally.
   - *Logic:* Section 4.8 establishes a 3-tier hierarchy (Swarm 0%, Elite 60–75%, Boss 100% displacement immune) with explicit code guards.

6. **The Punished & Backlog Resolution**:
   - *Observation:* The Punished was previously deferred due to dual-passive conflicts and lack of item support.
   - *Logic:* The v2 item pool supplies external sustain, retaliation buffs, and emergency panic buttons, enabling The Punished to launch with a pure single scaling passive (`reflected_damage: 40`), starter `whip1`, and bulk stats `{"armor": 3, "maxhp": 100}`, preserving character parity.

---

## 3. Caveats

- **Existing Spawners**: While `design_guidelines.md` mandates $t_{\text{wait}} \ge 0.05\text{s}$, pre-existing spawners (e.g., `icespear_spawner.gd`, `tornado_spawner.gd`) currently omit this guardrail; this is explicitly captured in `todo.md` under the spawner audit backlog task.
- **`player.gd` `base_stats` Parsing for `"maxhp"`**: In `player.gd`, `apply_stat_modifiers()` parses specific keys. When implementing The Punished in gameplay code, the developer will need to handle setting `base_maxhp = val` when `"maxhp"` is provided in `base_stats`.
- **Item Textures**: Per the user's latest follow-up directive (2026-10-08T20:06:57Z), AI image generation is disabled; existing placeholder sprites in the repository will be used for Milestone 2 (R2) item implementations.

---

## 4. Conclusion

Milestone 1 (R1) is complete. Both `design_guidelines.md` and `todo.md` have been updated and synchronized with the approved v2 balance framework:
- Cooldown safety floor ($t_{\text{wait}} \ge 0.05\text{s}$) specified in Section 4.2.
- Universal proc coefficients, formulas, baseline tables, and loop prevention rules codified in Section 4.4.
- Decentralized signal architecture (`health_ratio_changed`) codified in Section 4.6.
- Terraria-inspired ICD structures codified in Section 4.7.
- Enemy tenacity and crowd control hierarchy codified in Section 4.8.
- Section 5 architectural pattern table updated with Conditional / Threshold Buff pattern.
- Long-term horizons (loadouts, draft economy, closed maps/flow-fields) codified in Section 8.
- The Punished resolved in Section 2 and scheduled in `todo.md`.
- `todo.md` updated with active health items status and future roadmap items.
- Zero other repository files modified, preserving strict role and file ownership boundaries.

---

## 5. Verification Method

To independently verify this milestone:
1. **File Inspection**:
   - Inspect `design_guidelines.md` (Sections 2, 4.2, 4.4, 4.6, 4.7, 4.8, 5, 8).
   - Inspect `todo.md` (Health items, The Punished, Long-Term Horizons).
2. **Translation Integrity**:
   - Run `python .agents/skills/localization-validator/validate_translations.py` (Must output `Status: CLEAN` with 0 errors).
3. **Balance Evaluation**:
   - Run `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal` (Must complete cleanly with exit code 0).
4. **Automated Unit Tests**:
   - Run `godot --headless -s res://Tests/test_runner.gd` (Must complete cleanly with exit code 0).
5. **Git Boundaries**:
   - Run `git status` to verify only `design_guidelines.md` and `todo.md` (plus `.agents/teamwork/worker_o2_m1/`) were modified during this turn.
