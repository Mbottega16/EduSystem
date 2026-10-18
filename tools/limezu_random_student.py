#!/usr/bin/env python3
"""Procedural student generator for LimeZu Character & Portrait Generator assets.

Reverse-engineers the layering and palette ramp rules from tools/limezu_chars.py
and tools/limezu_cast.json to synthesize new, aesthetically balanced student recipes
for the LimeZu pipeline (including 18x4 sheets and 72px portraits).

Usage:
    python tools/limezu_random_student.py [N] [--seed S] [--format json|summary]

Outputs valid JSON recipes ready for direct insertion into tools/limezu_cast.json.
"""
import argparse
import json
import random
import sys

SKIN_IDS = ["1", "2", "3", "4"]
SKIN_RAMPS = ["skin_deep", "skin_brown", "skin_dark", None]
EYE_IDS = ["1", "2", "3", "4", "5", "6"]
OUTFIT_IDS = ["1", "2", "3", "4", "5"]

HAIR_STYLES = [
    "1_1", "1_2", "1_3",
    "2_1", "2_2",
    "3_1", "3_2",
    "4_1", "4_2", "4_3"
]

HAIR_RAMPS = [
    "hair_black", "hair_dark", "hair_brown", "hair_auburn",
    "hair_blond", "hair_silver", "hair_white"
]

PORTRAIT_HAIR_MAP = {
    "1_1": "01_1", "1_2": "01_2", "1_3": "02_4",
    "2_1": "03_1", "2_2": "03_2",
    "3_1": "05_1", "3_2": "05_2",
    "4_1": "09_1", "4_2": "09_2", "4_3": "09_3"
}

STYLE_DESCRIPTIONS = {
    "1_1": "short parted", "1_2": "short cropped", "1_3": "spiky",
    "2_1": "neat side-part", "2_2": "curly mop",
    "3_1": "pigtails", "3_2": "braids",
    "4_1": "long straight", "4_2": "classic bob", "4_3": "messy bangs"
}

OUTFIT_DESCRIPTIONS = {
    "1": "sweater vest", "2": "casual tee", "3": "collared polo",
    "4": "cardigan", "5": "school uniform top"
}


def generate_student(name: str, rng: random.Random) -> dict:
    skin_id = rng.choice(SKIN_IDS)
    skin_ramp = rng.choice(SKIN_RAMPS)
    eye_id = rng.choice(EYE_IDS)
    outfit_id = rng.choice(OUTFIT_IDS)
    hue_shift = rng.choice([0, 45, 90, 140, 180, 220, 280, 320])

    hair_id = rng.choice(HAIR_STYLES)
    hair_ramp = rng.choice(HAIR_RAMPS)

    portrait_hair = PORTRAIT_HAIR_MAP.get(hair_id, "01_1")
    portrait_eyes = f"{int(eye_id):02d}"

    body_spec = {"id": skin_id}
    if skin_ramp:
        body_spec["ramp"] = skin_ramp

    outfit_spec = {"id": outfit_id}
    if hue_shift > 0:
        outfit_spec["hue"] = hue_shift

    hair_spec = {
        "id": hair_id,
        "ramp": hair_ramp
    }

    portrait_spec = {
        "skin": skin_id,
        "eyes": portrait_eyes,
        "hair": {
            "id": portrait_hair,
            "ramp": hair_ramp
        }
    }
    if skin_ramp:
        portrait_spec["ramp"] = skin_ramp

    skin_desc = skin_ramp.replace("skin_", "") if skin_ramp else f"tone {skin_id}"
    hair_desc = f"{hair_ramp.replace('hair_', '')} {STYLE_DESCRIPTIONS.get(hair_id, 'hair')}"
    outfit_desc = OUTFIT_DESCRIPTIONS.get(outfit_id, "top")

    return {
        "kind": "kid",
        "body": body_spec,
        "eyes": eye_id,
        "outfit": outfit_spec,
        "hair": hair_spec,
        "portrait": portrait_spec,
        "why": f"{skin_desc} skin, {hair_desc}, {outfit_desc}"
    }


def main():
    parser = argparse.ArgumentParser(description="Generate procedural LimeZu student recipes.")
    parser.add_argument("count", nargs="?", type=int, default=4, help="Number of students to generate")
    parser.add_argument("--seed", type=int, default=None, help="RNG seed for reproducibility")
    parser.add_argument("--prefix", type=str, default="student_gen_", help="Key prefix for recipe JSON")
    args = parser.parse_args()

    seed = args.seed if args.seed is not None else random.randint(1000, 999999)
    rng = random.Random(seed)

    print(f"/* Seed: {seed} */", file=sys.stderr)
    output = {}
    for i in range(args.count):
        key = f"{args.prefix}{chr(ord('a') + i)}"
        output[key] = generate_student(key, rng)

    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
