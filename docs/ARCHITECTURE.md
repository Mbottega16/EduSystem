# EDUSystem — architecture map

A picture of how the pieces fit, for orienting before you dive into a file.
It is deliberately **stable**: it names modules and files, not counts or
tuning. A new sprite, a changed number, a bug fix never touch this document.
Revise it only when a whole system is **added or removed**.

- **What the game is**, in prose: [`docs/GDD.md`](GDD.md). If this file and
  the GDD disagree, the GDD wins. If the GDD and the running game disagree,
  the game wins.
- **The file-by-file map** with one-line jobs: the table in
  [`CLAUDE.md`](../CLAUDE.md) / [`AGENTS.md`](../AGENTS.md).
- The diagrams are Mermaid. GitHub renders them in place; VS Code renders
  them in Markdown preview.

---

## 1. Module map — who owns what, who talks to whom

```mermaid
flowchart TB
    subgraph AUTO["Autoloads - always alive (project.godot)"]
        GAME["Game<br/>the run: day, phase, roster, RNG,<br/>grading, terms, economy, perks, save"]
        SET["Settings"]
        SFX["Sfx"]
        MUS["Music<br/>beds and stings, crossfaded"]
    end

    subgraph WORLD["World - the live scene (scripts/world/)"]
        CLASS["Classroom<br/>world root: lesson clock, the day,<br/>bubbles, ambient weather"]
        GRID["grid / layout /<br/>room_builder / placement"]
        HALL["hallway / mentor_room"]
    end

    subgraph ACT["Actors (scripts/actors/)"]
        PLAYER["player - you<br/>per-button targeting,<br/>hold-to-confirm, autopilot"]
        STUD["student x class<br/>both extend actor"]
    end

    subgraph INT["Interactables - the verbs (scripts/interact/)"]
        LAND["podium, bell, noticeboard, desks,<br/>your desk, marking, homework,<br/>curriculum board, ...<br/>all extend interactable"]
    end

    subgraph UI["UI (scripts/ui/)"]
        HUD["hud<br/>every screen, one Mode at a time"]
        UIX["title, fx, floater,<br/>homework_sheet, debug_panel"]
    end

    subgraph DATA["Data layer - mostly static (scripts/data/)"]
        BAL["balance<br/>loads balance.json into tunable vars"]
        CURR["curriculum, items, traits,<br/>assignments, questions,<br/>cosmetics, milestones, names"]
        SDATA["student_data<br/>one child's whole record"]
        RSIM["room_sim<br/>a teacher as a POLICY<br/>= a hired teacher / a delegated room"]
        PROG["progress<br/>every perk effect, in one place"]
    end

    subgraph FILES["Data files (data/)"]
        BJSON["balance.json<br/>every tunable number"]
        CJSON["curriculum.json<br/>lessons and concepts"]
    end

    subgraph TOOLS["Tools - separate, read the same data (tools/)"]
        TSIM["sim - the balance contract"]
        TWALK["playterm - a whole term via real buttons"]
        TSCHOOL["schoolsim - delegated rooms"]
        TART["curator / master_forge - art"]
        TAUD["audit - every landmark, every phase"]
    end

    BJSON --> BAL
    CJSON --> CURR
    BAL --> GAME
    CURR --> GAME
    SDATA --> GAME
    PROG --> GAME

    CLASS -->|ticks the class model| GAME
    PLAYER -->|targets| LAND
    LAND -->|claim_action then a Game verb| GAME
    GAME -->|signals only| HUD
    GAME -->|signals only| MUS
    CLASS --> GRID
    GAME -->|delegated room / auto_teach| RSIM

    TSIM --> BJSON
    TWALK --> GAME
    TSCHOOL --> RSIM
```

**The one rule that keeps this untangled:** `Game` never reaches into the
HUD or Music. It emits signals (`phase_changed`, `day_changed`,
`coins_changed`, `roster_changed`, `run_started`); they listen. A landmark
never mutates run state directly either — it calls `Game.claim_action()` to
win the keypress, then a named `Game` verb.

---

## 2. The day — a three-phase state machine

Every verb in the game is gated on `Game.Phase`. That single rule is what
keeps the day coherent.

```mermaid
stateDiagram-v2
    [*] --> MORNING

    MORNING: MORNING
    MORNING: class files in and sits down
    MORNING: mark yesterday's homework, blind
    MORNING: podium deals 3 lesson plans, you set one

    LESSON: LESSON
    LESSON: lesson clock runs, about 45s
    LESSON: teach in radius fills attention, work advances with it
    LESSON: children get stuck, mess about, or fall behind
    LESSON: collect work, optional quiz on Q, unit test is a silent variant

    AFTERNOON: AFTERNOON
    AFTERNOON: hand work in at your desk
    AFTERNOON: ring the bell held, grades pay coins, upkeep is charged
    AFTERNOON: homework goes out on a diligence roll

    EXAM: EXAM
    EXAM: term grade vs the target seat count
    EXAM: boss term instead judges class average vs the card's bar

    MORNING --> LESSON: set a plan
    LESSON --> AFTERNOON: clock ends, or end early on F
    AFTERNOON --> MORNING: next day, autosave
    AFTERNOON --> EXAM: after 20 days
    EXAM --> MORNING: pass, next_term keeps room and perks, loses the class
    EXAM --> [*]: sustained miss, run_over, career screen

    note right of LESSON
        Side rails that step OUTSIDE the played lesson:
        auto_teach hands the whole lesson to room_sim
        skip_days hands the room over for up to 5 days
        Both resolved by the same policy sim a hired teacher runs.
    end note
```

