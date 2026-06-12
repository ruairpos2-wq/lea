# Qwen3-TTS — голос Леи на RunPod Serverless

Self-host TTS вместо Edge/Fish. Модель **Qwen3-TTS-12Hz-1.7B-CustomVoice**, голос
**serena** (тёплый молодой женский, русский), Apache-2.0 (коммерция разрешена).
Эмоция Леи приходит как `instruct`. Платишь только за секунды синтеза (scale-to-zero).

Файлы: `handler.py` (воркер), `Dockerfile` (печёт веса в образ), `requirements.txt`.

---

## 1. Залить в свой GitHub-репозиторий

RunPod Serverless умеет собирать образ прямо из репо — локальный Docker не нужен.

```bash
# из папки runpod-qwen-tts/
git init && git add . && git commit -m "qwen3-tts runpod worker"
gh repo create leabot-qwen-tts --private --source=. --push   # или вручную создать репо и запушить
```

## 2. Создать Serverless-эндпоинт

RunPod Console → **Serverless** → **New Endpoint** → **Import Git Repository** → выбрать репо.
- **Dockerfile path**: `Dockerfile`
- **GPU**: 16 GB (A4000 / A5000 / L4 / RTX 4090) — модели хватает ~4.3 ГБ, остальное запас.
- **Container disk**: ≥ 20 GB (веса вшиты в образ).
- **Active workers**: 0 (scale-to-zero, дёшево). Чтобы убрать холодный старт — поставь 1.
- **Idle timeout**: 30–60 с. **FlashBoot**: включить (быстрее холодный старт).
- **Max workers**: 1–3.
- Env (необязательно, дефолты уже в образе): `QWEN_SPEAKER=serena`, `QWEN_LANGUAGE=Russian`.

Деплой соберёт образ (~10–15 мин из-за torch + вшитых весов). После — скопируй
**Endpoint ID** и возьми **RunPod API Key** (Settings → API Keys).

## 3. Подключить к LEABOT

В прод `.env` на сервере (`/var/www/leabot/.env`):

```env
TTS_PROVIDER="qwen"
RUNPOD_API_KEY="<твой RunPod API key>"
QWEN_TTS_ENDPOINT_ID="<Endpoint ID>"
# опционально:
# QWEN_TTS_SPEAKER="serena"
# QWEN_TTS_LANGUAGE="Russian"
# QWEN_TTS_TIMEOUT_MS="45000"
```

Затем `pm2 restart leabot-app --update-env`. Без этих env LEABOT работает как раньше
(Edge). При сбое/холодном промахе Qwen — авто-фолбэк на Edge для конкретной реплики.

## 4. Проверка эндпоинта

```bash
curl -s -X POST "https://api.runpod.ai/v2/<ENDPOINT_ID>/runsync" \
  -H "Authorization: Bearer <RUNPOD_API_KEY>" -H "Content-Type: application/json" \
  -d '{"input":{"text":"Привет, я Лея. Я рядом с тобой.","language":"Russian","speaker":"serena","instruct":"Тёплым, заботливым тоном"}}' \
  | python3 -c "import sys,json,base64; d=json.load(sys.stdin)['output']; open('out.wav','wb').write(base64.b64decode(d['audio_base64'])); print('saved out.wav', d['sample_rate'])"
```

---

## Заметки

- **Голоса** (`QWEN_SPEAKER`): serena (тёплый жен.), vivian, ono_anna, sohee, ryan,
  aiden, dylan, eric, uncle_fu. Рекомендуется serena/ono_anna/sohee для Леи.
- **Скорость**: на A4000 RTF ~1.6 (короткая фраза → ~2.5 с). LEABOT синтезирует
  по предложениям (streaming-tts), поэтому первое аудио приходит быстро.
- **Холодный старт**: при 0 active workers первый запрос после простоя ~20–40 с
  (грузится модель) → эта реплика уйдёт на Edge-фолбэк, дальше Qwen. Хочешь без
  задержек — 1 active worker (платишь за него постоянно) или FlashBoot.
- **Клон реального голоса Леи** (позже): нужна модель `*-1.7B-Base` +
  `generate_voice_clone(ref_audio, ref_text)` с чистой записью .wav 3–15 с.
  Тогда меняем handler на Base+clone и баним speaker.
