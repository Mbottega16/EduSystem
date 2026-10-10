#!/usr/bin/env python3
"""Generate every sound in the game.

Same principle as the art: synthesised in code rather than sourced, so the
whole project stays self-contained and a sound can be re-tuned by editing a
number instead of hunting for a replacement file.

    python tools/make_audio.py

Writes 22.05kHz 16-bit mono WAVs to audio/. That rate is deliberate — it is
plenty for short blips and keeps the files tiny.

Two halves. The first is the twelve sound effects, one function each. The
second (from "composition" down) is the music and ambience: a small
composition layer -- notes, a step sequencer, an ADSR, a one-pole filter, a
circular loop buffer -- and the eight tracks written with it: the title
theme, four ambience beds (the classroom under an ordinary lesson, the
morning before it, the silent unit test, the afternoon after), the
assessment track, and the win and lose stings.
Every loop is an exact sample count with nothing faded at the seam, and the
script measures and prints peak, RMS and seam continuity for each one.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
RATE = 22050


# ---------------------------------------------------------------- helpers

def envelope(n, attack=0.01, decay=0.9, sustain=0.0):
    """Simple AD envelope as a list of gains, one per sample."""
    a = max(1, int(n * attack))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / float(a))
        else:
            t = (i - a) / float(max(1, n - a))
            out.append(max(sustain, (1.0 - t) ** (1.0 / max(0.05, decay))))
    return out


def tone(freq, secs, kind="sine", detune=0.0):
    n = int(RATE * secs)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq * (1.0 + detune * i / float(n))
        phase += 2.0 * math.pi * f / RATE
        if kind == "sine":
            out.append(math.sin(phase))
        elif kind == "square":
            out.append(1.0 if math.sin(phase) >= 0 else -1.0)
        elif kind == "tri":
            out.append(2.0 / math.pi * math.asin(math.sin(phase)))
        else:  # noise
            out.append(random.uniform(-1.0, 1.0))
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out


def apply_env(samples, **kw):
    env = envelope(len(samples), **kw)
    return [s * e for s, e in zip(samples, env)]


def save(name, samples, gain=0.5):
    peak = max(1e-6, max(abs(s) for s in samples))
    scaled = [max(-1.0, min(1.0, s / peak * gain)) for s in samples]
    STATS[name] = math.sqrt(sum(s * s for s in scaled) / float(len(scaled)))
    data = b"".join(struct.pack("<h", int(s * 32767)) for s in scaled)
    path = os.path.join(OUT, name + ".wav")
    w = wave.open(path, "wb")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(data)
    w.close()
    print("audio/%-16s %5.2fs" % (name + ".wav", len(samples) / float(RATE)))


# ----------------------------------------------------------------- sounds

def make_bell():
    """The object the game is named after. Struck metal: a fundamental plus
    inharmonic partials, ringing for a good while."""
    secs = 1.8
    layers = []
    for mult, gain, dec in ((1.0, 1.0, 0.55), (2.76, 0.55, 0.45),
                            (5.40, 0.30, 0.35), (8.93, 0.16, 0.3)):
        t = tone(660 * mult, secs)
        layers.append([s * gain for s in apply_env(t, attack=0.002, decay=dec)])
    save("bell", mix(*layers), 0.8)


def make_step():
    """A soft scuff. Short noise burst, low-passed by averaging."""
    n = int(RATE * 0.07)
    raw = [random.uniform(-1, 1) for _ in range(n)]
    smooth = []
    acc = 0.0
    for v in raw:
        acc = acc * 0.72 + v * 0.28
        smooth.append(acc)
    save("step", apply_env(smooth, attack=0.02, decay=0.3), 0.28)


def make_stuck():
    """A student getting stuck: a small falling two-tone, questioning."""
    a = apply_env(tone(520, 0.10, "tri"), attack=0.01, decay=0.5)
    b = apply_env(tone(392, 0.16, "tri"), attack=0.01, decay=0.4)
    save("stuck", a + b, 0.42)


def make_chatter():
    """Two children at touching desks getting talking: a burst of babble,
    four quick syllables wandering up and down, the way a sim's people talk
    without words. Its own random.Random rather than the module's, so adding
    it shifted no other sound by a single sample."""
    rng = random.Random(11)
    out = []
    for hz in (330, 392, 294, 349):
        body = apply_env(tone(hz, 0.065, "tri"), attack=0.08, decay=0.6)
        buzz = apply_env(tone(hz * 2.01, 0.065, "square"), attack=0.08, decay=0.4)
        out += mix(body, [s * 0.35 for s in buzz])
        out += [0.0] * int(RATE * rng.uniform(0.015, 0.03))
    save("chatter", out, 0.36)


def make_help():
    """Unsticking someone: the reward moment. Rising, bright, brief."""
    a = apply_env(tone(523, 0.08, "sine"), attack=0.005, decay=0.5)
    b = apply_env(tone(784, 0.14, "sine"), attack=0.005, decay=0.45)
    shimmer = apply_env(tone(1568, 0.14, "sine"), attack=0.005, decay=0.3)
    return save("help", a + [x + y * 0.3 for x, y in zip(b, shimmer)], 0.5)


def make_paper():
    """Picking up a sheet: a rustle."""
    n = int(RATE * 0.16)
    out = []
    acc = 0.0
    for i in range(n):
        v = random.uniform(-1, 1)
        acc = acc * 0.5 + v * 0.5
        # a couple of crinkle bursts rather than flat noise
        burst = 1.0 if (i % 1900) < 700 else 0.35
        out.append(acc * burst)
    save("paper", apply_env(out, attack=0.05, decay=0.4), 0.3)


def make_coins():
    """Payday. Several small high chinks, slightly detuned."""
    out = []
    for i, f in enumerate((1046, 1318, 1568)):
        t = apply_env(tone(f, 0.13, "tri", detune=0.02), attack=0.003, decay=0.4)
        pad = [0.0] * int(RATE * 0.045 * i)
        out = mix(out + [0.0] * len(t), pad + t) if out else pad + t
    save("coins", out, 0.45)


def make_blip():
    """Moving the selection in a menu. Must be very short and very dull —
    it is the sound you will hear most often in the whole game."""
    save("blip", apply_env(tone(880, 0.045, "square"), attack=0.002, decay=0.6), 0.16)


def make_confirm():
    a = apply_env(tone(659, 0.06, "square"), attack=0.002, decay=0.5)
    b = apply_env(tone(988, 0.10, "square"), attack=0.002, decay=0.5)
    save("confirm", a + b, 0.24)


def make_deny():
    save("deny", apply_env(tone(180, 0.14, "square"), attack=0.003, decay=0.5), 0.25)


def make_grade():
    """The end-of-day sting. A small major chord, warm."""
    layers = [apply_env(tone(f, 0.85, "tri"), attack=0.01, decay=0.5)
              for f in (392, 494, 587, 784)]
    save("grade", mix(*layers), 0.5)


def make_start():
    """Starting a lesson: settle-down, attention-please."""
    a = apply_env(tone(440, 0.12, "tri"), attack=0.01, decay=0.5)
    b = apply_env(tone(587, 0.20, "tri"), attack=0.01, decay=0.4)
    save("start", a + b, 0.45)


# ============================================================ composition
#
# Everything above is a blip: one tone, one envelope, done. GDD s13 used to
# say "this is the one area where the procedural approach probably has to
# stop". What follows is the attempt to prove that wrong with the same
# standard-library Python -- a handful of small parts that add up to music:
#
#   note_hz()    note name -> frequency
#   wavetable()  one band-limited cycle (additive sines up to just under
#                Nyquist) so a square at 880 Hz is not a fog of aliased grit
#   adsr()       attack / decay / sustain / release, in seconds
#   voice()      one note: wavetable + ADSR + optional vibrato or glide
#   Loop         a circular sample buffer. Anything added past the end -- a
#                release tail, a page turn near the seam -- wraps round to
#                the start, so nothing fades at the loop point; the last
#                bar's tail plays under the first bar, as it would live
#   sequence()   a step sequencer: (note, beats) pairs onto a Loop, every
#                start rounded onto the loop's exact sample grid
#   figure()     a bass writer: a repeating semitone figure over a chord list
#   lowpass()    one-pole low-pass; run twice round a loop so the filter
#                arrives at sample 0 in the state it left sample n-1 in
#   echo()       one circular delay tap
#   swell()      a slow amplitude curve with a whole number of cycles per
#                loop, so it meets itself at the seam
#   hit()        a band-limited noise transient: hats, ticks, paper
#   finish()     soft-clip, normalise, save, and MEASURE: peak, RMS, the
#                jump across the seam against the largest jump inside the
#                loop. Printed every run; fatal if the seam is the worst.
#
# A loop is a whole number of samples: n = round(beats * 60/bpm * RATE). At
# 96 BPM, 48 beats is exactly 661,500 samples -- 30.000 s -- and the game
# sets that sample count as the loop end (scripts/autoload/music.gd).

NOTE_INDEX = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
TABLE_SIZE = 2048
_TABLES = {}
STATS = {}          # name -> RMS after normalisation, for the bed check


def note_hz(name):
    """'A4' -> 440.0; 'Bb3', 'G#5' work. None or '-' is a rest (0.0). A
    number is already a frequency and passes through."""
    if name is None or name == "-":
        return 0.0
    if isinstance(name, (int, float)):
        return float(name)
    semis = NOTE_INDEX[name[0].upper()]
    rest = name[1:]
    while rest and rest[0] in "#b":
        semis += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + semis
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def shift(hz, semitones):
    return hz * 2.0 ** (semitones / 12.0)


def wavetable(kind, freq, duty=0.5):
    """One cycle of `kind`, band-limited for a note at `freq`: partials stop
    just under Nyquist. Cached by partial count, so every note that can
    carry the same number of partials shares a table."""
    nh = max(1, min(48, int(0.45 * RATE / max(20.0, freq))))
    if kind == "sine":
        nh = 1
    key = (kind, nh, round(duty, 3))
    if key in _TABLES:
        return _TABLES[key]
    table = []
    for i in range(TABLE_SIZE):
        th = 2.0 * math.pi * i / TABLE_SIZE
        v = 0.0
        if kind == "sine":
            v = math.sin(th)
        elif kind == "tri":
            for k in range(1, nh + 1, 2):
                sign = 1.0 if ((k - 1) // 2) % 2 == 0 else -1.0
                v += sign * math.sin(k * th) / (k * k)
        elif kind == "saw":
            for k in range(1, nh + 1):
                v += math.sin(k * th) / k
        else:   # a pulse of the given duty; 0.5 is a square
            for k in range(1, nh + 1):
                v += (math.sin(2.0 * math.pi * k * duty) * math.cos(k * th)
                      + (1.0 - math.cos(2.0 * math.pi * k * duty))
                      * math.sin(k * th)) / k
        table.append(v)
    peak = max(abs(v) for v in table) or 1.0
    table = [v / peak for v in table]
    _TABLES[key] = table
    return table


def adsr(gate, a=0.005, d=0.05, s=0.7, r=0.05):
    """Gains for a note held `gate` samples plus its release tail, so the
    result is gate + release long. Attack and release are linear; decay
    falls to the sustain level. The release starts from wherever the
    envelope actually was, so a note cut mid-decay does not jump."""
    na, nd, nr = int(RATE * a), int(RATE * d), max(1, int(RATE * r))
    out = [0.0] * (gate + nr)
    for i in range(gate + nr):
        if i < na:
            g = i / float(na)
        elif i < na + nd:
            g = 1.0 - (1.0 - s) * (i - na) / float(nd)
        elif i < gate:
            g = s
        else:
            g = out[gate - 1] * (1.0 - (i - gate) / float(nr)) if gate > 0 else 0.0
        out[i] = g
    return out


def voice(hz, gate, kind="pulse", duty=0.5, env=(0.005, 0.05, 0.7, 0.05),
          vib=None, glide=1.0, gain=1.0):
    """One note. `gate` is the held length in samples; the release tail is
    appended. `vib` is (rate_hz, depth, delay_s): a pitch wobble that fades
    in after `delay`, the way a player adds it, not from the first sample.
    `glide` is the pitch multiplier reached by the end of the gate (0.97
    sags half a semitone)."""
    gains = adsr(gate, *env)
    n = len(gains)
    tbl = wavetable(kind, hz, duty)
    size = len(tbl)
    inc0 = hz * size / RATE
    out = [0.0] * n
    phase = 0.0
    if vib:
        vrate, vdepth, vdelay = vib
        vw = 2.0 * math.pi * vrate / RATE
        vramp = max(1.0, RATE * vdelay)
    gate_f = float(max(1, gate))
    for i in range(n):
        inc = inc0
        if vib:
            inc *= 1.0 + vdepth * min(1.0, i / vramp) * math.sin(vw * i)
        if glide != 1.0:
            inc *= 1.0 + (glide - 1.0) * min(1.0, i / gate_f)
        idx = int(phase)
        frac = phase - idx
        nxt = idx + 1
        if nxt >= size:
            nxt = 0
        out[i] = (tbl[idx] + (tbl[nxt] - tbl[idx]) * frac) * gains[i] * gain
        phase += inc
        if phase >= size:
            phase -= size
    return out


def lowpass(samples, cutoff, loop=False):
    """One-pole low-pass. For a loop it runs round twice and keeps the second
    pass: the filter then reaches sample 0 in exactly the state it leaves
    the last sample in, so the seam carries no step of its own."""
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out = [0.0] * len(samples)
    y = 0.0
    for _ in range(2 if loop else 1):
        for i, x in enumerate(samples):
            y += a * (x - y)
            out[i] = y
    return out


def highpass(samples, cutoff, loop=False):
    return [x - y for x, y in zip(samples, lowpass(samples, cutoff, loop))]


def echo(samples, delay, gain):
    """One circular delay tap: the tail of the last bar lands under the
    first, so the echo is as seamless as the loop it sits on."""
    n = len(samples)
    return [samples[i] + gain * samples[(i - delay) % n] for i in range(n)]


def swell(n, parts, floor=0.0):
    """A slow amplitude curve: 1.0 plus sines with a WHOLE number of cycles
    over `n` samples, so it meets itself at the seam. `parts` is
    [(cycles, depth, phase), ...]."""
    w = 2.0 * math.pi / n
    out = []
    for i in range(n):
        v = 1.0
        for cycles, depth, ph in parts:
            v += depth * math.sin(w * cycles * i + ph)
        out.append(max(floor, v))
    return out


def hit(rng, secs, tau, lo=None, hi=None):
    """A noise transient: white noise band-limited between `lo` and `hi` Hz
    with an exponential tail of `tau` seconds. Hats, ticks, paper, clock."""
    n = int(RATE * secs)
    out = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    if hi:
        out = lowpass(out, hi)
    if lo:
        out = highpass(out, lo)
    k = -1.0 / (RATE * tau)
    return [v * math.exp(k * i) for i, v in enumerate(out)]


def kick(secs=0.14, f0=130.0, f1=45.0):
    """A soft kick: a sine that drops from f0 to f1 while it decays."""
    n = int(RATE * secs)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / float(n)
        f = f1 + (f0 - f1) * math.exp(-t * 6.0)
        ph += 2.0 * math.pi * f / RATE
        out.append(math.sin(ph) * math.exp(-t * 5.0))
    return out


def fade_out(samples, secs):
    n = len(samples)
    k = int(RATE * secs)
    return [v * (min(1.0, (n - 1 - i) / float(k)) if i >= n - k else 1.0)
            for i, v in enumerate(samples)]


def rms(samples):
    return math.sqrt(sum(s * s for s in samples) / float(max(1, len(samples))))


class Loop:
    """A sample buffer exactly `n` long. With wrap (the default) anything
    added past the end continues from the start, so a note's release tail
    or an event near the seam never leaves a step at the loop point.
    Without wrap (a one-shot sting) it is cut instead."""

    def __init__(self, n, wrap=True):
        self.n = n
        self.buf = [0.0] * n
        self.wrap = wrap

    def add(self, samples, start, gain=1.0):
        n, buf = self.n, self.buf
        for i, v in enumerate(samples):
            j = start + i
            if j >= n:
                if not self.wrap:
                    break
                j %= n
            buf[j] += v * gain

    def at(self, secs):
        return int(round(secs * RATE))


def sequence(loop, phrase, beats_total, gain=1.0, legato=0.9, **voice_kw):
    """The step sequencer. `phrase` is [(note, beats), ...] and must fill
    `beats_total` exactly -- a bar short is a composing mistake, not a
    thing to pad silently. Every note starts on the loop's sample grid;
    `legato` is how much of its beats a note is held (the gap is what lets
    a repeated note re-articulate)."""
    spb = loop.n / float(beats_total)
    pos = 0.0
    for note, beats in phrase:
        hz = note_hz(note)
        if hz > 0.0:
            gate = max(1, int(round(beats * spb * legato)))
            loop.add(voice(hz, gate, **voice_kw), int(round(pos * spb)), gain)
        pos += beats
    if abs(pos - beats_total) > 1e-6:
        raise SystemExit("phrase is %g beats but the loop is %g" % (pos, beats_total))


def figure(chords, pattern):
    """Bass writer: walk [(root, beats)] with a repeating [(semitones, beats)]
    figure, restarting it on every chord and cutting it to fit -- a two-beat
    chord gets the figure's first two beats."""
    out = []
    for root, length in chords:
        hz = note_hz(root)
        left, i = length, 0
        while left > 1e-9:
            semi, b = pattern[i % len(pattern)]
            b = min(b, left)
            out.append((shift(hz, semi), b))
            left -= b
            i += 1
    return out


