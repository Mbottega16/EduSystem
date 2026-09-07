
import math
import random
import struct
import io
import wave

RATE = 22050
STATS = {}

def envelope(n, attack=0.01, decay=0.9, sustain=0.0):
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

def save_to_bytes(name, samples, gain=0.5):
    peak = max(1e-6, max(abs(s) for s in samples))
    scaled = [max(-1.0, min(1.0, s / peak * gain)) for s in samples]
    STATS[name] = math.sqrt(sum(s * s for s in scaled) / float(len(scaled)))
    data = b"".join(struct.pack("<h", int(s * 32767)) for s in scaled)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    return buf.getvalue()

# ----------------------------------------------------------------- sfx

def make_bell(base_freq=660, secs=1.8, gain=0.8):
    layers = []
    for mult, g, dec in ((1.0, 1.0, 0.55), (2.76, 0.55, 0.45),
                            (5.40, 0.30, 0.35), (8.93, 0.16, 0.3)):
        t = tone(base_freq * mult, secs)
        layers.append([s * g for s in apply_env(t, attack=0.002, decay=dec)])
    return save_to_bytes("bell", mix(*layers), gain)

def make_step(secs=0.07, smoothing=0.72, gain=0.28):
    n = int(RATE * secs)
    raw = [random.uniform(-1, 1) for _ in range(n)]
    smooth = []
    acc = 0.0
    for v in raw:
        acc = acc * smoothing + v * (1.0 - smoothing)
        smooth.append(acc)
    return save_to_bytes("step", apply_env(smooth, attack=0.02, decay=0.3), gain)

def make_stuck(f1=520, f2=392, t1=0.10, t2=0.16, gain=0.42):
    a = apply_env(tone(f1, t1, "tri"), attack=0.01, decay=0.5)
    b = apply_env(tone(f2, t2, "tri"), attack=0.01, decay=0.4)
    return save_to_bytes("stuck", a + b, gain)

def make_help(f1=523, f2=784, f3=1568, shimmer_gain=0.3, gain=0.5):
    a = apply_env(tone(f1, 0.08, "sine"), attack=0.005, decay=0.5)
    b = apply_env(tone(f2, 0.14, "sine"), attack=0.005, decay=0.45)
    shimmer = apply_env(tone(f3, 0.14, "sine"), attack=0.005, decay=0.3)
    return save_to_bytes("help", a + [x + y * shimmer_gain for x, y in zip(b, shimmer)], gain)

def make_paper(secs=0.16, mix_factor=0.5, burst_mod=0.35, gain=0.3):
    n = int(RATE * secs)
    out = []
    acc = 0.0
    for i in range(n):
        v = random.uniform(-1, 1)
        acc = acc * mix_factor + v * (1.0 - mix_factor)
        burst = 1.0 if (i % 1900) < 700 else burst_mod
        out.append(acc * burst)
    return save_to_bytes("paper", apply_env(out, attack=0.05, decay=0.4), gain)

def make_coins(f1=1046, f2=1318, f3=1568, detune=0.02, gain=0.45):
    out = []
    for i, f in enumerate((f1, f2, f3)):
        t = apply_env(tone(f, 0.13, "tri", detune=detune), attack=0.003, decay=0.4)
        pad = [0.0] * int(RATE * 0.045 * i)
        out = mix(out + [0.0] * len(t), pad + t) if out else pad + t
    return save_to_bytes("coins", out, gain)

def make_blip(freq=880, secs=0.045, gain=0.16):
    return save_to_bytes("blip", apply_env(tone(freq, secs, "square"), attack=0.002, decay=0.6), gain)

def make_confirm(f1=659, f2=988, gain=0.24):
    a = apply_env(tone(f1, 0.06, "square"), attack=0.002, decay=0.5)
    b = apply_env(tone(f2, 0.10, "square"), attack=0.002, decay=0.5)
    return save_to_bytes("confirm", a + b, gain)

def make_deny(freq=180, secs=0.14, gain=0.25):
    return save_to_bytes("deny", apply_env(tone(freq, secs, "square"), attack=0.003, decay=0.5), gain)

def make_grade(f1=392, f2=494, f3=587, f4=784, gain=0.5):
    layers = [apply_env(tone(f, 0.85, "tri"), attack=0.01, decay=0.5)
              for f in (f1, f2, f3, f4)]
    return save_to_bytes("grade", mix(*layers), gain)

