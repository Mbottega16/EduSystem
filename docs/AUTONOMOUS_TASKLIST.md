# The standing task menu

What `/deep_grind` picks from, and what `/loop /deep_grind` works through
while you are away. **Every task here is small, verifiable, and additive.**

## How to use this list

Pick the highest-value task that is **not done** and whose dependencies
are met. Do one full cycle: implement, verify, screenshot if visual,
commit with a message that says *why*, tick it off here.

**One task per cycle.** A cycle that touches three things cannot be
bisected when it breaks.

**Unless the tasks are genuinely independent — then run them in
parallel.** When more than one unblocked task touches different files
with no shared state (a different data-file section, a different tool
script), dispatch them as separate `Agent` calls with
`isolation: "worktree"` instead of grinding through them one at a time.
Each agent gets its own git worktree, so they cannot step on each other's
edits. The content-integration batches in section A are the clearest
case: task 2 (items) and task 3 (traits) touch different sections of
`balance.json` and were genuinely safe to validate and integrate in
parallel once both were back. Do not parallelize tasks that touch the
same file, or where one task's output is the input to another.

### The bar for finishing a task

```
Run Tests.bat            count went UP, nothing failed
python tools/check_docs.py
```

plus whichever of these covers what you touched:

```
Simulate a Term.bat      anything touching grades, coins or the contract
Trace a Day.bat          anything touching the day's flow or the buttons
Audit the Room.bat       anything touching what E or F offers
Simulate the School.bat  anything touching staff or delegated rooms
Take a Screenshot.bat    anything visual. Headless never proves this
```

**Read the assertion COUNT, not the word PASSED.**

### Rules that override anything below

- Never move the balance contract. If a task would, stop and flag it.
- Never delegate a decision about a particular child to automation.
- If a task turns out to be bigger than one cycle, **split it and write
  the split back into this file** rather than half-doing it.
- If you finish a task and the count did not rise, you did not add a
  check. Go back.

---

## A. Content integration — do these the moment a batch lands

These are not optional work; they are the queue. Prompts live in
`docs/TASK_PACK.md`.

- [ ] **A1. Integrate task 2 — 21 items of furniture.** *(One round
      rejected Aug 2026.)* Validate with
      `python tools/check_items.py <file.json>` before touching
      `balance.json`. Reject rather than patch: an item outside the
      360–840 density window, a near-duplicate of the existing 29, a
      blurb that reads like a catalogue, or a concept link that does not
      make sense. The first submission failed on all counts — every item
      was missing `name` and `art` entirely, two ids (`beanbag`, `globe`)
      collided with existing items, and every `teaches`/`needs` cited a
      concept id from a stale, unintegrated curriculum draft rather than
      the real file. The prompt in `docs/TASK_PACK.md` is unchanged and
      correct; that round just didn't follow it. Re-send, don't patch
      around it. Then art, then a screenshot of the shop.
- [x] **A2. Integrate task 3 — 6 student traits.** *(Done Aug 2026.)*
      Loud, Shy, Restless, Panics, Anchor, Ghost — 6 to 12. Every one
      carries two hooks in tension rather than one bare multiplier: Ghost
      hides AND self-resolves by copying, so a player may never learn
      there is a gap until a test exposes it. `tools/check_traits.py`
      validates future submissions against the real hook set.
- [x] **A3. Integrate task 7 — 11 day events.** *(Done Aug 2026, see the
      content-batch entry under Done.)* ChatGPT's landed, all 11 carrying
      a real hook; Gemini's was pure flavour text and was rejected.
      `events.gd`: 9 → 20, weights re-summed to exactly 100, "none" still
      the largest by a wide margin.
- [x] **A4. Integrate task 8 — homework banks to 24 each.** *(Done Aug
      2026, see the content-batch entry under Done.)* Landed short of
      the target on purpose: two questions were fixed for an accidentally-
      correct or ambiguous wrong answer, and near-duplicate facts against
      the existing bank were dropped rather than kept to hit a round
      number. `questions.gd`: math 12→24, ela 12→22, science 12→19,
      social 12→24.

## B. Real gaps, found by counting — highest value first

- [ ] **B0. A grid-out-of-bounds error prints on every single room
      build.** *(Found Aug 2026, not chased -- unrelated to the task in
      progress at the time.)* `set_point_solid`/`block_rect` in
      `grid.gd`, called from `room_builder.gd`'s `build_walls()`, tries
      to mark points outside the AStarGrid2D's actual bounds (seen:
      `(20,0)`, `(21,0)`, `(22,0)`, `(20,1)`... against a `20x11` grid) --
      repeating dozens of times per build. Non-fatal: the suite passes,
      screenshots render correctly, walking/collision all work as
      expected in every manual check so far. Only surfaced because a
      full stderr capture was taken for once instead of the usual
      tail -- an error this noisy, printing on literally every room
      build including every test's own setup, went unnoticed for who
      knows how long. Worth tracing `build_walls()`'s loop bounds
      properly rather than living with a wall of caught-but-ignored
      engine errors on every run.
- [x] **B1. What a concept is for.** *(Decided and implemented Aug 2026.)*
      The finding was bigger than "112 aren't linked": `concept_bonus`
      caps at **ten** concepts, so 110 of the 120 move no number at all.
      Decision — **concepts are texture, not a collection** — is written
      into `docs/GDD.md`.
      The cap stays (raising it moves the contract, and row three is
      already 0.97). The board no longer prints `Curriculum (8/120)`,
      which promised a completion target and made a teacher's own subject
      knowledge look like a checklist she was failing. Item links are
      curated at roughly twenty across 50 items, and task 2's quota rose
      from 4/3 to 7/5 to close most of that gap.
      **Still open:** the ~20 target is not reached until task 2 lands.
      Re-count after integrating it.
- [x] **B2. The dead `icon` field.** *(Done Aug 2026.)* Nothing in
      `scripts/`, `tools/` or `tests/` read it — zero references. Ten of
      forty held an emoji, which the briefing bans in game text, and the
      other thirty were an invitation to spend a cycle filling in a field
      no screen renders. Deleted, with an assertion so it cannot drift
      back, and a note in `PLAN-tiers-buffs-shop.md` for whoever builds
      the icon column later.
