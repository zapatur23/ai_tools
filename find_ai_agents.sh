#!/usr/bin/env bash
# Finds AI agents active in the current environment

TOTAL=0

divider() { printf '%0.s─' {1..55}; echo; }
header()   { echo; echo "  $1"; divider; }

header "AI Agent Environment Scanner"

# ── 1. Running AI processes ──────────────────────────────────
header "Running AI Processes"
AI_PROCS=$(ps aux 2>/dev/null \
    | grep -iE '\b(claude|ollama|llama\.cpp|llama-server|llamafile|lm-studio|jan|gpt4all|localai|text-generation|vllm|mlx_lm)\b' \
    | grep -v grep \
    | grep -v "find_ai_agents")

COUNT=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    name=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf $i" "; print ""}' \
        | grep -oiE '\b(claude|ollama|llama[.-]?[a-z0-9]*|llamafile|jan|gpt4all|localai|vllm|mlx_lm)[^ ]*' \
        | head -1)
    pid=$(echo "$line" | awk '{print $2}')
    printf "  %-40s PID %s\n" "${name:-unknown}" "$pid"
    COUNT=$((COUNT + 1))
done <<< "$AI_PROCS"
[[ $COUNT -eq 0 ]] && echo "  (none)"
TOTAL=$((TOTAL + COUNT))

# ── 2. Installed AI CLI tools ────────────────────────────────
header "Installed AI CLI Tools"
COUNT=0
for tool in claude openai ollama gemini groq aider sgpt fabric llm tgpt; do
    path=$(which "$tool" 2>/dev/null)
    if [[ -n "$path" ]]; then
        printf "  %-40s %s\n" "$tool" "$path"
        COUNT=$((COUNT + 1))
    fi
done
[[ $COUNT -eq 0 ]] && echo "  (none)"
TOTAL=$((TOTAL + COUNT))

# ── 3. AI API keys in environment ────────────────────────────
header "AI API Keys in Environment"
COUNT=0
KEY_VARS=(
    ANTHROPIC_API_KEY OPENAI_API_KEY GEMINI_API_KEY GOOGLE_API_KEY
    GROQ_API_KEY COHERE_API_KEY HUGGINGFACE_API_KEY REPLICATE_API_TOKEN
    MISTRAL_API_KEY PERPLEXITY_API_KEY TOGETHER_API_KEY FIREWORKS_API_KEY
    DEEPSEEK_API_KEY XAI_API_KEY
)
for var in "${KEY_VARS[@]}"; do
    if [[ -n "${!var}" ]]; then
        printf "  %-40s (set)\n" "$var"
        COUNT=$((COUNT + 1))
    fi
done
[[ $COUNT -eq 0 ]] && echo "  (none)"
TOTAL=$((TOTAL + COUNT))

# ── 4. MCP servers (Claude Code) ────────────────────────────
header "Claude Code MCP Servers"
COUNT=0
CLAUDE_JSON="$HOME/.claude.json"
if [[ -f "$CLAUDE_JSON" ]] && command -v python3 &>/dev/null; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf "  %s\n" "$line"
        COUNT=$((COUNT + 1))
    done < <(python3 - "$CLAUDE_JSON" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
# global
for k in data.get("mcpServers", {}):
    print(f"{k}  (global)")
# per-project
for path, proj in data.get("projects", {}).items():
    for k in proj.get("mcpServers", {}):
        print(f"{k}  [{path}]")
PYEOF
)
fi
# project-local .mcp.json
for f in "$(pwd)/.mcp.json" "$(pwd)/.claude/settings.json"; do
    if [[ -f "$f" ]] && command -v python3 &>/dev/null; then
        while IFS= read -r srv; do
            [[ -z "$srv" ]] && continue
            printf "  %-40s (%s)\n" "$srv" "$(basename "$f")"
            COUNT=$((COUNT + 1))
        done < <(python3 -c "
import json, sys
data = json.load(open('$f'))
for k in data.get('mcpServers', {}): print(k)
" 2>/dev/null)
    fi
done
[[ $COUNT -eq 0 ]] && echo "  (none configured)"
TOTAL=$((TOTAL + COUNT))

# ── 5. Claude Code scheduled agents ─────────────────────────
header "Claude Code Scheduled Agents"
COUNT=0
CRON_FILE="$HOME/.claude/crons.json"
if [[ -f "$CRON_FILE" ]] && command -v python3 &>/dev/null; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        printf "  %s\n" "$line"
        COUNT=$((COUNT + 1))
    done < <(python3 - "$CRON_FILE" <<'PYEOF'
import json, sys
data = json.load(open(sys.argv[1]))
crons = data if isinstance(data, list) else data.get("crons", [])
for c in crons:
    name = c.get("name", c.get("id", "unnamed"))
    sched = c.get("schedule", "")
    print(f"{name}  [{sched}]")
PYEOF
)
fi
[[ $COUNT -eq 0 ]] && echo "  (none scheduled)"
TOTAL=$((TOTAL + COUNT))

# ── 6. Active Claude Code sessions ──────────────────────────
header "Active Claude Code Sessions"
COUNT=0
SESSION_DIR="$HOME/.claude/session-env"
if [[ -d "$SESSION_DIR" ]]; then
    while IFS= read -r sess; do
        [[ -z "$sess" ]] && continue
        printf "  %s\n" "$(basename "$sess")"
        COUNT=$((COUNT + 1))
    done < <(ls "$SESSION_DIR" 2>/dev/null)
fi
[[ $COUNT -eq 0 ]] && echo "  (none)"
TOTAL=$((TOTAL + COUNT))

# ── 7. Local AI model files ──────────────────────────────────
header "Local AI Model Files"
COUNT=0
MODEL_DIRS=(
    "$HOME/.ollama/models"
    "$HOME/Library/Application Support/LM Studio/models"
    "$HOME/.cache/huggingface/hub"
    "$HOME/Library/Application Support/Jan/models"
)
for dir in "${MODEL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        n=$(find "$dir" -maxdepth 4 \( -name "*.gguf" -o -name "*.bin" -o -name "*.safetensors" \) 2>/dev/null | wc -l | tr -d ' ')
        if [[ $n -gt 0 ]]; then
            printf "  %-40s %s model file(s)\n" "$(basename "$dir")" "$n"
            COUNT=$((COUNT + n))
        fi
    fi
done
[[ $COUNT -eq 0 ]] && echo "  (none)"
TOTAL=$((TOTAL + COUNT))

# ── Summary ──────────────────────────────────────────────────
echo
echo "╔══════════════════════════════════════════════════════╗"
printf "║  Total AI agents / components found: %-16s║\n" "$TOTAL"
echo "╚══════════════════════════════════════════════════════╝"
echo
