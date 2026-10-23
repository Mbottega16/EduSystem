#!/usr/bin/env python3
"""Draw or restyle a sprite with the local ComfyUI, then conform it to the LimeZu look.

    python tools/comfy_sprite.py microscope "a lab microscope" --grid 16x20 --models sd15,dreamshaper,sdxl
    python tools/comfy_sprite.py microscope "a lab microscope" --grid 16x20 --init art/microscope.png --denoise 0.6

ComfyUI must be running (127.0.0.1:8188). It is local, so it costs nothing.
Nothing here writes into art/: drafts go to shots/comfy/<name>/, so the owner
can pick one. To use a draft, copy it to art/<name>.png and run Reimport Art.

Two modes, one pipeline:
  draw      text only. ComfyUI invents the picture.
  restyle   --init <png>. The old sprite is enlarged and used as the starting
            picture, so the SHAPE stays and the STYLE changes. --denoise sets how
            far it may stray: 0.4 keeps nearly everything, 0.8 keeps little.

Steps per draft:
  1. ComfyUI draws a 512x512 picture.
  2. The plain background is cut away (flood fill from the border).
  3. tools/lz_conform.py shrinks it to --grid art pixels, snaps the colours to
     LimeZu's palette, adds the #3a3a50 keyline, and doubles it to game scale.

Same seed + same settings = same picture, so a good draft can be repeated.
The model cannot draw true pixel art. Step 3 does the real work; expect a
first draft to need a touch-up in Browse Art.bat.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import urllib.request

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOST = "http://127.0.0.1:8188"
COMFY_INPUT = r"D:\AI-Tools\ComfyUI_windows_portable\ComfyUI\input"

# One entry per checkpoint. `lora` only fits SDXL-family models.
MODELS = {
    "sd15": {"ckpt": "v1-5-pruned-emaonly.safetensors", "lora": None,
             "steps": 24, "cfg": 7.0, "sampler": "euler_ancestral", "scheduler": "normal"},
    "dreamshaper": {"ckpt": "DreamShaper_8_pruned.safetensors", "lora": None,
                    "steps": 24, "cfg": 6.5, "sampler": "dpmpp_2m", "scheduler": "karras"},
    "sdxl": {"ckpt": "sd_xl_turbo_1.0_fp16.safetensors", "lora": "pixel-art-xl.safetensors",
             "steps": 4, "cfg": 1.0, "sampler": "euler_ancestral", "scheduler": "normal"},
}
STYLE = ("pixel art, 16-bit game sprite, one object, centred, flat colors, "
         "limited palette, hard pixel edges, plain white background, ")
NEGATIVE = ("blurry, gradient, photo, 3d render, text, watermark, shadow, "
            "multiple objects, background scenery, soft edges, lowres, jpeg artifacts")


def workflow(model, prompt, seed, init=None, denoise=0.6):
    m = MODELS[model]
    w = {"1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": m["ckpt"]}}}
    mdl, clip = ["1", 0], ["1", 1]
    if m["lora"]:
        w["2"] = {"class_type": "LoraLoader", "inputs": {
            "model": ["1", 0], "clip": ["1", 1], "lora_name": m["lora"],
            "strength_model": 1.0, "strength_clip": 1.0}}
        mdl, clip = ["2", 0], ["2", 1]
    w["3"] = {"class_type": "CLIPTextEncode", "inputs": {"clip": clip, "text": STYLE + prompt}}
    w["4"] = {"class_type": "CLIPTextEncode", "inputs": {"clip": clip, "text": NEGATIVE}}
    steps = m["steps"]
    if init:
        w["5"] = {"class_type": "LoadImage", "inputs": {"image": init}}
        w["5b"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["5", 0], "vae": ["1", 2]}}
        latent = ["5b", 0]
        if m["steps"] <= 8:      # turbo models: only denoise*steps run, so give it more
            steps = 8
    else:
        w["5"] = {"class_type": "EmptyLatentImage",
                  "inputs": {"width": 512, "height": 512, "batch_size": 1}}
        latent = ["5", 0]
        denoise = 1.0
    w["6"] = {"class_type": "KSampler", "inputs": {
        "model": mdl, "positive": ["3", 0], "negative": ["4", 0], "latent_image": latent,
        "seed": seed, "steps": steps, "cfg": m["cfg"], "sampler_name": m["sampler"],
        "scheduler": m["scheduler"], "denoise": denoise}}
    w["7"] = {"class_type": "VAEDecode", "inputs": {"samples": ["6", 0], "vae": ["1", 2]}}
    w["8"] = {"class_type": "SaveImage",
              "inputs": {"images": ["7", 0], "filename_prefix": "edusystem_sprite"}}
    return w


def call(path, data=None):
    req = urllib.request.Request(HOST + path,
                                 data=None if data is None else json.dumps(data).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def comfy_up():
    try:
        call("/system_stats")
        return True
    except Exception:
        return False


def prepare_init(path, key):
    """Put an existing sprite in ComfyUI's input folder: nearest-neighbour up to
    ~400 px, centred on white in a 512 square (the same plain background the
    drawn pictures use). Returns the file name ComfyUI loads."""
    im = Image.open(path).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    scale = max(1, int(400 // max(im.size)))
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    canvas = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
    canvas.paste(im, ((512 - im.width) // 2, (512 - im.height) // 2), im)
    name = "init_%s.png" % key
    canvas.convert("RGB").save(os.path.join(COMFY_INPUT, name))
    return name


def draw(model, prompt, seed, init=None, denoise=0.6, timeout=1500):
    pid = json.loads(call("/prompt", {"prompt": workflow(model, prompt, seed, init, denoise)}))["prompt_id"]
    start = time.time()
    while time.time() - start < timeout:
        hist = json.loads(call("/history/" + pid))
        if pid in hist:
            img = hist[pid]["outputs"]["8"]["images"][0]
            q = "/view?filename=%s&subfolder=%s&type=%s" % (
                img["filename"], img["subfolder"], img["type"])
            return call(q)
        time.sleep(2)
    raise TimeoutError("ComfyUI did not finish in %ds" % timeout)


def cut_background(im, tol=40):
    """Make the plain background transparent: flood fill from every border pixel."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    ref = px[0, 0][:3]
    near = lambda c: sum(abs(c[i] - ref[i]) for i in range(3)) <= tol * 3
    seen = set()
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] \
        + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
            continue
        seen.add((x, y))
        if not near(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def make_draft(out_dir, tag, model, prompt, seed, grid, init=None, denoise=0.6):
    """One draft end to end. Returns (final path, seconds). Skips work already done."""
    fin = os.path.join(out_dir, "%s.png" % tag)
    if os.path.exists(fin):
        return fin, 0.0
    raw = os.path.join(out_dir, "raw_%s.png" % tag)
    cut = os.path.join(out_dir, "cut_%s.png" % tag)
    t0 = time.time()
    with open(raw, "wb") as f:
        f.write(draw(model, prompt, seed, init, denoise))
    secs = time.time() - t0
    cut_background(Image.open(raw)).save(cut)
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "lz_conform.py"),
                    cut, fin, "--grid", grid, "--x2"], check=True, cwd=ROOT,
                   stdout=subprocess.DEVNULL)
    return fin, secs


