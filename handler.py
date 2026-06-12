"""
RunPod Serverless worker — Qwen3-TTS (главный голос Леи).

Модель: Qwen3-TTS-12Hz-1.7B-CustomVoice, голос "serena" (тёплый молодой женский,
русский). Apache-2.0. Эмоция приходит из LEABOT как текстовая инструкция стиля
(`instruct`). Модель грузится один раз при старте воркера, далее переиспользуется.

Вход (job["input"]):
  { "text": str, "language"?: str="Russian", "speaker"?: str="serena", "instruct"?: str }
Выход:
  { "audio_base64": str(WAV), "sample_rate": int, "mime": "audio/wav" }
  либо { "error": str }
"""

import os
import io
import base64
import traceback

import torch
import soundfile as sf
import runpod
from qwen_tts import Qwen3TTSModel

MODEL_ID = os.environ.get("QWEN_MODEL_ID", "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice")
DEFAULT_SPEAKER = os.environ.get("QWEN_SPEAKER", "serena")
DEFAULT_LANGUAGE = os.environ.get("QWEN_LANGUAGE", "Russian")
MAX_CHARS = int(os.environ.get("QWEN_MAX_CHARS", "1200"))

print(f"[qwen-tts] loading model {MODEL_ID} ...", flush=True)
model = Qwen3TTSModel.from_pretrained(
    MODEL_ID,
    device_map="cuda:0",
    dtype=torch.bfloat16,
)
print("[qwen-tts] model ready", flush=True)


def handler(job):
    inp = (job or {}).get("input") or {}
    text = (inp.get("text") or "").strip()
    if not text:
        return {"error": "text is required"}
    if len(text) > MAX_CHARS:
        text = text[:MAX_CHARS]

    speaker = inp.get("speaker") or DEFAULT_SPEAKER
    language = inp.get("language") or DEFAULT_LANGUAGE
    instruct = (inp.get("instruct") or "").strip() or None

    try:
        wavs, sr = model.generate_custom_voice(
            text=text,
            language=language,
            speaker=speaker,
            instruct=instruct,
        )
    except Exception as exc:  # noqa: BLE001
        traceback.print_exc()
        return {"error": f"synthesis failed: {exc}"}

    buf = io.BytesIO()
    sf.write(buf, wavs[0], sr, format="WAV")
    return {
        "audio_base64": base64.b64encode(buf.getvalue()).decode("ascii"),
        "sample_rate": int(sr),
        "mime": "audio/wav",
    }


runpod.serverless.start({"handler": handler})
