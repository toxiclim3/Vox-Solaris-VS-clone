# Project Task List

## Expand item variety horizontally?
    Maybe add item modding a-la warframe (hard to implement well, but could be a way to replace common permanent progression)
    Offer item alternatives, e.g. poison bottle replacement that prioritises slow and has no damage (easier to implement, but kind of boring?)

## Place the game more inside of a game world, like EtG or Soul Knight
    So you wouldn't start your round from a title screen, but instead by walking to the entrance. And selecting a loadout\changing weapons\whatever pre-round stuff would also be done by doing it at a designated place

## Add maps
    Might need pathfinding improvements? 
    From a "Move to player" to a proper pathfinding algorhithm
    But in that case, figuring out a "pathfinding groups" kind of optimisation will be nessecary

## Try even harder to optimise the enemy count

## Add health-based items [COMPLETED]
    1. Glass Talisman: While health is above 95%, deal 5%/10%/15%/25% more damage (4 tiers + endless at +2% per stack).
    2. Warding Brooch: While health is above 90%, obtain a protection charge after 10s out of combat. This charge absorbs up to 5% of max health of incoming damage (with spillover). At level 2, losing a protection charge grants a 3s speed boost of 15% movement speed (2 tiers, no endless).
    3. Frenzy Charm: While health is below 30%, increase attack speed by 10%/20%/30% (wait time multiplied by 0.9/0.8/0.7) (3 tiers, no endless).
    4. Impact Buckler: When health drops below 20%, trigger a radial kinetic shockwave that knocks back swarms and staggers elites (bosses immune to displacement). Cooldown between activations: 60s/40s/20s (3 tiers, no endless).


## Add an item gallery
    Straight up just the item journal from risk of rain, minus the lore

## Add hover descriptions to items

## Replace texturebuttons with classic buttons, like the close button in the "How to play" menu
 
## Character Concept: The Punished / Retaliation Archetype [COMPLETED]
    - Status: Completed (implemented in global_events.gd, player.gd, and localized).
    - Resolved Blueprint:
        - Signature Starting Weapon: `whip1`
        - Base Stats (`base_stats`): `{"armor": 3, "maxhp": 100}` (+25% starting HP over base 80).
        - Clean Scaling Passive (`scaling_stats` @ Level 20): `reflected_damage: +40` (+40 flat retaliation).
    - Resolution Rationale:
        - Strict Parity: Conforms strictly to the "One Core Scaling Passive" Law and Rule 19 (YAGNI).
        - Baseline Durability: Starting armor and elevated HP provide the necessary physical bulk to absorb incoming hits without requiring a secondary passive.
        - Item Ecosystem Synergy: The v2 health item pool (Warding Brooch barrier, Frenzy Charm low-HP attack speed surge, Impact Buckler emergency blast) alongside Thorn Ring supplies the complete sustain and survival loop externally through upgrade drafts.

## Long-Term Horizons (Backlog Roadmap)
    - Draft Economy (1 Reroll per 3 Levels):
        - Start with 0 rerolls; earn 1 reroll charge every 3 character levels (levels 3, 6, 9, 12, ...). Balanced to prevent early bricking and endless late-game fishing.
    - Closed Maps & Environmental Wall Collision:
        - Dungeon/map arenas (EtG / Soul Knight style) with Tilemap Layer 1 solid walls.
        - Projectile collision: standard munitions terminate on walls, melee/ethereal pierce, bouncing munitions reflect.
        - Swarm navigation: Coarse chunk-based flow-field / vector fields for SwarmManager (avoiding individual Godot NavigationAgents).
    - Weapon Spawner Audit for Cooldown Safety Floor:
        - Audit all weapon spawners (icespear, tornado, whip, vampireknives, poisonbottle, glasslash, ritualcircle) to guarantee `t_wait >= 0.05s` floor via `max(0.05, ...)`.
    - Universal Proc Coefficient Expansion:
        - Standardize on-hit triggers across future accessory expansions using P_trigger = P_base * proc_coefficient and strict zero-proc loop prevention.
    - HurtBox & Hazard Immunity Standardization (Terraria 4-Tier ICD Model):
        - Audit enemy HurtBoxes and hazard systems (Poison Gas, Ritual Circle) to ensure Category Immunity is used for overlapping clouds without disabling enemy HurtBoxes to other weapons (preventing Ice Spear / projectile eaten hits).

## Future Variance & Core Gameplay Pillars (Design Notes)
    - Complex Enemy Behaviors & Per-Type Population Caps:
        - Goal: Introduce enemies with distinct, complex behaviors (chargers, ranged/zoners, shielders, etc.) rather than pure linear chasers.
        - Implementation Strategy: Combine further enemy performance optimization with per-type population caps in `enemy_spawner.gd` (capping specific complex node-based or state-driven enemy types independently of the general swarm soft limit).
    - Environmental Hazards & Boss Interactions (When Maps Are Added):
        - Once actual maps and environmental hazards exist, knocking/luring bosses into hazards can be a rewarding skill-shot interaction, provided it deals bounded bonus damage or a temporary debuff/stagger rather than instant-killing (so displacement items do not become mandatory meta).
        - Requires fixing detached boss telegraphs (e.g., parenting Dr. Franklin's telegraph to his pivot or syncing position on knockback).
    - Unconventional Variance Mechanics:
        - A. Empty-Slot Resonance (Weapon Slot Locking):
            - Sacrificing/locking empty weapon slots to supercharge remaining equipped weapons.
            - Caveat: Must NOT be toggleable on-demand; needs a dedicated activation point (e.g., between stages, after a boss, or at a stage transition shrine).
        - B. Stage-Driven World/Arena Rule Shifts:
            - Evolution of `GlobalEvents.advanceBackground` into full stage/map transitions with distinct environmental rules.
            - Caveat: Tie transitions to actual map design and structured stage progression (e.g., transitioning after defeating a boss rather than an arbitrary level counter).
        - C. Velocity / Stance-Coupled Combat (Addressing Game Pacing / "Feels Too Slow"):
            - Make movement state (standing still vs. moving, or angular momentum / tight kiting) an instrumental, core combat mechanic rather than a niche item effect.
            - Caveat: Requires a holistic combat and movement rebalance so stance/velocity interplay feels foundational to how Inritus plays.
        - D. XP Gem Ground Ecology (Passive / Non-Active Loot Interactions):
            - Using uncollected XP gems on the floor as combat fuel or enemy targets.
            - Caveat: Must be used sparingly (since destroying gems taxes XP progression) and strictly without active-use item buttons (must trigger passively via weapon/enemy behaviors).