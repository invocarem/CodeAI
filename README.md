# CodeAI — Swift AI Backend Service

CodeAI is a small Swift (Vapor) backend that routes requests to an AI provider for code-focused assistance. It supports OpenAI-compatible providers (OpenAI, Mistral cloud) and an on‑prem/localhost Ollama instance. The service includes helpers to re-number and clean comment markers in Swift string arrays (see the `renumber-verses` and `clean-verses` endpoints).

## Key features

- Health and models endpoints for quick diagnostics
- Chat-like completions endpoint compatible with OpenAI-style payloads
- Specialized endpoints and chat commands to:
  - Renumber numbered comments in Swift string arrays (@renumber-verses)
  - Remove numbered comments from Swift string arrays (@clean-verses)
- Works with these AI providers:
  - openai (uses `OPENAI_API_KEY`)
  - mistral (uses `MISTRAL_API_KEY`, compatible OpenAI-style endpoint)
  - ollama (local endpoint; uses `OLLAMA_ENDPOINT`)

## Repository layout

- `Sources/CodeAI/` — application sources (routes, AI client, formatters)
- `Dockerfile`, `docker-compose.yaml` — Docker delivery and local deployment
- `Package.swift` — Swift package manifest

## Configuration (environment variables)

The app reads configuration from environment variables (see `Sources/CodeAI/Config.swift`). Main variables:

- `AI_PROVIDER` — which provider to use. Defaults to `openai`.
  - Values: `openai`, `mistral`, `ollama`
- `OPENAI_API_KEY` — API key for OpenAI-compatible providers
- `MISTRAL_API_KEY` — API key for Mistral cloud (when `AI_PROVIDER=mistral`)
- `OLLAMA_ENDPOINT` — Ollama HTTP endpoint (default: `http://localhost:11434/api/generate`)
- `HOST` — server host (default `0.0.0.0`)
- `PORT` — server port (default `8080`)
- `DEFAULT_MODEL` — default chat model (overrides per-request model)
- `DEFAULT_SWIFT_MODEL` — default model used for swift formatting tasks
- `DEFAULT_MAX_TOKENS`, `DEFAULT_SWIFT_MAX_TOKENS`, `DEFAULT_TEMPERATURE` — tuning defaults

The app detects whether the provider is "OpenAI compatible" (OpenAI or Mistral) or Ollama. Ollama uses a different request shape and does not require an API key.

## Running with Docker (recommended delivery)

The project is intended to be delivered with Docker. Build and run with docker-compose:

```bash
# Build and start the service (reads environment variables from your shell)
docker-compose up --build


# development
docker-compose down
docker-compose up --build ai-server-dev

#my env
HOSTNAME=0.0.0.0
PORT=5000

AI_PROVIDER=openai
OPENAI_API_KEY=lAbgnma92xW1VqLxsuLCasdb0tB8mhSq
ENV=development
```

To run with a specific provider (example using OpenAI):

```bash
export AI_PROVIDER=openai
export OPENAI_API_KEY="sk-..."
export DEFAULT_MODEL="gpt-4o-mini"
docker-compose up --build
```

To run with an Ollama instance running locally (example):

```bash
export AI_PROVIDER=ollama
export OLLAMA_ENDPOINT="http://localhost:11434/api/generate"
docker-compose up --build
```

Notes:
- On Windows with PowerShell you can set environment variables with `$env:AI_PROVIDER = "ollama"` before running Docker.
- The provided `Dockerfile` and `docker-compose.yaml` in this repo are set up for packaging the Swift Vapor service — edit env values to match your deployment.

## API

Base URL: http://<HOST>:<PORT> (defaults to `http://0.0.0.0:8080`)

### Health

GET /health

Response: JSON with provider, configured status, default model

### List models

GET /v1/models

Returns a JSON list of known/supported model ids (includes Ollama models when `AI_PROVIDER=ollama`).

### Chat completions (OpenAI-style)

POST /v1/chat/completions

Accepts an OpenAI-compatible chat body (see `Sources/CodeAI/Models.swift`). Example payload:

```json
{
  "model": "mistral-small-latest",
  "messages": [
    { "role": "system", "content": "You are a Swift code assistant." },
    { "role": "user", "content": "Please review this array and remove numbered comments." }
  ],
  "max_tokens": 1024,
  "temperature": 0.0,
  "stream": false
}
```

Special in-message commands (the server also recognizes these when included in the last user message):
- `@renumber-verses` or `renumber-verses` — triggers the renumbering pipeline for Swift arrays
- `@clean-verses` or `clean-verses` — triggers the comment-cleaning pipeline for Swift arrays

If a message contains those commands the server will try to extract Swift code (fenced code block or `private let ... = [ ... ]`) and run the appropriate formatter.

### Renumber verses (direct endpoint)

POST /renumber-verses

Request body (JSON):

```json
{
  "code": "private let text = [\n    /* 1 */ \"alpha\",\n    \"beta\",\n    /* 2 */ \"gamma\"\n]",
  "model": "mistral-small-latest",
  "max_tokens": 1024,
  "temperature": 0.0
}
```

Response:

```json
{ "formatted_code": "```swift\nprivate let text = [\n    /* 1 */ \"alpha\",\n    /* 2 */ \"beta\",\n    /* 3 */ \"gamma\"\n]\n```" }
```

### Clean verses (direct endpoint)

POST /clean-verses

Request body (JSON):

```json
{
  "code": "private let text = [\n    /* 1 */ \"alpha\",\n    /* 2 */ \"beta\",\n    \"gamma\"\n]",
  "model": "mistral-small-latest",
  "max_tokens": 1024,
  "temperature": 0.0
}
```

Response:

```json
{ "cleaned_code": "```swift\nprivate let text = [\n    \"alpha\",\n    \"beta\",\n    \"gamma\"\n]\n```" }
```

Notes: If the configured AI provider is unavailable or fails, the server falls back to built-in deterministic Swift formatters (see `Sources/CodeAI/SwiftFormatter.swift`).

## Example: trigger from chat messages

You can send a user message containing the code plus the command and the server will route accordingly. Example (curl):

```bash
curl -s -X POST "http://localhost:8080/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "mistral-small-latest",
    "messages": [
      {"role":"system", "content":"You are a Swift formatter."},
      {"role":"user", "content":"@clean-verses\n```swift\nprivate let text = [\n  /* 1 */ \"one\",\n  \"two\",\n  /* 3 */ \"three\"\n]\n```"}
    ]
  }'
```

The response will contain the cleaned Swift code wrapped in a markdown code block (triple backticks) or, if `stream: true`, a streaming-style payload.

## Troubleshooting

- If `AI_PROVIDER=openai` or `mistral` make sure the corresponding API key env var is set (`OPENAI_API_KEY` or `MISTRAL_API_KEY`).
- For Ollama, ensure `OLLAMA_ENDPOINT` points to a reachable running Ollama HTTP server.
- Use `GET /health` to verify which provider the server thinks it's configured to use.

## Development notes

- Swift-specific helpers live in `SwiftFormatter.swift`. The server tries to extract Swift code from markdown fences or by scanning for `private let ... = [ ... ]` array patterns.
- The AI client (`AIClient.swift`) contains two code paths: OpenAI-compatible (POST JSON with messages) and Ollama (prompt-based). Adjust `Config.swift` defaults if you prefer different behavior.

## License

This repository is provided as-is. Adjust and extend for your deployment needs.