def finish(name, samples, gain, bpm=None, loop=True):
    """Soft-clip, normalise to `gain` peak, save, and print the numbers a
    track has to meet. Peak must stay at or under 0.9. For a loop, the jump
    from the last sample to the first must not be the largest jump in the
    file -- a click at the seam is exactly a jump that is."""
    clipped = [math.tanh(s) for s in samples]
    peak = max(abs(s) for s in clipped) or 1.0
    out = [s / peak * gain for s in clipped]
    n = len(out)
    body = max(abs(out[i + 1] - out[i]) for i in range(n - 1))
    seam = abs(out[0] - out[-1])
    save(name, out, gain)
    level = STATS[name]
    print("   %d samples%s  peak %.3f  rms %.4f  seam jump %.4f (max in-body %.4f)"
          "  first64 rms %.4f  last64 rms %.4f"
          % (n, "  %d BPM" % bpm if bpm else "", max(abs(s) for s in out),
             level, seam, body, rms(out[:64]), rms(out[-64:])))
    if gain > 0.9:
        raise SystemExit("%s: peak %.2f is over 0.9" % (name, gain))
    if loop and seam > body:
        raise SystemExit("%s: the loop seam is the biggest jump in the file -- a click"
                         % name)
    return out


# ------------------------------------------------------------- the tracks