- [x] **B3. Numbers in player-facing text.** *(Done Aug 2026.)* The
      curriculum screen printed *"Knowing your subjects is worth +12% to
      every grade"*; it is now banded prose, with the thresholds taken as
      a ratio of `concept_bonus_cap` so no number moved into code. The
      `bookshelf` blurb is now *"Reaches further than it looks like it
      should."*
      **The rule was only ever enforced on the student file**, which is
      how both survived — and the row test actually *allowlisted* the
      violation by accepting any line containing `"worth +"`. Coverage now
      extends to the curriculum screen and every item blurb.
      *Correction: the third suspect, `"room 40%  lesson 0%  hw 3%"`,
      appears only in comments describing what that screen used to print.
      A false positive in the scan that produced this list — grep the
      strings, not the file.*
- [x] **B4. Onboarding — first slice.** *(Done Aug 2026.)* One sentence,
      at the moment it explains something the player has just watched:
      *"Work only moves while you are at the front."*
      It fires on the **downward crossing** of an attention threshold, not
      when you step away — walking to a stuck child *is* the game, and a
      nudge fired then would read as "do not do that". By the time
      attention has fallen that far the player has already seen the work
      slow, so the line explains rather than pre-empts.
      The threshold is `teaching.drift_hint_below` in `balance.json`,
      because numbers do not live in code. `hint_once()` already existed
      and was used exactly once in the whole game; this is the second
      caller.
      **Still open:** this is one line, not onboarding. Nothing yet
      teaches collecting, marking, the shop, or what the term target
      means. Next slice should come from watching a real first run, not
      from a list.

## C. Verification debt

- [x] **C1. Assertions that test a count instead of a claim.** *(Swept
      Aug 2026.)* Automated the sweep — extract every `size() == <int>` /
      `count() == <int>` literal from the suite and cross-reference it
      against the ten live content counts. **No remaining matches.** The
      one real instance (`lessons.size() == 20`) was found and fixed
      during the task-1 integration; everything else compares against
      state the test itself created, which is legitimate. Re-run the
      sweep after any content batch.
- [x] **C2. Panel fit-test the screens that grew.** *(Done Aug 2026, and
      it found a live bug.)* The curriculum screen and the shop both
      **window** their lists with `...` markers, so 40 lessons and 50
      items do not clip. But the shop prints an item name through
      `substr(0, 13)` into a `%-13s` column and **cuts anything longer
      with no warning** — and nothing constrained the field.
      Two shipped items were already truncated: *Alphabet Frieze* rendered
      as "Alphabet Frie", *Supply Cabinet* as "Supply Cabine". Renamed to
      **Letter Frieze** and **Store Cabinet**. Eight of round one's
      twenty-two would have been cut. Now asserted, in the task-2 prompt,
      and in `check_items.py`.
- [x] **C3. Assert the art contract.** *(Done Aug 2026.)* The per-item
      check used `ResourceLoader.exists()`; it now also `load()`s, because
      `art/inspector.png` once existed, passed every file-exists check in
      the project, and still threw at runtime because nothing had imported
      it. The directory sweep already loaded every PNG and covers all 71
      (no subdirectories).

## E. The art overhaul — same user request as the consumables, both parts done

*(Aug 2026.)* "isthere anyway to change the characters to a more cute
chibi art style? also lets convert to 32 bit as the pixelated look is
good but needs more detail." Confirmed with the user before starting:
the resolution jump is **same layout, everything crisper** — the
viewport doubles (320x176 -> 640x352, `Grid.TILE` 16 -> 32) so the room
still shows the same desks and the same layout, just rendered denser.
Not the alternative (same window, fewer tiles visible), which would
have put the balance contract's own camera/layout assumptions at risk
for no reason.

- [x] **E1. Chibi character proportions.** *(Done Aug 2026.)* Redesigned
      `draw_char()` in `tools/make_art.py` -- head 12/24 rows, body 5,
      legs 4 (was head 8, body 7, legs 4+shoes), plus bigger eyes with a
      white highlight pixel each, the actual "cute" signal. All ten
      characters (player, inspector, principal, 8 students) redrawn from
      the SAME routine and palette table, so this was a ~90-line rewrite
      of one function rather than ten redraws.
      **Sequencing note, corrected from the original plan below:** the
      plan said do this AFTER a resolution bump, reasoning "draw it once
      at the final resolution." That assumed hand-painted art. This is a
      PROCEDURAL generator -- adjusting proportions after E2 is a second
      pass over the same numbers, not a second drawing, so there was no
      real cost to shipping chibi now and E2 later. Worth remembering
      next time a sequencing call leans on an assumption about the art
      pipeline rather than checking it.
      Verified against every screen that shows a portrait, not just the
      room: dashboard, student bio, the principal's own corner popup,
      and the classroom itself, all screenshotted. Balance contract
      re-verified unmoved, as expected for an art-only change.
