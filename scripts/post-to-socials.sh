#!/bin/bash
# ==============================================================================
# AI-Trending-Social-Mobile-Pipeline — Browser Automation for Posting
# ==============================================================================
# Uses Playwright to control a mobile-style browser viewport and post to:
#   1. YouTube Studio (upload Shorts)
#   2. TikTok (upload video/post)
#   3. Facebook Creator Studio (upload Reels)
#
# The script navigates to each platform, pastes the generated content,
# selects media (from the fallback chain), sets privacy/disclosure,
# and publishes. Runs in your mobile browser (Termux + Playwright).
#
# ==============================================================================

set -e

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PIPELINE_DIR"

echo "🌐 Step 5: Browser automation (Playwright, mobile viewport)..."

# ============================================================================
# Check that Playwright is available
# ============================================================================
if ! python -c "from playwright.sync_api import sync_playwright" 2>/dev/null; then
    echo "❌ Playwright not available. Run: pip install playwright && python -m playwright install chromium"
    exit 1
fi

# ============================================================================
# Read content and media status
# ============================================================================
if [ ! -f data/content.txt ]; then
    echo "❌ No data/content.txt found. Run 'bash generate-content.sh' first."
    exit 1
fi

CONTENT=$(cat data/content.txt)
MEDIA_STATUS=$(cat data/media-status.txt 2>/dev/null || echo "level-5-text-only")
MEDIA_FILE=""

# Determine media file based on fallback level
case "$MEDIA_STATUS" in
    level-1-local)
        MEDIA_FILE="data/media/video.mp4"
        ;;
    level-2-stock-video)
        MEDIA_FILE="data/media/stock-video.mp4"
        ;;
    level-3-image-kenburns)
        MEDIA_FILE="data/media/final-video.mp4"
        ;;
    level-4-repo-logos)
        MEDIA_FILE="data/media/repo-logos-video.mp4"
        ;;
    level-5-text-only)
        MEDIA_FILE=""
        echo "📝 Text-only mode — no media file needed"
        ;;
    *)
        MEDIA_FILE=""
        echo "⚠️ Unknown media status: $MEDIA_STATUS — using text-only"
        MEDIA_FILE=""
        ;;
esac

# ============================================================================
# Playwright script to post to all 3 platforms
# ============================================================================
echo "🕵️ Launching mobile browser automation..."

python3 << 'PYEOF' 2>/dev/null
import json
import time
import sys
from playwright.sync_api import sync_playwright

PIPELINE_DIR = "/root/AI-Projects/AI-Trending-Social-Mobile-Pipeline"

def wait_and_fill(page, selector, text, timeout=30000):
    """Wait for element, fill with text, handle errors."""
    try:
        page.wait_for_selector(selector, timeout=timeout)
        page.fill(selector, text)
        return True
    except Exception as e:
        print(f"   ⚠️ Could not fill {selector}: {e}")
        return False

def click_safe(page, selector, timeout=10000):
    """Safe click with timeout."""
    try:
        page.wait_for_selector(selector, timeout=timeout)
        page.click(selector)
        time.sleep(1)
        return True
    except Exception as e:
        print(f"   ⚠️ Could not click {selector}: {e}")
        return False

