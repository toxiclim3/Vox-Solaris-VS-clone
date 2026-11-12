#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2024-2026 SurvivorsClone Contributors
"""
Game Balance Evaluation & DPS Modeling CLI for SurvivorsClone.

Simulates and analyzes:
- Player DPS progression across 0-20 minute runs
- Character passives and stat modifier curves
- Enemy health scaling and wave spawn rate
- Boss HP scaling: BossHP(t) = 500 * (1.05)^t * DifficultyMod
- Time-to-Kill (TTK) metrics for fodder, elites, and bosses
- Overwhelm / Sponginess risk detection
"""

import argparse
import json
import math
import sys
from typing import Dict, List, Tuple


# Difficulty modifiers from GlobalEvents.gd
DIFFICULTY_MODS = {
    "easy": {
        "enemy_hp": 0.8,
        "boss_hp": 0.8,
        "spawn_mod": 0.8,
        "xp_mod": 1.2,
        "player_regen": 1.5,
        "weapon_slots": 6,
        "upgrade_slots": 8,
    },
    "normal": {
        "enemy_hp": 1.0,
        "boss_hp": 1.0,
        "spawn_mod": 1.0,
        "xp_mod": 1.0,
        "player_regen": 1.0,
        "weapon_slots": 6,
        "upgrade_slots": 8,
    },
    "hard": {
        "enemy_hp": 1.2,
        "boss_hp": 1.2,
        "spawn_mod": 1.2,
        "xp_mod": 0.8,
        "player_regen": 1.0,
        "weapon_slots": 5,
        "upgrade_slots": 6,
    },
    "custom": {
        "enemy_hp": 1.0,
        "boss_hp": 1.0,
        "spawn_mod": 1.0,
        "xp_mod": 1.0,
        "player_regen": 1.0,
        "weapon_slots": 6,
        "upgrade_slots": 8,
    },
}

# Base enemy stats
ENEMY_SPECS = {
    "kobold_weak": {"hp": 10.0, "speed": 45.0, "xp": 1.0, "dmg": 1.0},
    "kobold_strong": {"hp": 20.0, "speed": 57.0, "xp": 1.0, "dmg": 2.0},
    "cyclops": {"hp": 100.0, "speed": 39.0, "xp": 5.0, "dmg": 5.0},
    "juggernaut": {"hp": 300.0, "speed": 68.0, "xp": 100.0, "dmg": 8.0},
    "boss_base": {"hp": 500.0, "speed": 68.0, "xp": 100.0, "dmg": 30.0},
}

# Weapon tiers: [lvl1, lvl2, lvl3, lvl4] -> (single_target_dps, cleave_dps)
WEAPON_DATA = {
    "icespear": {
        1: (5.33, 5.33),
        2: (10.67, 21.33),
        3: (16.0, 32.0),
        4: (40.0, 160.0),
    },
    "tornado": {
        1: (15.0, 45.0),
        2: (30.0, 90.0),
        3: (45.0, 135.0),
        4: (75.0, 225.0),
    },
    "javelin": {
        1: (2.0, 8.0),
        2: (4.0, 16.0),
        3: (6.0, 24.0),
        4: (9.0, 36.0),
    },
    "poisonbottle": {
        1: (12.5, 37.5),
        2: (15.6, 62.4),
        3: (25.0, 100.0),
        4: (37.5, 187.5),
    },
    "glasslash": {
        1: (16.0, 32.0),
        2: (25.0, 50.0),
        3: (36.0, 72.0),
        4: (50.0, 120.0),
    },
    "whip": {
        1: (5.33, 10.66),
        2: (10.0, 20.0),
        3: (16.0, 32.0),
        4: (25.0, 50.0),
    },
    "vampireknives": {
        1: (12.5, 25.0),
        2: (21.0, 42.0),
        3: (30.0, 60.0),
        4: (45.0, 90.0),
    },
    "lightningrod": {
        1: (8.0, 8.0),
        2: (12.0, 12.0),
        3: (18.0, 54.0),
        4: (26.0, 104.0),
    },
}


