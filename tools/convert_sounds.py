"""Replace the Xbox 360 XMA sounds embedded in HexicDeluxe.swf with PCM.

The Xbox build stores every DefineSound with a non-standard format id (14)
whose payload is a RIFF/WAVE file containing XMA audio. No Flash player
outside the Xbox can decode that, so each one is decoded with ffmpeg and
re-embedded as uncompressed 16-bit PCM (format 3). MP3 was tried first, but
several effects peak at or above full scale and the MP3 round trip clipped
their bass; PCM plus a little headroom keeps them clean.
"""
import re
import struct
import subprocess
import tempfile
from pathlib import Path

from swf import DEFINE_SOUND

XMA_WAVE_FORMAT = 14
RATE = 44100
PEAK_CEILING_DB = -1.0


def ffmpeg(*args):
    result = subprocess.run(["ffmpeg", "-hide_banner", "-y", *args], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg {' '.join(args)} failed:\n{result.stderr}")
    return result.stderr


def peak_db(path):
    log = ffmpeg("-i", str(path), "-af", "astats=metadata=0:measure_perchannel=none", "-f", "null", "-")
    return float(re.search(r"Peak level dB: (-?[\d.]+|-inf)", log).group(1))


def to_pcm_sound(sound_id, wav_bytes, tmp):
    src, pcm = tmp / f"{sound_id}.wav", tmp / f"{sound_id}.pcm"
    src.write_bytes(wav_bytes)
    # Only turn down sounds that would otherwise clip; the rest keep their level.
    gain_db = min(0.0, PEAK_CEILING_DB - peak_db(src))
    ffmpeg("-i", str(src), "-af", f"volume={gain_db}dB", "-ar", str(RATE), "-ac", "2",
           "-f", "s16le", "-c:a", "pcm_s16le", str(pcm))
    samples = pcm.stat().st_size // 4
    # format 3 (uncompressed little-endian), rate 3 (44 kHz), 16-bit, stereo
    flags = (3 << 4) | (3 << 2) | (1 << 1) | 1
    return struct.pack("<HBI", sound_id, flags, samples) + pcm.read_bytes()


def convert_sounds(swf):
    converted = 0
    with tempfile.TemporaryDirectory() as tmp:
        for i, (code, data) in enumerate(swf.tags):
            if code == DEFINE_SOUND and data[2] >> 4 == XMA_WAVE_FORMAT:
                sound_id, = struct.unpack_from("<H", data)
                swf.tags[i] = (code, to_pcm_sound(sound_id, data[7:], Path(tmp)))
                converted += 1
    return converted
