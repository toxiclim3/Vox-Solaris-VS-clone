---
name: game-balance-eval
description: Simulates, models, and evaluates weapon DPS, enemy health scaling, wave density, and boss encounter pacing across run timelines and difficulty tiers.
---

# Game Balance Evaluation Skill

## Overview
The `game-balance-eval` skill provides mathematical modeling and automated simulation tools to analyze game balance in SurvivorsClone. As runs progress, enemy health and wave density escalate polynomially while boss HP increases exponentially. This skill ensures that player DPS curves maintain engaging encounter pacing without causing unintended difficulty spikes or unkillable "bullet sponge" bosses.

## Mathematical Models & Mechanics

### 1. Difficulty Scaling (`GlobalEvents.gd`)
The game supports three baseline difficulty tiers affecting global modifiers:
| Parameter | Easy | Normal | Hard |
|---|---|---|---|
| Enemy HP Mod | 0.8 | 1.0 | 1.2 |
| Boss HP Mod | 0.8 | 1.0 | 1.2 |
| Spawn Intensity Mod | 0.8 | 1.0 | 1.2 |
| XP Gain Mod | 1.2 | 1.0 | 0.8 |
| Player Regen Mod | 1.5 | 1.0 | 1.0 |
| Weapon Slots | 6 | 6 | 5 |
| Passive Slots | 8 | 8 | 6 |

### 2. Boss Health Progression (`enemy_spawner.gd`)
Boss health scales exponentially with elapsed run time $t$ in minutes ($t = \text{time} / 60.0$):
$$\text{Boss HP}(t) = \text{Base HP} \times (1.05)^t \times \text{Difficulty Boss HP Mod}$$
With Base HP = 500:
- **Minute 5 (First Boss)**: $500 \times 1.05^5 \approx 638 \text{ HP (Normal)}$, $766 \text{ HP (Hard)}$
- **Minute 10 (Second Boss)**: $500 \times 1.05^{10} \approx 814 \text{ HP (Normal)}$, $977 \text{ HP (Hard)}$
- **Minute 15**: $500 \times 1.05^{15} \approx 1039 \text{ HP (Normal)}$, $1247 \text{ HP (Hard)}$
- **Minute 20**: $500 \times 1.05^{20} \approx 1327 \text{ HP (Normal)}$, $1592 \text{ HP (Hard)}$

### 3. Wave Spawn Intensity (`enemy_spawner.gd`)
$$\text{Intensity}(t) = \begin{cases}
3.0 & t \le 1.0 \\
3.0 + 0.75 t^2 & 1.0 < t \le 3.0 \\
4.5 + 1.5 t & t > 3.0
\end{cases}$$

### 4. Player Damage Formulas (`player.gd`)
- **Armor Damage Reduction**: $\text{DR} = \frac{\text{armor}}{\text{armor} + 40.0}$
- **Cooldown**: $t_{\text{cooldown}} = t_{\text{base}} \times (1.0 - \text{spell\_cooldown})$
- **Burst Ammo**: $\text{ammo} = \text{base\_ammo} + \lfloor\text{additional\_attacks}\rfloor + \text{Bernoulli}(\text{frac})$

## Step-by-Step Simulation Workflow

### Step 1: Run Baseline Run Simulation
Run the simulation CLI tool across a standard 20-minute run:
```bash
python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal --character mage --weapons icespear,tornado
```

### Step 2: Evaluate Time-to-Kill (TTK) Metrics
Inspect the generated table:
- **Boss TTK**: The sustained single-target time required to defeat the boss.
  - Target: $10\text{s} - 30\text{s}$ under typical gear progression.
  - Alert: If Boss TTK exceeds $60\text{s}$, the boss is flagged as a "bullet sponge".
- **Overwhelm Ratio**: Ratio of incoming spawned enemy HP per second to player cleave DPS.
  - $< 1.0\text{x}$: Player comfortably clears waves.
  - $1.0\text{x} - 2.5\text{x}$: Challenging horde pressure requiring movement and kite routing.
  - $> 3.0\text{x}$: Severe swarm overwhelm risk unless player utilizes area bottlenecks or burst nukes.

### Step 3: Hard Mode Stress Testing
Evaluate worst-case progression with reduced XP gain (0.8x) and higher health pools (1.2x):
```bash
python .agents/skills/game-balance-eval/balance_eval.py --difficulty hard --character punished --weapons whip,vampireknives
```

### Step 4: Machine-Readable CI Output
To integrate into automated balance checks, output structured JSON:
```bash
python .agents/skills/game-balance-eval/balance_eval.py --difficulty normal --json
```

## Verification & Acceptance Checklist
- [ ] `balance_eval.py` executes cleanly and returns exit code `0`.
- [ ] Boss HP calculations match `GlobalEvents` and `enemy_spawner.gd` formulas.
- [ ] No unexplained TTK spikes under standard weapon builds.
- [ ] JSON output is valid RFC 8259 JSON.
