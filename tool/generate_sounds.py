#!/usr/bin/env python3
"""Generates Pastello's interface sounds (F-15) as small WAV files.

The sounds are synthesized here, so they are original works of the project,
dedicated to the public domain (CC0). Run from the repository root:

    python3 tool/generate_sounds.py
"""
import math
import random
import struct
import wave

RATE = 22050


def write(name, samples):
    with wave.open(f"app/assets/sounds/{name}.wav", "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        peak = max(abs(s) for s in samples) or 1
        f.writeframes(
            b"".join(struct.pack("<h", int(s / peak * 0.6 * 32767)) for s in samples)
        )


def envelope(t, attack, length):
    if t < attack:
        return t / attack
    return max(0.0, 1 - (t - attack) / (length - attack)) ** 2


def pop():
    # A short, round "bloop": a sine sliding down in pitch.
    length = 0.12
    out = []
    phase = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        freq = 900 - 500 * (t / length)
        phase += 2 * math.pi * freq / RATE
        out.append(math.sin(phase) * envelope(t, 0.004, length))
    return out


def whoosh():
    # Filtered noise rising and falling: something flying into the trash.
    random.seed(7)
    length = 0.35
    out = []
    low = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        # The filter opens and closes, so the noise "moves".
        cutoff = 0.05 + 0.25 * math.sin(math.pi * t / length)
        low += cutoff * (random.uniform(-1, 1) - low)
        out.append(low * math.sin(math.pi * t / length))
    return out


def ding():
    # A soft bell: two harmonics with a long decay.
    length = 0.6
    out = []
    for i in range(int(RATE * length)):
        t = i / RATE
        e = math.exp(-5 * t) * min(1.0, t / 0.005)
        out.append(
            e * (math.sin(2 * math.pi * 1318.5 * t) + 0.4 * math.sin(2 * math.pi * 2637 * t))
        )
    return out


write("pop", pop())
write("whoosh", whoosh())
write("ding", ding())
