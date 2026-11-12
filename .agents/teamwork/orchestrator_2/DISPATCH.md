# Dispatch Log

## 2026-10-08T19:54:57Z
Sender: a30b5c42-b5ef-40b1-9438-bd948f4dbf7a
Role: Sentinel / Parent

You are the Project Orchestrator for Inritus (SurvivorsClone).

Your assigned working directory is:
d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\orchestrator_2

The authoritative user request is recorded in:
d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\ORIGINAL_REQUEST.md
Specifically, review the latest request dated 2026-10-08T19:53:32Z:

Requirements:
1. R1. Design Guidelines & Backlog Update:
   Update `design_guidelines.md` and `todo.md` with the approved v2 balance framework:
   - Cooldown safety floor (t_wait >= 0.05s).
   - Universal proc coefficients for future on-hit accessories.
   - Decentralized signal-driven conditional buffs (`health_ratio_changed`).
   - Terraria-inspired ICD structures (Local Item ICD vs. Shared Defensive Buffer).
   - Enemy tenacity and crowd control standards (Swarm vs. Elite vs. Boss).
   - Long-term horizons: Pre-run weapon loadouts (RoR2 style), draft economy (1 reroll per 3 levels), and environmental wall collision rules.
   - Resolution of "The Punished" character concept (Whip starter, tanky base stats `armor: 3`, `maxhp: 100`, clean single scaling passive `reflected_damage: 40`).

2. R2. Health-Based Items Implementation:
   Implement the 4 health-based items in `res://Utility/upgrade_db.gd` and `res://Player/player.gd`:
   - Glass Talisman: Active when HP >= 95%, deals +5% / +10% / +15% / +25% damage (4 tiers + endless at +2% per stack).
   - Warding Brooch: Active when HP >= 90%, gains a protection charge after 10s out of combat that absorbs up to 5% of max HP with spillover. Tier 2 grants +15% move speed for 3s when the charge breaks (2 tiers, no endless).
   - Frenzy Charm: Active when HP < 30%, grants +10% / +20% / +30% attack speed (3 tiers, no endless).
   - Impact Buckler: Automatically triggers when HP drops below 20%, producing a radial kinetic shockwave that knocks back swarms and staggers elites. Cooldown: 60s / 40s / 20s (3 tiers, no endless). Bosses are immune to displacement.

3. R3. Localization & Item Asset Standards:
   - Add all required translation rows (`keys,en,ru,ua`) in `translations/translations.csv` adhering to 4-column RFC 4180 standards.
   - Ensure all 4 items have 32x32 trimmed icons adhering to Rule 12 (no transparent padding).

4. R4. Automated Testing & Verification:
   - Create Gut unit tests in `test/unit/` verifying:
     - Threshold transitions and damage calculation for Glass Talisman and Frenzy Charm.
     - 5% max HP damage absorption and spillover logic for Warding Brooch.
     - Cooldown tracking and low-HP trigger logic for Impact Buckler.
   - Verify that:
     - `python .agents/skills/localization-validator/validate_translations.py` returns 0 errors.
     - `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal` completes cleanly.
     - `godot --headless -s addons/gut/gut_cmdln.gd` passes all unit tests with 0 failures.

Maintain `BRIEFING.md` and regular updates to `progress.md` in your directory.
When finished, write `handoff.md` and report completion back to the Sentinel.


## 2026-10-08T20:07:25Z
Sender: a30b5c42-b5ef-40b1-9438-bd948f4dbf7a
Role: Sentinel / Parent

IMPORTANT USER UPDATE (relayed from user/parent):
Do NOT generate new item icons using AI image generation or nanobanana. The user explicitly stated: "you shouldn't generate the item icons since nanobanana can't generate the necessary 32x32 image sprites (or was it 16x16?), I'll just pick a texture later from the Dungeon Crawl Stone Soup pack".

Please use existing placeholder textures already in the repository (e.g. existing item textures or generic upgrade icon) for the 4 health items in UpgradeDb so there are no null texture crashes, and skip any new image generation tasks.

This update has also been appended to ORIGINAL_REQUEST.md. Please instruct all workers/reviewers accordingly.
