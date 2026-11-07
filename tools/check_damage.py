"""Check AK-47 point-blank damage against the generated script stats."""

import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..", "lua")
STATS = os.path.join(ROOT, "css_weapons", "sh_stats.lua")
BEHAVIOR = os.path.join(ROOT, "css_weapons", "sh_behavior.lua")


def block(text, name):
    match = re.search(rf"\t{name} = \{{(.*?)\n\t\}},", text, re.S)
    if not match:
        raise SystemExit(f"missing {name}")
    return match.group(1)


def num(block_text, key):
    match = re.search(rf"\t{key} = ([0-9.]+)", block_text)
    if not match:
        raise SystemExit(f"missing {key}")
    return float(match.group(1))


def main():
    stats = open(STATS, encoding="utf-8").read()
    behavior = open(BEHAVIOR, encoding="utf-8").read()
    ak = block(stats, "ak47")
    damage = num(ak, "Damage")
    cycle = num(ak, "CycleTime")
    stand = num(ak, "InaccuracyStand")
    range_mod = num(ak, "RangeModifier")
    if damage != 36 or cycle != 0.1 or stand != 0.00916 or range_mod != 0.98:
        raise SystemExit(f"AK stats drifted: {damage} {cycle} {stand} {range_mod}")

    chest = damage * 1
    head = damage * 4
    at_500 = damage * (range_mod ** (500 / 500))
    armored = chest * 0.5
    if chest != 36 or head != 144 or abs(at_500 - 35.28) > 0.001 or armored != 18:
        raise SystemExit(f"damage math failed: {chest} {head} {at_500} {armored}")

    stat_ids = re.findall(r"\n\t([a-z0-9]+) = \{", stats)
    behavior_ids = re.findall(r"\n\t([a-z0-9]+) = \{", behavior)
    missing = [name for name in stat_ids if name not in behavior_ids]
    if missing:
        raise SystemExit("no behavior for " + ", ".join(missing))
    print(f"AK-47 point-blank chest {chest:g}, head {head:g}, 500 units {at_500:g}, armored chest {armored:g}")
    print(f"{len(stat_ids)} guns")


if __name__ == "__main__":
    main()
