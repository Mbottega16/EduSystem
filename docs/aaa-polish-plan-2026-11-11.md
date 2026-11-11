# EduSystem — AAA Polish, Cutscenes, Dialogue & Conversions Master Plan

**Date:** 2026-11-11
**Baseline:** Branch `ui-overhaul-2026-11-10` (commit `16e8a96`), **3,291 assertions** across 151 sections, 341/341 doc checks passing, balance contract `0.63 C / 0.72 C / 0.97 A`.
**Designed by:** Argon (High) architectural pass, written specifically so **smaller, faster agents (Flash / Haiku / Sonnet)** can execute one phase per session with zero ambiguity.

---

## 1. Executive Vision: What Makes EduSystem Feel Like a Real AAA Indie Title

With Phases 0–12 of the UI Overhaul complete, EduSystem now has a unified tactile material system (`Chalkboard`, `PaperSheet`, `WoodPlank`, `DeskSheet.Kind.CLIPBOARD`, and `DeskSheet.Kind.DESK`). To elevate the game from a "well-built systems sim" to an unforgettable, **AAA-feeling pixel-art management RPG** (in the lineage of *Stardew Valley*, *Eastward*, *Persona*, and *Two Point Campus*), four layers must be completed:

1. **100% Material Conversions (Retiring the Last Dark Boxes):**
   - Thirteen secondary screens in `scripts/ui/hud.gd` (`SPECIALISM`, `PATHS`, `EXAM_PICK`, `HALL`, `STAGE`, `SKIP`, `SKIP_REPORT`, `TROPHIES`, `ADS`, `HELP`, `OFFICE`, `MENTOR`, `CALLER`), plus `scripts/ui/tutorial.gd` and `$DialogueBox`, still use the legacy dark bamboo `UI_FRAME` or `_paper_on()` overlay. Converting them onto `DeskSheet` and `UITheme` ensures the player **never** sees a programmer-art dark box anywhere in the game.
2. **Tactile Selection Options (Cards, Not Plain Text Lists):**
   - High-stakes choices—picking your teaching **Specialism**, choosing a **Term Path / Boss Card** at the term fork, assembling the **4-Subject Final Exam**, selecting **Age-Tier Captains** in the Hall, or answering a **Desk Caller**—currently render as plain `> row` text lines. Turning these into structured **Selection Cards** (with subject marks, clear trade-off tags, amber selection highlights, and handwritten preview notes) makes every decision feel weighty and physical.
3. **Two-Way Dialogue & Interactive Conversations (Talking *With* People, Not Being Talked *At*):**
   - Today, talking to the Mentor or Principal is a one-way page flip, and students never speak to you outside of random mid-lesson desk interruptions. Adding **multi-turn branching conversations** (`scripts/data/conversations.gd`), **After-School Student Check-Ins** ("A Word Before the Bell"), **Mentor Coaching & Student Advice Hubs**, and **Principal Grant/Policy Pitches** brings the cast to life.
4. **In-Engine Cutscenes & Stage Direction (`CutsceneDirector`):**
   - Today, only the Day 1 Intro and Mentor skill demos move actors on screen. Adding a lightweight, deterministic `CutsceneDirector` (letterbox bars, camera pans, scripted walks, emote bubbles, and dialogue beats) lets key milestones—the **Inspector's Walk-In**, the **Boss Examiner's Arrival**, the **End-of-Term Graduation Walk**, and the **Principal's Promotion Offer**—play out in the live classroom before handing control back to the player.

---

## 2. Hard Rules for Every Build Agent (Read Before Touching Code)

Every agent executing a phase in this plan **must** follow these rules without exception:

1. **Read First:** Read `CLAUDE.md` and `docs/ARCHITECTURE.md` before editing any file. Never scan `.godot/`, `shots/`, `*.import`, `*.uid`, or audio files.
2. **The Balance Contract (`0.63 C / 0.72 C / 0.97 A`) Must Not Move:**
   - Never modify `grade_for()`, `grade_class()`, or `tools/sim.gd`'s core grading math.
   - Dialogue choices, cutscenes, and after-school check-ins may award coins, reputation, cabinet items, temporary movement boosts, homework turn-in guarantees, or `StudentData.moments` entries, or coach a delegated teacher's `RoomSim` policy—**never** a raw multiplier on the player's classroom grade.
3. **Determinism (`Game.rng` Only):**
   - Global `randi()`, `randf()`, and `Array.shuffle()` are **banned**. Every random roll must use `Game.rng` or a deterministic hash of `(Game.term, Game.day, seat_index)`.
4. **Numbers Live in `data/balance.json`:**
   - Any gameplay tunable (durations, coin costs/rewards, reputation deltas, cooldowns) must live in `data/balance.json` with a matching `static var` in `scripts/data/balance.gd`. UI layout pixel coordinates and animation frame timings (`0.25s` tween) may be `const` in UI scripts.