def contact_sheet(out_path, rows, old=None, scale=6):
    """rows: [(label, [draft paths])]. One labelled row per recipe, old sprite first."""
    cells = [(l, [Image.open(p).convert("RGBA") for p in ps if os.path.exists(p)])
             for l, ps in rows]
    cw = max([i.width for _, ims in cells for i in ims] + [old.width if old else 0]) * scale + 12
    ch = max([i.height for _, ims in cells for i in ims] + [old.height if old else 0]) * scale + 12
    n = max([len(ims) for _, ims in cells] + [1])
    label_w = 190
    allrows = ([("OLD sprite", [old])] if old else []) + cells
    sheet = Image.new("RGBA", (label_w + cw * (n + 0), ch * len(allrows)), (206, 194, 170, 255))
    d = ImageDraw.Draw(sheet)
    for r, (label, ims) in enumerate(allrows):
        d.text((6, r * ch + 8), label, fill=(30, 30, 40, 255))
        for c, im in enumerate(ims):
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            sheet.paste(big, (label_w + c * cw + 6, r * ch + 6), big)
    sheet.save(out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("prompt")
    ap.add_argument("--grid", default="16x16", help="size in art pixels, e.g. 16x20")
    ap.add_argument("--models", default="dreamshaper", help="comma list: " + ",".join(MODELS))
    ap.add_argument("--seeds", default="1,2,3")
    ap.add_argument("--init", help="restyle this sprite instead of drawing from scratch")
    ap.add_argument("--denoise", type=float, default=0.6)
    a = ap.parse_args()
    if not comfy_up():
        sys.exit("ComfyUI is not running on %s" % HOST)

    out = os.path.join(ROOT, "shots", "comfy", a.name)
    os.makedirs(out, exist_ok=True)
    init_name = prepare_init(a.init, a.name) if a.init else None
    seeds = [int(s) for s in a.seeds.split(",")]
    rows = []
    for model in a.models.split(","):
        paths = []
        for seed in seeds:
            tag = "%s_%s_%d" % (model, "restyle" if init_name else "draw", seed)
            fin, secs = make_draft(out, tag, model, a.prompt, seed, a.grid,
                                   init_name, a.denoise)
            print("%-28s %5.0fs" % (tag, secs), flush=True)
            paths.append(fin)
        rows.append(("%s %s" % (model, "restyle" if init_name else "draw"), paths))
    old = Image.open(a.init).convert("RGBA") if a.init else None
    contact_sheet(os.path.join(out, "sheet_%s.png" % ("restyle" if init_name else "draw")), rows, old)


if __name__ == "__main__":
    main()
