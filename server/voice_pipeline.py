import numpy as np
import asyncio
from scipy.signal import resample_poly
from faster_whisper import WhisperModel

WHISPER_RATE = 16000  # Whisper always expects 16 kHz

# tiny.en is English-only but ~30% faster than multilingual tiny
whisper_model = WhisperModel("tiny.en", device="cpu", compute_type="int8")


async def transcribe_audio(audio_bytes: bytes, sample_rate: int = 44100) -> str:
    loop = asyncio.get_event_loop()

    def _transcribe():
        audio_np = np.frombuffer(audio_bytes, dtype=np.float32).copy()
        if audio_np.size == 0:
            return ""

        # Resample from Godot's mix rate down to 16 kHz (what Whisper expects)
        if sample_rate != WHISPER_RATE:
            audio_np = resample_poly(
                audio_np, WHISPER_RATE, sample_rate
            ).astype(np.float32, copy=False)

        # Require at least 0.5s of audio after resampling
        if audio_np.size < WHISPER_RATE * 0.5:
            return ""

        # Normalize to handle quiet mics
        peak = float(np.max(np.abs(audio_np)))
        if peak < 1e-6:
            return ""  # silence, skip entirely
        audio_np = audio_np / peak

        segments, _ = whisper_model.transcribe(
            audio_np,
            language="en",
            beam_size=1,
            vad_filter=True,
            vad_parameters={"min_silence_duration_ms": 300},
            condition_on_previous_text=False,
        )
        return " ".join(s.text.strip() for s in segments).strip()

    return await loop.run_in_executor(None, _transcribe)


async def synthesize_ghost_voice(
    text: str,
    voice_id: str = None,
    stability: float = 0.3,
    similarity: float = 0.8,
) -> bytes:
    _ = (text, voice_id, stability, similarity)
    return b""