def xp_required_for_level(lvl: int) -> int:
    """Calculates XP cap for a given level according to player.gd."""
    if lvl <= 1:
        return 5
    elif lvl == 2:
        return 10
    elif lvl == 3:
        return 15
    elif lvl == 4:
        return 30
    elif lvl == 5:
        return 50
    elif lvl == 6:
        return 75
    elif lvl == 7:
        return 110
    elif lvl == 8:
        return 130
    elif lvl == 9:
        return 150
    elif lvl == 10:
        return 200
    elif lvl < 20:
        return 200 + (lvl - 10) * 250
    else:
        return 2700 + (lvl - 20) * 400


def get_spawn_multiplier(t_min: float) -> float:
    """Wave spawn intensity multiplier from Utility/enemy_spawner.gd."""
    if t_min <= 1.0:
        return 3.0
    elif t_min <= 3.0:
        return 3.0 + 0.75 * (t_min ** 2)
    else:
        return 4.5 + 1.5 * t_min


def simulate_run(
    difficulty: str = "normal",
    character: str = "mage",
    weapons: List[str] = None,
    total_minutes: int = 20,
    time_step: float = 1.0,
) -> Dict:
    """Executes deterministic balance modeling across the specified run timeline."""
    diff_mod = DIFFICULTY_MODS.get(difficulty.lower(), DIFFICULTY_MODS["normal"])
    if not weapons:
        weapons = ["icespear", "tornado"]

    # Filter valid weapons
    active_weapons = [w for w in weapons if w in WEAPON_DATA]
    if not active_weapons:
        active_weapons = ["icespear"]

    timeline = []
    total_xp_accumulated = 0.0
    current_level = 1
    xp_to_next = xp_required_for_level(current_level)

    balance_alerts = []

    t = 0.0
    while t <= total_minutes + 1e-5:
        # Enemy spawn rate per second
        intensity = get_spawn_multiplier(t) * diff_mod["spawn_mod"]
        spawn_rate_per_sec = intensity * 1.5  # average base pack size is ~1.5

        # Enemy health scaling at this minute
        if t < 3.0:
            avg_enemy_hp = ENEMY_SPECS["kobold_weak"]["hp"] * diff_mod["enemy_hp"]
            avg_enemy_xp = 1.0
        elif t < 8.0:
            avg_enemy_hp = ENEMY_SPECS["kobold_strong"]["hp"] * diff_mod["enemy_hp"]
            avg_enemy_xp = 1.0
        elif t < 15.0:
            avg_enemy_hp = ENEMY_SPECS["cyclops"]["hp"] * 0.3 * diff_mod["enemy_hp"] + 20.0 * 0.7
            avg_enemy_xp = 2.2
        else:
            avg_enemy_hp = ENEMY_SPECS["juggernaut"]["hp"] * 0.2 * diff_mod["enemy_hp"] + 50.0 * 0.8
            avg_enemy_xp = 4.0

        # Accumulated XP in this time step
        if t > 0:
            xp_gained_in_step = spawn_rate_per_sec * avg_enemy_xp * diff_mod["xp_mod"] * (time_step * 60.0)
            total_xp_accumulated += xp_gained_in_step

            # Level up loop
            while total_xp_accumulated >= xp_to_next:
                total_xp_accumulated -= xp_to_next
                current_level += 1
                xp_to_next = xp_required_for_level(current_level)

        # Character passive scaling (level 1-20)
        passive_progress = min(current_level, 20) / 20.0
        cdr_bonus = 0.15 * passive_progress if character == "mage" else 0.0
        size_bonus = 0.50 * passive_progress if character == "plague_doctor" else 0.0

        # Weapon levels based on player level (weapon upgrades earned as level increases)
        weapon_tier = min(4, max(1, 1 + current_level // 5))

        # Calculate player DPS
        single_dps = 0.0
        cleave_dps = 0.0
        for w in active_weapons:
            w_single, w_cleave = WEAPON_DATA[w][weapon_tier]
            # Apply CDR
            w_single *= (1.0 + cdr_bonus)
            w_cleave *= (1.0 + cdr_bonus) * (1.0 + size_bonus * 0.5)
            single_dps += w_single
            cleave_dps += w_cleave

        # Boss HP at time t
        boss_hp = ENEMY_SPECS["boss_base"]["hp"] * (1.05 ** t) * diff_mod["boss_hp"]
        boss_ttk = boss_hp / max(1.0, single_dps)

        # Overwhelm check: incoming enemy HP per second vs player Cleave DPS
        incoming_hp_per_sec = spawn_rate_per_sec * avg_enemy_hp
        overwhelm_ratio = incoming_hp_per_sec / max(1.0, cleave_dps)

        # Alerts
        if t in [5.0, 10.0, 15.0, 20.0] and boss_ttk > 60.0:
            balance_alerts.append(
                f"Minute {int(t)}: Boss TTK is {boss_ttk:.1f}s (> 60s sponge threshold)."
            )
        if overwhelm_ratio > 1.25 and t >= 3.0:
            balance_alerts.append(
                f"Minute {int(t)}: Swarm overwhelm risk! Incoming HP/s ({incoming_hp_per_sec:.1f}) exceeds cleave DPS ({cleave_dps:.1f}) by {overwhelm_ratio*100-100:.1f}%."
            )

        timeline.append({
            "minute": round(t, 1),
            "player_level": current_level,
            "single_target_dps": round(single_dps, 1),
            "cleave_dps": round(cleave_dps, 1),
            "boss_hp": round(boss_hp, 1),
            "boss_ttk_sec": round(boss_ttk, 1),
            "incoming_hp_rate": round(incoming_hp_per_sec, 1),
            "overwhelm_ratio": round(overwhelm_ratio, 2),
        })

        t += time_step

    return {
        "difficulty": difficulty,
        "character": character,
        "weapons": active_weapons,
        "total_minutes": total_minutes,
        "timeline": timeline,
        "alerts": balance_alerts,
    }


def print_ascii_table(result: Dict) -> None:
    print(f"=== Game Balance Simulation Report ===")
    print(f"Difficulty: {result['difficulty'].upper()} | Character: {result['character'].title()}")
    print(f"Equipped Weapons: {', '.join(result['weapons'])}")
    print("-" * 78)
    print(f"{'Min':>4} | {'Lvl':>4} | {'Single DPS':>10} | {'Cleave DPS':>10} | {'Boss HP':>9} | {'Boss TTK':>9} | {'Overwhelm':>9}")
    print("-" * 78)

    for step in result["timeline"]:
        m = step["minute"]
        lvl = step["player_level"]
        sdps = step["single_target_dps"]
        cdps = step["cleave_dps"]
        bhp = step["boss_hp"]
        bttk = f"{step['boss_ttk_sec']:.1f}s"
        ow = f"{step['overwhelm_ratio']:.2f}x"
        print(f"{m:>4.0f} | {lvl:>4} | {sdps:>10.1f} | {cdps:>10.1f} | {bhp:>9.0f} | {bttk:>9} | {ow:>9}")

    print("-" * 78)
    if result["alerts"]:
        print("\n[BALANCE ALERTS]")
        for alert in set(result["alerts"]):
            print(f"  ⚠️ {alert}")
    else:
        print("\n[OK] Balance Healthy: DPS curves sustain wave scaling and boss encounter pacing.")


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(
        description="SurvivorsClone Game Balance & DPS Scaling Evaluator."
    )
    parser.add_argument(
        "--difficulty",
        choices=["easy", "normal", "hard", "custom"],
        default="normal",
        help="Difficulty tier to evaluate (default: normal)",
    )
    parser.add_argument(
        "--character",
        choices=["mage", "occultist", "plague_doctor", "punished"],
        default="mage",
        help="Player character class (default: mage)",
    )
    parser.add_argument(
        "--weapons",
        type=str,
        default="icespear,tornado",
        help="Comma-separated list of active weapons (default: icespear,tornado)",
    )
    parser.add_argument(
        "--minutes",
        type=int,
        default=20,
        help="Simulation run duration in minutes (default: 20)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results in JSON format.",
    )

    args = parser.parse_args()

    weapon_list = [w.strip() for w in args.weapons.split(",") if w.strip()]
    result = simulate_run(
        difficulty=args.difficulty,
        character=args.character,
        weapons=weapon_list,
        total_minutes=args.minutes,
    )

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print_ascii_table(result)

    sys.exit(0)


if __name__ == "__main__":
    main()