5. **Prose, Never Numbers About a Child:**
   - Never print a decimal (`0.xx`) or numeric stat score standing in for a child's ability, understanding, or inspection score. Enforced by `tests/run.gd`.
6. **GDScript Formatting & Typing Discipline:**
   - **Indent `.gd` files with TABS only.** Spaces cause GDScript parse errors.
   - **Explicit Variant typing:** Godot 4 refuses `var x := dict.get("k", 0)` when the dictionary is untyped. Always write `var x: int = int(dict.get("k", 0))` or `var s := String(dict.get("k", ""))`.
   - **No colour literals in Design System files:** `scripts/ui/ui_theme.gd`, `scripts/ui/desk_sheet.gd`, `scripts/ui/title.gd`, and `scenes/ui/title.tscn` must contain **zero** `Color(...)` or `#hex` literals (enforced by `test_design_system()`). In `hud.gd`, always use `UITheme.color(&"token")` and `UITheme.hex(&"token")`.
   - **Preserve `hud.body.text`, `hud.title.text`, and `hud.hint.text`:** Existing tests in `tests/run.gd` assert on the plain-text contents of `hud.body.text`, `hud.title.text`, and `hud.hint.text`, and `test_panels_fit()` calls `hud._rich_overflows()`. When converting a screen in `hud.gd` onto `DeskSheet`:
     - Keep populating `title.text`, `body.text`, and `hint.text` (with `body.visible = false` when `rich` is used on `DeskSheet`).
     - Render the visible styled lines into `hud.rich.text` via `_sheet_join(rich_lines)` and run the bottom-up `_small_print()` overflow guard if `_rich_overflows()` is true.
     - On `DeskSheet.Kind.DESK`, pass at most **2–3 concise key caps** to `desk_sheet.set_keys(...)` so the right-aligned key caps never extend left of `x = 120` (where the wooden desk pencil sits at `x = 34..104`).
7. ** headless / Test Safety for Cutscenes & Tutorials:**
   - Any new cutscene or dialogue prompt that triggers automatically on a phase/day transition **must** check `if not Game.tutorials_enabled:` (or `if Game.save_path != Game.SAVE_PATH:` when appropriate) or complete instantaneously in headless test runs so `tools/playterm.gd` (`Play a Whole Term.bat`) and existing `tests/run.gd` sections are never blocked by unexpected modal prompts.
8. **End-of-Phase Verification Protocol:**
   - Run `Run Tests.bat 1` and verify `ALL EDUSYSTEM CHECKS PASSED` with a higher assertion count.
   - Sync the new assertion count (written without commas, e.g. `3305 assertions`) across `CLAUDE.md`, `AGENTS.md`, `README.md`, `docs/GDD.md`, and `docs/SALVAGE.md`.
   - Run `python tools/check_docs.py` (must pass 341/341) and `python tools/check_balance.py`.
   - Capture before/after screenshots using `Take a Screenshot.bat <screen>` and visually inspect the PNGs.

---

## 3. Phase-by-Phase Implementation Plan

### Phase 13 — Remaining UI Conversions, Part 1: Selection & Progression Screens
**Size:** Medium · **Target Files:** `scripts/ui/hud.gd`, `tools/shot.gd`, `tests/run.gd`

**Goal:** Convert the 5 progression/selection screens (`SPECIALISM`, `PATHS`, `EXAM_PICK`, `HALL`, `STAGE`) from the legacy dark bamboo window onto `DeskSheet`, upgrading their plain text rows into scannable **Selection Cards**.

#### 13.1 `show_specialism()` (`Mode.SPECIALISM`)
- **Surface:** `_sheet_on(DeskSheet.Kind.DESK, DAY_SHEET_RECT)`.
- **Heading & Tag:** `desk_sheet.set_heading("CHOOSE YOUR SPECIALISM", "YOUR TRAINING & FOCUS", "SPECIALISM", &"olive")`.
- **Key Caps:** `[[_key_cap("interact"), "choose"], ["Esc", "later"]]` (2 caps, clear of pencil).
- **Selection Cards in `rich`:**
  - Keep `body.text` and `title.text` populated as today for test compatibility; set `body.visible = false`.
  - Render each of the 4 strands (`math`, `ela`, `science`, `social`) as a structured 2-line card row:
    - Selected row highlighted with `_highlighted("[color=#%s]> [img=16x16]res://art/icon_%s.png[/img] %s[/color]" % [UITheme.hex(&"ink"), strand_icon, label], &"amber")`.
    - Right side / second line shows the specialism benefit in `olive` (`"Lessons in %s pay extra coins and XP"`), with a handwritten `_note()` at the bottom of the sheet: `"You can teach every subject; your specialism is the one that feels like home."`

