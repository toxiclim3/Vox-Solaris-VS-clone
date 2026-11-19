# Inritus — Meta-Progression Plans & Alternative Concepts

> **Status:** Planned (Not yet implemented)  
> **Target Engine:** Godot 4.6  
> **Core Constraints:** `NinePatchUI.tres` theme consistency (Rule 6), 3-language localization in `translations.csv` (Rule 5), `StatsManager` taint-awareness (`is_run_tainted`).

> [!NOTE]
> This document preserves **Part I: The Gacha System Plan (Nov 17, newer)**—including both its lightweight YAGNI core (Sections 1–5) and intentional powercreep/design-creep expansions (Sections 6–7)—alongside **Part II: Alternative Non-Gacha Meta-Progression & Hub Concepts** ("Walkable Hub World" from `todo.md` and "The Vault of Inritus & Covenants of Agony" from the Nov 14 Variance Proposal).

---

# Part I: Meta-Progression Gacha System Plan (Nov 17)

## 1. Design Summary

| Pillar | Decision |
|---|---|
| **Location** | Main Menu (`TitleScreen/menu.tscn`) as a slide-in panel alongside Play, Stats, and Settings |
| **Pull Currency** | **Boss Tickets** (working name) earned exclusively from defeating bosses |
| **Reward Pool** | **Playable Characters** (unlocking locked roster members) + **Cosmetic Skins** (color palettes via `recolor.gdshader` & optional trail tints) |
| **Persistence** | Saved locally via `ConfigFile` (`StatsManager.gd` or dedicated save section), respecting `is_run_tainted` |

---

## 2. Currency & Earning Rules

- **Source:** Awarded when a boss is defeated (`GlobalEvents.boss_defeated` / `StatsManager.register_kill(true)`).
- **Taint Protection:** No tickets are awarded if `StatsManager.is_run_tainted and not StatsManager.allow_tainted_stats` (prevents debug-menu farming).
- **Suggested Drop Rates (tunable):**
  - Standard Boss Kill: `+1 Ticket`
  - Run Victory (Final Boss): `+1 Bonus Ticket` (optional difficulty scaling: Easy `x1`, Normal `x1`, Hard `x2`)
- **UI Feedback:** Show `+X Tickets` on the Victory / Death summary panel in `Player/gui.gd` and current ticket balance in the Main Menu Gacha button/panel.

---

## 3. Data & Persistence Architecture

### Recommended Approach (Option A — Lightweight / YAGNI)
Extend existing singletons without adding a new Autoload:
1. **`Utility/StatsManager.gd`** (`user://statistics.cfg`, `[gacha]` section):
   - `gacha_tickets: int = 0`
   - `unlocked_characters: Array[String] = ["mage"]` (starter character unlocked by default)
   - `unlocked_skins: Array[String] = []`
   - `equipped_skins: Dictionary = {}` (e.g. `{"mage": "mage_crimson"}`)
   - `pity_counter: int = 0` (optional guaranteed-character pity after $N$ cosmetic pulls)
2. **`Utility/global_events.gd`**:
   - Add `"unlocked_by_default": bool` (or `"gacha_rarity": String`) metadata to `CHARACTERS` entries.
   - Add `const SKINS: Dictionary` mapping `skin_id` to `{ "character_id", "displayname", "rarity", "icon_color", "shader_config", "trail_color" }`.

### Alternate Approach (Option B — Dedicated `GachaManager` Autoload)
Create `Utility/gacha_manager.gd` with its own `user://gacha.cfg` save file.
- **When to prefer Option B:** If the system later expands to multiple rotating banners, pull history logs, or complex shard/crafting economies. For a single permanent banner, Option A avoids extra singleton boilerplate.

---

## 4. Gacha Roll & Duplicate Handling

### Pool Structure & Rates
- **SSR / Mythic Tier (0.1% base rate):** Banner-exclusive characters & broken weapons.
- **SR Tier (0.9% base rate):** Awakened stat-stick skins and standard characters.
- **Common / Trash Tier (99.0% base rate):** Minor palette tints, redundant stickers, and filler XP-gem recolors.
- **Pity Rule ("Duplicates Galore"):** Pity triggers only at **320 pulls** and guarantees *any* SSR in the pool—**including ones you already own**. Getting a duplicate at pity resets the counter anyway.

