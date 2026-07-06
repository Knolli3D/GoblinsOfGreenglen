#!/usr/bin/env python3
"""Generiert alle Chiptune-Sounds (SFX + Musik-Loop) als 16-bit Mono-WAVs
nach assets/audio/. Nur Python-Stdlib, kein numpy noetig.

Aufruf:  python3 tools/generate_audio.py
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def midi_to_freq(n: float) -> float:
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


def square(phase: float, duty: float = 0.5) -> float:
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase: float) -> float:
    p = phase % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def saw(phase: float) -> float:
    return 2.0 * (phase % 1.0) - 1.0


def render_tone(samples, start, dur, f_start, f_end=None, vol=0.5,
                wave_fn=square, attack=0.005, release=None, duty=0.5):
    """Mischt einen Ton (optional mit Frequenz-Sweep) additiv in `samples`."""
    if f_end is None:
        f_end = f_start
    if release is None:
        release = dur * 0.6
    n = int(dur * SAMPLE_RATE)
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = f_start + (f_end - f_start) * (t / dur)
        phase += freq / SAMPLE_RATE
        env = 1.0
        if t < attack:
            env = t / attack
        rem = dur - t
        if rem < release:
            env *= rem / release
        idx = start + i
        if idx < len(samples):
            v = wave_fn(phase, duty) if wave_fn is square else wave_fn(phase)
            samples[idx] += v * vol * env


def render_noise(samples, start, dur, vol=0.4, seed=7):
    rng = random.Random(seed)
    n = int(dur * SAMPLE_RATE)
    val = 0.0
    for i in range(n):
        # leicht gefiltertes Rauschen (klingt dumpfer/percussiver)
        val = 0.6 * val + 0.4 * rng.uniform(-1.0, 1.0)
        env = 1.0 - i / n
        idx = start + i
        if idx < len(samples):
            samples[idx] += val * vol * env * env


def write_wav(name: str, samples):
    path = os.path.join(OUT_DIR, name)
    frames = bytearray()
    for s in samples:
        s = max(-1.0, min(1.0, s))
        frames += struct.pack("<h", int(s * 32000))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(bytes(frames))
    print("wrote %-18s %6.2fs" % (name, len(samples) / SAMPLE_RATE))


def buf(dur: float):
    return [0.0] * int(dur * SAMPLE_RATE)


def gen_sfx():
    # Jump: Square-Sweep nach oben
    s = buf(0.16)
    render_tone(s, 0, 0.14, 250, 550, vol=0.5)
    write_wav("jump.wav", s)

    # Double-Jump: hoeherer Sweep
    s = buf(0.16)
    render_tone(s, 0, 0.14, 380, 800, vol=0.5)
    write_wav("double_jump.wav", s)

    # Coin: zwei helle Noten (B5 -> E6)
    s = buf(0.22)
    render_tone(s, 0, 0.07, 988, vol=0.4, duty=0.3)
    render_tone(s, int(0.07 * SAMPLE_RATE), 0.14, 1319, vol=0.4, duty=0.3)
    write_wav("coin.wav", s)

    # Stomp: Noise-Burst + tiefer Thump
    s = buf(0.18)
    render_noise(s, 0, 0.10, vol=0.5)
    render_tone(s, 0, 0.14, 130, 55, vol=0.55, wave_fn=triangle)
    write_wav("stomp.wav", s)

    # Hit: Saw-Sweep nach unten
    s = buf(0.25)
    render_tone(s, 0, 0.22, 300, 90, vol=0.45, wave_fn=saw)
    write_wav("hit.wav", s)

    # Death: absteigende Notenfolge
    s = buf(0.75)
    for i, m in enumerate([67, 64, 60, 55]):  # G4 E4 C4 G3
        render_tone(s, int(i * 0.16 * SAMPLE_RATE), 0.15,
                    midi_to_freq(m), vol=0.45)
    write_wav("death.wav", s)

    # Level Cleared: aufsteigendes Arpeggio C5 E5 G5 C6
    s = buf(0.75)
    for i, m in enumerate([72, 76, 79, 84]):
        dur = 0.10 if i < 3 else 0.32
        render_tone(s, int(i * 0.11 * SAMPLE_RATE), dur,
                    midi_to_freq(m), vol=0.42)
    write_wav("level_clear.wav", s)

    # Win: kleine Fanfare
    s = buf(1.5)
    notes = [(72, 0.12), (72, 0.12), (72, 0.12), (76, 0.28),
             (79, 0.12), (76, 0.12), (79, 0.55)]
    t = 0.0
    for m, d in notes:
        render_tone(s, int(t * SAMPLE_RATE), d, midi_to_freq(m), vol=0.42)
        render_tone(s, int(t * SAMPLE_RATE), d, midi_to_freq(m - 12),
                    vol=0.2, wave_fn=triangle)
        t += d * 0.95
    write_wav("win.wav", s)

    # UI-Click: kurzer Tick
    s = buf(0.05)
    render_tone(s, 0, 0.035, 1200, vol=0.35, duty=0.25)
    write_wav("click.wav", s)


def gen_music():
    """8-Takt-Chiptune-Loop, 140 BPM, C-Dur. Melodie (Square) + Bass (Triangle)."""
    bpm = 140
    eighth = 60.0 / bpm / 2.0
    bars = [
        # (Melodie-Achtel als MIDI, 0 = Pause), Bass-Grundton
        ([72, 76, 79, 76, 72, 76, 79, 76], 48),
        ([74, 77, 81, 77, 74, 77, 81, 77], 50),
        ([76, 79, 83, 79, 76, 79, 83, 79], 52),
        ([79, 77, 76, 74, 72, 74, 76, 77], 55),
        ([72, 76, 79, 76, 72, 76, 79, 76], 48),
        ([74, 77, 81, 77, 74, 77, 81, 77], 50),
        ([76, 79, 83, 79, 81, 79, 77, 74], 52),
        ([72, 0, 76, 0, 79, 83, 84, 0],   55),
    ]
    total = len(bars) * 8 * eighth
    s = buf(total)
    t = 0.0
    for melody, bass_root in bars:
        for k, m in enumerate(melody):
            if m > 0:
                render_tone(s, int(t * SAMPLE_RATE), eighth * 0.9,
                            midi_to_freq(m), vol=0.22, duty=0.4)
            # Bass: Viertelnoten, Grundton/Quinte im Wechsel
            if k % 2 == 0:
                b = bass_root if k % 4 == 0 else bass_root + 7
                render_tone(s, int(t * SAMPLE_RATE), eighth * 1.8,
                            midi_to_freq(b - 12), vol=0.18, wave_fn=triangle)
            t += eighth
    write_wav("music.wav", s)


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    random.seed(42)
    gen_sfx()
    gen_music()