- [x] **E2. The 2x resolution pass.** *(Done Aug 2026.)* User confirmed the
      UI should be redone natively at the new resolution rather than
      wrapped in a sub-viewport, accepting the larger, riskier job.

      **Art.** `Grid.TILE` 16 -> 32; `project.godot`'s viewport 320x176
      -> 640x352, window override 960x528 -> 1920x1056 (same 3x integer
      scale, so pixel edges stay crisp). Characters redrawn natively at
      32x48 -- the chibi routine from E1 wrapped in a small `R()`/`P()`
      helper that scales every call 2x on the way to the canvas, plus
      real NEW detail the bigger canvas afforded (rosy cheeks, a mouth)
      rather than a blind doubling. Furniture, room tiles and shop icons
      (~70 assets) run through a new `scale2x()` -- Scale2x/AdvMAME2x,
      the decades-old pixel-art upscaler emulators use -- rather than
      nearest-neighbour, because nearest-neighbour would have been a
      complete NO-OP on screen: the window doubled exactly as much as
      the art, so a naive 2x resize lands every source pixel back on the
      same physical screen pixels it always occupied. Scale2x actually
      redraws staircased diagonal edges into real diagonal ones, which
      is where the "more detail" genuinely comes from. The title screen
      (`draw_title_bg`, `draw_logo`) draws natively at the new size
      instead, since both were already screen-sized rather than
      tile-sized.

      **Pacing, the part a pure art pass would have silently broken.**
      `Actor.SPEED` doubled (60 -> 120) alongside every pixel-distance
      balance value that does NOT cancel out algebraically against it --
      `teacher_speed`, `teacher_pick_radius`, `brisk_walk_speed`,
      `long_reach_radius`, `calm_presence_radius` all doubled in
      `data/balance.json`. Missing any one of these would not have
      crashed anything; it would have quietly made either the player or
      the students faster than the other, or reach further than intended
      -- a real balance regression a screenshot alone would not catch.
      Caught by tracing the actual formula (`speed_scale()` divides by
      `SPEED` again, so `SPEED` itself cancels out of the PLAYER's real
      speed entirely -- the balance.json value is what actually matters).
      New guard-rail assertions pin `Grid.TILE`, the viewport, and the
      SPEED/TILE ratio directly so this class of regression fails loudly
      next time instead of shipping quietly.

      **The UI.** Every offset in `hud.tscn`, every
      `add_theme_font_size_override`/`add_theme_constant_override` call
      in `hud.gd` (38 of them), the three portrait `AtlasTexture` crop
      regions, `debug_panel.gd`'s programmatic panel, `floater.gd`'s
      popup text, `title.tscn`/`title.gd` (dust bounds, logo breathing,
      the walker), `hallway.gd`'s whole geometry, and every hardcoded
      collision box / sprite offset in `room_builder.gd` (desk, podium,
      bell, noticeboard, teacher desk, the shadow's own width divisor) --
      all doubled. `LINE_CHARS`/`LIST_ROWS` deliberately NOT touched:
      those are character/row counts, and a screen that fits 11 rows at
      font 8 in a 288px body still fits 11 rows at font 16 in a 576px
      body -- doubling them too would have been the same bug as touching
      `SPEED` twice.

      **Real bugs, all found by screenshot or by the suite, not assumed
      fixed:**
      - `Take a Screenshot.bat` hardcoded 320x176 as the capture size --
        every "verification" screenshot taken early in this pass was
        silently re-rendering the OLD resolution regardless of what the
        project actually shipped. Every shot after the fix used 640x352;
        every shot before it was worthless and had to be retaken.
      - The actual title screen (`scenes/ui/title.tscn`) is a different
        scene from what `tools/shot.gd`'s `"title"` case opens (an
        in-game HUD overlay) -- so screenshotting `"title"` was never
        looking at the boot scene at all. Added a real `"boot_title"`
        case that loads `title.tscn` directly.
      - A test at the noticeboard started failing for a reason that had
        nothing to do with geometry: `Actor.player.targets` is a CACHE,
        only refreshed by `_repick()` on a physics frame, and a stray
        held key from earlier in the same long test function landed the
        cache's last refresh on the wrong facing direction. The desk
        three tiles away scored higher than the noticeboard for that one
        cached frame and never got asked again. Fixed by forcing a clean
        `_repick()` at the point a test actually needs one, and by
        making `place_player()` re-assert facing after its own await,
        not just before it -- neither alone was enough.
      - `floater.gd`: a doubled-value comment landed between a
        method-chain call and its trailing `\` line-continuation,
        turning the continuation into ordinary comment text and breaking
        the chain. A reminder that a comment appended after code on a
        continuation line is not safe in GDScript.

      **Known gap, deliberately not fixed here:** the HTML sprite editor
      (`Draw a Sprite.bat`) still exports at the old 80x96/16x24 size, so
      the five hand-edited furniture items (bookshelf, lab_bench,
      art_easel, rug, plant) are the one part of the shop still at the
      old scale until that tool is updated too. Noted in `README.md` and
      `docs/GDD.md` rather than silently left for someone to discover.

      1147 -> 1150 assertions (3 new guard-rails). Balance contract
      re-verified unmoved. Screenshotted: the real boot title, the
      classroom, the shop, the office, the principal's corner popup, the
      dashboard, the hallway, the dev panel, the curriculum screen, the
      watch screen, and the career screen -- eleven real screens, not one.

## D. Housekeeping

- [x] **D0. Update the HTML sprite editor for the Aug 2026 resolution
      doubling.** Done — `tools/sprite_editor.html` now matches
      `tools/make_art.py`'s current 32x48-cell grid (previously it was
      still 16x24, and briefly claimed a wrong "400x192" sheet size in
      between). It was also expanded from a 5x4 to a 9x4 grid at the
      same time (see D3): four one-shot pose columns added past the
      existing walk cycle and sit pose. Any *character* re-drawn through
      it today is the current scale and grid. The five hand-drawn
      furniture items (bookshelf, lab_bench, art_easel, rug, plant) are
      a separate case — they're one-off art edited via `Browse Art.bat`'s
      in-editor curator, not this HTML tool, and still need checking
      individually against the doubled scale.
- [~] **D1. `.godot/` and OneDrive.** Git half was **already done** —
      `.godot/` is in `.gitignore` and zero files under it are tracked.
      **The OneDrive half needs the user**: excluding a folder from sync
      is a setting in the OneDrive client, not something a script can set
      reliably. Right-click `.godot` in Explorer → *Always keep on this
      device* off, or move the repo outside OneDrive.
- [ ] **D2. Run `/deep_update` after any batch integration.** Counts move
      in six documents at once and disagreement is worse than staleness.
      *(Last run 2026-08-19.)* Found real drift beyond assertion counts:
      the suite has grown to **79 sections** (CLAUDE.md said 74, GDD said
      75), `hud.gd` is 2741 lines now (was quoted at 2053), there are
      **11** interactable types not 10 (`hall_door.gd`), and the title
      screen's own build stamp was three features behind
      (`b30`/"a reputation you can lose" → `b31`/"a door to every room
      you hold"). A3/A4 on this list were also stale — both integrations
      landed sessions ago but the checkboxes were never ticked.
- [x] **D3. Sheet grid expanded 5x4 -> 9x4 for real animation room.**
      *(Aug 2026 -- user request.)* `tools/make_art.py` draws four new
      one-shot poses per character (`POSE_HANDOFF/CHAT/JUMP/SAD`,
      `Actor.gd`), `sprite_editor.html` matches the grid, and `Actor`
      gained `play_pose()`/`tick_pose()` to hold one for a beat and hand
      back to idle/seated. Wired to two real triggers so far: the player
      flashes the hand-off pose on every pickup/hand-in
      (`player.gd::carry_work/drop_all_work` etc.), and a student flashes
      jump-for-joy on WORKING->DONE and the sad pose whenever their
      stuck bubble comes on. Chatting between students and anything
      fancier than these two edge-triggered moments is NOT wired --
      the art and the plumbing exist, the behaviour that would call them
      more often does not.
- [x] **D4. One `Dev Console.bat` menu for every root launcher.**
      *(Aug 2026 -- user request.)* Every individual `.bat` still exists
      and still works stand-alone; the console just calls them, so this
      added a front door rather than a replacement.

---

## Done

- [x] **One dedicated key per verb: quiz, homework and desk-move each got
      their own.** *(Aug 2026 -- direct user instruction: "H to collect
      homework / E to answer questions... / F to move furniture / Q to
      pop a quiz / D to move a desk", with three genuine conflicts
      resolved by asking rather than guessing: D already meant
      walk-right, Q already meant settle, and lesson/bell had no key
      left in the list at all.)* This revises the project's own "two
      buttons per landmark" hard constraint, which held until a THIRD
      landmark verb (the quiz) needed somewhere to live with nowhere
      left that wasn't a lie about what E or F meant. `Interactable.Key`
      grew from `{USE, MANAGE}` to five values, each a real, distinct,
      registered input action (`Interactable.KEY_ACTIONS` is the single
      list); `player.gd`'s picker, prompt and hold logic all generalised
      from a hardcoded pair to iterating that list, rather than special-
      casing three more times.
      Split cleanly along existing lines: quiz_caller.gd and
      desk_mover.gd just changed which key they answer to; the teacher's
      desk split into two Interactables sharing one tile (marking_desk.gd
      keeps "hand in classwork" on E, new homework_desk.gd owns "mark
      homework" on H), wired through classroom.gd exactly the way the
      curriculum board already shares the noticeboard's tile -- a
      classroom-level signal relay, not a special case.
      Two silent-overflow bugs caught by screenshot, not assumed: the
      Principal's Office's own flat tutorial list (already windowed
      elsewhere this session) needed no further change, but the title
      screen's CONTROLS page -- a plain, non-scrolling Label -- had never
      been screenshotted at all, and three new rebindable actions pushed
      its list into the footer's own row. Built `tools/title_shot.gd`/
      `.tscn` (the title scene was never reachable through `shot.gd`,
      which only ever loads `main.tscn`) specifically to catch this, and
      windowed the Controls list the same way Career already pages past
      thirty milestones.
      `Audit the Room.bat` extended from two columns (E/F) to five
      (E/F/Q/H/M) -- an audit tool blind to three of five possible
      actions would have been actively misleading about what changed.
      Re-ran it, `Trace a Day.bat` and `Simulate a Term.bat`: every
      landmark answers on the right key in every phase, contract
      unmoved (key rebinding touches no grade input).
      1189 -> 1193 assertions, including a genuine walk-up-and-press
      test for the new homework key that was never covered even for the
      OLD key (previous tests called `hud.open_marking()` directly).
      Also noted, not fixed (pre-existing, unrelated): a
      `set_point_solid` / grid-out-of-bounds error prints on every room
      build, caught only because a full stderr capture was taken for the
      first time rather than the usual tail. Worth a real look later.

- [x] **A `/deep_critique` pass, and all ten findings implemented.**
      *(Aug 2026 -- user: "give me a list of the 10 most important
      improvements... macro and micro", then "I agree entirely implement
      all".)* Ran the skeptical-outsider critique for real: `Trace a
      Day.bat`, `Audit the Room.bat`, `Simulate a Term.bat`, and screenshots
      of the hallway/office/shop/consumables rather than reasoning about
      them. Findings and fixes:
      1. Principal portrait crop -- investigated, found ALREADY fixed by
         an earlier commit; no code change needed, corrected the record.
      2. Hallway doors were all identical -- now tinted per kind (home
         plain, office gold, a staffed room cool blue, unstaffed room
         greyer, a locked slot dim), confirmed by screenshot.
      3. The status bar silently dropped `need N` off the end once the
         coin count got long enough (LINE_CHARS=47, unchanged since
         before the resolution doubled) -- reordered so the term target
         comes right after the day counter rather than last, and added
         `_clip_visibly()` so ANY future overflow ends in a visible `…`
         rather than silence.
      4. Consumables could buy grade: `photocopies` used `lesson_mult`,
         which longer lesson time turns straight into more work done --
         a day EVENT doing that is random, a purchasable one is a
         guaranteed no-downside nudge the contract's own simulator never
         models buying. Moved to `stall_mult`, the same lever `coffee`
         already uses.
      5. The shop's item preview was a distorted blob for anything not
         shaped like a 32x48 character portrait -- the shared portrait
         `TextureRect` used `stretch_mode = 0` (distort-to-fill). Fixed
         at the node, once, for every item and character screen at once
         (`stretch_mode = 5`, keep-aspect-centered).
      6. Room mess and the janitor had zero screenshot coverage --
         two new `shot.gd` cases, and found in the process that a
         freshly-hired janitor's first clean fires on the very next
         physics frame (timer starts at 0.0), not after a real interval.
      7. The Principal's Office tutorial shelf only covered the four
         original hints -- five more added (consumables, mess, the
         janitor, weather, milestones) and, since ten flat lines silently
         clipped past the fourth with no sign anything was missing (the
         exact failure this project keeps a rule against), the section is
         now windowed and scrollable the same way Career already pages
         past thirty milestones.
      8. `Audit the Room.bat` showed the noticeboard losing its own F
         prompt to "Move Ava's desk" in the afternoon -- every desk's
         move-offer used the Interactable default 40px pick radius with
         no per-desk tuning, unlike every other landmark sharing ground
         with a neighbour. Shrunk to 16px; re-ran the audit and confirmed
         the shop (and the teacher's own desk, which had the same bleed)
         both answer correctly again.
      9. Macro finding, no code fix by nature: eight systems have shipped
         around the core loop without once changing it, each
         individually justified but collectively a lot of surface for a
         new player to cross. Written into `docs/GDD.md`'s roadmap as a
         real decision -- the next block of work is a consolidation pass
         (count what a first twenty minutes actually introduces, defer
         what can be deferred), not another new system, before Phase 4.
      10. "Prose, never numbers" was being read two ways as more numeric
          screens (prices, milestone counts, day counters) shipped --
          the rule's actual, already-enforced scope (bans a number
          standing in for a CHILD's ability; never banned prices or
          counts) is now written into `CLAUDE.md` explicitly.
      Also fixed in passing, found only by manually re-verifying every
      change with a real screenshot rather than trusting the diff:
      `Take a Screenshot.bat` computed `SCREEN=title` for the output
      filename when called with no argument, but still passed the
      original EMPTY argument to Godot -- so the plain, no-argument form
      never actually opened the title screen, just saved whatever the
      default classroom state was under that name.
      1189 assertions throughout (no new tests needed beyond one updated
      assertion for the photocopies effect change). Contract re-verified
      unmoved. Build bumped to b32.

- [x] **Consumables: a fifth shop tab, spent the same day rather than
      placed.** *(Aug 2026 -- user request, part of a three-part ask: "I
      want to implement some sort of consumable for each day. something
      that could be purchased in the shop.")* The other two parts of that
      request (a chibi art style, a 2x/32px resolution upgrade) are
      tracked separately below -- this piece shipped first because it
      needed no art-pipeline rework to be real and correct.
      Four items -- Coffee (calms the room), Sticker Chart (guarantees
      homework), Bake Sale (a flat coin bonus), Photocopies (more lesson
      time) -- reusing DayEvent's own hook vocabulary
      (`stall_mult`/`lesson_mult`/`coin_mult`/`bonus_coins`/
      `homework_sure`) rather than inventing a second effect system, since
      a consumable and a day event are mechanically the same kind of
      thing: one bought, one rolled, and they stack the same way.
      Bought and used in one motion -- `Game.use_consumable()` charges
      the coins and applies the effect immediately, with no inventory to
      manage, which is the actual design point: a decision about today,
      not a stockpile. The shop's BUY flow branches on category so a
      consumable never enters the ghost-cursor placement flow furniture
      uses, since there is nowhere to place it.
      **Two real bugs found by running the checkers, not by them staying
      quiet:** `tests/run.gd` had three places that read `d["bonus"]` /
      `d["range"]` by direct dict-subscript across EVERY item in the
      catalogue, which crashed the moment an item existed without those
      keys -- consumables are the first items in the shop's history that
      genuinely don't have them. `tools/check_docs.py` had the identical
      bug in its own value-density check. All four fixed by branching on
      `cat == "consumable"` rather than widening what every item is
      required to have.
      1132 -> 1147 assertions. Balance contract re-verified unmoved --
      `tools/sim.gd`'s policies never buy anything from the shop, so the
      three contract rows cannot see this feature at all, which is
      exactly why it was safe to add without resimulating a term by hand.
- [x] **The principal's office, and the principal as the tutorial mascot.**
      *(Aug 2026 -- user request: "create a principal's office that will
      hold all of the progress bars, achievements, and accolades,
      tutorials for how to do things... I actually want the principal of
      the school to be the tutorial mascot and pop up and explain how
      things are done.")*
      A new character, drawn through the same palette-on-one-generator
      pipeline as the inspector (`tools/make_art.py`'s `CHARACTERS`
      table) rather than hand-painted -- white hair for "older, in
      charge", a colour (deep plum) nobody else in the building wears,
      same reasoning as the inspector's grey suit.
      **The office** is the second door in the hallway, always there,
      counting against neither `Game.rooms` nor the room cap since it is
      about the player rather than a room they run. It is a SUMMARY, not
      a second copy of the career list: milestones as a progress bar
      (`X/Y`, `Milestones.all()` against `Game.milestones`), career
      totals, and a shelf of tutorial text -- with E jumping straight to
      the real, already-built `show_career()` for the full paged list,
      rather than re-implementing paging a second time to drift from it.
      **The principal as mascot:** `hint_once()` gained a sibling,
      `principal_says(id, text)` -- same once-per-run gate, same
      `Settings.show_hints` respect, but shown with a portrait in a new
      corner popup (`MascotBox`/`MascotPortrait`) built deliberately
      OUTSIDE `$Overlay`, because `$Overlay` is hidden whenever no menu
      is open and that is exactly when a tutorial nudge needs to fire.
      Every existing hint (work stopping when you leave the front,
      uncollected work, build mode mid-lesson) now goes through the
      principal, plus one new one on the hallway's first use.
      **Two real layout bugs found by screenshot:** the office's first
      screenshot had the portrait rendering, on top of it, the FULL
      TUTORIALS list -- Rich runs the whole body height on a list screen
      this long, and the portrait box sat square inside that rectangle,
      so wrapped text painted over the face. Fixed by dropping the
      portrait from the office screen entirely rather than fighting text
      wrap for a box neither needed to share space with; the corner
      popup is where the face actually appears. Confirmed by screenshot,
      not assumed, both before and after the fix.
      1120 -> 1127 assertions. Balance contract re-verified unmoved --
      nothing here touches a grade input.
      **Follow-up tweak, same session:** a 23rd milestone, `met_principal`
      ("An open door"), proved by a new `Game.met_principal` bool set the
      moment the office door is used -- saved, loaded, and reset in
      `new_run()` alongside `cheated`, the existing flag it copies the
      pattern from. The one genuinely new piece of state this whole
      feature needed; everything else in the office reads state the game
      already kept. 1127 -> 1129 assertions.
- [x] **A hallway between the rooms you hold.**
      *(Aug 2026 -- user request: "make the ability to hold multiple
      classrooms at a time, have it so that the teacher can step out of
      the door of the room to walk into a hallway then can select to go
      to a separate room once unlocked.")* The door already drawn into the
      left wall (`Layout.DOOR`, where students spawn) now does something:
      walk to it outside a lesson and press F to step into a real
      corridor scene, reusing the classroom's own door art. Every room in
      `Game.rooms` is a door in it, built by a new `hall_door.gd`
      Interactable shared between the one door in your own room and every
      door the hallway itself builds; your own leads back in, a staffed
      room's opens `show_watch()`, an unstaffed one opens `show_hiring()`
      pre-selected to it, and a locked-until-affordable door for the next
      room only appears when `Game.can_open_room()` is actually true --
      same "hidden, not greyed out" rule the shop follows.
      **Deliberately does not** let the player personally teach a second
      room at once: a delegated room is still resolved by `RoomSim`
      exactly as before, and the hallway is a faster way to reach that
      room's own screen, not a second body to puppet -- see the GDD's §6
      update on why that is Phase 2, not this.
      **Two real bugs found by screenshot, not by the suite passing:**
      the hallway's own StaticBody2D walls were built at the same origin
      as the classroom, so a HIDDEN corridor was colliding with the
      player in their own room (`visible = false` does not stop
      collision) -- caught by an EXISTING wall-collision test failing,
      not by anything written for this feature, and fixed by parking the
      hallway 10000px away. Then the hallway rendered completely empty on
      its own first screenshot: the doors had no sprite at all, an
      "offers nothing" failure of exactly the kind CLAUDE.md warns about,
      fixed by drawing the real door art per door.
      Regression test drives it through the REAL input pipeline
      (`place_player` + `tap`, not calling `interact()` directly): out
      the door, room count and door count agree, opening a room from the
      hallway works, an unstaffed room's door routes to hiring, and the
      home door hands the player back with the classroom visible again.
      1106 -> 1120 assertions. Balance contract re-verified unmoved.
- [x] **Ambient weather: day events you can see, not just read about.**
      *(Aug 2026 -- user request, with ChatGPT/Gemini unavailable: "I need
      something to make the game feel fresh... I don't care what it is.")*
      Looked for the biggest gap between a system that already exists and
      what the player actually experiences of it. Found one: `DayEvent`
      had grown to 20 real entries with real mechanical hooks, but the
      only trace of an event during the actual lesson was a line on last
      night's report -- the room itself looked identical every day.
      Five events (`wet_play`, `heatwave`, `sports_day`, `cold_snap`,
      `cleaning`) now spawn drifting motes in the room while their lesson
      runs, via a new `Fx.weather_mote()` reusing the existing dust-puff
      texture rather than new art. Purely cosmetic -- changes nothing
      `DayEvent`'s own hooks do not already change -- and the other 15
      events spawn nothing, on purpose, so most days still look plain.
      **The tuning took three full screenshot passes**, not one: the
      first version was genuinely invisible (the shared dust texture is
      2x2 pixels with one transparent corner, fine for a five-at-once
      burst, a near-invisible smudge alone), confirmed by isolating the
      render pipeline with an oversized debug sprite before touching
      real values again; the second pass fixed falling motes but rising
      ones (heatwave/sports_day) spawned under the HUD's own bottom hint
      bar; the third widened contrast and spawn rate until each event
      was confirmed legible in an actual screenshot, not just spawning
      in a test. Regression test drives `_tick_weather()` directly:
      an ordinary day spawns nothing, `wet_play` spawns a mote and
      queues its own next one rather than firing every frame.
      1103 -> 1106 assertions. Balance contract re-verified unmoved,
      as expected for a change that touches no grade input.
- [x] **Content batch: Tasks 2, 5–11, from two independent model runs.**
      *(Aug 2026.)* Both ChatGPT and Gemini were sent the same task pack;
      each task was scored against its own prompt's rules and the real
      checkers (`check_items.py`, `check_traits.py`) rather than
      integrated on trust. Task 3 was already done in a prior session —
      both models re-sent it anyway; ignored.

      **Task 2 (21 items) — REJECTED, 16 of 16 problems real.** Every
      `teaches`/`needs` concept id was fabricated -- none exist in
      `curriculum.json` (`patterns_sequences.rules`,
      `citizenship.rights`, etc., all invented). Also: 0/7 teaches, 0/5
      needs (the fabricated ones do not count), `sensory_corner` is 14
      chars against a 13 limit, and the `seating` category got zero
      items against a 2 minimum. Nothing integrated. Needs a resend with
      `curriculum.json` actually read.

      **Task 5 (6 staff archetypes) — ChatGPT's, all landed.** No
      strict-dominance violations against any of the existing six
      (checked programmatically: reaction/wage/teaches/collects/settles/
      quizzes on every pair), every blurb ≤47 chars, no id collisions.
      `staff.gd`: 6 → 12 archetypes. Re-verified with
      `Simulate the School.bat`: the twelve-archetype spread is still
      0.48 (D) to 0.68 (C) -- same range as the original six, so nothing
      dominates the pool.

      **Task 6 (15 milestones) — 7 of 15, ChatGPT's only.** Gemini's 15
      skipped the prompt's central requirement (a proof line from state
      the engine actually keeps) entirely and used Title Case names
      against house style; rejected outright. ChatGPT's followed the
      rule and even filed three ideas under NEEDS NEW STATE rather than
      inventing engine state -- but 8 of its 15 turned out to duplicate
      an EXISTING milestone once checked against `milestones.gd`'s real
      proof code: `quiet_excellence` == `outstanding`, `learned_it_all`
      and `full_curriculum` both == `polymath` (the second also hardcoded
      a stale 60 against the current 120), `big_room` == `grown`,
      `proper_room` a weaker `furnished`, `clean_run` == `full_house`
      verbatim (the task pack's OWN worked example for `full_house`),
      and `hard_choice` both near-duplicates `legendary_done` and checks
      a condition (`rarity == "Legendary"`, wrong case) that does not
      actually confirm the paper was finished. The 7 that survived:
      `no_empty_chairs`, `wall_to_wall`, `good_enough`, `thin_day`,
      `enough_money`, `one_went_wrong`, `still_here` -- two blurbs
      trimmed to fit 47 chars, `no_empty_chairs` proved against
      `Balance.class_hard_cap` (24) rather than the literal old cap of 8
      so it stays meaningful now desks are buyable past the start.
      `milestones.gd`: 15 → 22.

      **Task 7 (11 day events) — ChatGPT's, all landed.** Gemini's 11
      carried zero mechanical hooks -- pure flavour text against a
      prompt whose Rule 1 is "each must change a real number" -- and
      omitted `weight` entirely, both of which are hard schema failures
      with no fix short of a resend. ChatGPT's carried real hooks, every
      blurb ≤55 chars, and its full rebalanced 20-row table (existing 9
      re-weighted plus 11 new) sums to exactly 100 with `none` still the
      largest by a wide margin (30 vs next-highest 8). `events.gd`: 9 →
      20 events.

      **Task 8 (48 questions) — 41 of 48, ChatGPT's only.** Gemini's
      broke house style throughout (question marks and capitals against
      the existing lowercase-fragment style the prompt explicitly asked
      to match), had zero Maryland content in the social bank despite
      the prompt naming that requirement directly, and included one
      openly silly wrong answer (`London` for "capital of the USA").
      Rejected. ChatGPT's passed every mechanical check (lengths, exactly
      three wrongs, no wrong equal to the answer) but two were fixed by
      hand after a correctness read: `0.5 as a fraction` offered `5/10`
      as a WRONG answer, which is mathematically equal to `1/2` (swapped
      for `5/1`); `Maryland state nickname` offered `Free State` as
      wrong, which is also a real, commonly-used Maryland nickname
      (swapped for `Sunshine State`). Two more were dropped as exact
      duplicates of existing bank entries the model had been given but
      restated anyway (`correct spelling` / necessary, `opposite of
      ancient` / modern, both already in `BANK_ELA`), and five science
      questions were dropped as near-duplicates of existing facts tested
      from the other side (`force that pulls down` == existing gravity
      question, `metal attracted to magnets` == existing iron question,
      etc). `questions.gd`: math 12→24, ela 12→22, science 12→19,
      social 12→24 (89 total, short of the 96 target because duplicates
      were dropped rather than kept to hit a number).
      Also fixed a test that broke as a direct, honest consequence of
      the bank actually growing: `test_curriculum`'s maths-homework check
      used to grep the sampled question for `x` or `+` as a proxy for
      "looks like arithmetic" -- true of every old question, false of
      new ones like `half of 86` or `one quarter of 40`. Rewrote it to
      check the real thing (the question is one of `Questions.bank_for
      ("math")`'s own) instead of guessing at its shape.

      **Task 9 (Steam page) and Task 10 (audio brief) — ChatGPT's,
      saved as docs, no code.** Gemini's Steam page had no tagline,
      features or screenshot order; its audio brief was one
      unstructured paragraph against a prompt asking for named cues,
      lengths and moods. ChatGPT's followed the schema fully. Saved
      verbatim as `docs/STEAM_PAGE.md` and `docs/AUDIO_BRIEF.md` --
      copy only, nothing here touches balance, and no music or SFX
      assets exist yet for anything the brief names.

      **Task 11 (80 names) — ChatGPT's, all landed.** Gemini's list was
      24 adult names with no FIRST/LAST split and most well over the
      5-character hard limit (`Josephine`, `Penelope`, `Beatrice`) --
      rejected outright, not a partial. ChatGPT's 48 first / 32 surnames
      all landed inside 3–5 characters, none collided with the existing
      pool or each other. `names.gd`: 48 → 96 first, 32 → 64 surnames.

      1090 -> 1098 assertions (net zero from the new content itself --
      the only test change was the maths-homework rewrite). Balance
      contract re-verified (`Simulate a Term.bat`: still C / C / A).
      `check_docs.py` and `check_balance.py` both clean. Docs synced:
      the "content plan" and "content, counted" tables in `docs/GDD.md`,
      and `docs/SALVAGE.md`'s milestone count -- both had ALSO gone
      stale on traits (still said 6, live count has been 12 since a
      prior session) and that was fixed in passing.
- [x] **A one-key dev room, and a real bug in the panel that made it.**
      *(Aug 2026 -- user request: "make me a dev room with max coins,
      itms, stuudents, sstats, etc.")* The F1 dev panel already had
      individual cheats for all of this (coins, teacher, students,
      furniture, enrolling, growing the room) -- what was missing was one
      key to fire all of them in the right order. Found a real bug while
      wiring it: the "grow" cheat was listed in `CHEATS` with a label but
      had no case in `_do_cheat()`'s match, so pressing E on it silently
      did nothing but mark the run cheated. Refactored each cheat into
      its own function so "EVERYTHING (dev room)" can call them in an
      order that actually works -- coins BEFORE grow (growing costs
      money), grow BEFORE enrol/furnish (both need the extra floor).
      Screenshotted both the panel (`dev_room`) and the room it produces
      (`dev_room_bare`) to confirm coins, room size, roster and furniture
      all actually changed, not just the message line. Regression-tested
      directly against the debug panel's own `_do_cheat`, including the
      previously-silent `grow` case.
- [x] **An auto-play system: watch a delegated room play out.**
      *(Aug 2026 -- user request, "an auto play system for the game as
      well".)* Conflicts directly with "legwork, not judgement" if read
      as automating the PLAYER's own room, so asked first rather than
      guessing -- the user picked "watch a delegated room play out",
      which turns automation the game already considers legitimate (a
      hired NPC teacher's fixed archetype policy) from an invisible
      number into something you can actually watch happen.
      `RoomSim.play_day()` already RUNS the real lesson model for a
      delegated room once a day (`Game.resolve_rooms()`, called at the
      bell) -- it was never a formula, so nothing needed to be re-derived
      for honesty, only recorded. Added a `history` array to its
      existing tick loop: one frame a second (roster + who is at the
      front), appended into the SAME dict `resolve_rooms()` already
      stores as `room["last"]`, so playback is the identical roll that
      produced the letter, not a fresh, possibly-different one.
      New `V` key (global, not landmark-bound -- `Mode.WATCH`, #15) from
      the School screen, only offered once a room is staffed AND has a
      day behind it (`_can_watch()`). Steps through its own frames on
      the idle clock at a speed a person can watch, ends on the actual
      grade letter, `V` again skips straight to the bell, Esc backs out.
      Regression-tested (frames recorded, screen reachable/gated
      correctly, last frame's letter matches `resolve_rooms()`'s own,
      panel fits) and screenshotted mid-lesson. Balance contract
      re-verified after touching `room_sim.gd`'s tick loop -- all three
      rows still hold, `Simulate the School.bat` still shows archetypes
      producing genuinely different, sensible results.
- [x] **A dashboard, and what "two buttons is not enough" actually meant.**
      *(Aug 2026 -- user request.)* Checked the actual rule in CLAUDE.md
      before touching it: E/F were never "two buttons total", they are
      "no LANDMARK ever offers more than two" -- the game already had
      Tab/B/Q/P as dedicated global keys, unrelated to any landmark,
      before that rule was written down. A dashboard is not about
      anywhere you are standing, so it got the same treatment: a new
      global key (`I`), Mode.DASHBOARD as #14, E/F untouched.
      Three pages, cycled with the shop's own tab-cycling pattern:
      OVERVIEW (level, speciality, class size, room, coins, portrait, and
      two deliberately-empty Hat/Background lines -- the cosmetic slots
      were asked for and explicitly deferred, same pattern as the hand-
      size luck skill), ITEMS (what is owned, by category, reusing
      `cat_colour`/`_worth_bar` from the shop rather than re-inventing
      them), SKILLS (a read-only mirror of the staff room's perk bars --
      spending stays the staff room's job).
      Found a real, silent clipping bug while screenshotting it: the body
      panel does not scroll (`scroll_active = false`), and the true
      visual capacity at font 8 / line-separation 2 is BELOW what the
      `<= 11` logical-line-count assertion catches, since that assertion
      only counts `
