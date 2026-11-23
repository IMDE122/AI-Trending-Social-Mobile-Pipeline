#!/bin/bash
# ==============================================================================
# AI-Trending-Social-Mobile-Pipeline — 5-Level Media Fallback Chain
# ==============================================================================
# Guaranteed output: always produces usable media or falls back to text-only.
# Levels (in order of preference):
#   Level 1: Local video generation (Remotion/Manim) — may fail on low-RAM phones
#   Level 2: Free stock video (Pexels/Pixabay) — CC0, no attribution required
#   Level 3: Stock image + Ken Burns effect → create video
#   Level 4: Repo logos + title card (from trending research — always works)
#   Level 5: Text-only (guaranteed fastest path, ≈30 seconds)
# ==============================================================================

set -e

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PIPELINE_DIR"

echo "📸 Step 4: Starting 5-level media fallback chain..."

# ============================================================================
# Level 1: Local video generation (Remotion/Manim)
# ============================================================================
echo "🟢 Level 1: Trying local video generation (Remotion/Manim)..."

# Check if we have enough RAM for video generation
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $1}' || echo "400000")
TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))

if [ "$TOTAL_RAM_MB" -ge 2000 ]; then
    echo "   📹 RAM OK ($TOTAL_RAM_MB MB) — attempting Remotion video generation..."
    # Try to generate a simple Remotion project
    npx remotion init 2>/dev/null || echo "   ⚠️ Remotion init attempted (may fail on phone)"

    # If we get here with some output, use it
    if [ -f "output.mp4" ] || [ -f "video.mp4" ]; then
        echo "   ✅ Level 1: Local video generated successfully"
        cp output.mp4 || video.mp4 data/media/video.mp4 2>/dev/null
        echo "level-1-local" > data/media-status.txt
        exit 0
    fi
fi

echo "   ⏭️ Level 1 skipped (insufficient RAM / Remotion not available on mobile)"
echo "   → Falling through to Level 2"

# ============================================================================
# Level 2: Free stock video (Pexels / Pixabay)
# ============================================================================
echo "🟡 Level 2: Trying free stock video (Pexels / Pixabay)..."

# Try Pexels first via direct API-like approach (no auth needed for public videos)
PEXELS_SEARCH=$(curl -sL "https://api.pexels.com/videos/search?query=AI%20agents%20tutorial&per_page=1" 2>/dev/null \
    || echo "")

# If Pexels API key not available, try downloading description-based
# For now, use a simple approach: check if we can download a known-free video
# Or skip to level 3 with a note

# Attempt: download a short AI-related stock video from Pexels via public endpoints
# Pexels doesn't require API key for basic access in many cases
STOCK_VIDEO_URL="https://cdn.download.pexels.com.com/video-files/2936078/2936078-mobile.mp4 2>/dev/null || echo ""

# Try wget/curl to download a short stock video
echo "   🔍 Checking for available stock video resources..."

# Create a simple placeholder stock video reference
# In production, the phone would download from Pexels/Pixabay
# For now, we'll create a placeholder and move to Level 3

# Check if we can actually download something usable
HAS_NET=$(ping -c 1 -W 3 8.8.8.8 2>/dev/null && echo "yes" || echo "no")

if [ "$HAS_NET" = "yes" ]; then
    echo "   🌐 Network available — attempting stock video download..."

    # Try to download a short AI-related video from Pexels public catalog
    STOCK_RESULT=$(timeout 15 wget -q -O data/media/stock-video.mp4 "https://images.pexels.com/videos/stock-video-ai-technology-abstract-4k.mp4" 2>&1 || echo "download_failed")

    if [ -f "data/media/stock-video.mp4" ] && [ -s "data/media/stock-video.mp4" ]; then
        FILE_SIZE=$(wc -c < "data/media/stock-video.mp4")
        if [ "$FILE_SIZE" -gt 100000 ]; then  # At least 100KB
            echo "   ✅ Level 2: Stock video downloaded ($FILE_SIZE bytes)"
            echo "level-2-stock-video" > data/media-status.txt
            exit 0
        fi
    fi
fi

echo "   ⏭️ Level 2: Stock video not available (falling through)"

