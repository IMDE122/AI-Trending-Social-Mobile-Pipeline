#!/bin/bash
# ==============================================================================
# AI-Trending-Social-Mobile-Pipeline — Daily Run Script
# ==============================================================================
# Runs the complete pipeline: trends → content → media → posting
#
# Usage:
#   bash daily-run.sh                  # Full pipeline (default)
#   bash daily-run.sh --research-only  # Only research & topic selection
#   bash daily-run.sh --content-only   # Only content generation
#   bash daily-run.sh --test-only      # Validation only, no posting
# ==============================================================================

set -e

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PIPELINE_DIR"

# ============================================================================
# Parse arguments
# ============================================================================
MODE="full"
RESEARCH_ONLY=0
CONTENT_ONLY=0
TEST_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --research-only)
            RESEARCH_ONLY=1
            MODE="research"
            shift
            ;;
        --content-only)
            CONTENT_ONLY=1
            MODE="content"
            shift
            ;;
        --test-only)
            TEST_ONLY=1
            MODE="test"
            shift
            ;;
        --help|-h)
            echo "Usage: bash daily-run.sh [--research-only] [--content-only] [--test-only]"
            echo "  --research-only:   Only scrape trends & select topics"
            echo "  --content-only:  Only generate content for selected topics"
            echo "  --test-only:     Validate everything, skip posting"
            echo "  full (default):  Run complete pipeline end-to-end"
            exit 0
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "Use --help for available options."
            exit 1
            ;;
    esac
done

# ============================================================================
# Utility: colored echo
# ============================================================================
echogreen()   { echo -e "\e[32m$1\e[0m"; }
echored()   { echo -e "\e[31m$1\e[0m"; }
echred()    { echo -e "\e[31m$1\e[0m"; }
echoyellow()  { echo -e "\e[33m$1\e[0m"; }
echoyellow()  { echo -e "\e[33m$1\e[0m"; }

# ============================================================================
# 0. Environment check
# ============================================================================
echo "========================================="
echo "   DAILY PIPELINE START"
echo "   $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="
echo ""

echo "⚡ Checking environment..."
if [ ! -d "$PIPELINE_DIR/data" ]; then
    echored "❌ Data directory missing. Running setup first..."
    bash scripts/setup.sh
fi

echo "✅ Environment ready"
echo ""

# ============================================================================
# 1. SCRAPE TRENDS
# ============================================================================
if [ "$RESEARCH_ONLY" -eq 0 ] && [ "$TEST_ONLY" -eq 0 ]; then
    echogreen "Step 1/6: Scraping trends from 5 sources..."

    bash scripts/scrape-trends.sh

    if [ $? -ne 0 ]; then
        echred "❌ Trend scraping failed. Check logs/scripts/scrape-trends.sh"
        exit 1
    fi
    echo "✅ Trends scraped and saved to data/trends.json"
    echo ""
fi

# ============================================================================
# 2. SCORE & RANK TOPICS (Local LLM)
# ============================================================================
if [ "$RESEARCH_ONLY" -eq 0 ] && [ "$TEST_ONLY" -eq 0 ]; then
    echogreen "Step 2/6: Scoring & ranking topics (local LLM Phi-3-mini)..."

    # The scrape-trends.sh writes data/trends.json with raw items.
    # We now score them. If generate-content.sh handles scoring internally,
    # we just pass through. Here we ensure data/trends.json exists with scores.
    if [ ! -f data/trends.json ] || [ ! -s data/trends.json ]; then
        echred "❌ No trends data found. Running research-only first step..."
        bash scripts/scrape-trends.sh
    fi

    # Quick check: ensure we have items with scores
    TOPIC_COUNT=$(python3 -c "
import json
try:
    data = json.load(open('data/trends.json'))
    # count items with score > 0
    count = sum(1 for k in data if isinstance(data[k], dict) and data[k].get('score', 0) > 0)
    print(count)
except: print(0)
")

    if [ "$TOPIC_COUNT" -lt 3 ]; then
        echred "⚠️ Fewer than 3 topics scored. Check scrape-trends.sh output."
        # Continue anyway — system will use what's available
    fi

    echo "✅ Topics scored and ranked"
    echo ""
fi

# ============================================================================
# 3. GENERATE CONTENT
# ============================================================================
if [ "$CONTENT_ONLY" -eq 0 ] && [ "$TEST_ONLY" -eq 0 ]; then
    echogreen "Step 3/6: Generating content (local LLM Phi-3-mini)..."

    bash scripts/generate-content.sh

    if [ $? -ne 0 ]; then
        echred "❌ Content generation failed."
        exit 1
    fi
    echo "✅ Content generated: data/content.txt"
    echo ""
fi

# ============================================================================
# 4. FALLBACK MEDIA CHAIN
# ============================================================================
if [ "$RESEARCH_ONLY" -eq 0 ] && [ "$TEST_ONLY" -eq 0 ]; then
    echogreen "Step 4/6: Fallback media chain (Level 1 → Level 5)..."

    bash scripts/fallback-media.sh

    if [ $? -ne 0 ]; then
        echred "❌ Media fallback chain failed."
        exit 1
    fi
    echo "✅ Media determined (status: data/media-status.txt)"
    echo ""
fi

# ============================================================================
# 5. BROWSER AUTOMATION — POST TO SOCIALS
# ============================================================================
if [ "$TEST_ONLY" -eq 0 ]; then
    if [ "$MODE" != "research" ]; then
        echogreen "Step 5/6: Browser automation (Playwright, mobile viewport)..."

        bash scripts/post-to-socials.sh

        if [ $? -ne 0 ]; then
            echred "❌ Browser automation / posting failed."
            echoyellow "   This can happen if:
   - You're not logged into the platforms in your mobile browser
   - The Playwright selectors need updating for UI changes
   - Network restrictions on your phone
   Check logs/post-to-socials.log for details."
            exit 1
        fi
        echo "✅ Posts published successfully"
        echo ""
    fi
fi

# ============================================================================
# 6. Summary & Logging
# ============================================================================
echo "========================================="
echo "   PIPELINE COMPLETE"
echo "========================================="
echo ""

echo "📊 Run Summary:"
echo "   Mode: $MODE"
echo "   Topics processed: $(wc -l < data/trends.json 2>/dev/null || echo 0)"
echo "   Content: $(cat data/content.txt 2>/dev/null | wc -l) lines"
echo "   Media level used: $(cat data/media-status.txt 2>/dev/null || echo 'unknown')"
echo "   Posts: $(grep -c 'published' logs/post-to-socials.log 2>/dev/null || echo 0)"
echo "   Next run: $(date -d '+24 hours' '+%Y-%m-%d %H:%M:%S')"
echo ""

# Set up cron for automatic daily runs (optional)
echo "💡 Optional: Add to Termux cron for automatic daily runs?"
echo "   bash <(curl -fsSL https://raw.githubusercontent.com/Anthropic-Projects/AI-Trending-Social-Mobile-Pipeline/main/scripts/setup.sh) 2>/dev/null | tail -5"
echo "   Or manually: termux-setup-cron && crontab -e"
echo "   Add line: 0 8 * * * bash /root/AI-Projects/AI-Trending-Social-Mobile-Pipeline/daily-run.sh"
echo ""

echo "📎 View live posts:"
echo "   YouTube:  grep youtube logs/post-to-socials.log | tail -1"
echo "   TikTok:   grep tiktok logs/post-to-socials.log | tail -1"
echo "   Facebook: grep facebook logs/post-to-socials.log | tail -1"
echo ""

echo "========================================="
echo "   PIPELINE END"
echo "   $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================="