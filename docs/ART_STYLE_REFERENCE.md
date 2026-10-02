# Art style reference — target look, and what we've learned

A living document, not a one-time writeup. Every time the user buys a new
reference pack, the `integrate-art-pack` skill (`.claude/skills/`) reads
this file first, studies the new pack, and comes back and UPDATES it —
so understanding compounds across packs instead of resetting each time.

**The goal, in the user's own words:** "I want the art style to be what
limezu uses here. I like this art. I want it exactly like this... WE
have to be the ones to adapt to conform the art style."

**The chosen approach (confirmed with the user, Oct 2026):**
reverse-engineer the TECHNIQUE into `tools/make_art.py`'s procedural
pipeline, not import assets directly for characters. Reasons this won,
over adopting their actual layered asset files:
- Keeps EduSystem's chibi proportions (big head, small body) — a
  documented, load-bearing design choice every character inherits.
  Switching to the pack's normal RPG proportions would mean redrawing
  every character from scratch in the new proportions.
- EduSystem needs poses (sit, handoff, chat, jump, sad) the farm pack
  doesn't have at all — it only has idle/walk/harvest/dig/water/chop/
  fish. No amount of asset reuse covers those; they'd have to be
  hand-drawn in matching style regardless.
- The farm pack is a true layered paper-doll system (separate Body/
  Hair/Outfit/Accessory PNGs composited at runtime). EduSystem loads one
  flat pre-baked PNG per character. Adopting their asset pipeline
  directly means building new Godot-side layer-compositing code, not an
  art change.
- Staying procedural keeps every existing advantage: deterministic,
  license-clean, retune-by-editing-a-number, same poses we already have.

Direct asset reuse is still fair game for single-icon PROPS (furniture,
containers) — see "Direct-use props" below — because those have none of
the above problems: one flat sprite, no pose, no proportion mismatch.

---

## Confirmed technique findings (limezu's "Modern Farm" pack)

Studied by zooming into reference pieces at 16x+ (`Crate_Brown_Empty`,
`Wooden_Table`, `Basket_Empty`, `Stool_Wood_1`, all from the 32x32
singles export). Compared directly against EduSystem's current
`rim_light()`/`finish()` in `tools/make_art.py`.

1. **Outline is cool, not warm.** Their line colour reads as a dark,
   desaturated blue-slate (roughly in the `#2d2b3d` family) — a COOL
   tone, deliberately contrasting against the warm wood/skin fills it
   borders. EduSystem's `LINE = (36, 26, 18)` is warm dark brown. This
   is one of the most visually distinctive differences between the two
   styles side by side — worth testing a cool-shifted outline option.

2. **Shading follows per-surface form, not silhouette distance.** This
   is the big structural difference. EduSystem's `rim_light()` shades
   based on a pixel's distance from the sprite's OUTER transparent
   boundary — one light pass over the whole silhouette. Limezu's crate
   shades each PLANK independently (its own light-top/dark-bottom
   gradient), and the round basket shades by ANGLE around the ring
   (brightest upper-left, darkest lower-right, following the curve's own
   implied surface normal) — not by distance from the basket's outer
   edge. A silhouette-edge rim light can never reproduce "each plank has
   its own highlight," because it has no idea where the internal plank
   boundaries are.
   - Practical translation: furniture draw routines already build
     objects out of discrete `rect()` calls per surface (a plank, a
     panel, a leg) — shading needs to happen PER RECT, not once at the
     end over the whole flattened image. `rrect`-based curved forms
     (baskets, barrels) need an angular gradient, not a radius-distance
     one — `ring()` already exists as a starting point.

3. **Visible grain/noise texture within a fill, not a flat colour.**
   Each plank has scattered pixel-level colour variation (small warm/
   cool flecks, not a smooth gradient, not fully random either — reads
   as curated noise, similar in spirit to how EduSystem's own floor
   tiles already do seeded speckle). EduSystem furniture fills
   (`WOOD`/`WOOD_L`/`WOOD_D` flat `rect()` blocks) have none of this.

4. **More value steps per surface than we use.** A single limezu plank
   reads as roughly 3-4 distinct tones (a bright top-edge highlight line,
   a noisy mid-tone body, a darker lower band, plus the dark joint/seam
   between planks acting as an extra shadow line) where EduSystem
   furniture currently gets 2-3 flat blocks total for the WHOLE object.

5. **Dark joints double as both structure and shadow.** The seams
   between crate planks aren't just a outline-coloured 1px line — they're
   a distinct dark reddish-brown BAND (several px), reading as both "this
   is where one board ends and another begins" and "this crevice is in
   shadow." EduSystem's furniture has no equivalent — surfaces that
   should read as multiple boards currently read as one flat block.

## What this session actually shipped (Oct 2026, partial progress)

`second_band()` / `rim_light2()` / `finish_rich()` in `tools/make_art.py`
— a second, softer shading ring one pixel in from the silhouette edge.
This is a modest step in the right DIRECTION (more tonal steps than a
single hard edge) but it is still silhouette-edge-based, not per-surface
— it does NOT yet implement finding #2 above, the biggest structural
gap. Applied to: `window_seat`, `low_shelf`, `display_rack` (make_items.py)
and all 13 characters + 12 portraits (make_art.py). Characters/portraits
also don't yet have the cool-outline or grain-texture treatment.

**Not yet done — the real next steps, in priority order:**
1. A per-rect/per-surface shading helper (finding #2) — this is the
   single highest-leverage change, since it's what actually produces
   "each plank/panel has its own highlight" instead of today's one
   whole-object rim light.
2. Cool-shifted outline option (finding #1) — cheap to test, could be
   as simple as a new `LINE_COOL` constant and an opt-in `outline()` arg.
3. Grain/noise texture pass (finding #3) — likely a new helper akin to
   `floor_tile()`'s existing seeded-speckle approach, applied to large
   flat fills.
4. Angular (not radial) shading for curved/round forms (finding #2b).

## Direct-use props (license-clean, no style problem)

Single-icon sprites transfer fine as-is (crop/resize/recolour as
needed) because EduSystem furniture is already one-flat-sprite-per-item,
same convention the pack uses. Shortlist confirmed from the FULL 1102-
file single-exports pass (not just a keyword grep) — see conversation
history for the full category breakdown; everything not listed here
(fences, trees, crop-growth stages, animal infrastructure, market-stand
signage, farm buildings, crafting-station tool props) is unambiguously
farm-specific with no classroom equivalent:

Pencil, Pencils Can, Handbook, Photo Frame, Stool (×2 variants), Wooden
Table, Box, Crate, Wood Box, Basket, Color Can, Sign Blank, Trunk/Chest
(closed+open, 2 sizes — good `cabinet` fit), Scale (market-stand weighing
scale — good math/science-corner fit).

## License (per pack — re-check every new one)

limezu "Modern Farm": edit/use freely in commercial or non-commercial
projects; cannot resell or redistribute the assets themselves; credit
to limezu.itch.io appreciated. Record each new pack's license terms here
when it's added, since terms can differ pack to pack.

## Packs studied so far

| Pack | Studied | Verdict |
|---|---|---|
| limezu "Modern Farm" (`artgen.zip`) | 2026-10-02 | Characters: inspiration only (proportions/poses/architecture mismatch). Props: ~20 direct-use candidates out of 1102 files. Technique findings #1-5 above. |
