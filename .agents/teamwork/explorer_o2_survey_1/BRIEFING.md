# BRIEFING — 2026-10-08T20:02:00Z

## Mission
Investigate design_guidelines.md, todo.md, ORIGINAL_REQUEST.md, and related mechanics to formulate exact specification updates for R1.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigation, synthesis
- Working directory: d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\explorer_o2_survey_1
- Original parent: 367189cb-de49-4169-88a6-0559799f7fc7
- Milestone: R1 Design Guidelines & Backlog Update Investigation

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- No grep command in shell; use grep_search or Select-String
- Files for content delivery, Messages for coordination

## Current Parent
- Conversation ID: 367189cb-de49-4169-88a6-0559799f7fc7
- Updated: not yet

## Investigation State
- **Explored paths**:
  - `design_guidelines.md`, `todo.md`, `ORIGINAL_REQUEST.md`, `GEMINI.md`
  - `Utility/global_events.gd`, `Player/player.gd`, `Utility/swarm_manager.gd`, `Utility/hurt_box.gd`
  - `Enemy/Base/enemy_body.gd`, `Enemy/Boss/boss.gd`, `Enemy/Boss/dr_franklin.gd`
  - `Player/Attack/*` (cooldowns & proc coefficients)
  - `Tests/test_runner.gd`, `Tests/Unit/*`, skills (`game-balance-eval`, `localization-validator`)
- **Key findings**:
  1. Attack Cooldown safety floor ($t_{\text{wait}} \ge 0.05\text{s}$) is missing across most weapon spawners; only Lightning Rod currently has a clamp (`0.1s`). Formula and contract must be formally codified in Section 4.2.
  2. Proc coefficients currently exist in attack nodes and are emitted via `player_dealt_damage`, but guidelines only mention lifesteal. Need universal on-hit scaling formula, standard archetype table, and strict zero-proc loop rule (`proc_coefficient = 0.0` for sub-munitions/procs).
  3. `health_ratio_changed(current, old)` signal is needed for decentralized conditional items (Glass Talisman, Warding Brooch, Frenzy Charm, Impact Buckler) to eliminate polling loops and adhere to Rule 19 (YAGNI).
  4. Terraria-inspired ICD model: Local Item ICD (autonomous cooldowns per accessory) vs. Shared Defensive Buffer (player hurt i-frames preventing multi-hit wipes) vs. Enemy-side local immunity.
  5. Enemy tenacity standards: Swarm = 0% tenacity (full displacement), Elite = 60-75% tenacity (stagger interrupt), Boss = 100% displacement immunity (cannot be moved by Impact Buckler or weapons).
  6. The Punished is fully resolved: Whip starter (`whip1`), tanky base stats (`armor: 3`, `maxhp: 100`), single scaling passive (`reflected_damage: 40` at lvl 20), naturally closing the loop with the 4 health items and Thorn Ring.
  7. Long-term horizons: RoR2 style pre-run loadouts, 1 reroll per 3 levels draft economy, and environmental wall collision / swarm flow-field rules.
  8. Found test runner nuance: Test suite uses custom `Tests/test_runner.gd` rather than external GUT.
- **Unexplored areas**: None for R1 scope.

## Key Decisions Made
- Formulate complete, drop-in replacement sections and diffs for `design_guidelines.md` and `todo.md` in `handoff.md`.

## Artifact Index
- DISPATCH.md — Dispatch instructions
- BRIEFING.md — Situational awareness
- progress.md — Liveness heartbeat
- handoff.md — Complete 5-component handoff report
