#!/usr/bin/env python3
"""Runs desktop-power-policy's real apply() logic against fake sysfs trees (no root, no hardware)."""
import importlib.util, os, sys, tempfile

src = open(sys.argv[1]).read().replace("@USER_HOME@", "/nonexistent")
tmp = tempfile.mkdtemp()
mod_path = os.path.join(tmp, "policy.py"); open(mod_path, "w").write(src)
spec = importlib.util.spec_from_file_location("policy", mod_path)
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

def tree(files):
    root = tempfile.mkdtemp()
    for rel, val in files.items():
        p = os.path.join(root, rel); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, "w").write(val)
    return root
def rd(root, rel): return open(os.path.join(root, rel)).read().strip()

def run(root, desktop=True, on_battery=True, gamezone=None):
    m.CPU = os.path.join(root, "cpu"); m.GPU_LEVEL = os.path.join(root, "gpu_level")
    m.STATE = os.path.join(root, "state.json"); m.gamezone_dir = lambda: gamezone
    m.DISABLED = os.path.join(root, "disabled"); m.log = lambda *a: None
    p = object.__new__(m.Policy); p.desktop = desktop; p.on_battery = on_battery
    p.apply("test")

# 1. AMD / Legion-like: per-policy boost + EPP + global boost + Lenovo profile
amd = tree({"cpu/cpu0/cpufreq/energy_performance_preference": "balance_power", "cpu/cpu0/cpufreq/boost": "0",
            "cpu/cpu1/cpufreq/energy_performance_preference": "power", "cpu/cpu1/cpufreq/boost": "0",
            "cpu/cpufreq/boost": "0", "cpu/smt/control": "off", "gpu_level": "low", "gz/profile": "custom"})
run(amd, gamezone=os.path.join(amd, "gz"))
assert rd(amd, "gz/profile") == "balanced"
assert rd(amd, "cpu/cpu0/cpufreq/energy_performance_preference") == "balance_performance"
assert rd(amd, "cpu/cpu1/cpufreq/boost") == "1" and rd(amd, "cpu/cpufreq/boost") == "1"
assert rd(amd, "cpu/smt/control") == "on" and rd(amd, "gpu_level") == "auto"
run(amd, on_battery=False, gamezone=os.path.join(amd, "gz"))
assert rd(amd, "gz/profile") == "performance"                     # AC transition

# 2. Intel-like: intel_pstate no_turbo, EPP, no Lenovo profile, no per-policy boost
intel = tree({"cpu/cpu0/cpufreq/energy_performance_preference": "power", "cpu/intel_pstate/no_turbo": "1"})
run(intel)
assert rd(intel, "cpu/intel_pstate/no_turbo") == "0"
assert rd(intel, "cpu/cpu0/cpufreq/energy_performance_preference") == "balance_performance"

# 3. Gaming Mode (not desktop): nothing is written
gm = tree({"cpu/cpu0/cpufreq/boost": "0", "cpu/intel_pstate/no_turbo": "1"})
run(gm, desktop=False)
assert rd(gm, "cpu/cpu0/cpufreq/boost") == "0" and rd(gm, "cpu/intel_pstate/no_turbo") == "1"

# 4. dynamic scaling preserved: governor and max frequency are never touched
gv = tree({"cpu/cpu0/cpufreq/scaling_governor": "powersave", "cpu/cpu0/cpufreq/scaling_max_freq": "3300000", "cpu/cpu0/cpufreq/boost": "1"})
run(gv)
assert rd(gv, "cpu/cpu0/cpufreq/scaling_governor") == "powersave" and rd(gv, "cpu/cpu0/cpufreq/scaling_max_freq") == "3300000"
print("ok")
