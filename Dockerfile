# Stage 1: Download model files
FROM python:3.12-slim AS model-downloader

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

WORKDIR /models
RUN curl -L -o kokoro-v1.0.onnx \
      https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx && \
    curl -L -o voices-v1.0.bin \
      https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin

# Stage 2: Runtime (NVIDIA CUDA for GPU acceleration)
FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip ffmpeg && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --break-system-packages -r requirements.txt && \
    pip install --no-cache-dir --break-system-packages onnxruntime-gpu

# Copy model files from downloader stage
COPY --from=model-downloader /models/kokoro-v1.0.onnx .
COPY --from=model-downloader /models/voices-v1.0.bin .

# Copy application code
COPY . .

RUN mkdir -p /app/mp3

EXPOSE 3050

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD python3 -c "import socket; s=socket.socket(); s.settimeout(2); s.connect(('127.0.0.1',3050)); s.close()"

CMD ["python3", "mcp-tts.py", "--transport", "streamable-http", "--host", "0.0.0.0", "--port", "3050"]