#### 13.2 `show_term_paths()` (`Mode.PATHS` — Term Fork & Boss Card Selection)
- **Surface:** `_sheet_on(DeskSheet.Kind.DESK, DAY_SHEET_RECT)`.
- **Heading & Tag:**
  - Ordinary fork: `desk_sheet.set_heading("THE TERM AHEAD", "TERM %d · CHOOSE ONE PATH" % Game.term, "TERM PATH", &"amber")`.
  - Boss fork: `desk_sheet.set_heading("ASSESSMENT TERM", "TERM %d · CHOOSE THE PAPER" % Game.term, "BOSS EXAM", &"terracotta")`.
- **Key Caps:** `[["Up/Down", "choose"], [_key_cap("interact"), "take this path"]]`.
- **Selection Cards in `rich`:**
  - Each offered card (`Game.term_choices`) renders with its title in bold `amber` (when selected) or `ink`, its stake/modifier tag in `olive` or `terracotta`, and its full description in `_note()` below the card list so the player sees the exact rules of the selected card before pressing `E`.

#### 13.3 `show_exam_picks()` / `_render_exam_picks()` (`Mode.EXAM_PICK`)
- **Surface:** `_sheet_on(DeskSheet.Kind.CLIPBOARD, Rect2(24, 18, 592, 324))`.
- **Heading & Tag:** `desk_sheet.set_heading("FINAL ASSESSMENT", "CHOOSE ONE LESSON PER SUBJECT (%d/4)" % picked_count, "EXAM PAPER", &"amber")`.
- **Top-Right Card:** `desk_sheet.set_cards([["CHOSEN", "%d / 4" % picked_count, &"olive" if picked_count == 4 else &"amber"]])`.
- **Key Caps:** `[["Up/Down", "lesson"], [_key_cap("interact"), "pick"], ["Esc", "close"]]`.
- **Body (`rich`):** Show the 4 strand slots at the top (with `[img=14x14]` strand icons and either the chosen lesson name in `olive` or `"— pick below —"` in `pencil`), followed by the windowed lessons for the current strand with mastery badges (`taught N times`).

#### 13.4 `show_hall()` / `_render_hall()` (`Mode.HALL` — Age-Tier Promotion Captains)
- **Surface:** `_sheet_on(DeskSheet.Kind.DESK, DAY_SHEET_RECT)`.
- **Heading & Tag:** `desk_sheet.set_heading("MOVING UP TO %s" % next_stage.to_upper(), "CHOOSE UP TO %d TO COME WITH YOU" % cap, "PROMOTION", &"olive")`.
- **Stamp:** `desk_sheet.set_stamp("%d / %d" % [picked.size(), cap], &"olive")`.
- **Key Caps:** `[[_key_cap("interact"), "pick / unpick"], [_key_cap("manage"), "begin term"]]`.
- **Body (`rich`):** Each qualifying child rendered with `[KEEP]` badge in `olive` when picked, their level, favourite subject, and trait note.

#### 13.5 `show_stage()` (`Mode.STAGE` — Grade Wing Plaque Card)
- **Surface:** `_sheet_on(DeskSheet.Kind.CLIPBOARD, Rect2(36, 28, 568, 284))`.
- **Heading & Tag:** `desk_sheet.set_heading(stage_name.to_upper(), subtitle, "GRADE WING", &"wood_dark")`.
- **Top-Right Card:** Shows `CURRENT` in `olive`, `LOCKED` in `pencil`, or `FEE: %d` in `amber`.
- **Key Caps:** `[[_key_cap("manage"), "move up"], ["Esc", "close"]]` when available, or `[["Esc", "close"]]`.

#### 13.6 Verification & Screenshots for Phase 13
- Add assertions in `tests/run.gd` (`test_design_system`) verifying `show_specialism`, `show_term_paths`, `show_exam_picks`, `show_hall`, and `show_stage` all turn `hud.desk_sheet.visible == true` and `!hud._rich_overflows()`.
- Capture screenshots: `specialism`, `exam_picks`, `stage_card`, `stage_moved`.

---

### Phase 14 — Remaining UI Conversions, Part 2: Overlays, Trophies, Skip, Ads & Tutorials
**Size:** Medium · **Target Files:** `scripts/ui/hud.gd`, `scripts/ui/tutorial.gd`, `tests/run.gd`

**Goal:** Convert the remaining utility/corridor screens (`SKIP`, `SKIP_REPORT`, `TROPHIES`, `ADS`, `HELP`) and the in-room `Tutorial` cutscene panel (`scripts/ui/tutorial.gd`) onto `DeskSheet` and `UITheme`.