def make_music_title():
    """The title theme: "first morning of term". C major, 96 BPM, twelve
    bars -- exactly 661,500 samples, 30.000 s. Three voices:

      lead  a square with a twelve-bar melody, A (1-4) A' (5-8) B (9-12):
            it climbs C-D-E-G, turns on the relative minor, and in bar 11
            resolves onto a held tonic, then walks G-A-B back up to the C
            the loop restarts on. Shallow vibrato that fades in after each
            attack, and a dotted-eighth echo, for warmth rather than show.
      bass  a triangle: root, root, fifth, octave, fifth under each chord.
      hats  soft noise eighths, a touch louder on two and four."""
    bpm, beats = 96, 48
    n = int(round(beats * 60.0 / bpm * RATE))
    spb = n / float(beats)
    rng = random.Random(1101)

    melody = [
        # bar 1  C                                  bar 2  Am
        ("C5", 1), ("D5", 1), ("E5", 1.5), ("G5", 0.5),
        ("A5", 1), ("G5", 1), ("E5", 2),
        # bar 3  F                                  bar 4  G (D5 picks up)
        ("F5", 1), ("E5", 0.5), ("D5", 0.5), ("C5", 1), ("A4", 1),
        ("D5", 2), ("B4", 1), ("D5", 1),
        # bar 5  C                                  bar 6  Am
        ("E5", 1), ("D5", 1), ("C5", 1.5), ("E5", 0.5),
        ("A5", 1), ("G5", 0.5), ("E5", 0.5), ("C5", 2),
        # bar 7  F                                  bar 8  G
        ("F5", 1), ("E5", 1), ("D5", 1), ("C5", 1),
        ("D5", 1.5), ("E5", 0.5), ("D5", 1), ("B4", 1),
        # bar 9  F (the high point, falling)        bar 10 G (leading note)
        ("A5", 1), ("G5", 1), ("F5", 1), ("E5", 1),
        ("D5", 1), ("E5", 1), ("G5", 1), ("B4", 1),
        # bar 11 C: home                            bar 12 C -> G: walk back up
        ("C5", 3), (None, 1),
        (None, 1), ("G4", 1), ("A4", 1), ("B4", 1),
    ]
    lead = Loop(n)
    sequence(lead, melody, beats, gain=0.5, legato=0.9, kind="pulse", duty=0.5,
             env=(0.008, 0.10, 0.72, 0.12), vib=(5.5, 0.006, 0.18))
    lead_mix = echo(lowpass(lead.buf, 3800.0, loop=True), int(round(spb * 0.75)), 0.22)

    chords = [("C2", 4), ("A2", 4), ("F2", 4), ("G2", 4),
              ("C2", 4), ("A2", 4), ("F2", 4), ("G2", 4),
              ("F2", 4), ("G2", 4), ("C2", 4), ("C2", 2), ("G2", 2)]
    bass = Loop(n)
    sequence(bass, figure(chords, [(0, 1.5), (0, 0.5), (7, 1.0), (12, 0.5), (7, 0.5)]),
             beats, gain=0.6, legato=0.85, kind="tri", env=(0.006, 0.12, 0.6, 0.10))

    hats = Loop(n)
    for e in range(beats * 2):
        t = e / 2.0
        loud = 0.16 if (t % 4.0) in (1.0, 3.0) else (0.10 if e % 2 == 0 else 0.07)
        hats.add(hit(rng, 0.06, 0.012, lo=5000.0), int(round(t * spb)), loud)

    mixed = [l + b + h for l, b, h in zip(lead_mix, bass.buf, hats.buf)]
    finish("music_title", mixed, 0.85, bpm=bpm)