### Anti-Consumer Duplicate Handling
No knockout pool—duplicates are the core experience:
1. **Unmaxed Duplicates (1–6):** Feed into the character/skin's Limit Break track (you need 7 total copies to max a single SSR).
2. **Overflow Duplicates (7+):**
   - **Common / Rare Dupes:** Convert into **0.01 Starlight Dust** (100 duplicate commons = 1/10th of a single pull) and display a cheerful *"Better luck next time!"* popup.
   - **SSR Dupes:** Refund **5% of a pull** in Void Shards, which expire if not spent before the banner rotates.
3. **Dark-Pattern Safeguards:**
   - **No Pity Carryover:** Each banner has its own isolated pity counter that hard-resets to `0` when the banner ends.
   - **No 10-Pull Discount:** Pulling 10x costs 10x tickets and only guarantees a single Common-or-higher item (i.e., guarantees nothing).

---

## 5. Integration Points

### A. Main Menu (`TitleScreen/menu.tscn` & `menu.gd`)
- Add `btn_gacha` to the main menu button stack (showing current ticket count badge if `> 0`).
- Add `GachaMenu` panel (`TitleScreen/gacha_menu.tscn` + `gacha_menu.gd`) using `NinePatchUI.tres`, sliding in/out with the same `Tween` pattern as `StatsMenu` and `PlayMenu`.
- **Gacha Panel UI:**
  - Current Ticket balance & Pull x1 (and optional Pull x5) buttons.
  - Simple reveal animation (card flip / glow / sound effect) showing the pulled character or skin + rarity.
  - Pool preview / collection progress (`X / Y Unlocked`).
  - Explicit `focus_neighbors` and `ui_cancel` handling (Rule 14).

### B. Character Select (`TitleScreen/play_menu.gd`)
- In `_setup_character_grid()`:
  - Check `StatsManager.is_character_unlocked(char_id)`.
  - If locked: dim the sprite, overlay a lock icon, and disable starting a run with that character (show `"UNLOCK_IN_GACHA"` translation key in `label_char_details`).
- Add a **Skin / Palette Selector** (`<` / `>` buttons or small swatch row) below or beside the selected character to cycle through `default` + unlocked skins for that `char_id`, saving selection to `StatsManager.equipped_skins[char_id]`.

### C. In-Game Player (`Player/player.gd`)
- When applying character visuals (`recolor.gdshader`), check if `StatsManager.equipped_skins` has an active skin for `GlobalEvents.selected_character`:
  - Override `icon_color` (`target_color`) and `shader_config` with the skin's values.
  - If trail cosmetics are included, tint or enable the player's movement trail node accordingly.

### D. Localization (`translations.csv`)
Add EN, RU, and UA entries for:
- Menu button & panel title (`MENU_GACHA`, `GACHA_TITLE`)
- Currency & pull buttons (`GACHA_TICKETS`, `GACHA_PULL_1`, `GACHA_NO_TICKETS`)
- Status & lock messages (`GACHA_LOCKED_CHAR`, `GACHA_NEW_UNLOCK`, `GACHA_ALL_UNLOCKED`)
- Skin names (`skin_*`)

---

## 6. Massive Powercreep Expansion (Intentional Vertical Bloat)

> [!WARNING]
> This section intentionally breaks `docs/design_guidelines.md` ("Horizontal Diversity over Vertical Bloat") in favor of classic gacha power escalation.

### A. Rarity Tiers & Stat Multiplication
- **Common (C) / Rare (R):** Standard cosmetic palettes and minor flat stat charms (`+5 HP`, `+2% Move Speed`).
- **Super Rare (SR):** Awakened skins that also grant passive starting bonuses (`+15% Might`, `+1 Projectile`, `-10% Cooldown`).
- **Super Super Rare (SSR) / Mythic (UR):**
  - **Account-Wide Global Passives:** Simply *owning* an SSR/UR character applies permanent, stacked passive buffs to **every character on your account**, even when playing someone else (e.g., owning *Chronos Mage* grants `+35% All Damage` + `+1 Free Revive` globally; owning *Void Doctor* grants `+50% Boss Damage` and `+20% Lifesteal` across all runs—and each Limit Break doubles the global passive).
  - **Banner-Exclusive Characters** with uncapped or double/triple scaling passives (e.g., `+100% Area` + `+50% Cooldown Reduction` + built-in revive).
  - **Gacha-Exclusive Overpowered Weapons** unlocked directly into Level 1 starting loadouts (bypassing standard `UpgradeDb` prerequisites).
  - **Stat-Stick Cosmetics:** Skins and trails now carry massive multiplicative stats (e.g., `"Cosmic Trail": +30% XP Gain, +25% Crit/Damage, +2 Pierce`), making default skins strictly obsolete.

