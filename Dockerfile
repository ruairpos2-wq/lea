# Qwen3-TTS serverless worker для RunPod. Голос Леи: Serena, русский.
# База Ubuntu 24.04 (Python 3.12 из коробки) + CUDA 12.8 cuDNN runtime.
# Если этот тег недоступен — возьми любой соседний 12.8.x-cudnn-runtime-ubuntu24.04.
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    HF_HOME=/models/hf \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip sox ffmpeg libsndfile1 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# qwen-tts + рантайм RunPod (тянет свои torch/torchaudio). flash-attn НЕ ставим.
RUN pip3 install --no-cache-dir --break-system-packages \
      qwen-tts soundfile runpod "huggingface_hub[hf_transfer]"

# КРИТИЧНО: привести torch И torchaudio к ОДНОЙ сборке cu128 (CUDA 12.8). Иначе
# pip ставит torchaudio из PyPI под CUDA 13 → при импорте падает
# "libcudart.so.13: cannot open shared object file" и воркер вылетает (exit 1).
# --no-deps меняет только эти два пакета, не трогая остальные зависимости qwen-tts.
RUN pip3 install --no-cache-dir --break-system-packages --force-reinstall --no-deps \
      torch==2.8.0 torchaudio==2.8.0 --index-url https://download.pytorch.org/whl/cu128

# Печём веса в образ → холодный старт без скачивания (модель ~4.3ГБ + токенайзер).
RUN python3 -c "from huggingface_hub import snapshot_download; \
snapshot_download('Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice'); \
snapshot_download('Qwen/Qwen3-TTS-Tokenizer-12Hz')"

COPY handler.py /handler.py
CMD ["python3", "-u", "/handler.py"]