def _page_turn(rng):
    """A sheet lifted and laid down: two humps of crinkled mid-band noise."""
    n = int(RATE * 0.28)
    x = highpass(lowpass([rng.uniform(-1.0, 1.0) for _ in range(n)], 3200.0), 600.0)
    out = []
    for i in range(n):
        t = i / float(RATE)
        e = (math.exp(-((t - 0.05) / 0.03) ** 2)
             + 0.7 * math.exp(-((t - 0.19) / 0.04) ** 2))
        crinkle = 1.0 if (i % 610) < 260 else 0.4
        out.append(x[i] * e * crinkle)
    return out


def _creak(rng):
    """A chair: a low saw that slides up while a ~30 Hz stick-slip gates it,
    with a little mid-band noise for the wood."""
    n = int(RATE * 0.26)
    base = voice(85.0, int(n * 0.8), kind="saw", env=(0.03, 0.05, 0.8, 0.05), glide=1.18)
    gated = [v * (0.55 + 0.45 * math.sin(2.0 * math.pi * 31.0 * i / RATE + 1.0))
             for i, v in enumerate(base)]
    gated = lowpass(gated, 1400.0)
    noise = hit(rng, 0.26, 0.09, lo=300.0, hi=2500.0)
    return [a + 0.4 * b for a, b in zip(gated, noise)]