#### 14.1 `show_skip()` and `show_skip_report()` (`Mode.SKIP`, `Mode.SKIP_REPORT`)
- **`show_skip()`:** Move onto `DeskSheet.Kind.CLIPBOARD` (`Rect2(48, 36, 544, 268)`) with tag `"DELEGATE"`, heading `"STEP AWAY FROM THE ROOM"`, top-right card `["DAYS", "%d" % _skip_days, &"amber"]`, and key caps `[["Left/Right", "days"], [_key_cap("interact"), "hand over"], ["Esc", "stay"]]`.
- **`show_skip_report()`:** Move onto `DeskSheet.Kind.DESK` (`DAY_SHEET_RECT`) with tag `"SUMMARY"`, heading `"WHILE YOU WERE AWAY"`, tilted stamp `"%d DAYS" % days_run`, right-hand ledger showing total coins earned and purse, and per-day summary rows on the left.

#### 14.2 `show_trophies()` (`Mode.TROPHIES` — Hallway Trophy Case)
- **Surface:** `_sheet_on(DeskSheet.Kind.DESK, DAY_SHEET_RECT)`.
- **Heading & Tag:** `desk_sheet.set_heading("THE TROPHY CASE", "BOSS TERMS CONQUERED", "HONOURS", &"amber")`.
- **Stamp:** `desk_sheet.set_stamp("%d / %d" % [Game.trophies.size(), Trophies.count()], &"olive" if Game.trophies.size() > 0 else &"pencil")`.
- **Key Caps:** `[["Up/Down", "shelf"], ["Esc", "close"]]`.
- **Body (`rich`):** Won trophies in bold `amber` with `[WON]` badge in `olive`; unwon trophies as `- - -` in `pencil`; selected trophy blurb in `_note()` at the bottom.

#### 14.3 `show_ads()` (`Mode.ADS` — Noticeboard Grant / Sponsor Poster)
- **Surface:** `_sheet_on(DeskSheet.Kind.CLIPBOARD, Rect2(44, 28, 552, 284))`.
- **Heading & Tag:** `desk_sheet.set_heading("SPONSORSHIP BOARD", "OPTIONAL FUNDING GRANTS", "GRANT", &"olive")`.
- **Top-Right Card:** `["PURSE", "%d" % Game.coins, &"amber"]`.
- **Body (`rich`):** Each tier row styled as a clean grant slip with duration in `pencil` and coin grant in `olive`.

#### 14.4 `show_help()` (`Mode.HELP` — In-Play Controls Sheet)
- **Surface:** `_sheet_on(DeskSheet.Kind.CLIPBOARD, Rect2(32, 16, 576, 316))`.
- **Heading & Tag:** `desk_sheet.set_heading("CLASSROOM KEYS", "YOUR VERBS & SHORTCUTS", "CONTROLS", &"wood_dark")`.
- **Key Caps:** `[["Up/Down", "scroll"], ["Esc", "close"]]`.
- **Body (`rich`):** Two-column alignment of action labels (`ink`) and live bound keys (`amber` in brackets).

#### 14.5 `scripts/ui/tutorial.gd` & `hud.gd` Speech/Mascot Boxes
- In `scripts/ui/tutorial.gd`:
  - Replace `_panel = hud._nine_patch(hud.UI_FRAME, ...)` with a `Panel` using `UITheme.box(&"PaperSheet")` (or apply `UITheme` colours and border tokens so the bamboo frame is retired).
  - Style `_face` with a 2px `wood` border frame (`UITheme.box(&"PaperCard")`), `_title` in `UITheme.color(&"wood_dark")`, `_text` in `UITheme.color(&"ink")`, and `_hint` in `UITheme.color(&"pencil")`.
- In `scripts/ui/hud.gd`:
  - Upgrade `dialogue_box` (`$DialogueBox`) and `mascot_box` (`$MascotBox`) to use `UITheme` paper/wood styling instead of raw colour rects.

#### 14.6 Verification & Screenshots for Phase 14
- Add assertions in `tests/run.gd` verifying `show_skip`, `show_skip_report`, `show_trophies`, `show_ads`, `show_help`, and `tutorial.gd` panel styling.
- Capture screenshots: `skip`, `skip_report`, `trophies`, `ads`, `help_sheet`, `tutorial_quiz`.

---

### Phase 15 — Interactive Dialogue Engine & Two-Way Mentor, Principal & Caller Conversations
**Size:** Medium–Large · **Target Files:** `scripts/data/conversations.gd` (new), `scripts/data/complications.gd`, `scripts/ui/hud.gd`, `scripts/main.gd`, `tests/run.gd`

**Goal:** Convert `CALLER`, `MENTOR`, and `OFFICE` onto the tactile paper/desk-sheet system and transform them from static monologues into **two-way interactive conversations with selection options**.

