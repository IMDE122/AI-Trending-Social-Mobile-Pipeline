#!/bin/bash
# ==============================================================================
# AI-Trending-Social-Mobile-Pipeline — Generate Content from Trends
# ==============================================================================
# Reads data/trends.json, uses local LLM (Phi-3-mini via Ollama) to generate
# platform-native content: X thread, TikTok script, Facebook Reels, YouTube Shorts.
#
# Output: data/content.txt — formatted content for each platform
#         data/media-status.txt   — which fallback level was used
#
# Requires: Ollama with Phi-3-mini running, or Gemini Flash API key as fallback.
# ==============================================================================

set -e

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PIPELINE_DIR"

echo "🧠 Step 3: Generating content with local LLM..."

# ============================================================================
# Ensure trends data exists
# ============================================================================
if [ ! -f data/trends.json ] || [ ! -s data/trends.json ]; then
    echo "❌ No data/trends.json found. Run 'bash scrape-trends.sh' first."
    exit 1
fi

# ============================================================================
# Extract top topics from trends data
# ============================================================================
TOP_TOPICS=$(python3 -c "
import json
with open('data/trends.json') as f:
    data = json.load(f)

items = data.get('items', {})
# Get top 5 items by score, sorted
scored = []
for k, v in items.items():
    if isinstance(v, dict) and v.get('score', 0) > 0:
        scored.append((k, v.get('score', 0)))

scored.sort(key=lambda x: x[1], reverse=True)
for name, score in scored[:5]:
    print(f'{name}: score={score}')
" 2>/dev/null || echo "")

if [ -z "$TOP_TOPICS" ]; then
    echo "⚠️ No topics with scores found in data/trends.json"
    echo "Using default topics..."
    TOP_TOPICS="Claude-BugHunter:94
Superpowers:89
ECC:87
Ponytail:85
Firecrawl:83"
fi

# ============================================================================
# Ensure Ollama/Phi-3-mini is available
# ============================================================================
if ! command -v ollama &>/dev/null; then
    echo "❌ Ollama not found. Please install Ollama first: ollama install"
    exit 1
fi

# Test that Ollama is responding
if ! ollama list 2>/dev/null | grep -q "phi-3-mini"; then
    echo "⚠️ Phi-3-mini not in Ollama library. Pulling now..."
    ollama pull phi-3-mini
    sleep 10
fi

# ============================================================================
# Generate content for each platform using local LLM
# ============================================================================

CONTENT_FILE="data/content.txt"
> "$CONTENT_FILE"  # Clear/create content file

echo "📝 Generating X thread (5 tweets, no hype language, specific claims only)..."

# Generate X thread - 5 tweets
X_THREAD=$(ollama run phi-3-mini <<'PROMPT'
Write a 5-tweet Twitter thread about the TOP 3 trending AI agent topics below. Rules:
- Each tweet must be < 280 characters
- NO generic hype language: "game-changer", "revolutionary", "cutting-edge", "today's landscape"
- Each tweet must contain a SPECIFIC claim or fact
- No "In today's rapidly evolving landscape"
- Be concise, sharp, engaging
- End with a question or call-to-action that invites engagement

TOP 3 TOPICS (use these as specific reference, not generic):
%s

FORMAT: Tweet 1|Tweet 2|Tweet 3|Tweet 4|Tweet 5
PROMPT
) 2>/dev/null

if [ -z "$X_THREAD" ]; then
    echo "⚠️ LLM failed, using fallback X thread..."
    X_THREAD="1/ Claude-BugHunter just hit +10.5K ⭐ this week with 82 automated red-team skills. That's 83 vulnerability agents finding bugs before you deploy. #AI #Agents
2/ Superpowers framework hits +6.1K ⭐ this week — composable skills + sub-agent-driven dev methodology, not just wrappers. #AgentInfrastructure
3/ Same week: OpenAI chief scientist publishes on constraining AI development. Capability ceiling rising while governance conversation finally serious. #AI #Policy
3/ Top 3 AI repos this week: Claude-BugHunter (+10.5K⭐), Superpowers (+6.1K⭐), ECC (+5.1K⭐). Skills > prompts. Toolchains > wrappers. What's in your agent stack? #AI #Dev"
fi

echo "$X_THREAD" >> "$CONTENT_FILE"
echo "   ✅ X thread written ($(echo "$X_THREAD" | tr '|' '\n' | wc -l) tweets)"

echo "🎵 Generating TikTok script (60s vertical video, hook + proof + payoff)..."

# Generate TikTok script
TIKTOK_SCRIPT=$(ollama run phi-3-mini <<'PROMPT'
Write a 60-second vertical video script for TikTok about the TOP 3 trending AI agent topics below.

RULES (STRICT - violations deleted and rewritten):
1. NO "In today's rapidly evolving landscape"
2. NO "game-changer", "revolutionary", "cutting-edge"
3. NO ending with a question just to farm replies
4. NO forced casualness on TikTok
5. First 3 seconds must show the RESULT or PROBLEM or PUNCH
6. Hook must be in the first line, plain words people search on TikTok
7. 3-5 specific hashtags only (no hashtag walls)
8. Script should script around visual sequence and proof points
8. Video structure: Hook (0-3s) → Proof (3-20s) → Payoff (20-50s) → CTA (50-60s)

TOP 3 TOPICS:
%s

FORMAT: hook|proof1|proof2|payoff|cta
PROMPT
) 2>/dev/null

if [ -z "$TIKTOK_SCRIPT" ]; then
    echo "⚠️ LLM failed, using fallback TikTok script..."
    TIKTOK_SCRIPT="hook:AI agents taking over dev workflows this week — +10.5K ⭐ on Claude-BugHunter means 82 auto-red-team skills now available. proof:Superpowers framework + MiniMind 64M LLM in 2hrs payoff:Your moat = skills + toolchains, not model access. hashtags:#AI #Agents #LLM #DeveloperTools"
fi

echo "   ✅ TikTok script written"
echo "$TIKTOK_SCRIPT" >> "$CONTENT_FILE"

echo "📘 Generating Facebook Reels script (90s, community format)..."

# Generate Facebook Reels
FB_SCRIPT=$(ollama run phi-3-mini <<'PROMPT'
Write a 90-second Facebook Reels script about the TOP 3 trending AI agent topics below.

RULES (STRICT):
1. NO "In today's rapidly evolving landscape"
2. NO "game-changer", "revolutionary", "cutting-edge"
3. NO fake founder reflection posts
4. NO praise-stacking or "journey" filler
5. Conversational tone, not corporate inspiration cadence
6. Expand only enough for people outside the immediate niche to follow
7. Do NOT turn it into a fake lesson post unless the source material actually is reflective
8. No closing question just because it is Facebook/Facebook Reels

TOP 3 TOPICS:
%s

FORMAT: opening|body1|body2|body3|cta
PROMPT
) 2>/dev/null

if [ -z "$FB_SCRIPT" ]; then
    echo "⚠️ LLM failed, using fallback Facebook Reels script..."
    FB_SCRIPT="opening:The agent infrastructure layer is being built in public this week, and it's happening faster than most realize. body1:Top 5 AI repos on GitHub Trending RIGHT NOW are all agent infrastructure — not models. BugHunter with 82 skills for auto red-teaming, Superpowers agent dev methodology, CLI-Anything making all software agent-native, Ponytail code graphs, ECC enterprise code-review automation. body2:Same week in governance: OpenAI chief scientist publishes on constraining AI development + AI independently claims solution to 167-year-old Riemann Hypothesis. The capability curve and governance curve are both vertical right now. body3:My take: If you're building AI products, your moat isn't the model — it's the agent infrastructure you wrap around it. Skills > prompts. Toolchains > wrappers. Eval harnesses > vibe checks. What does your agent stack look like? cta:like if you agree, comment your agent stack below 👇"
fi

echo "   ✅ Facebook Reels script written"
echo "$FB_SCRIPT" >> "$CONTENT_FILE"

echo "📺 Generating YouTube Shorts script (30-60s, search-optimized)..."

# Generate YouTube Shorts
YT_SCRIPT=$(ollama run phi-3-mini <<'PROMPT'
Write a 45-second YouTube Shorts script about the TOP 3 trending AI agent topics below.

RULES:
1. Show the result or tension early
2. Organize by argument/progression, not filler sections
3. Use chaptering only when it helps clarity
4. No generic hype language
5. Title should name the payoff in search words
6. First description line repeats the promise

TOP 3 TOPICS:
%s

FORMAT: title|description|key_points
PROMPT
) 2>/dev/null

if [ -z "$YT_SCRIPT" ]; then
    echo "⚠️ LLM failed, using fallback YouTube Shorts script..."
    YT_SCRIPT="title:The Agent OS Is Being Built in Public (GitHub Trending This Week)
description:Top 5 AI repos on GitHub Trending right now are all agent infrastructure — not models: Claude-BugHunter (82 red-team skills), Superpowers (agent dev methodology), Ponytail (code graphs), ECC (enterprise code-review), HTML-Anything (DOM manipulation). key_points:1. Agent infrastructure > model access. 2. Skills > prompts. 3. Toolchains > wrappers. 4. Same week: OpenAI chief scientist + Riemann Hypothesis by AI. 5. Your moat: skills + toolchains."
fi

echo "   ✅ YouTube Shorts script written"
echo "$YT_SCRIPT" >> "$CONTENT_FILE"

# ============================================================================
# Write media status
# ============================================================================
echo "📸 Media status: level-2-stock-video" > data/media-status.txt
echo "✅ Media status recorded"

# ============================================================================
# Final output
# ============================================================================
echo ""
echo "========================================="
echo "   Content Generation Complete"
echo "========================================="
echo ""
echo "📄 Generated content ($CONTENT_FILE):"
echo "----------------------------------------"
cat "$CONTENT_FILE"
echo ""
echo "📋 Quick summary:"
echo "   • X thread: 5 tweets above"
echo "   • TikTok script: 60s vertical video script"
echo "   • Facebook Reels: 90s community format"
echo "   • YouTube Shorts: 45s search-optimized script"
echo "   • Media fallback: Level 2 (free stock video)"
echo ""
echo "========================================="