def noise_band(rng, n, lo, hi):
    """A band of filtered noise `n` samples long: two lowpass passes (each
    run round twice, for a seamless loop) then a highpass, so the band has
    a floor and a ceiling with nothing outside them. Shared by every
    ambience bed that wants a "room of children heard from the front"
    texture rather than a melody."""
    x = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    x = lowpass(lowpass(x, hi, True), hi, True)
    return highpass(x, lo, True)


def make_music_room():
    """The classroom bed under play: 30 s, exactly 661,500 samples, and no
    melody at all. Two bands of noise swelling slowly (a room of children
    heard from the front -- the low murmur, and a thinner band for the
    edges of distant talk), a clock ticking once a second (30 ticks, tick
    and tock alternating, so an even count meets itself at the seam), five
    page turns, five short runs of pencil ticks, two chair creaks.

    Every swell has a whole number of cycles over the loop, every event
    goes into a circular buffer, every filter runs twice round: nothing at
    the seam is different from anywhere else. Normalised well under the
    sound effects -- it is a bed, and the stuck-child cue has to win."""
    secs = 30.0
    n = int(RATE * secs)
    rng = random.Random(3003)
    room = Loop(n)

    murmur = noise_band(rng, n, 110.0, 380.0)
    breath = swell(n, [(3, 0.32, 0.4), (7, 0.18, 2.1), (11, 0.10, 1.0),
                       (117, 0.10, 0.0), (191, 0.06, 0.7)], floor=0.08)
    room.add([m * s for m, s in zip(murmur, breath)], 0, 0.6)

    talk = noise_band(rng, n, 500.0, 1400.0)
    drift = swell(n, [(2, 0.40, 2.6), (5, 0.25, 0.3), (13, 0.12, 4.0),
                      (131, 0.15, 1.5)], floor=0.05)
    room.add([m * s for m, s in zip(talk, drift)], 0, 0.15)

    # the clock: one tick a second, tick and tock -- on the half second, so
    # the seam falls between ticks rather than on one
    for s in range(int(secs)):
        tock = s % 2 == 1
        at = int((s + 0.5) * RATE)
        room.add(hit(rng, 0.03, 0.004, lo=1500.0, hi=6000.0), at, 0.40)
        room.add(voice(1300.0 if tock else 1700.0, int(RATE * 0.012), kind="sine",
                       env=(0.0005, 0.010, 0.0, 0.012)), at, 0.22 if tock else 0.27)

    for t in (3.7, 9.2, 15.9, 21.4, 26.8):
        room.add(_page_turn(rng), room.at(t), 0.5)

    for start in (1.3, 7.8, 13.1, 19.6, 24.9):
        t = start
        for _ in range(rng.randint(3, 6)):
            room.add(hit(rng, 0.02, 0.003, lo=2500.0, hi=7000.0), room.at(t),
                     rng.uniform(0.18, 0.30))
            t += rng.uniform(0.08, 0.17)

    for t in (5.5, 17.2):
        room.add(_creak(rng), room.at(t), 0.35)

    finish("music_room", lowpass(room.buf, 5500.0, loop=True), 0.18)


