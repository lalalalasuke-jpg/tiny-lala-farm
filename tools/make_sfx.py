# コードで作る効果音（sfx/code/*.wav）を作り直すスクリプト。
# 使い方: uv run --no-project python tools/make_sfx.py
# 音は「音の高さ（周波数）× 長さ × 波の形 × 音量の変化（エンベロープ）」の組み合わせで作っている。
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "sfx" / "code"


def tone(freq_from, freq_to, dur, wave_kind="sine", vol=0.5, attack=0.005, release=None):
    """freq_from → freq_to へ音の高さを変えながら鳴らす。release は消えていく時間（省略で全体）"""
    n = int(RATE * dur)
    release = dur if release is None else release
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq_from + (freq_to - freq_from) * (i / n)
        phase += 2 * math.pi * f / RATE
        if wave_kind == "sine":
            v = math.sin(phase)
        elif wave_kind == "square":
            v = 0.6 if math.sin(phase) >= 0 else -0.6
        elif wave_kind == "triangle":
            v = 2 / math.pi * math.asin(math.sin(phase))
        else:  # noise
            v = random.uniform(-1, 1)
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= max(0.0, 1 - max(0.0, t - (dur - release)) / release)
        out.append(v * env * vol)
    return out


def lowpass(samples, k=0.15):
    y = 0.0
    out = []
    for s in samples:
        y += k * (s - y)
        out.append(y)
    return out


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(RATE * gap)
    return out


def mix(a, b):
    n = max(len(a), len(b))
    return [(a[i] if i < len(a) else 0) + (b[i] if i < len(b) else 0) for i in range(n)]


def save(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples))


random.seed(1)
C5, E5, G5, C6, E6 = 523.3, 659.3, 784.0, 1046.5, 1318.5
save("till", mix(lowpass(tone(0, 0, 0.12, "noise", 0.9), 0.08), tone(180, 90, 0.1, "sine", 0.5)))  # ざくっ
save("sow", seq(tone(1400, 1600, 0.04, "sine", 0.3), tone(1700, 1900, 0.04, "sine", 0.3), gap=0.03))  # ぱらぱら
save("water", mix(tone(900, 300, 0.18, "sine", 0.45), lowpass(tone(0, 0, 0.2, "noise", 0.25), 0.3)))  # ちゃぷん
save("harvest", tone(400, 1200, 0.09, "triangle", 0.55))  # ぽんっ
save("good", seq(*(tone(f, f, 0.08, "square", 0.25, release=0.06) for f in (C6, E6, G5 * 2, C6 * 2))))  # きらりん
save("fert", tone(220, 110, 0.15, "triangle", 0.6))  # どさっ
save("clear", lowpass(tone(0, 0, 0.18, "noise", 0.6), 0.25))  # がさがさ
save("ship", seq(tone(988, 988, 0.06, "square", 0.25), tone(1319, 1319, 0.2, "square", 0.25)))  # チャリーン
save("error", seq(tone(200, 200, 0.08, "square", 0.25), tone(160, 160, 0.12, "square", 0.25), gap=0.04))  # ぶぶっ
save("click", tone(1200, 1200, 0.03, "sine", 0.3))  # ぴっ
save("morning", seq(*(tone(f, f, 0.12, "triangle", 0.4) for f in (C5, E5, G5, C6))))  # おはよう
print("saved to", OUT)
