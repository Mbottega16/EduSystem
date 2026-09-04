# EDUSystem — audio brief

*Originally a content batch from ChatGPT (August 2026), integrated as a
draft brief only — copy, not code. A later pass (September 2026) built
real music and ambience against the spirit of that draft, not a literal
implementation of it. This file now says, section by section, what
shipped and what is still just the original proposal.*

## Feel

EDUSystem should sound like a real classroom heard from inside it: paper,
chairs, footsteps, distant voices and the occasional school bell. The
tension is quiet and cumulative. Nothing explodes and nothing needs a
heroic musical cue; the pressure comes from hearing the room become
slightly harder to manage while you are already deciding which child
needs you next. The music should support concentration rather than
compete with the stuck-child cue.

This still holds and guided the built tracks: the classroom bed is a
murmur under everything, well below the sound effects, and the
assessment track leans on pressure (a driving bass, a lead that never
quite resolves) rather than volume.

## What actually exists now

Five WAVs, written by `tools/make_audio.py` the same way every sound
effect is, played by the `Music` autoload:

| track | length | role |
|---|---|---|
| `music_title` | 30s loop | the title screen, from `_ready()` |
| `music_room` | 30s loop | the one bed under all of play — put there by *listening* for `Game.run_started` and `Game.term_began`, not by a scene calling it |
| `music_fight` | 23s loop | built and tested; **not yet triggered** — nothing in the game currently detects "the assessment started" |
| `music_win` | 2.5s one-shot | built and tested; **not yet triggered** — same gap, the other side |
| `music_lose` | 2.5s one-shot | built and tested; **not yet triggered** |

Two buses now: Master (everything else, unchanged) and Music, so
`Settings.music_volume` — its own row on the Settings screen, next to
Sound effects — moves the score without moving a single sound effect.
Crossfades between tracks; a sting plays over the bed without cutting it.

Every loop is an exact sample count with nothing faded at the seam, and
`make_audio.py` prints and checks peak, RMS and the jump across the loop
point for each one before it will save the file — a click at the seam is
exactly a jump bigger than any other in the file, and that's now a build
failure, not something to notice by ear later. What no script can check:
whether the composed music is actually *good*. It has been measured, not
sat through end-to-end by a person yet.

## What's still just this draft's proposal (not built)

Everything below this line describes the **original ChatGPT brief**,
kept for anyone tackling the next round — it was not implemented as
written, and the built tracks above do not map onto it one-to-one.

### Ambience layers (proposed, not built)

One classroom bed (`music_room`) currently covers all of play. The
richer state-dependent layering below — different ambience for morning,
a lesson, a silent test, a noisy room, the afternoon, an exam — is
future work, additive on top of what exists, not a redesign of it.

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

### Music cues (original proposal, superseded by the table above)

The brief originally asked for seven mood-tagged cues (`morning_loop`,
`lesson_loop`, `afternoon_loop`, `exam_loop`, `term_pass`, `term_fail`,
`graduation`) built around per-state ambience. What shipped instead is
five tracks around three situations the game can currently tell apart —
title, in-play, and (unwired) the assessment plus its two outcomes. If
the state layering above ever gets built, splitting `music_room` into
several of these moods is the natural next step rather than starting
over.

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

## New sound effects (proposed, not built)

None of these exist yet. Filenames below are proposals, not registered
`Sfx` calls — unrelated to the music/ambience work above and untouched
by it.

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
