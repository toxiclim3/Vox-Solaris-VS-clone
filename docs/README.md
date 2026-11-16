# Inritus Documentation & Technical Analyses Index

This directory stores game design proposals, mathematical simulations, engine benchmarks, and architectural audits generated across development and multi-agent reviews.

## 1. Core Living Project Documents
- [**`design_guidelines.md`**](./design_guidelines.md) — Authoritative design specifications, stat budgets, and balance rules (`res://docs/design_guidelines.md`).
- [**`tech_debt.md`**](./tech_debt.md) — Central tracker for known visual quirks, deferred fixes, and engine limitations (`res://docs/tech_debt.md`).
- [**`todo.md`**](./todo.md) — Active feature backlog, stage/map roadmap, and unconventional variance notes (`res://docs/todo.md`).

## 2. Game Design & Variance Proposals
- [**`game_design_variance_proposal.md`**](./game_design_variance_proposal.md) — Master Game Design & Run Variance Proposal (Draft Agency: Reroll/Banish, Tier 4 Weapon Overclocks, Cursed Relics, Arena Anomalies, Boss Mutation Contracts, and 2-Phase Implementation Roadmap).
- [**`design_guidelines_evolution_plan_v2.md`**](./design_guidelines_evolution_plan_v2.md) — Evolution plan for the v2 Balance Framework (Proc Coefficients, Cooldown Safety Floor, Decentralized `health_ratio_changed` Signal Pattern, Terraria-Style ICDs, Enemy Tenacity, and "The Punished" resolution).
- [**`debug_system_expansion_plan.md`**](./debug_system_expansion_plan.md) — Multi-perspective architectural plan to expand the developer/designer debugging suite (Hold-to-Peek / Tap-to-Pin Quick Drawer, Unified Build & Sandbox Workbench, Live Per-Weapon DPS & Telemetry HUD, and `SwarmManager` / Rule 16–17 Collision Visualizer).
- [**`testing_levels_and_utilities_plan.md`**](./testing_levels_and_utilities_plan.md) — Multi-perspective plan for dedicated fast-loading test rooms (`res://Tools/TestRooms/`) with room-specific hotkeys (`F5` Switcher, Texture/Animation/Shader Gallery, Combat Proving Ground, Boss/Swarm Stress Lab, and UI/Localization/Audio Soundboard).

## 3. Mathematical Models & Engine Benchmarks
- [**`monte_carlo_draft_and_scaling_math.md`**](./monte_carlo_draft_and_scaling_math.md) — 10,000-run Monte Carlo draft simulation quantifying Tier 4 acquisition probabilities (with and without Reroll/Banish), derivative collapse at Minute 3:00 ($dI/dt: 4.5 \to 1.5$), and effective combinatorial loadout counts.
- [**`combat_multimesh_benchmarks_and_mitigations.md`**](./combat_multimesh_benchmarks_and_mitigations.md) — Headless Godot MultiMesh stress benchmarks ($N=3,000$ units at $0.904\text{ ms/frame}$) and 4 critical combat/collision mitigations (Leyline Rift separation dampening, dual-layer hazard routing for Player Layer 2 vs. Swarm Layer 3, Dr. Franklin detached telegraph cleanup, and Ancient Amoeba `DISSOLVING` timing).

## 4. Implementation Guardrails & Architectural Audits
- [**`phase1_adversarial_edge_case_audit.md`**](./phase1_adversarial_edge_case_audit.md) — Adversarial code-level review uncovering 5 concrete edge cases when implementing Tier 4 Overclocks and Cursed Relics (`player.gd:735` `.rstrip("0123456789")` failing on `_b` suffixes, `gui.gd` weapon slot duplication when `displayname` differs, `player.gd:845` AND-lockout on endless prerequisites, and `SwarmManager` instance color resets).
- [**`phase2_engine_integration_guardrails.md`**](./phase2_engine_integration_guardrails.md) — Technical integration audit for Phase 1 & Phase 2 mechanics against `player.gd`, `gui.gd`, `upgrade_db.gd`, and `swarm_manager.gd`.
- [**`lightning_rod_and_diorama_analysis.md`**](./lightning_rod_and_diorama_analysis.md) — Root-cause analysis and verification report for the Lightning Rod freed-instance/coordinate-space bug, "The Punished" implementation, and the Promotional Diorama Studio (`Tools/Diorama/`).

## 5. Deep-Dive Survey Reports
- [**`survey_r1_progression_and_draft_bottlenecks.md`**](./survey_r1_progression_and_draft_bottlenecks.md) — Survey of current progression, `StatsManager` disconnection, `UpgradeDb` pool dilution, and weapon/item architectural patterns.
- [**`survey_r2_variance_mechanics_deep_dive.md`**](./survey_r2_variance_mechanics_deep_dive.md) — Deep dive into candidate variance mechanics, exact GDScript snippets, and mathematical impact tables.
- [**`survey_r3_engine_and_yagni_feasibility.md`**](./survey_r3_engine_and_yagni_feasibility.md) — Godot 4.6 engine constraints, `SwarmManager` collision rules, and Rule 19 (YAGNI) compliance matrix.

## 6. Root-Level Repository Metadata
- [**`../README.md`**](../README.md) — Repository overview, architecture map, and CLI test commands.
- [**`../ATTRIBUTION.md`**](../ATTRIBUTION.md) — GPL-3.0 licensing, audio/font attributions, and placeholder asset notices.
- [**`../GEMINI.md`**](../GEMINI.md) — AI agent context and rules.