### B. Duplicate Merging ("Constellations / Limit Breaks")
Instead of a knockout pool, duplicates feed a **6-Stage Limit Break** per character and skin:
- **Dupes 1–5:** Exponentially scale base stats (`+20%` → `+50%` → `+100%` → `+200%` all damage/HP) and unlock broken passive overrides (e.g., "Projectiles split into 3 on hit", "Bosses take +50% bonus damage").
- **Dupe 6+ (Overflow):** Converts into **Astral Cores** used to uncapped-level a global **Power Altar** (`+5% All Stats` per level, infinite levels).

### C. Character Design & Banner Release Cadence
- **Asymmetrical Maximalism:** Limited SSR/UR female characters follow peak gacha over-design: floating halos, 14 unnecessary belts, mismatched thigh-highs, giant glowing weapon-umbrellas, and wildly impractical silhouettes—paired with "Summer / Bunny / Wedding" seasonal skin variants that somehow have *higher* combat stats than full plate armor. *(Implementation note: since 2D pixel sprites are tiny, most of the absurdity lives in the UI portrait/splash-art slots and particle aura overkill.)*
- **The 1-Guy-Per-Year Quota:**
  - **Female Roster:** 90%+ of Limited SSR/UR banners, receiving all the broken Global Passives, seasonal alt skins, and meta-defining kits.
  - **Male Roster:** Exactly **1 character per year**, either relegated to an SR support on someone else's banner or released as a "niche" SSR that gets powercrept two weeks later.

---

## 7. Design Creep Expansion (Feature & System Bloat)

> [!WARNING]
> This section intentionally breaks Rule 19 (YAGNI) by layering interlocking meta-systems on top of the core Vampire Survivors loop.

### A. Multi-Currency Economy (3+ Currencies)
1. **Boss Tickets:** Earned from boss kills (used on the Standard Banner).
2. **Void Shards:** Earned from dismantling duplicate gear/relics or Hard-mode wins (used in the Shard Shop or converted at 10:1 into Premium Pulls).
3. **Starlight Dust:** Earned from daily/weekly quests and pity overflow (used to craft guaranteed SSR selectors).

### B. Multiple Rotating Banners & Pity Ladders
- **Standard Banner:** Permanent pool of base characters & skins.
- **Limited Rate-Up Banner:** Time-gated (or run-count-gated) banner featuring a single busted SSR character with a **25/75 coin-flip at 160 pulls** and a **hard guarantee at 320 pulls**—with **zero pity carryover** when the banner rotates.
- **Weapon / Relic Banner:** Separate pity counter for stat-stick relics and starting weapons.

### C. RNG Relic / Artifact Equipping System
- Pullable **Relic Slots** (4 slots per character: Crown, Ring, Tome, Cloak) with **Rarity + RNG Substats** (e.g., `+8.4% Cooldown`, `+12.1% Might`, `+3 Armor`) that can be **upgraded/rerolled** using Boss Tickets & Void Shards.

### D. Extra Meta-Loop Subsystems
- **Daily / Weekly Bounty Board:** Tracked in `StatsManager` ("Kill 500 enemies with Whip", "Clear 3 runs without taking damage") awarding pull currencies.
- **Idle Dispatch / Expeditions:** Send unused characters on timed background missions (while you do runs or based on system clock) to farm passive tickets and upgrade materials.
- **Collection Codex & Milestone Ladder:** A 50-tier meta-progression track granting permanent stat multipliers and free pulls just for owning more stuff.

---

## 8. Suggested Implementation Phases

1. **Phase 1 — Data & Currency:** Add `[gacha]` state (multi-currency, limit breaks, relics, pity counters) to `StatsManager.gd`, hook boss-kill ticket awards (with taint check), and define `SKINS`, `BANNERS`, and `RELICS` in `GlobalEvents.gd`.
2. **Phase 2 — Play Menu & Player Skinning:** Gate locked characters in `play_menu.gd`, add skin + relic loadout UI, and apply equipped skins, limit-break multipliers, and relic stats in `player.gd`.
3. **Phase 3 — Gacha UI & Roll Logic:** Build `gacha_menu.tscn` / `gacha_menu.gd` with banner tabs, pull x1/x10, 50/50 pity tracking, reveal animations/SFX, and update `translations.csv`.
4. **Phase 4 — Meta-Subsystems:** Add Bounty Board, Limit Break merging screen, Relic reroll/upgrade UI, and Collection Codex.
5. **Phase 5 — Verification:** Test taint-free boss kills awarding tickets, save/load persistence across restarts, controller/keyboard focus navigation, and all 3 languages.


