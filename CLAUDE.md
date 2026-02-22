# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kokoro TTS MCP Server — an MCP (Model Context Protocol) server that generates MP3 audio from text using the Kokoro ONNX TTS model. Supports optional S3 upload, multiple transport modes, and GPU acceleration via CUDA.

## Running the Server

```bash
# Local development (default: streamable-http on port 9876)
uv run mcp-tts.py

# With specific transport
uv run mcp-tts.py --transport stdio      # For Claude Desktop
uv run mcp-tts.py --transport sse        # Server-Sent Events

# With options
uv run mcp-tts.py --port 3050 --debug --disable-s3

# Via Docker
docker compose up -d
```

## Client Usage

```bash
python mcp_client.py --text "Hello, world!"
python mcp_client.py --file example.txt --voice af_heart --speed 1.2
```

## Architecture

Three main files, no test suite or linter configured:

- **`mcp-tts.py`** — Entry point. Creates a `FastMCP` server (Starlette-based, not Flask despite Flask being in deps). Contains:
  - `MCPTTSServer` class: S3 client setup, audio file management, MP3 retention cleanup
  - `text_to_speech()` MCP tool: primary interface for Claude/MCP clients
  - `GET /mp3/{filename}`: HTTP endpoint for downloading generated MP3s
  - `POST /api/tts`: REST endpoint returning raw MP3 binary (no S3, cleans up file after response)

- **`kokoro_service.py`** — `KokoroTTSService` class wrapping `kokoro_onnx`. Handles ONNX provider selection (CUDA preferred, CPU fallback), WAV generation via `kokoro.create()`, WAV-to-MP3 conversion via ffmpeg subprocess, and markdown link stripping from input text. Falls back to macOS `say` command if Kokoro model unavailable.

- **`mcp_client.py`** — Standalone CLI client using raw TCP sockets to send JSON TTS requests.

## Key Dependencies

- **Python >=3.12**, managed with **uv** (not pip)
- **ffmpeg** — required system dependency for WAV-to-MP3 conversion
- **kokoro-onnx** — the TTS model library (requires `kokoro-v1.0.onnx` and `voices-v1.0.bin` model files in project root; Docker auto-downloads these)
- **mcp[cli]** — FastMCP server framework (uses Starlette under the hood)
- **boto3** — S3 uploads (optional, controlled by `S3_ENABLED` env var)

## Configuration

All config via `.env` file or environment variables (see `.env.example`). Key variables:

- `MCP_HOST`, `MCP_PORT`, `MCP_TRANSPORT` — server binding
- `S3_ENABLED` — must be explicitly `true` to enable S3 uploads
- `TTS_VOICE` (default: `af_heart`), `TTS_SPEED`, `TTS_LANGUAGE`
- `BASE_URL` — override the base URL used in MP3 download links
- `MP3_RETENTION_DAYS` — auto-cleanup of old MP3 files on startup

Command-line args override env vars for S3 settings.
