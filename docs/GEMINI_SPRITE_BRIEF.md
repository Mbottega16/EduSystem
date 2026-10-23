# Sprite brief for Gemini (Antigravity)

Use this when the owner hands sprite work to Gemini. Gemini draws better pixel
art than the local models, but it costs usage. So send it only the items the
local queue (`tools/comfy_batch.py`) could not get right.

**How to use.** Open a new Gemini chat per item. Paste the block below with the
item filled in. Save every image it returns into `shots/gemini/<item>/`. Then
tell Claude Code: "integrate gemini <item>". Claude runs the picture through
`tools/lz_conform.py` and shows it next to the old sprite. Nothing goes into
`art/` until the owner picks one.

## Prompt (paste verbatim, change only the ITEM line)

```
Draw 4 different versions of ONE small game sprite.

ITEM: a school science microscope. Grey metal body, one angled eyepiece tube,
a focus dial on the side, a flat round base. Side view.

Style:
- Pixel art for a classroom game. Chunky, readable at 16 x 20 pixels.
- Draw each version large (at least 512 x 512) with big, square, hard-edged pixels.
- One light source, upper left. Flat shading, two or three tones per colour.
- A 1 pixel dark blue-grey outline (#3a3a50) round the whole shape.
- Muted, warm colours. No gradients. No anti-aliasing. No soft edges.
- Plain white background. One object, centred, nothing else.
- No text, no watermark, no shadow on the ground.

Make the 4 versions differ in shape (pose, angle, proportions), not in style.
```

## Why each rule is there

- **Large with big pixels.** Claude shrinks the picture to the sprite size. Big,
  clean pixels shrink cleanly. Small, noisy ones turn to mush.
- **Plain white background.** Claude removes it automatically.
- **Outline #3a3a50.** This is the LimeZu keyline. Every sprite in the game has it.
- **Four versions.** The owner picks one. One draft is rarely the best.

## Limits

- Do not use Gemini for character sheets. Eight kids would come back as eight
  different kids. See `docs/AI_ART_PROMPTS.md`.
- Gemini may ignore the pixel grid. That is fine. Claude snaps the result to
  the LimeZu palette and grid afterwards.