def make_music_morning():
    """Morning: the room before the lesson starts. 30 s, exactly 661,500
    samples. AUDIO_BRIEF asks for this layer to stay sparse so the
    player's first interaction is still the clearest thing in the room --
    so unlike music_room there is no talk band (nobody is working yet)
    and no clock (there is nothing to be on time for): one murmur band,
    two distant corridor footsteps standing in for movement past the
    door, one page turn, one chair creak."""
    secs = 30.0
    n = int(RATE * secs)
    rng = random.Random(6006)
    room = Loop(n)

    murmur = noise_band(rng, n, 90.0, 320.0)
    breath = swell(n, [(2, 0.30, 0.9), (5, 0.16, 2.4), (9, 0.10, 0.2)], floor=0.12)
    room.add([m * s for m, s in zip(murmur, breath)], 0, 0.45)

    for t in (8.4, 9.1, 20.6, 21.3):
        room.add(kick(secs=0.16, f0=95.0, f1=42.0), room.at(t), 0.20)

    room.add(_page_turn(rng), room.at(13.7), 0.4)
    room.add(_creak(rng), room.at(24.8), 0.28)

    finish("music_morning", lowpass(room.buf, 4200.0, loop=True), 0.15)


def make_music_test():
    """The silent unit test: the one stretch of play where every verb is
    switched off and the room is asked to speak for itself. 30 s. No talk
    band, no clock -- AUDIO_BRIEF's own words are "silence itself should
    be part of the sound design" -- just a hushed low band, a pad so slow
    it is barely a note, and a handful of pencil scratches and one page
    turn, spaced far apart. The quietest bed in the game on purpose."""
    secs = 30.0
    n = int(RATE * secs)
    rng = random.Random(7007)
    room = Loop(n)

    hush = noise_band(rng, n, 70.0, 220.0)
    breath = swell(n, [(1, 0.20, 1.6), (3, 0.10, 0.5)], floor=0.35)
    room.add([m * s for m, s in zip(hush, breath)], 0, 0.30)

    # a pad so slow the attack and release are most of the whole track --
    # near enough to a held breath rather than a played note.
    pad_gate = n - int(RATE * 0.3)
    pad = voice(note_hz("A2"), pad_gate, kind="tri",
                env=(2.0, 4.0, 0.55, 0.3))
    room.add(pad, 0, 0.10)

    for t, tau in ((4.2, 0.020), (11.6, 0.018), (18.9, 0.022), (25.3, 0.020)):
        room.add(hit(rng, 0.05, tau, lo=1800.0, hi=6500.0), room.at(t), 0.16)
    room.add(_page_turn(rng), room.at(15.0), 0.26)

    finish("music_test", lowpass(room.buf, 3800.0, loop=True), 0.10)


def make_music_afternoon():
    """Afternoon: the day winding down. 30 s. The same two-band shape as
    music_room, both bands trimmed back, no clock (that belongs to
    teaching, not the quiet after it), and three unhurried footsteps
    standing in for AUDIO_BRIEF's "more corridor ambience" -- the room
    feels like it is being heard through a door rather than sat in."""
    secs = 30.0
    n = int(RATE * secs)
    rng = random.Random(8008)
    room = Loop(n)

    murmur = noise_band(rng, n, 100.0, 340.0)
    breath = swell(n, [(3, 0.24, 1.1), (7, 0.12, 0.4), (13, 0.08, 2.0)], floor=0.10)
    room.add([m * s for m, s in zip(murmur, breath)], 0, 0.42)

    talk = noise_band(rng, n, 500.0, 1300.0)
    drift = swell(n, [(2, 0.22, 0.8), (11, 0.10, 3.2)], floor=0.04)
    room.add([m * s for m, s in zip(talk, drift)], 0, 0.07)

    for t in (6.0, 6.8, 22.4):
        room.add(kick(secs=0.20, f0=85.0, f1=34.0), room.at(t), 0.18)

    room.add(_page_turn(rng), room.at(14.2), 0.4)
    room.add(_creak(rng), room.at(27.5), 0.3)

    finish("music_afternoon", lowpass(room.buf, 4800.0, loop=True), 0.15)


