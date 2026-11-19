# Inritus Documentation Index

Unified documentation for **Inritus** (Godot 4.6), grouped by topic with conflicts resolved in favor of the latest active specifications.

## 1. Core Architecture & Living Ledgers
- [**`design_guidelines.md`**](./design_guidelines.md) — Authoritative character profiles ("One Core Scaling Passive" Law, The Punished spec), item classification & endless scaling rules, combat formulas (armor DR, `0.05s` cooldown floor, proc coefficients, Terraria-inspired 4-tier ICDs, decentralized `health_ratio_changed` health items, enemy tenacity), and engine/schema contracts (`Layer 3`, `CircleShape2D`/`RectangleShape2D`, `test_upgrade_db.gd` invariants).
- [**`tech_debt.md`**](./tech_debt.md) — Living ledger of known visual quirks, mathematical discontinuities, active metadata bugs, resolved issues (Lightning Rod transform/freed guards, `StatsManager` I/O deferral, `translations.csv` row normalization), and engine workarounds.
- [**`todo.md`**](./todo.md) — Active feature backlog, completed milestones, long-term roadmap, and QA checklist pointers.

## 2. Gameplay, Movement & Meta-Progression Design
- [**`movement_combat_ponderings.md`**](./movement_combat_ponderings.md) — Movement-coupled combat design (player speed compression, zero-inertia Layer 1 kinematic substrate, Layer 2 `Spacebar` `mobility_type` abilities, `movement_group` taxonomy, weapon/passive rebalance matrices, graphic badges & vertical cards with Simplified Descriptions toggle), plus empirical run progression/draft diagnostics (10,000-run Monte Carlo metrics) and curated future variance pillars.
- [**`gacha_system_plan.md`**](./gacha_system_plan.md) — Meta-progression architecture and alternative concepts: **Part I** covers the newer Boss-Ticket Gacha System plan (lightweight YAGNI core + intentional powercreep/design-creep expansions), while **Part II** preserves non-gacha alternatives (*Walkable Hub World* setup and *The Vault of Inritus & Covenants of Agony*).

## 3. Performance & Optimization
- [**`swarm_optimization.md`**](./swarm_optimization.md) — MultiMesh swarm architecture (`SwarmManager` + `EnemySpawner`), empirical headless Godot 4.6 benchmarks (`0.904 ms/frame` for 3,000 units, `6.193 ms` separation spike under tight compression, `O(N)` spatial-grid fallback rules), further GDScript/GPU optimization strategies, and Flow Field + Grid SDF pathfinding design for walled maps.

## 4. Developer Tooling & Testing
- [**`debug_and_testing_suite.md`**](./debug_and_testing_suite.md) — Unified specification and QA status for the In-Run Debugging Suite (`res://Utility/Debug/`: `Tab` Quick Drawer, `F1` Workbench, `F2` Telemetry & DPS HUD, `F3` Swarm/Layer-3 Hitbox Visualizer, `F4`/`Mouse5` Freeze & `.` Step), Dedicated Testing Rooms (`res://Tools/TestRooms/` + `F5` Switcher + `DioramaStudio`), and the active Nov 17 QA polish backlog.

## 5. Root-Level Repository Metadata
- [**`../README.md`**](../README.md) — Repository overview, setup, and test runner commands.
- [**`../ATTRIBUTION.md`**](../ATTRIBUTION.md) — GPL-3.0 licensing, audio/font attributions, and placeholder asset notices.
- [**`../GEMINI.md`**](../GEMINI.md) — AI agent context, architecture overview, and project rules.
