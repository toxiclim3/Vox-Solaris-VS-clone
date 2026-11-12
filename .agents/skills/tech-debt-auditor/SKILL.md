---
name: tech-debt-auditor
description: Guides systematic audits of technical debt, deferred visual quirks, engine limitations, and synchronization of tech_debt.md in accordance with Rule 10 and the YAGNI principle.
---

# Tech Debt Auditor Skill

## Overview
The `tech-debt-auditor` skill establishes a standardized workflow for identifying, evaluating, cataloging, and synchronizing technical debt in the SurvivorsClone project. 

In game development, attempting to prematurely eliminate every minor visual quirk or architectural edge case often introduces speculative complexity, breaks fragile third-party integrations, or wastes development cycles on non-critical paths. This skill enforces **Rule 10 (Technical Debt Accountability)** and the **YAGNI (You Aren't Gonna Need It)** principle:
- If a fix carries prohibitive complexity or risk of regression, the rationale must be documented transparently in `tech_debt.md`.
- No speculative refactoring or premature abstractions are permitted.
- `tech_debt.md` is treated as a first-class living architectural ledger.

## Standard `tech_debt.md` Schema
Every entry in `tech_debt.md` MUST conform to this exact 4-field markdown schema:

```markdown
### <Issue Name>
- **Status:** <Known Issue | Partially Fixed / Haunted | Partially Optimized | Deferred | Investigating | Resolved>
- **Description:** <Clear, unambiguous explanation of the technical quirk, visual artifact, or performance bottleneck>
- **Why it was deferred:** <Concrete rationale explaining why an immediate fix is prohibitive, architectural trade-offs, or Godot engine constraints>
- **Current Mitigation:** <Workarounds or safeguards currently implemented in production>
```

Categorize issues into one of the top-level sections:
- `## Visual & Rendering` (e.g., Line2D subpixel scaling, sprite clipping, particle artifacts)
- `## UI & Navigation` (e.g., controller focus trapping, layout anchoring, font rendering)
- `## Performance & Loading` (e.g., scene transition freezes, physics bottlenecks, garbage collection spikes)
- `## Architecture & System Coupling` (e.g., hardcoded dispatch lists, curve discontinuities)

## Triggers & When to Use
Invoke this skill when:
- Reviewing an issue or visual glitch that cannot be solved simply without major structural rework.
- Conducting pre-milestone codebase health inspections.
- Introducing a temporary workaround, hack, or fallback in engine code.
- Resolving a previously documented technical debt item (to update status to `Resolved`).

## Step-by-Step Audit Workflow

### Step 1: Scan for Latent Technical Debt & Warnings
Run targeted static searches across the GDScript and scene codebase for markers:
```bash
# Search for markers in code:
python -c "import os, re; [print(f'{root}/{f}:{i+1}: {line.strip()}') for root, _, files in os.walk('.') if not any(x in root for x in ['.git', '.agents', '.godot']) for f in files if f.endswith('.gd') for i, line in enumerate(open(os.path.join(root, f), encoding='utf-8', errors='ignore')) if any(k in line for k in ['TODO', 'FIXME', 'HACK', 'WORKAROUND', 'push_warning'])]"
```

### Step 2: Apply the YAGNI & Rule 10 Filter
Evaluate each identified issue using this decision matrix:
1. **Can it be fixed safely within the minimal-change principle (< 20 lines)?**
   - YES $\implies$ Fix it immediately and test.
   - NO $\implies$ Proceed to step 2.
2. **Does the issue break core gameplay, cause crashes, or corrupt saved data?**
   - YES $\implies$ Prioritize dedicated architectural task.
   - NO $\implies$ Defer it in accordance with YAGNI.
3. **Formulate the Deferral Rationale**:
   - Document exactly *why* a fix was deferred (e.g., "Attempting custom Line2D antialiasing shaders caused 40% fillrate degradation on integrated GPUs").
   - Document the current mitigation (e.g., "Clamped line width to integer values").

### Step 3: Synchronize `tech_debt.md`
Edit `tech_debt.md`:
- Place the issue under the matching categorical section.
- Ensure all 4 fields (`Status`, `Description`, `Why it was deferred`, `Current Mitigation`) are fully populated.
- If an existing entry has been solved by recent changes, update its `Status` to `Resolved` and reference the version or commit.

### Step 4: Validate Formatting & Layout
Ensure `tech_debt.md` remains clean, strictly formatted, and free of extraneous comments.

## Verification & Acceptance Checklist
- [ ] Every entry in `tech_debt.md` follows the 4-field specification.
- [ ] No speculative abstractions were introduced into source code to "fix" deferred quirks.
- [ ] All known engine quirks identified during audits are cataloged.
- [ ] Status updates accurately reflect the current state of the codebase.
