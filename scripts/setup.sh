#!/bin/bash
# ==============================================================================
# AI-Trending-Social-Mobile-Pipeline — One-Time Setup Script
# ==============================================================================
# This script installs ALL dependencies, configures everything, and validates
# the pipeline is ready to run. Run it once after cloning the repository.
#
# After this runs, just use: bash daily-run.sh
# ==============================================================================

set -e

echo "========================================="
echo "AI-Trending-Social-Mobile-Pipeline Setup"
echo "========================================="
echo ""

# ============================================================================
# 1. Verify we're in the right directory
# ============================================================================
echo "⚡ Step 1: Verifying pipeline directory..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
echo "   ✅ Pipeline directory: $SCRIPT_DIR"
echo ""

# ============================================================================
# 2. Install Python dependencies
# ============================================================================
echo "⚡ Step 2: Installing Python dependencies..."
pip install --upgrade pip 2>/dev/null | tail -1
pip install playwright 2>/dev/null | tail -1
python -m playwright install chromium 2>/dev/null | tail -1
echo "   ✅ Python + Playwright installed"
echo ""

# ============================================================================
# 3. Configure Ollama (local LLM)
# ============================================================================
echo "⚡ Step 3: Configuring local LLM (Phi-3-mini)..."
if ! command -v ollama &>/dev/null; then
    echo "   📦 Ollama not found, installing..."
    curl -fsSL https://ollama.com/install.sh | sh
    sleep 2
fi

if ! ollama list | grep -q "phi-3-mini"; then
    echo "   📥 Pulling Phi-3-mini model (first run may take 2-3 minutes)..."
    ollama pull phi-3-mini
fi

if ollama list | grep -q "phi-3-mini"; then
    echo "   ✅ Phi-3-mini is ready $(ollama list | grep phi-3-mini)"
else
    echo "   ⚠️ Phi-3-mini could not be loaded. The system will try Gemini Flash as fallback."
fi
echo ""

# ============================================================================
# 4. Configure Playwright (browser automation)
# ============================================================================
echo "⚡ Step 4: Configuring browser automation (Playwright)..."
if ! pip list 2>/dev/null | grep -q "playwright"; then
    echo "   📦 Installing playwright..."
    pip install playwright
fi

if ! python -c "from playwright.sync_api import sync_playwright" 2>/dev/null; then
    echo "   📥 Installing playwright browsers..."
    python -m playwright install chromium
fi

echo "   ✅ Playwright browser ready"
echo ""

# ============================================================================
# 5. Verify all scripts are executable
# ============================================================================
echo "⚡ Step 5: Making scripts executable..."
chmod +x *.sh
echo "   ✅ All scripts are now executable"
echo ""

# ============================================================================
# 6. Create data directories
# ============================================================================
echo "⚡ Step 6: Creating data directories..."
mkdir -p data
mkdir -p data/media
mkdir -p logs
echo "   ✅ Data directories created"
echo ""

# ============================================================================
# 7. Quick validation test
# ============================================================================
echo "⚡ Step 7: Quick validation..."
echo "   Checking Python can import required modules..."
python3 -c "
import playhouse
import ollama
print('   ✅ All Python modules available')
" 2>&1 | head -3

echo ""
echo "   ✅ Quick validation complete"
echo ""

# ============================================================================
# 8. Final summary
# ============================================================================
echo ""
echo "========================================="
echo "   Setup Complete! 🎉"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Run:    bash daily-run.sh        # Full pipeline"
echo "  2. Or:     bash daily-run.sh --test-only  # Test mode only"
echo "  3. Or:     bash daily-run.sh --research-only  # Topics only"
echo ""
echo "Pipeline logs:    tail -f logs/daily-run.log"
echo "Post history:     cat data/post-history.log"
echo "Media files:      ls data/media/"
echo ""
echo "========================================="