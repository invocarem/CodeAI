#!/bin/bash

# Read file and create the JSON payload
CODE_CONTENT=$(cat "../Sources/CodeAI/AIClient.swift")

curl -X POST http://localhost:5000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"deepseek-coder:6.7b\",
    \"prompt\": \"Review this Swift code for any issues:\\n\\n$CODE_CONTENT\",
    \"stream\": false
  }"