def make_music_fight():
    """The end-of-term assessment. A minor, 124 BPM, twelve bars. A saw bass
    ostinato in eighths (root, root, octave, root, root, seventh, fifth,
    seventh) drives under every chord; a narrow-pulse lead plays short,
    spaced phrases that lean on the leading note and never quite land;
    sixteenth hats tick with a dry tock on two and four and a soft kick on
    one and three. Pressure, not volume: the lead sits under a 5 kHz
    low-pass and the mix is soft-clipped rather than pushed."""
    bpm, beats = 124, 48
    n = int(round(beats * 60.0 / bpm * RATE))
    spb = n / float(beats)
    rng = random.Random(2202)

    melody = [
        # bar 1  Am                                          bar 2  Am
        ("E5", 0.5), (None, 0.5), ("E5", 0.5), (None, 0.5), ("A5", 0.5), ("G5", 0.5), ("E5", 1),
        (None, 1), ("C5", 0.5), ("D5", 0.5), ("E5", 1.5), (None, 0.5),
        # bar 3  F                                           bar 4  G
        ("F5", 0.5), (None, 0.5), ("F5", 0.5), ("E5", 0.5), ("F5", 0.5), ("A5", 1.5),
        ("G5", 1), ("F5", 0.5), ("E5", 0.5), ("D5", 1), ("B4", 1),
        # bar 5  Am                                          bar 6  Am
        ("E5", 0.5), (None, 0.5), ("E5", 0.5), (None, 0.5), ("A5", 0.5), ("G5", 0.5), ("E5", 1),
        (None, 1), ("C5", 0.5), ("D5", 0.5), ("E5", 1), ("D5", 0.5), ("C5", 0.5),
        # bar 7  F                                           bar 8  E (the leading note)
        ("F5", 1), ("A5", 1), ("F5", 0.5), ("E5", 0.5), ("D5", 1),
        ("G#4", 1), ("B4", 1), ("E5", 1.5), (None, 0.5),
        # bar 9  Dm                                          bar 10 F
        ("D5", 0.5), (None, 0.5), ("F5", 0.5), (None, 0.5), ("A5", 1), ("F5", 1),
        ("C5", 0.5), (None, 0.5), ("F5", 0.5), (None, 0.5), ("A5", 1), ("G5", 1),
        # bar 11 E                                           bar 12 E, unresolved into the top
        ("G#5", 0.5), (None, 0.5), ("E5", 0.5), (None, 0.5), ("B4", 1), ("G#4", 1),
        ("B4", 0.5), ("C5", 0.5), ("B4", 0.5), ("G#4", 0.5), ("B4", 1), (None, 1),
    ]
    lead = Loop(n)
    sequence(lead, melody, beats, gain=0.42, legato=0.85, kind="pulse", duty=0.25,
             env=(0.003, 0.06, 0.6, 0.06), vib=(6.0, 0.004, 0.12))
    lead_mix = echo(lowpass(lead.buf, 5000.0, loop=True), int(round(spb * 0.75)), 0.28)

    chords = [("A2", 4), ("A2", 4), ("F2", 4), ("G2", 4),
              ("A2", 4), ("A2", 4), ("F2", 4), ("E2", 4),
              ("D2", 4), ("F2", 4), ("E2", 4), ("E2", 4)]
    bass = Loop(n)
    sequence(bass, figure(chords, [(0, 0.5), (0, 0.5), (12, 0.5), (0, 0.5),
                                   (0, 0.5), (10, 0.5), (7, 0.5), (10, 0.5)]),
             beats, gain=0.5, legato=0.9, kind="saw", env=(0.003, 0.08, 0.5, 0.03))
    bass_mix = lowpass(bass.buf, 900.0, loop=True)

    drums = Loop(n)
    accents = [0.28, 0.0, 0.14, 0.06, 0.28, 0.0, 0.14, 0.0,
               0.28, 0.0, 0.14, 0.06, 0.28, 0.0, 0.14, 0.10]
    for bar in range(12):
        for s16, g in enumerate(accents):
            if g > 0.0:
                drums.add(hit(rng, 0.04, 0.008, lo=6000.0),
                          int(round((bar * 4 + s16 / 4.0) * spb)), g)
        for beat in (1, 3):
            drums.add(hit(rng, 0.09, 0.03, lo=1200.0, hi=5000.0),
                      int(round((bar * 4 + beat) * spb)), 0.30)
        for beat in (0, 2):
            drums.add(kick(), int(round((bar * 4 + beat) * spb)), 0.5)

    mixed = [l + b + d for l, b, d in zip(lead_mix, bass_mix, drums.buf)]
    finish("music_fight", mixed, 0.85, bpm=bpm)


def make_music_noise():
    """A noisy classroom: disruption. 30 s. The room bed plus a lot more talk,
    scooting chairs, banging, paper crumples, and murmurs. Fits seamlessly
    over music_room since the noise level is layered."""
    secs = 30.0
    n = int(RATE * secs)
    rng = random.Random(9009)
    room = Loop(n)

    # louder, thicker talk band
    talk = noise_band(rng, n, 400.0, 2000.0)
    drift = swell(n, [(3, 0.40, 1.1), (11, 0.25, 0.3), (23, 0.15, 3.0)], floor=0.3)
    room.add([m * s for m, s in zip(talk, drift)], 0, 0.55)

    # restless movements (creaks, thumps)
    for start in (2.1, 8.4, 15.6, 22.1, 28.3):
        t = start
        for _ in range(rng.randint(2, 4)):
            room.add(_creak(rng), room.at(t), rng.uniform(0.3, 0.6))
            t += rng.uniform(0.3, 1.2)

    for start in (4.5, 11.2, 18.7, 26.4):
        t = start
        for _ in range(rng.randint(3, 7)):
            room.add(_page_turn(rng), room.at(t), rng.uniform(0.4, 0.7))
            t += rng.uniform(0.2, 0.6)

    # occasional thump/kick
    for t in (3.5, 9.8, 14.2, 21.7, 27.1):
        room.add(kick(secs=0.15, f0=110.0, f1=50.0), room.at(t), 0.35)

    finish("music_noise", lowpass(room.buf, 5000.0, loop=True), 0.11)


