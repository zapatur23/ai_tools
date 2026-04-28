#!/usr/bin/env python3
"""Finds AI agents and components active in the current environment."""

import json
import os
import shutil
import subprocess
from pathlib import Path

HOME = Path.home()
TOTAL = 0


def divider():
    print("  " + "─" * 53)


def header(title):
    print(f"\n  {title}")
    divider()


def row(label, note=""):
    print(f"  {label:<42}{note}")


# ── 1. Running AI processes ──────────────────────────────────
header("Running AI Processes")
AI_KEYWORDS = r"\b(claude|ollama|llama\.cpp|llama-server|llamafile|lm-studio|jan|gpt4all|localai|text-generation|vllm|mlx_lm)\b"
try:
    out = subprocess.check_output(
        ["ps", "aux"], text=True, stderr=subprocess.DEVNULL
    )
    import re
    found = 0
    for line in out.splitlines():
        if re.search(AI_KEYWORDS, line, re.IGNORECASE) and "find_ai_agents" not in line:
            parts = line.split(None, 10)
            pid = parts[1] if len(parts) > 1 else "?"
            cmd = parts[10] if len(parts) > 10 else line
            match = re.search(r"\b(claude|ollama|llama[.\-]?\w*|llamafile|jan|gpt4all|localai|vllm|mlx_lm)\S*", cmd, re.IGNORECASE)
            name = match.group(0) if match else cmd.split()[0]
            row(name, f"PID {pid}")
            found += 1
            TOTAL += 1
    if not found:
        row("(none)")
except Exception as e:
    row(f"(error: {e})")

# ── 2. Installed AI CLI tools ────────────────────────────────
header("Installed AI CLI Tools")
CLI_TOOLS = ["claude", "openai", "ollama", "gemini", "groq", "aider", "sgpt", "fabric", "llm", "tgpt"]
found = 0
for tool in CLI_TOOLS:
    path = shutil.which(tool)
    if path:
        row(tool, path)
        found += 1
        TOTAL += 1
if not found:
    row("(none)")

# ── 3. AI API keys in environment ────────────────────────────
header("AI API Keys in Environment")
KEY_VARS = [
    "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY",
    "GROQ_API_KEY", "COHERE_API_KEY", "HUGGINGFACE_API_KEY", "REPLICATE_API_TOKEN",
    "MISTRAL_API_KEY", "PERPLEXITY_API_KEY", "TOGETHER_API_KEY", "FIREWORKS_API_KEY",
    "DEEPSEEK_API_KEY", "XAI_API_KEY",
]
found = 0
for var in KEY_VARS:
    if os.environ.get(var):
        row(var, "(set)")
        found += 1
        TOTAL += 1
if not found:
    row("(none)")

# ── 4. MCP servers (Claude Code) ────────────────────────────
header("Claude Code MCP Servers")
found = 0
claude_json = HOME / ".claude.json"
if claude_json.exists():
    try:
        data = json.loads(claude_json.read_text())
        for name in data.get("mcpServers", {}):
            row(name, "(global)")
            found += 1
            TOTAL += 1
        for proj_path, proj in data.get("projects", {}).items():
            for name in proj.get("mcpServers", {}):
                row(name, f"[{proj_path}]")
                found += 1
                TOTAL += 1
    except Exception:
        pass

for f in [Path.cwd() / ".mcp.json", Path.cwd() / ".claude" / "settings.json"]:
    if f.exists():
        try:
            data = json.loads(f.read_text())
            for name in data.get("mcpServers", {}):
                row(name, f"({f.name})")
                found += 1
                TOTAL += 1
        except Exception:
            pass
if not found:
    row("(none configured)")

# ── 5. Claude Code scheduled agents ─────────────────────────
header("Claude Code Scheduled Agents")
found = 0
cron_file = HOME / ".claude" / "crons.json"
if cron_file.exists():
    try:
        data = json.loads(cron_file.read_text())
        crons = data if isinstance(data, list) else data.get("crons", [])
        for c in crons:
            name = c.get("name", c.get("id", "unnamed"))
            schedule = c.get("schedule", "")
            row(name, f"[{schedule}]")
            found += 1
            TOTAL += 1
    except Exception:
        pass
if not found:
    row("(none scheduled)")

# ── 6. Active Claude Code sessions ──────────────────────────
header("Active Claude Code Sessions")
found = 0
session_dir = HOME / ".claude" / "session-env"
if session_dir.is_dir():
    for sess in sorted(session_dir.iterdir()):
        row(sess.name)
        found += 1
        TOTAL += 1
if not found:
    row("(none)")

# ── 7. Local AI model files ──────────────────────────────────
header("Local AI Model Files")
found = 0
MODEL_DIRS = [
    HOME / ".ollama" / "models",
    HOME / "Library" / "Application Support" / "LM Studio" / "models",
    HOME / ".cache" / "huggingface" / "hub",
    HOME / "Library" / "Application Support" / "Jan" / "models",
]
MODEL_EXTS = {".gguf", ".bin", ".safetensors"}
for d in MODEL_DIRS:
    if d.is_dir():
        count = sum(
            1 for f in d.rglob("*") if f.suffix in MODEL_EXTS
        )
        if count:
            row(d.name, f"{count} model file(s)")
            found += count
            TOTAL += count
if not found:
    row("(none)")

# ── Summary ─────────────────────────────────────────────────
print()
print("  ╔" + "═" * 53 + "╗")
print(f"  ║  Total AI agents / components found: {TOTAL:<15}║")
print("  ╚" + "═" * 53 + "╝")
print()
