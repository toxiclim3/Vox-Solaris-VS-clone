import subprocess
import sys

commands = [
    ["godot", "--headless", "-s", "addons/gut/gut_cmdln.gd"],
    ["python", ".agents/skills/localization-validator/validate_translations.py"],
    ["python", ".agents/skills/game-balance-eval/balance_eval.py", "--difficulty", "normal"],
    ["godot", "--headless", "-s", "res://Tests/test_runner.gd"]
]

all_passed = True

for cmd in commands:
    cmd_str = " ".join(cmd)
    print(f"==================================================")
    print(f"RUNNING: {cmd_str}")
    print(f"==================================================")
    res = subprocess.run(cmd, capture_output=True, text=True)
    print(res.stdout)
    if res.stderr:
        print("STDERR:\n" + res.stderr)
    print(f"EXIT CODE: {res.returncode}")
    if res.returncode != 0:
        print(f"FAILED: {cmd_str}")
        all_passed = False
        break
    print(f"PASSED: {cmd_str}\n")

if all_passed:
    print("ALL ACCEPTANCE COMMANDS COMPLETED WITH EXIT CODE 0!")
    sys.exit(0)
else:
    print("ONE OR MORE COMMANDS FAILED!")
    sys.exit(1)