---

# Part II: Alternative Non-Gacha Meta-Progression & Hub Concepts

If the project chooses a non-gacha meta-progression path aligned with strict Rule 19 (YAGNI) and *Risk of Rain*-style horizontal design, the following two alternative concepts remain preserved for evaluation:

## Alternative Concept A: Walkable Hub World Pre-Run Setup (EtG / Soul Knight Style)

> Source: [`docs/todo.md`](todo.md)

* **Concept:** Replace starting runs directly from the Title Screen `PlayMenu` with an interactive physical hub area (*Enter the Gungeon* / *Soul Knight* style).
* **Loop & Stations:**
  * Players spawn inside a safe sanctuary room and physically walk to designated stations to switch characters, equip unlocked alternate starting weapons or cosmetic loadouts, review the Item Gallery/Codex, and configure difficulty/covenant shrines.
  * Entering a run occurs by walking into the arena/dungeon entrance portal rather than clicking a UI `"New Run"` button.

---

## Alternative Concept B: "The Vault of Inritus & Covenants of Agony" (Horizontal RoR2 / Hades Model)

> Source: Nov 14 Variance Proposal & Survey R2 (`survey_r2_variance_mechanics_deep_dive.md`)

### Mathematical Rationale Against Flat Vertical Stat Shops
In a time-scaled game where wave intensity $I(t)$ ramps up to $49.5\times$ and boss HP grows exponentially ($1.05^t$), purchasing flat vertical meta-stats (`+30% Might`, `+50 HP`, `+5 Armor`) creates two simultaneous balance failures:
1. **Early-Game Collapse (Minutes 0–3):** Easy swarms have `10–20` static base HP. Permanent vertical damage/projectile boosts wipe waves off-screen before they threaten the player.
2. **Exponential Devaluation (Minutes 20–30):** Flat bonuses become mathematically negligible against $1.05^{20} = 2.65\times$ to $1.05^{30} = 4.32\times$ boss HP and high-intensity waves.

### The 3 Horizontal Pillars (Zero New Autoloads)
Stored cleanly inside `Utility/StatsManager.gd` (`user://statistics.cfg`) using a boss/elite meta-currency (**Essence of Inritus**, e.g., `50 Essence` per boss kill, `2 Essence` per elite kill, subject to `is_run_tainted` guards):

1. **Pillar 1: Pre-Run Character Mastery Loadouts (RoR2 Style):**
   * Unlock alternate `starting_weapon` choices via milestone achievements (0% vertical stat bloat; alters minute-0 gameplay feel, aligning with the Pre-Run Weapon Loadouts roadmap in [`docs/design_guidelines.md`](design_guidelines.md)):
     * *Mage:* **Frost Warden** (`icespear1`, default) vs. **Stormcaller** (`lightningrod1`).
     * *Plague Doctor:* **Toxicologist** (`poisonbottle1`, default) vs. **Blood Cultist** (`ritualcircle1`).
     * *The Punished:* **Flagellant** (`whip1`, default) vs. **Glass Executioner** (`glasslash1`).
2. **Pillar 2: Covenants of Agony (Opt-In Risk-Reward Run Modifiers):**
   * Pre-run toggles hooking directly into `GlobalEvents.custom_*_modifier` in exchange for Essence reward multipliers:
     * *Covenant of the Swarm:* Swarm spawn modifier `1.5x`, XP gain `-20%`, Essence reward `+40%`.
     * *Covenant of Frailty:* Player max HP capped at `50`, base movement speed `+15%`, Essence reward `+35%`.
     * *Covenant of Chronos:* Game clock / intensity ramps `1.33x` faster, XP pickup radius `2x`, Essence reward `+50%`.
3. **Pillar 3: Bounded Draft & Pool Unlocks (Vault Licensing):**
   * Spend Essence to unlock structural draft agency (up to 2 starting Reroll charges and 2 Banishment seals per run) and unlock exotic/boss items (e.g., `relicdrone`, `vampireknives`, `wardingbrooch`) into the general `UpgradeDb` pool.