def make_start(f1=440, f2=587, gain=0.45):
    a = apply_env(tone(f1, 0.12, "tri"), attack=0.01, decay=0.5)
    b = apply_env(tone(f2, 0.20, "tri"), attack=0.01, decay=0.4)
    return save_to_bytes("start", a + b, gain)

# Registry for dynamic calling and UI parameter generation
REGISTRY = {
    "bell": {"func": make_bell, "params": {"base_freq": 660, "secs": 1.8, "gain": 0.8}},
    "step": {"func": make_step, "params": {"secs": 0.07, "smoothing": 0.72, "gain": 0.28}},
    "stuck": {"func": make_stuck, "params": {"f1": 520, "f2": 392, "t1": 0.10, "t2": 0.16, "gain": 0.42}},
    "help": {"func": make_help, "params": {"f1": 523, "f2": 784, "f3": 1568, "shimmer_gain": 0.3, "gain": 0.5}},
    "paper": {"func": make_paper, "params": {"secs": 0.16, "mix_factor": 0.5, "burst_mod": 0.35, "gain": 0.3}},
    "coins": {"func": make_coins, "params": {"f1": 1046, "f2": 1318, "f3": 1568, "detune": 0.02, "gain": 0.45}},
    "blip": {"func": make_blip, "params": {"freq": 880, "secs": 0.045, "gain": 0.16}},
    "confirm": {"func": make_confirm, "params": {"f1": 659, "f2": 988, "gain": 0.24}},
    "deny": {"func": make_deny, "params": {"freq": 180, "secs": 0.14, "gain": 0.25}},
    "grade": {"func": make_grade, "params": {"f1": 392, "f2": 494, "f3": 587, "f4": 784, "gain": 0.5}},
    "start": {"func": make_start, "params": {"f1": 440, "f2": 587, "gain": 0.45}},
}

def generate(sound_name, **kwargs):
    if sound_name not in REGISTRY:
        raise ValueError(f"Unknown sound {sound_name}")
    func = REGISTRY[sound_name]["func"]
    return func(**kwargs)


if __name__ == "__main__":
    import sys
    import os
    if len(sys.argv) < 2:
        print("Usage: python forge_audio.py <sound_name> [key=value] [count=N] [variance=0.1]")
        print("Available sounds:", ", ".join(REGISTRY.keys()))
        sys.exit(1)
    
    sound_name = sys.argv[1]
    if sound_name == "list":
        # One name per line, for the Master Forge's Audio dropdown. The
        # no-argument usage text above is for a human at a prompt; a tool
        # parsing that would pick up the word "Usage:" as a sound.
        for n in sorted(REGISTRY):
            print(n)
        sys.exit(0)
    if sound_name not in REGISTRY:
        print(f"Unknown sound {sound_name}")
        sys.exit(1)
        
    kwargs = {}
    count = 1
    variance = 0.0
    for arg in sys.argv[2:]:
        if "=" in arg:
            k, v = arg.split("=", 1)
            if k == "count":
                count = int(v)
            elif k == "variance":
                variance = float(v)
            else:
                kwargs[k] = float(v)
            
    try:
        import random
        for i in range(count):
            iter_kwargs = {}
            # Apply variance
            for k, v in kwargs.items():
                if variance > 0.0 and k != "gain":
                    iter_kwargs[k] = v * random.uniform(1.0 - variance, 1.0 + variance)
                else:
                    iter_kwargs[k] = v
            # Use default params for anything not specified
            for k, v in REGISTRY[sound_name]["params"].items():
                if k not in iter_kwargs:
                    if variance > 0.0 and k != "gain":
                        iter_kwargs[k] = v * random.uniform(1.0 - variance, 1.0 + variance)
                    else:
                        iter_kwargs[k] = v

            wav_bytes = generate(sound_name, **iter_kwargs)
            out_name = f"{sound_name}.wav" if count == 1 else f"{sound_name}_{i+1}.wav"
            out_path = os.path.join(os.getcwd(), "audio", out_name)
            if not os.path.exists(os.path.dirname(out_path)):
                out_path = out_name
            with open(out_path, "wb") as f:
                f.write(wav_bytes)
            print(f"Successfully forged and saved {out_name} to {out_path} with params {iter_kwargs}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)