#### 15.1 Convert `show_caller()` (`Mode.CALLER`) onto Tactile Paper Choice Cards
- **Surface:** Instead of the full-screen dark `OVERLAY_COLOUR` (`0.93` alpha) that hides the lesson clock and classroom, `show_caller()` uses `_sheet_on(DeskSheet.Kind.CLIPBOARD, Rect2(44, 28, 552, 284))` (which dims the room by at most `22%`, keeping the live classroom and lesson clock visible!).
- **Portrait:** Pin the speaker's 64×64 portrait (`portrait_principal.png`, `portrait_mentor.png`, `portrait_staff_*.png`, or `portrait_<student>.png`) at the top-right of the clipboard via `_portrait_at(Rect2(516, 42, 56, 56))`.
- **Choice Options:** Render each choice in `_caller_row["choices"]` as a highlighted **Choice Card row** (`>` in `amber`, bold `ink` label on an `amber` highlight strip when selected), and when answered (`_caller_said != ""`), render their reply in `_note()` (`Patrick Hand` 18px).
- **Expand `Complication.TABLE` (`scripts/data/complications.gd`):**
  - Add 3 new characterful desk callers (using existing `EFFECTS` only—`coins`, `reputation`, `disrupt_one`, `item`, `boost`—so `test_callers()` passes automatically):
    1. `"colleague_swap"`: A colleague asks to swap spare classroom supplies (` Give them a hand` → `+2.0 reputation`, `-20 coins`; `Trade for their spare plant` → `-15 coins`, `item: "plant"`).
    2. `"parent_checkin"`: A parent asks for a quick word about how their child is settling in (`Reassure them warmly` → `+1.5 reputation`, `boost`; `Be blunt about the workload` → `+15 coins`, `disrupt_one`).
    3. `"student_idea"`: A student asks to try a harder extension problem on the board (`Let them lead for a minute` → `boost`, `+1.0 reputation`; `Keep them on today's sheet` → `+10 coins`).

#### 15.2 Interactive Principal's Office (`show_office()` in `scripts/ui/hud.gd`)
- **Surface:** Move `show_office()` onto `DeskSheet.Kind.DESK` (`DAY_SHEET_RECT`) with heading `"THE PRINCIPAL'S OFFICE"`, sub-heading `"SCHOOL STANDING: %s" % Game.reputation_words().to_upper()`, tag `"OFFICE"`, and `PRINCIPAL_PORTRAIT` pinned via `_portrait_at(Rect2(552, 16, 48, 48))`.
- **Interactive Selection Options (Dialogue Hub at Bottom of Sheet):**
  - Alongside Up/Down tip browsing and `E` for the Career list, add a **Topic / Action selector** on `Left/Right` (or rows at the bottom of Page 0) when `Game.admin_unlocked()`:
    1. **`"Open the full career & alumni record"`** (existing `E` action → `show_career()`).
    2. **`"Pitch for a classroom supply grant"`** (once per term, tracked via `Game.term_grant_claimed: bool` in `game.gd`):
       - Opens a 3-choice pitch right on the sheet:
         - *"Point to our recent exam & inspection results"* (succeeds if `Game.reputation >= 55.0` or last term passed cleanly → grants `Balance.office_grant_coins` e.g. `45` coins; Principal replies in `_note()`).
         - *"Ask for a piece of surplus furniture from storage"` (succeeds once per term if `Game.roster.size() >= 6` → adds `"stool"` or `"plant"` to `Game.cabinet`; costs `1.0` reputation).
         - *"Never mind—we can manage on our own"` (no cost).
- **Important Invariant:** Keep `hud.rich.text` containing `"The school is %s"` and `"Milestones"` on `_sel == 0`, and `"TIP %d of %d"` on `_sel > 0`, and keep `E` on `_sel == 0` (when on the default Career option) opening `show_career()` so all existing `test_hallway()` / `test_office` assertions pass!

#### 15.3 Interactive Mentor Room Consultations (`show_mentor()` in `scripts/ui/hud.gd`)
- **Surface:** Keep the Mentor's first-visit teaching sequences (`TEACH`, `CHAIN_INTRO`, `CHAIN_AFTER`, `CALL`) working identically for every existing test in `test_mentor()`, while styling the Mentor's sheet with `UITheme` tokens.
- **Upgrade Revisit (`MentorTalk.IDLE` / `MentorTalk.READ`):**
  - Once all three mentor moves are taught (`dash_taught`, `chain_dash_taught`, `call_response_taught`), visiting the Mentor offers **3 interactive consultation options** (`Up/Down` to pick, `E` to ask, `Esc` to close):
    1. **`"Read my room for the upcoming assessment"`** → Shows `_mentor_readiness_text() + _mentor_tactic_text()`.
    2. **`"Ask about a child who is struggling"`** → Deterministically picks the student on `Game.roster` with the lowest average grade or most stalls, and the Mentor gives specific, trait-aware seating & furniture advice in prose (e.g., *"Sit %s away from the noisy ones and put a lamp or bookshelf within reach."*).
    3. **`"Ask how to coach my hired staff"`** (shown when `Game.rooms.size() > 0`) → Names your first staffed room's teacher and diagnoses their `Staff.weakness(t)` with actionable advice.