` and cannot see a wrapped or simply-too-tall block
      clip silently. The Overview page's Background line was cut off on
      screen while its own line-count assertion still reported it fit.
      Trimmed for real margin rather than exactly at the arithmetic edge.
      CLAUDE.md's constraint itself reworded from "Two buttons" to "Two
      buttons per landmark" to say the true rule out loud, since the old
      wording was ambiguous enough to prompt this very question.
- [x] **The homework screen went silent, for real players, permanently,
      after the first room rebuild.** *(Aug 2026 -- real bug, user-
      reported: "we broke the homework page as now it shows nothing".)*
      Root cause: `RoomBuilder.add_prop()` puts the "room_part" group on
      the PROP (a StaticBody2D), not on the Interactable, which is a
      CHILD of that prop. `rebuild_room()` calls `queue_free()` on the
      prop; the child's own `is_queued_for_deletion()` stays false right
      up until the deferred free actually runs, even though
      `remove_child()` already took it out of the tree. `Game.new_run()`
      rebuilds the room every time, and the crash happened INSIDE
      `_pick_target()`, which aborts `_physics_process()` before `targets`
      ever refreshes -- so the marking desk went untargetable for the rest
      of the run, silently, no error a player would ever see, just a
      button that stopped doing anything.
      Fixed at both the caller (`player.gd`'s `_pick_target()`/`_live()`
      now check `is_inside_tree()`, the actual general check, not
      `is_queued_for_deletion()`) and the source (`marking_desk.gd`'s own
      `_carrier()` no longer calls `get_tree()` on a detached node). A
      dedicated regression test forces the exact rebuild path and polls
      immediately, no `await`, to hit the narrow window. Verified live:
      screenshotted the marking screen straight after a fresh
      `new_run()` and confirmed it renders real content.
      **Only `marking_desk.gd` called `get_tree()` directly** among all
      the Interactable subclasses -- checked, so this was not a wider
      pattern needing a sweep.
      **Found, not fixed, out of scope for that pass — fixed later
      (August 2026, dev-panel session):** `Placement._refresh()` threw
      `Cannot call method 'get_height' on a null value` on a null
      `_ghost.texture`. Confirmed none of the three real entry points
      (`begin`, `begin_desk`, `begin_browse`) can actually reach it —
      each either sets a real texture first or stays in `browsing`,
      which `_refresh()` returns out of before the line that crashed —
      so this was defensive, not a live player-facing bug. Fixed with a
      null-guarded height fallback and a regression test that builds
      the exact broken state by hand, since no real caller does.
- [x] **Grading felt too hard, and the hand of cards is now a real
      shuffle of 3-7.** *(Aug 2026.)* Grade LETTER bands (not the pillar
      itself) moved from hardcoded A .88/B .75/C .62/D .50/E .38 in
      `game.gd` to `data/balance.json`'s `grade_bands`, softened to
      A .85/B .73/C .55/D .42/E .30 -- the pillar's own bare-room-perfect
      row (0.63) sat one point above the old C floor, so realistic,
      imperfect-but-decent play landed in D. Contract re-verified
      unmoved: 0.63/0.71/0.97 still land C/C/A, now with real margin.
      `assignments.hand_size` (fixed at 3) became `hand_size_min`/`_max`
      (3-7), rolled fresh every draw via `Assignments.draw()`, with a
      test proving the size actually VARIES across draws rather than
      landing on the same number by seed coincidence. Added a shuffle
      flourish in `hud.gd` -- a brief riffling pip-row with a paper sound
      per frame -- that plays once on a freshly drawn hand and never on a
      page turn. Found and fixed a stale test that could only ever have
      passed by coincidence of a fixed 3-card hand: it checked that every
      card's title appeared on a single page, when the UI only ever shows
      one card at a time.
      **Left for later, on purpose:** a teacher LUCK skill (more, and
      eventually better, cards for a teacher who has earned it) was asked
      for but explicitly deferred. `hand_size_min`/`_max` in
      `data/balance.json` is the intended hook -- when that lands, it
      should read these rather than hardcoding a count anywhere.
- [x] **Integrate task 1 — 20 lessons.** Curriculum 20 → 40, concepts
      60 → 120. 15 verified codes, 5 honestly uncited. Added five
      assertions including the `short`-length check that nothing had ever
      enforced. Suite 1033 → 1038. *(Aug 2026)*
- [x] **Port the `/deep` commands and make doc drift fail loudly.**
      `tools/check_docs.py`, 271 checks. *(Aug 2026)*
