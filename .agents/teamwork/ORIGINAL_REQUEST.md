# Original User Request

## Initial Request — 2026-10-06T18:59:47Z

Audit and modernize the SurvivorsClone Godot 4.6 project up to Antigravity 2.0 standards by implementing an automated headless unit testing suite, auditing and synchronizing project documentation and technical debt, authoring custom Antigravity workflow skills, enshrining the YAGNI (You Aren't Gonna Need It) principle, and maintaining GPL-3.0 open-source compliance.

Working directory: d:/Школа/Сезон 6/Group project/Vampire survivors clone 100%
Integrity mode: development

## Requirements

### R1. Headless Godot 4.6 Unit Testing Suite
Implement a robust, automated unit testing framework suitable for Godot 4.6 that runs headlessly via CLI. Keep it pragmatic and adhere strictly to YAGNI (focus on high-value, existing logic rather than speculative abstractions). The suite must cover core non-visual systems, including:
- Player stat calculations, scaling, and upgrade application formulas.
- Database integrity for `UpgradeDb` (verifying all weapon, item, and boss item levels, keys, and prerequisites).
- Difficulty and wave progression calculations from `GlobalEvents`.

### R2. Documentation, Tech Debt & YAGNI Standard in GEMINI.md
Audit the codebase against existing documentation:
- Add the YAGNI (You Aren't Gonna Need It) principle explicitly into `GEMINI.md` under project rules / architecture to prevent over-engineering.
- Document all core singletons, weapon spawner patterns, swarm systems, and event buses in `README.md` or dedicated architectural docs.
- Update `tech_debt.md` with any undocumented technical debt, deferred visual quirks, or engine limitations.
- Ensure strict adherence and alignment with existing project architectural guidelines and rules.

### R3. Project-Specific Antigravity Skills Suite
Author clean, modular Antigravity skills following standard `SKILL.md` conventions in the workspace customization directory:
1. `weapon-scaffolder`: Guides creating compliant weapons (spawner, projectile, `upgrade_db` registrations, PhasedAnimator standards).
2. `localization-validator`: Scans `translations.csv` across EN, RU, and UA, validating formatting, detecting missing keys, and reporting incomplete translations.
3. `tech-debt-auditor`: Systematically checks the codebase for known issues and synchronizes `tech_debt.md`.
4. `game-balance-eval`: Simulates and analyzes stat scaling, DPS curves, and enemy health/spawn scaling across difficulty levels.

### R4. Repository & License Compliance
Ensure all additions, new dependencies, and file headers comply with the project's GPL-3.0 licensing and repository structure.

## Acceptance Criteria

### Automated Testing & CLI Verification
- [ ] A CLI command executes the test suite headlessly via Godot (e.g., `godot --headless -s ...`) and exits cleanly with 0 on pass and non-zero on failure.
- [ ] Unit tests pass for `UpgradeDb` item integrity, stat modifier calculations, and difficulty curve scaling.

### Skills & Tooling Verification
- [ ] Each skill folder contains a valid `SKILL.md` with proper YAML frontmatter and clear step-by-step instructions.
- [ ] The localization validation skill or script can be executed against `translations.csv` and reports clean status without format corruption.

### Documentation & Repository State
- [ ] `GEMINI.md` includes the YAGNI principle clearly documented.
- [ ] `tech_debt.md` and project architecture documentation accurately reflect the latest engine state and patterns without breaking existing conventions.
- [ ] The Git working tree remains clean of unnecessary binaries, temporary caches, or incompatible licensed code.


## Follow-up — 2026-10-08T19:53:32Z

Update Inritus's core design guidelines and backlog with the v2 balance framework, and fully implement the 4 new health-based items (Glass Talisman, Warding Brooch, Frenzy Charm, Impact Buckler) into the game engine, complete with localization, tests, and balance verification.

Working directory: d:/Школа/Сезон 6/Group project/Vampire survivors clone 100%
Integrity mode: demo

## Requirements

### R1. Design Guidelines & Backlog Update
Update `design_guidelines.md` and `todo.md` with the approved v2 balance framework:
- Cooldown safety floor ($t_{\text{wait}} \ge 0.05\text{s}$).
- Universal proc coefficients for future on-hit accessories.
- Decentralized signal-driven conditional buffs (`health_ratio_changed`).
- Terraria-inspired ICD structures (Local Item ICD vs. Shared Defensive Buffer).
- Enemy tenacity and crowd control standards (Swarm vs. Elite vs. Boss).
- Long-term horizons: Pre-run weapon loadouts (RoR2 style), draft economy (1 reroll per 3 levels), and environmental wall collision rules.
- Resolution of "The Punished" character concept (Whip starter, tanky base stats `armor: 3`, `maxhp: 100`, clean single scaling passive `reflected_damage: 40`).

### R2. Health-Based Items Implementation
Implement the 4 health-based items in `res://Utility/upgrade_db.gd` and `res://Player/player.gd`:
1. **Glass Talisman:** Active when HP >= 95%, deals +5% / +10% / +15% / +25% damage (4 tiers + endless at +2% per stack).
2. **Warding Brooch:** Active when HP >= 90%, gains a protection charge after 10s out of combat that absorbs up to 5% of max HP with spillover. Tier 2 grants +15% move speed for 3s when the charge breaks (2 tiers, no endless).
3. **Frenzy Charm:** Active when HP < 30%, grants +10% / +20% / +30% attack speed (3 tiers, no endless).
4. **Impact Buckler:** Automatically triggers when HP drops below 20%, producing a radial kinetic shockwave that knocks back swarms and staggers elites. Cooldown: 60s / 40s / 20s (3 tiers, no endless). Bosses are immune to displacement.

### R3. Localization & Item Asset Standards
- Add all required translation rows (`keys,en,ru,ua`) in `translations/translations.csv` adhering to 4-column RFC 4180 standards.
- Ensure all 4 items have 32x32 trimmed icons adhering to Rule 12 (no transparent padding).

### R4. Automated Testing & Verification
- Create Gut unit tests in `test/unit/` verifying:
  - Threshold transitions and damage calculation for Glass Talisman and Frenzy Charm.
  - 5% max HP damage absorption and spillover logic for Warding Brooch.
  - Cooldown tracking and low-HP trigger logic for Impact Buckler.

## Acceptance Criteria

### Documentation Integrity
- [ ] `design_guidelines.md` and `todo.md` are updated and consistent with all approved v2 architectural decisions.
- [ ] No over-engineered central state machines added to `player.gd`; items respond autonomously to `health_ratio_changed`.

### Gameplay Mechanics & Balance
- [ ] All 4 items appear in level-up card pools when prerequisites are met, obeying tier limits.
- [ ] Glass Talisman dynamic damage bonus toggles accurately when crossing the 95% HP threshold.
- [ ] Warding Brooch absorbs incoming damage up to 5% max HP and spills over excess; breaks grant speed boost at Tier 2.
- [ ] Frenzy Charm wait time multiplier applies only while HP < 30% and caps at 30% attack speed.
- [ ] Impact Buckler shockwave triggers on HP drops below 20%, obeys cooldown (60/40/20s), and does not displace bosses.

### Verification Resources
- [ ] `python .agents/skills/localization-validator/validate_translations.py` returns status code 0 with 0 errors.
- [ ] `python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal` completes cleanly.
- [ ] `godot --headless -s addons/gut/gut_cmdln.gd` passes all unit tests with 0 failures.


## Follow-up — 2026-10-08T20:06:57Z

IMPORTANT USER UPDATE: Do NOT generate new item icons using AI image generation or nanobanana. The user explicitly stated: "you shouldn't generate the item icons since nanobanana can't generate the necessary 32x32 image sprites (or was it 16x16?), I'll just pick a texture later from the Dungeon Crawl Stone Soup pack". 

Please use existing placeholder textures already in the repository (e.g. existing item textures or generic upgrade icon) for the 4 health items in UpgradeDb so there are no null texture crashes, and skip any new image generation tasks.