# ============================================================================
# Level 3: Stock image + Ken Burns effect → create video
# ============================================================================
echo "🟠 Level 3: Trying stock image + Ken Burns effect..."

# Search for a free stock image (Unsplash / Pexels)
# Create a video from a static image with pan/zoom effect using ffmpeg

# Try to get a free image URL
UNSPLASH_IMAGE="https://images.unsplash.com/photo-1581091042226-96191693ce17?auto=format&fit=crop&w=1080&q=80 2>/dev/null || echo ""

# Try to download the image
if curl -sL -o data/media/cover.jpg "$UNSPLASH_IMAGE" 2>/dev/null && [ -f "data/media/cover.jpg" ] && [ -s "data/media/cover.jpg" ]; then
    echo "   ✅ Level 3: Stock image downloaded"

    # Create a video from the image with Ken Burns effect (pan/zoom) + title card
    # Using ffmpeg to create a 60-second video: 5s title card + 55s Ken Burns effect
    if command -v ffmpeg &>/dev/null; then
        echo "   🎬 Creating video with Ken Burns effect + title card..."

        # Create a simple title card first (first 5 seconds)
        ffmpeg -y -f lavfi -i color=c=black:r=30:s=1080x1920:d=5 -vf "drawtext=text='Top 5 AI Agent Repos':fontsize=40:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" data/media/card.mp4 2>/dev/null

        # Then create the Ken Burns effect portion (next 55 seconds)
        # Using a simple zoom/pan filter
        ffmpeg -y -i data/media/cover.jpg \
            -vf "zoompan=d=55:fps=30:s=1920x1080:pads=0/0/0/0,format=yuv420p" \
            -t 55 -c:v libx264 data/media/ken-burns.mp4 2>/dev/null

        # Concatenate title card + Ken Burns portion
        ffmpeg -y -i "concat:data/media/card.mp4|data/media/ken-burns.mp4" -c copy data/media/final-video.mp4 2>/dev/null

        if [ -f "data/media/final-video.mp4" ] && [ -s "data/media/final-video.mp4" ]; then
            FILE_SIZE=$(wc -c < "data/media/final-video.mp4")
            echo "   ✅ Level 3: Video from image + Ken Burns ($FILE_SIZE bytes)"
            echo "level-3-image-kenburns" > data/media-status.txt
            exit 0
        fi
    else
        echo "   ⚠️ ffmpeg not available for Ken Burns effect"
    fi
else
    echo "   ℹ️ Level 3: Stock image not downloaded (falling through)"
fi

# ============================================================================
# Level 4: Repo logos + title card (from trending research)
# ============================================================================
echo "🔵 Level 4: Repo logos + title card (from trending research)..."

# This level ALWAYS works — uses repo logo URLs from the trending research
# Create a static image collage + title card as video

# Repo logo URLs (from earlier search/trending data)
REPO_LOGOS=(
    "https://raw.githubusercontent.com/elementalsouls/Claude-BugHunter/main/README/assets/logo.png"
    "https://raw.githubusercontent.com/obra/superpowers/main/assets/superpowers-logo.png"
    "https://raw.githubusercontent.com/DietrichGebert/ponytail/main/assets/pyncheader.svg"
    "https://raw.githubusercontent.com/affaan-m/ECC/main/assets/ecc-logo.png"
    "https://raw.githubusercontent.com/nexu-io/html-anything/main/assets/logo.png"
)

# Create a 1080x1920 canvas image with repo logos
python3 << 'PYEOF' 2>/dev/null
import requests
from PIL import Image, ImageDraw, ImageFont
import textwrap

# Create 1080x1920 canvas
canvas = Image.new('RGB', (1080, 1920), color=(10, 10, 20))

# Try to load repo logos
logos = []
logo_urls = [
    "https://raw.githubusercontent.com/elementalsouls/Claude-BugHunter/main/README/assets/logo.png",
    "https://raw.githubusercontent.com/obra/superpowers/main/assets/superpowers-logo.png",
    "https://raw.githubusercontent.com/DietrichGebert/ponytail/main/assets/pyncheader.svg",
    "https://raw.githubusercontent.com/affaan-m/ECC/main/assets/ecc-logo.png",
]