#### 15.4 Verification & Screenshots for Phase 15
- Verify `test_mentor()`, `test_callers()`, and `test_hallway()` pass 100%, plus add new assertions in `test_design_system()`.
- Capture screenshots: `caller`, `mentor_talk`, `office`, `office_career`, `office_locked`.

---

### Phase 16 — After-School Student Conversations ("A Word Before the Bell")
**Size:** Medium · **Target Files:** `scripts/data/conversations.gd` (new), `scripts/world/classroom.gd`, `scripts/interact/desk_station.gd`, `scripts/ui/hud.gd`, `tests/run.gd`

**Goal:** Make students feel like real individuals you mentor, not just sprites with progress bars. After a lesson ends (`Game.Phase.AFTERNOON`), one student who had a notable lesson lingers with a thought/speech bubble. Walking up to their desk lets you have a short, **branching 1-on-1 conversation with 3 pedagogical choices**.

#### 16.1 How It Works Mechanically (Zero Impact on Balance Contract)
- **When it triggers:** When `end_lesson()` transitions to `Game.Phase.AFTERNOON`, `Classroom` deterministically picks **at most one** seated child (`afternoon_talk_seat: int`) who either:
  - Got stuck 2+ times during the lesson,
  - Had a flare-up or disruption during the lesson,
  - Joined the class today (`joined_day == Game.day`), or
  - Finished their work first.
- **Visual cue in the room:** That child shows a soft speech/thought bubble (`...`) during `Phase.AFTERNOON`.
- **Landmark interaction (`desk_station.gd`):**
  - During `Phase.AFTERNOON`, once homework on that desk (if any) is collected, standing at `afternoon_talk_seat`'s desk offers `E: Talk to <FirstName>` (`uses_key = Key.USE`, reversible/optional before ringing the bell).
- **The Conversation (`hud.show_student_talk(student, topic)` on `DeskSheet.Kind.CLIPBOARD`):**
  - Shows the child's portrait, their opening line (keyed to their `trait_id` and what happened in the lesson—12 trait voices in `scripts/data/conversations.gd`), and **3 Teacher Response Options**:
    1. **Warm Encouragement (*"Show them what they got right first"*):**
       - Effect: Guarantees the child hands in homework tomorrow morning (`student.guaranteed_hw_tonight = true`) and logs a `"talk_encouraged"` moment in `student.moments`.
    2. **Peer Connection (*"Ask them to compare notes with their neighbour tomorrow"*):**
       - Effect: Gives a small coin/XP tip (`+8 coins`) and logs a `"talk_paired"` moment in `student.moments`.
    3. **Quiet Focus (*"Give them a quiet strategy for when the room gets loud"*):**
       - Effect: Narrows their effective whisper distraction radius by `1` tile for tomorrow's lesson (`student.calm_tomorrow = true`) and logs a `"talk_focused"` moment in `student.moments`.
- **Why this is 100% Contract-Safe:** `tools/sim.gd` never runs `Phase.AFTERNOON` desk conversations, and none of the three outcomes alters `grade_for()`'s room/lesson/homework weights.

#### 16.2 Verification & Screenshots for Phase 16
- Add a new test section `== STUDENT CONVERSATIONS ==` in `tests/run.gd` testing:
  - Afternoon talk candidate selection is deterministic.
  - Opening `show_student_talk()` displays the child's portrait, trait-specific line, and 3 choices on `DeskSheet.Kind.CLIPBOARD`.
  - Selecting each choice applies its effect, logs a moment to `StudentData.moments`, and clears `afternoon_talk_seat` for the day.
- Add screenshot target `student_talk` in `tools/shot.gd` and capture `docs/ui-audit-2026-11-10/after/student_talk.png`.

---

### Phase 17 — In-Engine Cutscene Director & 4 Signature Classroom Cutscenes
**Size:** Medium–Large · **Target Files:** `scripts/world/cutscene_director.gd` (new), `scripts/world/classroom.gd`, `scripts/ui/hud.gd`, `scripts/main.gd`, `tests/run.gd`

**Goal:** Build a clean, deterministic stage-direction helper (`CutsceneDirector`) with cinema letterbox bars, scripted actor walks, poses, emotes, and dialogue beats—and stage **4 signature cutscenes** that make the school year feel like a directed story.