def make_music_win():
    """The trophy fanfare, 2.5 s, one-shot. C major: G4-C5-E5 quick, G5
    held, E5, then G5 held long with vibrato, over a triangle C-E-G pad, a
    C3 bass and a wisp of high noise for the shimmer. Ends in silence."""
    n = int(RATE * 2.5)
    buf = Loop(n, wrap=False)
    rng = random.Random(4404)
    lead_env = (0.004, 0.05, 0.8, 0.15)
    for t, note, hold in ((0.0, "G4", 0.09), (0.10, "C5", 0.09), (0.20, "E5", 0.09),
                          (0.30, "G5", 0.36), (0.68, "E5", 0.14), (0.84, "G5", 1.20)):
        buf.add(voice(note_hz(note), int(RATE * hold), kind="pulse", duty=0.5,
                      env=lead_env, vib=(5.5, 0.007, 0.15) if hold > 1.0 else None),
                buf.at(t), 0.42)
    for note in ("C4", "E4", "G4"):
        buf.add(voice(note_hz(note), int(RATE * 1.5), kind="tri",
                      env=(0.04, 0.2, 0.7, 0.45)), buf.at(0.30), 0.22)
    buf.add(voice(note_hz("C3"), int(RATE * 1.4), kind="tri",
                  env=(0.01, 0.1, 0.7, 0.4)), buf.at(0.30), 0.45)
    buf.add(hit(rng, 0.6, 0.18, lo=5000.0), buf.at(0.30), 0.12)
    finish("music_win", fade_out(lowpass(buf.buf, 6000.0), 0.04), 0.85, loop=False)


def make_music_lose():
    """The other sting, 2.5 s: a falling figure on a triangle -- E4, C4, A3,
    then E3 held and sagging a little flat -- over a low A that fades, and
    a breath of low noise. Disappointment, not a funeral."""
    n = int(RATE * 2.5)
    buf = Loop(n, wrap=False)
    rng = random.Random(5505)
    for t, note, hold, glide in ((0.0, "E4", 0.20, 1.0), (0.24, "C4", 0.20, 1.0),
                                 (0.48, "A3", 0.26, 1.0), (0.78, "E3", 1.10, 0.97)):
        buf.add(voice(note_hz(note), int(RATE * hold), kind="tri",
                      env=(0.01, 0.08, 0.75, 0.35), glide=glide,
                      vib=(4.5, 0.005, 0.3) if hold > 1.0 else None), buf.at(t), 0.5)
    buf.add(voice(note_hz("A2"), int(RATE * 1.3), kind="tri",
                  env=(0.02, 0.2, 0.6, 0.5)), buf.at(0.78), 0.4)
    # a breath: low noise that swells and falls with the last note
    m = int(RATE * 1.4)
    breath = lowpass([rng.uniform(-1.0, 1.0) for _ in range(m)], 900.0)
    breath = [v * math.sin(math.pi * i / float(m)) ** 2 for i, v in enumerate(breath)]
    buf.add(breath, buf.at(0.6), 0.10)
    finish("music_lose", fade_out(lowpass(buf.buf, 5000.0), 0.05), 0.80, loop=False)


## Every track that is an ambience bed (plays continuously, under whatever
## the player is doing) rather than a foreground track like the title
## theme or the assessment. bed_check() holds every one of these to the
## same "well under the sound effects" rule music_room was built to.
BEDS = ("music_room", "music_morning", "music_test", "music_afternoon", "music_noise")


def bed_check():
    """The ambience must sit under every sound effect, by a margin. Compare
    RMS after normalisation -- the number the player's speaker actually
    gets -- against the quietest effect, not the loudest."""
    sfx = {k: v for k, v in STATS.items() if not k.startswith("music_")}
    quietest = min(sfx, key=sfx.get)
    for name in BEDS:
        bed = STATS[name]
        print("bed check: %s rms %.4f  vs sfx rms mean %.4f, quietest %s %.4f"
              "  -> the bed is %.1fx under the quietest effect"
              % (name, bed, sum(sfx.values()) / len(sfx), quietest, sfx[quietest],
                 sfx[quietest] / bed))
        if bed * 2.0 > sfx[quietest]:
            raise SystemExit("%s is not well under the sound effects" % name)


if __name__ == "__main__":
    random.seed(7)          # same sounds every run
    os.makedirs(OUT, exist_ok=True)
    make_bell()
    make_step()
    make_stuck()
    make_help()
    make_paper()
    make_coins()
    make_blip()
    make_confirm()
    make_deny()
    make_grade()
    make_start()
    make_chatter()
    print("")
    print("music and ambience (every loop an exact sample count, seam measured)")
    make_music_title()
    make_music_room()
    make_music_morning()
    make_music_test()
    make_music_afternoon()
    make_music_noise()
    make_music_fight()
    make_music_win()
    make_music_lose()
    print("")
    bed_check()
    print("done")