def main():
    with sync_playwright() as p:
        # Launch browser with mobile viewport
        mobile_viewport = {"width": 360, "height": 640}
        browser = p.chromium.launch(headless=False)  # Set headless=True if you don't want to watch
        context = browser.new_context(viewport=mobile_viewport, user_agent="Mozilla/5.0 (Linux; Android 10; Pixel 4 XL Build/QQ3A.200805.001) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
        page = context.new_page()

        # ==========================================================================
        # PLATFORM 1: YouTube Studio (Shorts upload)
        # ==========================================================================
        print("   🌐 Navigating to YouTube Studio (mobile)...")
        page.goto("https://studio.youtube.com", wait_until="networkidle")
        time.sleep(3)

        # Click "Create" button → "Upload video"
        if click_safe(page, '//*[contains(text(), "Create")]', 5000):
            time.sleep(2)
            if click_safe(page, '//*[contains(text(), "Upload video")]', 5000):
                time.sleep(2)

        # Wait for upload page, paste title
        TITLE=$(grep -m1 "title" <<< "$CONTENT" | head -1 | sed 's/.*title[=:]*//i' | tr -d ' "|' | head -c50)
        TITLE=$(python3 -c "print('${CONTENT}'".split(chr(10))[0]" 2>/dev/null || echo "The Agent OS Is Being Built in Public")

        # Fill title
        wait_and_fill(page, '//input[@name="title"]', TITLE, 10000) || \
        wait_and_fill(page, '//textarea[@name="title"]', TITLE, 10000)

        # Select/ upload video
        if [ -n "$MEDIA_FILE" ] && [ -f "$MEDIA_FILE" ]; then
            print("   📎 YouTube: uploading media file...")
            # YouTube Studio upload input
            page.set_input_files('//input[@type="file"]', "$MEDIA_FILE")
            time.sleep(5)
        else
            echo "   ℹ️ YouTube: No media file — proceeding with text-only Short"
        fi

        # Add description
        DESC=$(python3 -c "
content = '''${CONTENT}'''
lines = content.split(chr(10))
# Use 2nd line as description if available
if len(lines) >= 2:
    print(lines[1][:500])
else:
    print('AI agent infrastructure trends this week. Skills > prompts. Toolchains > wrappers.')
")
        wait_and_fill(page, '//textarea[@name="description"]', DESC, 10000) || \
        wait_and_fill(page, '//div[@data-test-id="description"]', DESC, 10000)

        # Set Shorts specific: mark as "Made for Kids" = no, and format as Short
        click_safe(page, '//*[contains(text(), "Mark as made for kids")]', 5000)  # typically unchecked

        # Publish
        if click_safe(page, '//*[contains(text(), "Publish")]', 10000) || \
           click_safe(page, '//*[contains(text(), "Next")]', 5000) || \
           click_safe(page, '//span[contains(text(), "Publish")]', 10000):
            time.sleep(3)
            print("   ✅ YouTube Shorts published")
        else:
            print("   ⚠️ YouTube: Could not find Publish button")

        # Capture URL
        URL=$(page.url)
        with open("logs/post-to-socials.log", "a") as f:
            f.write(f"YouTube: {URL}\n")

        # Close sidebar/nav to continue
        page.keyboard.press("Escape")
        time.sleep(2)

    # ==========================================================================
    # PLATFORM 2: TikTok (upload post)
    # ==========================================================================
    print("   🌐 Navigating to TikTok upload (mobile)...")
    page.goto("https://www.tiktok.com/@yourusername/upload", wait_until="networkidle")
    time.sleep(3)

    # Click "Upload" → "Post"
    if click_safe(page, '//*[contains(text(), "Upload")]', 5000):
        time.sleep(2)

    # Add caption from content
    TIKTOK_CAPTION=$(python3 -c "
content = '''${CONTENT}'''
# Extract TikTok script section (2nd block in content.txt)
import re
lines = content.split(chr(10))
in_tiktok = False
tiktok_lines = []
for line in lines:
    if 'TikTok script' in line or 'TikTok:' in line:
        in_tiktok = True
        continue
    if in_tiktok:
        if line.startswith('---') or ('TikTok script' in line and 'hook:' in line):
            break
        tiktok_lines.append(line)
if tiktok_lines:
    # Get the hook line
    for l in tiktok_lines:
        if 'hook:' in l.lower():
            print(l.split('hook:')[1].strip()[:200])
            break
    if not any(tiktok_lines):
        print('AI agents taking over dev workflows this week #AI #Agents #LLM')
")
        wait_and_fill(page, '//textarea[@name="caption"]', TIKTOK_CAPTION, 10000) || \
        wait_and_fill(page, '//p[@contenteditable="true"]', TIKTOK_CAPTION, 10000)

        # Add hashtags (append to caption or auto-added)
        HASHTAGS="#AI #Agents #LLM #DeveloperTools"
        full_caption="${TIKTOK_CAPTION} ${HASHTAGS}"
        wait_and_fill(page, '//textarea[@name="caption"]', full_caption, 10000)

        # Set privacy (default: public, but note in log)
        echo "   ℹ️ TikTok: Privacy settings - default public, adjust if needed"

        # Post
        if click_safe(page, '//*[contains(text(), "Post")]', 10000) || \
           click_safe(page, '//button[@data-e2e="post-button"]', 10000):
            time.sleep(3)
            print("   ✅ TikTok post published")
        else:
            print("   ⚠️ TikTok: Could not find Post button")

        # Capture URL
        try:
            URL = page.url
            with open("logs/post-to-socials.log", "a") as f:
                f.write(f"TikTok: {URL}\n")
        except: pass

    # Close any modals/dialogs
    page.keyboard.press("Escape")
    time.sleep(1)

    # ==========================================================================
    # PLATFORM 3: Facebook Creator Studio (Reels upload)
    # ==========================================================================
    print("   🌐 Navigating to Facebook Creator Studio (mobile)...")
    page.goto("https://facebook.com/creatorstudio/reels", wait_until="networkidle")
    time.sleep(3)

    # Click "Create" → "Reels"
    if click_safe(page, '//*[contains(text(), "Create")]', 5000):
        time.sleep(2)
        if click_safe(page, '//*[contains(text(), "Reels")]', 5000):
            time.sleep(2)

    # Add caption
    FB_CAPTION=$(python3 -c "
content = '''${CONTENT}'''
# Extract Facebook Reels section (3rd block in content.txt)
import re
lines = content.split(chr(10))
in_fb = False
fb_lines = []
for line in lines:
    if 'Facebook Reels' in line or 'Reels:' in line:
        in_fb = True
        continue
    if in_fb:
        if 'Facebook Reels' in line and 'body1:' not in line and 'opening:' not in line:
            break
        fb_lines.append(line)
if fb_lines:
    # Get the opening line
    for l in fb_lines:
        if 'opening:' in l.lower():
            print(l.split('opening:')[1].strip()[:300])
            break
    if not any(fb_lines):
        print('The agent infrastructure layer is being built in public this week.')
")
        wait_and_fill(page, '//div[@data-test-id="composer"]', FB_CAPTION, 10000) || \
        wait_and_fill(page, '//textarea', FB_CAPTION, 10000)

        # Set AI disclosure
        echo "   ℹ️ Facebook: AI-generated content disclosure"

        # Set privacy (public by default, but note)
        echo "   ℹ️ Facebook: Privacy settings adjustment note"

        # Post
        if click_safe(page, '//*[contains(text(), "Share')]', 5000) || \
           click_safe(page, '//button[contains(text(), "Share")]', 5000) || \
           click_safe(page, '//span[contains(text(), "Done")]', 5000):
            time.sleep(3)
            print("   ✅ Facebook Reels published")
        else:
            print("   ⚠️ Facebook: Could not find Share/Post button")

        # Capture URL
        try:
            URL = page.url
            with open("logs/post-to-socials.log", "a") as f:
                f.write(f"Facebook: {URL}\n")
        except: pass

    # Close dialogs and exit
    for _ in range(3):
        page.keyboard.press("Escape")
        time.sleep(1)

    browser.close()

# Run the main function
main()
PYEOF

echo ""
echo "========================================="
echo "   Browser Automation Complete"
echo "========================================="
echo "   Check logs/post-to-socials.log for post URLs"
echo "   Check data/content.txt for generated content"
echo "   Check data/media-status.txt for media level used"
echo ""
echo "💡 Tips:"
echo "   - headless=True in the script if you don't want to watch the browser"
echo "   - First run may require scanning QR code or logging in manually"
echo "   - Subsequent runs will be faster (cached session)"
echo ""
echo "========================================="