#### 17.1 `scripts/world/cutscene_director.gd` (`class_name CutsceneDirector extends Node`)
- **Letterbox Bars:** Adds two `ColorRect` bars (`top_bar`, `bottom_bar`, height `24px`, colour `UITheme.color(&"ink")`) inside `$UI/HUD` that slide in over `0.25s` when a cutscene starts and slide out when it ends.
- **Step Queue API:**
  - `walk_actor(actor, target_world_pos, facing_dir)`
  - `pose_actor(actor, pose_col, seconds)`
  - `bubble_actor(actor, mark_tex, colour, seconds)`
  - `camera_bump(strength)` / `puff_at(pos)`
  - `say(speaker_name, portrait_tex, text, choices_array)` (uses the upgraded `$DialogueBox` on `PaperSheet` + `WoodFrame`)
- **Skip & Headless Safety:**
  - Pressing `Esc` at any point during a cutscene immediately fast-forwards all actors to their end positions, hides the letterbox bars, and finishes the cutscene (`skip()`).
  - When `not Game.tutorials_enabled` (all headless tests, `sim.gd`, `playterm.gd`) and `not CutsceneDirector.force_in_test`, cutscenes execute their final state immediately in `0` frames so no automated test or walkthrough ever hangs.

#### 17.2 The 4 Signature Cutscenes
1. **Cutscene 1 — Upgraded Day 1 Opening (`show_intro` / `_start_intro_cutscene`):**
   - Style the `MONDAY` title slate (`_sel == -1`) on `UITheme`'s `Chalkboard` with `Kalam` chalk lettering (matching the Phase 1 Title Screen!).
   - Add letterbox bars while the teacher walks from the door to the cabinet, pulls out the desks (`Fx.land` + dust puffs), and watches the initial 4 students walk in through `Layout.DOOR` and wave (`play_pose`) as they take their seats.
2. **Cutscene 2 — The Inspector's Knock (Morning of an `inspector` DayEvent):**
   - When a day begins with `Game.being_inspected()`, `world.refresh_inspector()` places the inspector at the door first; during a 3-second cutscene on real play, the Inspector walks from `Layout.DOOR` to their observation tile, looks around the room, and speaks one line based on `Game.room_score(0)`:
     - Bare room: *"Clipboard out. Let us see what you can do with four walls and chalk."*
     - Furnished room: *"You have put real work into this room. Let us see if the teaching matches it."*
3. **Cutscene 3 — The Subject Boss Arrival ("Papers on the Desk"):**
   - When `start_boss_fight()` is triggered at the podium on Day 20 of a Boss Term, the Examiner steps up to the front with a camera bump (`_bump(1.5)`), and you get a **3-option Pre-Exam Pep Talk** before the timer starts:
     - *"Take a breath. Read the question twice."* (Starts the fight with composure steady and a 2-second grace buffer on the first question).
     - *"Look around you—the answers are in this room."* (Highlights the podium/room with an encouraging `Fx.puff` across all desks).
     - *"Just do what we practised."* (Starts immediately).
4. **Cutscene 4 — End-of-Term Graduation Walk:**
   - When a term is won (`exam_passed`), before the New Term sheet opens, the students who met the target stand up, cheer, and walk toward `Layout.DOOR`, with your top/focus graduate pausing to deliver a 1-line farewell in `$DialogueBox` drawn from their `trait_id`.

#### 17.3 Verification & Screenshots for Phase 17
- Add `test_cutscenes()` in `tests/run.gd` (with `CutsceneDirector.force_in_test = true` for that section, then `false`) asserting that:
  - Letterbox bars appear when a cutscene starts and hide on `skip()` or completion.
  - The Monday intro slate uses `Chalkboard` / `UITheme` tokens.
  - The Inspector arrival and Pre-Exam Pep Talk choices work cleanly and never alter the balance contract.
- Capture screenshots: `intro`, `intro_walk`, `inspector_here`.

---

### Phase 18 — Principal's Rounds, Counselor Shift, Teacher Coaching & Promotion Cutscene
**Size:** Large · **Target Files:** `scripts/roles/rounds_shift.gd` (new), `scripts/roles/calm_shift.gd` (new), `scripts/interact/calm_spot.gd` (new), `scripts/data/duties.gd`, `scripts/world/visit_room.gd`, `scripts/ui/hud.gd`, `scripts/main.gd`, `tests/run.gd`

**Goal:** Complete the school-layer arc from `roles-design.md` and `docs/SIM_FORMULAS.md`:
1. **Principal's Rounds (`rounds` duty — `build-plan-2026-11-06.md` Task 5):**
   - Walk into a staffed room you hold. Dash across the room's floor grid (`3×3` tiles light up per dash) before the clock runs out.
   - Completing a full observation reveals that teacher's strength and weakness on the `DeskSheet.Kind.CLIPBOARD` duty report (`show_duty_report`) and unlocks **Coaching** for that teacher!
