# PixelRoom — audio brief (draft)

*Content batch, August 2026. Source: ChatGPT, integrated without changes
(copy only — nothing here touches code, balance or the contract. Not yet
built: no music or SFX assets exist for any of this. Filenames below are
proposals, not registered `Sfx`/`Fx` calls.)*

## Feel

PixelRoom should sound like a real classroom heard from inside it: paper,
chairs, footsteps, distant voices and the occasional school bell. The
tension is quiet and cumulative. Nothing explodes and nothing needs a
heroic musical cue; the pressure comes from hearing the room become
slightly harder to manage while you are already deciding which child
needs you next. The music should support concentration rather than
compete with the stuck-child cue.

## Ambience layers

**Morning.** Low room tone, distant corridor movement, occasional chair
scrape and faint paper handling. Keep the layer sparse so the player's
first interaction remains clear.

**Lesson.** Add very quiet pupil movement, pencils, pages and occasional
chair shifts. The loop should vary subtly so it does not sound like a
repeated sample.

**Silent test.** Remove pupil chatter almost completely. Keep paper,
pencils and occasional chair movement. Silence itself should be part of
the sound design.

**Noisy room.** Increase chair movement, paper movement and indistinct
pupil voices. Do not simply increase volume; make the room feel busier
through more events.

**Afternoon.** Reduce activity and introduce more corridor ambience. The
room should feel like the day is winding down.

**Exam.** Use the lesson palette with the room stripped back. Paper,
pencils and the occasional movement should dominate. Avoid music that
tells the player whether they are winning.

## Music cues

| cue | length | mood | type |
|---|---|---|---|
| `morning_loop` | ~3 min | restrained, prepared, slightly hopeful | loop |
| `lesson_loop` | ~4 min | focused, steady | loop |
| `afternoon_loop` | ~3 min | tired but settled | loop |
| `exam_loop` | ~4 min | concentrated, restrained tension | loop |
| `term_pass` | <10s | quiet relief | one-shot |
| `term_fail` | <8s | disappointment without melodrama | one-shot |
| `graduation` | ~15s | reflective, warm | one-shot |

`morning_loop`: sparse piano or mallet figures, soft bass, a gentle
rhythmic pulse. Leave enough space that it can repeat without becoming
noticeable.

`lesson_loop`: a restrained repeating motif with small variations every
pass. Deliberately sparse; no strong melodic climax.

`afternoon_loop`: softer harmony, fewer notes, less rhythmic activity
than the lesson cue.

`exam_loop`: a slow repeating figure with unresolved harmony. No
cinematic escalation.

`term_pass`: a short harmonic resolution rather than a fanfare.

`term_fail`: a restrained descending figure that ends cleanly.

`graduation`: a simple melodic phrase that feels like a pupil moving
onwards rather than a victory screen.

## New sound effects

| effect | trigger | brief |
|---|---|---|
| `card_cycle` | cycling the lesson-card hand | very short soft click, filtered square/triangle transient, tiny upward pitch move. Under 200ms, quieter than `confirm`. |
| `card_select` | choosing a lesson card | two-note sine/triangle blip, fast attack, short decay, ends slightly higher. Under 250ms. |
| `quiz_open` | opening the quiz | short paper-like noise layer then a soft pitched tone. Quick envelope, under 400ms. |
| `quiz_result` | quiz result lands | two short pitched tones, second slightly lower/higher by result. Under 350ms; failure should not sound catastrophic. |
| `unit_test_start` | beginning the silent unit test | single muted low note, soft attack, rapid fade. Under 400ms — the room settling. |
| `voice_settle` | raising your voice to settle the room | short filtered broadband burst then a low wooden knock. Under 450ms, clearly different from `stuck`. |
| `build_enter` | entering build mode | compact ascending three-note synth figure, quick envelope. Under 350ms. |
| `build_place` | successfully placing furniture | short low-frequency thump layered with a wooden click. Under 300ms. |
| `build_reject` | invalid placement | muted two-tone downward blip. Under 250ms, softer than `deny`. |
| `school_board` | opening the school board | soft paper slide then a restrained bell-like note. Under 400ms. |
| `hire_confirm` | hiring a teacher | two warm notes, short decay, slightly more substantial than `confirm`. Under 500ms. |

## Reference tracks

References for **musical behaviour**, not tracks to copy or include.

- Erik Satie — *Gymnopédie No. 1*: the restraint, repetition, amount of
  musical space.
- Brian Eno — *Music for Airports 1/1*: the patience and avoidance of
  obvious musical punctuation.
- Joe Hisaishi — *One Summer's Day*: restrained melodic warmth, not
  cinematic scale.
- Philip Glass — *Opening*: controlled repetition and gradual movement.
- Ólafur Arnalds — *Near Light*: quiet texture and measured tension.