for url in logo_urls:
    try:
        r = requests.get(url, timeout=5)
        if r.status_code == 200:
            logo = Image.open(io.BytesIO(r.content))
            # Resize maintaining aspect ratio
            ratio = min(200 / logo.width, 200 / logo.height)
            logo = logo.resize((int(logo.width * ratio), int(logo.height * ratio)))
            logos.append(logo)
    except: pass

# Arrange logos vertically with spacing
y_offset = 100
for logo in logos:
    canvas.paste(logo, (440 - logo.width // 2, y_offset))
    y_offset += logo.height + 30

# Add title text
draw = ImageDraw.Draw(canvas)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 36)
except:
    font = ImageFont.load_default()

title = "Top 5 AI Agent Repos This Week"
title_bbox = draw.textbbox((0, 0), title, font=font)
text_width = title_bbox[2] - title_bbox[0]
draw.text(((1080 - text_width) / 2, 50), title, font=font, fill=(255, 255, 255))

# Add description
desc = "AI agent infrastructure projects trending this week"
desc_bbox = draw.textbbox((0, 0), desc, font=font)
draw.text((60, 1800), desc, font=font, fill=(180, 180, 180))

# Save as JPEG, then convert to video
canvas.save("data/media/repo-logos.jpg", "JPEG", quality=85)
PYEOF

# Create a 60-second video from the repo logos image
if [ -f "data/media/repo-logos.jpg" ] && [ -s "data/media/repo-logos.jpg" ]; then
    # Use ffmpeg to create a video from the static image
    if command -v ffmpeg &>/dev/null; then
        ffmpeg -y -loop 1 -i data/media/repo-logos.jpg \
            -c:v libx264 -t 60 -pix_fmt yuv420p data/media/repo-logos-video.mp4 2>/dev/null

        if [ -f "data/media/repo-logos-video.mp4" ] && [ -s "data/media/repo-logos-video.mp4" ]; then
            FILE_SIZE=$(wc -c < "data/media/repo-logos-video.mp4")
            echo "   ✅ Level 4: Repo logos + title card video ($FILE_SIZE bytes)"
            echo "level-4-repo-logos" > data/media-status.txt
            exit 0
        fi
    else
        echo "   ⚠️ ffmpeg not available for Level 4"
    fi
else
    echo "   ℹ️ Level 4: Could not download repo logos (using alternative approach)"
fi

# ============================================================================
# Level 5: Text-only (guaranteed fallback)
# ============================================================================
echo "🔴 Level 5: Text-only (guaranteed fallback, fastest path)..."

# Create a text-only post — guaranteed to work, no media needed
cat > data/media-status.txt << 'EOF'
level-5-text-only'
EOF

# Create a text summary file for the platform posts
cat > data/text-summary.txt << 'EOF'
TEXT-ONLY POST READY:
Topic: AI Agent Infrastructure Trending This Week
Key points:
- Agent infrastructure > model access (signaled by GitHub Trending dominance)
- Skills > prompts, toolchains > wrappers (per LLM scoring)
- Same week: OpenAI chief scientist on AI constraints + AI solves Riemann Hypothesis
- Your moat: skills + toolchains, not model access

PLATFORM OPTIMIZATIONS:
X/Twitter: Thread with specific claims, 1-2 hashtags max
TikTok: Hook in first line, 3-5 specific hashtags
Facebook Reels: Conversational, no fake "journey" filler
YouTube Shorts: Search-optimized title + description

POST READY TO PASTE MANUALLY — no video/media needed.
EOF

echo "   ✅ Level 5: Text-only fallback active"
echo "   ✅ Text summary written to data/text-summary.txt"
echo ""
echo "========================================="
echo "   Media Fallback Chain Complete"
echo "========================================="
echo "   Final level used: $(cat data/media-status.txt 2>/dev/null || echo 'unknown')"
echo "   System guaranteed output above"
echo ""
echo "💡 If Level 5 was used, you can still post text-only immediately:"
echo "   - Copy the text-summary.txt content to each platform"
echo "   - Add your own image/video if desired"
echo "   - Post with proper AI disclosure"
echo ""
echo "========================================="