2. **Counselor Shift (`counselor` duty — `build-plan-2026-11-06.md` Task 6):**
   - Walk into a staffed room. Calm boiling-over students (`E` at their desk before the yellow-to-red fuse bubble pops; 3 strikes or clock end).
   - A clean shift boosts school reputation, pays `calm_bonus_coins`, and calms that room's next day.
3. **Coaching Delegated Teachers ("Teaching Teachers How to Teach" — `docs/SIM_FORMULAS.md`):**
   - Once you have observed a delegated room via **Principal's Rounds**, pressing `C` (or choosing **Coach Teacher** on `show_school()` / `VisitRoom`) lets you spend coins/XP to coach that teacher up one tier (`coaching_level 1..5` from `docs/SIM_FORMULAS.md`), reducing their reaction delay $R(\ell)$ or teaching them to `settle` / `quiz` in `RoomSim`!
4. **The Promotion Cutscene (`roles-design.md` R4):**
   - When your classroom has passed 3+ terms with an `A` or `B` class average and `Game.admin_unlocked()` is true, visiting the Principal's Office triggers a **Promotion Offer Cutscene**: the Principal offers you the Headship (with a clear **Accept / Stay in My Classroom** selection card).

---

## 4. Recommended Execution Order for Smaller Agents

Each phase below is sized so a single **Flash / Haiku / Sonnet** session can complete it, run the test suite, take the screenshots, and commit in ~15–20 minutes:

| Phase | Scope | Key Deliverable | Est. New Assertions |
|---|---|---|---|
| **Phase 13** | Conversions & Selection Cards, Part 1 | `SPECIALISM`, `PATHS`, `EXAM_PICK`, `HALL`, `STAGE` on `DeskSheet` with Selection Cards | +8 assertions |
| **Phase 14** | Conversions & Selection Cards, Part 2 | `SKIP`, `SKIP_REPORT`, `TROPHIES`, `ADS`, `HELP`, `tutorial.gd`, and `$DialogueBox` on `UITheme`/`DeskSheet` | +8 assertions |
| **Phase 15** | Two-Way Dialogue & Choice Hubs | `CALLER` on clipboard, expanded `Complication.TABLE`, interactive `OFFICE` grants & `MENTOR` consultations | +10 assertions |
| **Phase 16** | After-School Student Conversations | `"A Word Before the Bell"` 1-on-1 student check-ins in `Phase.AFTERNOON` with 3 pedagogical choices & `moments` | +8 assertions |
| **Phase 17** | Cutscene Director & 4 Classroom Cutscenes | `CutsceneDirector` (letterbox, walks, poses, skip) + Intro Chalk Slate, Inspector Walk-In, Boss Pep Talk, Graduation Farewell | +10 assertions |
| **Phase 18** | Admin Duties, Coaching & Promotion | `RoundsShift`, `CalmShift`, Teacher Coaching (`SIM_FORMULAS.md`), and Principal's Promotion Cutscene | +16 assertions |

---

## 5. Master Kickoff Prompt for Smaller Agents (Copy-Paste)

Use this exact prompt when launching a smaller agent (e.g., Gemini Flash, Claude Haiku, or Sonnet) for any phase:

```text
Read the EduSystem AAA Polish Master Plan in full before doing anything:
- Vault copy: C:\Users\mbott\OneDrive\Desktop\AI Projects\my-brain\projects\edusystem\aaa-polish-plan-2026-11-11.md
- Repo copy: C:\Users\mbott\OneDrive\Desktop\EduSystem\docs\aaa-polish-plan-2026-11-11.md

Also read C:\Users\mbott\OneDrive\Desktop\EduSystem\CLAUDE.md and docs/ARCHITECTURE.md and follow Section 2 ("Hard Rules for Every Build Agent") of the AAA Polish Master Plan strictly.

Execute ONLY Phase [N] in this session:
1. Make the code edits for Phase [N] (use tabs for indentation in .gd files, explicit Variant types, and UITheme tokens).
2. Keep hud.body.text, hud.title.text, and hud.hint.text populated for existing test compatibility while rendering onto DeskSheet / hud.rich.
3. Add the Phase [N] unit test assertions in tests/run.gd and run `Run Tests.bat 1`. Verify 0 failures and a higher assertion count.
4. Sync the new assertion count across CLAUDE.md, AGENTS.md, README.md, docs/GDD.md, and docs/SALVAGE.md, then run `python tools/check_docs.py` (must be 341/341 green).
5. Capture the Phase [N] screenshots with `Take a Screenshot.bat <screen>` and inspect them visually.
6. Log the session in HISTORY.md and CLAUDE.md Session Handoff, commit, and stop for my review.
```
