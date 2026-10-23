#!/usr/bin/env python3
"""The overnight sprite queue: draw or restyle every item in tools/art_queue.json.

    python tools/comfy_batch.py                 draw everything not done yet
    python tools/comfy_batch.py --write-prompts fill in missing prompts with LM Studio first

Needs ComfyUI running (127.0.0.1:8188). Safe to stop and restart: a finished
draft is never redone, so a rerun picks up where the last one ended.

Each item in art_queue.json:
    {"name": "microscope",            file name in art/ it is meant to replace
     "idea": "a school microscope",   one line; used if "prompt" is missing
     "prompt": "...",                 the full picture description (optional)
     "grid": "16x20",                 size in ART pixels (game pixels / 2)
     "model": "dreamshaper",          sd15 | dreamshaper | sdxl
     "seeds": [1, 2, 3, 4, 5, 6],     one draft per seed; more seeds, better odds
     "init": "art/microscope.png",    optional: restyle this sprite
     "denoise": 0.6}                  optional: how far a restyle may stray

Output, all under shots/comfy/ (nothing touches art/):
    <name>/sheet.png     every draft side by side, old sprite first
    MORNING.md           one line per item: drafts made, minutes taken

LM Studio is used ONLY to write prompts (--write-prompts). This machine has
8 GB of RAM, so LM Studio and ComfyUI cannot both be loaded: run the prompt
step first, close LM Studio, then run the queue.
"""
import json
import os
import sys
import time
import urllib.request

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import comfy_sprite as cs

QUEUE = os.path.join(cs.ROOT, "tools", "art_queue.json")
LM = "http://127.0.0.1:1234/v1/chat/completions"
LM_RULES = ("You write one-sentence picture descriptions for an image model that draws small "
            "game sprites. Describe ONE object, side or front view, plain materials and 2-3 "
            "colours, no scenery, no text. Reply with the sentence only.")


def write_prompts(queue):
    for it in queue["items"]:
        if it.get("prompt"):
            continue
        body = {"messages": [{"role": "system", "content": LM_RULES},
                             {"role": "user", "content": it["idea"]}], "temperature": 0.4}
        req = urllib.request.Request(LM, json.dumps(body).encode(),
                                     {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=300) as r:
            it["prompt"] = json.loads(r.read())["choices"][0]["message"]["content"].strip()
        print(it["name"], "->", it["prompt"], flush=True)
    with open(QUEUE, "w", encoding="utf-8") as f:
        json.dump(queue, f, indent=2)


def run(queue):
    if not cs.comfy_up():
        sys.exit("ComfyUI is not running on %s" % cs.HOST)
    report = ["# Overnight sprite queue", "", "Run %s" % time.strftime("%Y-%m-%d %H:%M"), ""]
    for it in queue["items"]:
        if not it.get("prompt"):
            report.append("- **%s**: skipped, no prompt (run --write-prompts)" % it["name"])
            continue
        out = os.path.join(cs.ROOT, "shots", "comfy", it["name"])
        os.makedirs(out, exist_ok=True)
        init = it.get("init")
        init_name = cs.prepare_init(os.path.join(cs.ROOT, init), it["name"]) if init else None
        mode = "restyle" if init else "draw"
        paths, total = [], 0.0
        for seed in it.get("seeds", [1, 2, 3]):
            tag = "%s_%s_%d" % (it["model"], mode, seed)
            try:
                fin, secs = cs.make_draft(out, tag, it["model"], it["prompt"], seed,
                                          it["grid"], init_name, it.get("denoise", 0.6))
            except Exception as e:     # one bad draft must not stop the night
                print("FAILED", tag, e, flush=True)
                continue
            total += secs
            paths.append(fin)
            print("%-14s %-28s %5.0fs" % (it["name"], tag, secs), flush=True)
        old = Image.open(os.path.join(cs.ROOT, init)).convert("RGBA") if init else None
        cs.contact_sheet(os.path.join(out, "sheet.png"), [("%s %s" % (it["model"], mode), paths)], old)
        report.append("- **%s**: %d drafts, %.0f min. Look at `%s/sheet.png`." % (
            it["name"], len(paths), total / 60.0, it["name"]))
    with open(os.path.join(cs.ROOT, "shots", "comfy", "MORNING.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(report) + "\n")
    print("\n".join(report))


if __name__ == "__main__":
    with open(QUEUE, encoding="utf-8") as f:
        q = json.load(f)
    if "--write-prompts" in sys.argv:
        write_prompts(q)
    else:
        run(q)
