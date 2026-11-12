## 2026-10-06T19:17:39Z
Your role: Skills and Localization Worker
Your working directory: d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\worker_m3
Original request path: d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\ORIGINAL_REQUEST.md

You MUST read ORIGINAL_REQUEST.md before starting work.

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Exclusive file ownership:
You exclusively own:
- `.agents/skills/*`
- `translations/translations.csv`

Reference survey report:
`d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\explorer_survey_3\survey_report.md`
`d:\Школа\Сезон 6\Group project\Vampire survivors clone 100%\.agents\teamwork\explorer_survey_3\handoff.md`

Objectives for Milestone 3 (R3):
1. Author 4 Antigravity skills in `.agents/skills/` following standard `SKILL.md` format with YAML frontmatter:
   - `.agents/skills/weapon-scaffolder/SKILL.md`: Guides creating compliant weapons with Layer 3 (value 4), CollisionShape2D child node, PhasedAnimator standard for AOE, and 5-tier UpgradeDb registration. Include scaffold templates or generator script.
   - `.agents/skills/localization-validator/SKILL.md`: Guides validating translations. Include Python CLI script `.agents/skills/localization-validator/validate_translations.py` validating CSV columns, missing keys, untranslated entries.
   - `.agents/skills/tech-debt-auditor/SKILL.md`: Guides systematic checks of codebase and synchronizing `tech_debt.md`.
   - `.agents/skills/game-balance-eval/SKILL.md`: Guides balance evaluation. Include Python CLI script `.agents/skills/game-balance-eval/balance_eval.py` modeling player DPS vs enemy/boss HP scaling.
   Include SPDX license headers on Python scripts.
2. Fix `translations/translations.csv`:
   - Fix line 30 column mismatch: `"ui_gameTitle","Inritus","Inritus","Inritus"`.
   - Add missing `"lang_ukrainian"` key (`"lang_ukrainian","Ukrainian","Украинский","Українська"`).
   - Ensure formatting is intact.
3. Run the localization validator CLI script against `translations/translations.csv` using Python 3 and verify that it reports clean status with return code 0!
4. Run `balance_eval.py` using Python 3 and verify clean execution!
5. Write comprehensive handoff report to `.agents/teamwork/worker_m3/handoff.md` and send completion message.