See GDD §4 (the core loop) and §9 (failure).

---

## 3. The grade pipeline — behaviour in, coins and cosmetics out

The loop most worth having a picture of: how a child's day at a desk becomes
a letter, money, and eventually new furniture.

```mermaid
flowchart TB
    subgraph INPUTS["What moves a child's work, per tick"]
        ATT["attention<br/>full only while you teach in radius,<br/>zero when the class is unattended"]
        HELP["help / settle / collect<br/>your verbs at the desk"]
        FURN["furniture by the desk<br/>some items teach; cluster penalty"]
        CONC["concepts taught<br/>breadth, small, capped"]
        TRAIT["the child's trait"]
    end

    ATT --> WORK
    HELP --> WORK
    FURN --> WORK
    CONC --> WORK
    TRAIT --> WORK

    WORK["per-child work and understanding<br/>student_data"]
    WORK --> GRADE["grade_for / grade_class<br/>room term + lesson term + homework term<br/>the quiz pays NOTHING toward grade"]
    GRADE --> BANDS["grade_bands in balance.json<br/>numeric grade becomes a letter A..E"]

    BANDS --> COIN["economy<br/>coins_per_grade_point x class avg x size<br/>x assignment rarity x specialism"]
    BANDS --> XP["teacher XP, levels, perks<br/>all effects via progress.gd"]

    COIN --> SHOP["shop at the noticeboard<br/>furniture, cosmetics, consumables"]
    XP --> SHOP
    SHOP -->|some furniture teaches a concept| FURN
    XP -->|perks feed back: skip_days, teaches| INPUTS

    subgraph CONTRACT["the balance contract - balance.json._contract"]
        C1["bare room, perfect teaching -> 0.63, C"]
        C2["full room, never helped -> 0.71, C"]
        C3["full room, perfect teaching -> 0.97, A"]
        C4["neither input alone reaches the top band"]
    end

    GRADE -.->|measured by sim, asserted by the suite| CONTRACT
```

**Why it is shaped this way:** the quiz pays no grade, and assignment rarity
pays coins and XP but never grade, so nothing can move the contract *by luck
rather than by play*. See GDD §2 (the balance contract) and §10 (economy).

---

## 4. Where the numbers live

No tunable number is a `const` in a `.gd` file. There is one table.

```mermaid
flowchart LR
    BJSON["data/balance.json<br/>about 40 sections"] --> LOAD["Balance.ensure_loaded()"]
    LOAD --> VARS["balance.gd static vars<br/>work with no SceneTree"]
    VARS --> SYS["every system reads Balance.name"]
    CHECK["tools/check_balance.py"] -.->|asserts every key is read| BJSON
```

The `_contract` and `grade_bands` sections of `balance.json` are load-bearing
design, not ordinary tuning — GDD §2 says why, and the tests assert the band
logic against `Balance.grade_band_*` rather than pinned literals.

---

## 5. How a change gets verified — the golden rule as a picture

> Verify by looking at the running game, not by reading the code.

```mermaid
flowchart TB
    CHANGE["a change"] --> SUITE["Run Tests.bat - tests/run.gd<br/>no crash, the logic holds<br/>read the assertion COUNT, not PASSED"]
    CHANGE --> SIM["Simulate a Term.bat - sim.gd<br/>the 3 contract rows still hold"]
    CHANGE --> WALK["Play a Whole Term.bat - playterm.gd<br/>every real day reaches the bell<br/>prints WALKTHROUGH PASSED / FAILED"]
    CHANGE --> SCHOOL["Simulate the School.bat - schoolsim.gd<br/>delegation still matters, the board moves"]
    CHANGE --> AUDIT["Audit the Room.bat - audit.gd<br/>every landmark offers something, every phase"]
    CHANGE --> SHOT["Take a Screenshot.bat<br/>it is actually on screen, headless cannot see"]
    SUITE --> VERIFY["Verify.bat runs the lot"]
    SIM --> VERIFY
    WALK --> VERIFY
    SCHOOL --> VERIFY
    AUDIT --> VERIFY
```

Only the suite and the walkthrough have a machine-readable pass/fail. The
rest speak prose; read their output.

---

## Keeping this document honest

- It is at the altitude of **modules and rules**, which barely moves. Do not
  pull it down to function level — that is what the code and the GDD are for.
- Update it when a system is **added or removed** (a new autoload, a new
  data module, a phase, the school layer's Phase 2), not on tuning or art.
- The counts and measured numbers live in `docs/GDD.md`, which carries a
  "measured on" date. This file carries none, on purpose.
