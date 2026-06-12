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

# torch с CUDA 12.8 (колёса несут вшитую CUDA/cuDNN — совместимо с драйвером RunPod)
RUN pip3 install --no-cache-dir --break-system-packages \
      torch --index-url https://download.pytorch.org/whl/cu128

# qwen-tts + рантайм RunPod. flash-attn НЕ ставим — для TTS он не ускоряет.
RUN pip3 install --no-cache-dir --break-system-packages \
      qwen-tts soundfile runpod "huggingface_hub[hf_transfer]"

# Печём веса в образ → холодный старт без скачивания (модель ~4.3ГБ + токенайзер).
RUN python3 -c "from huggingface_hub import snapshot_download; \
snapshot_download('Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice'); \
snapshot_download('Qwen/Qwen3-TTS-Tokenizer-12Hz')"

COPY handler.py /handler.py
CMD ["python3", "-u", "/handler.py"]
