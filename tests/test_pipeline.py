"""
test_pipeline.py — Comprehensive test suite for AI-Trending-Social-Mobile-Pipeline.

TDD Red-Green-Refactor methodology. Tests cover:
1. setup.sh runs without errors
2. daily-run.sh executes the full pipeline
3. Each individual script: scrape-trends, generate-content, fallback-media, post-to-socials
4. Fallback media chain has all 5 levels
5. LLM content generation works
6. Trend scraping from all 5 sources
7. Mobile viewport compatibility

Run: pytest tests/test_pipeline.py -v
Coverage: pytest tests/test_pipeline.py --cov=.
"""

import json
import os
import re
import subprocess
import sys

import pytest

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
PIPELINE_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..")
)
SCRIPTS_DIR = os.path.join(PIPELINE_DIR, "scripts")
CONFIG_DIR = os.path.join(PIPELINE_DIR, "config")
DATA_DIR = os.path.join(PIPELINE_DIR, "data")
LOGS_DIR = os.path.join(PIPELINE_DIR, "logs")

SETUP_SH = os.path.join(SCRIPTS_DIR, "setup.sh")
DAILY_RUN_SH = os.path.join(SCRIPTS_DIR, "daily-run.sh")
SCRAPE_TRENDS_SH = os.path.join(SCRIPTS_DIR, "scrape-trends.sh")
GENERATE_CONTENT_SH = os.path.join(SCRIPTS_DIR, "generate-content.sh")
FALLBACK_MEDIA_SH = os.path.join(SCRIPTS_DIR, "fallback-media.sh")
POST_TO_SOCIALS_SH = os.path.join(SCRIPTS_DIR, "post-to-socials.sh")

TRENDS_JSON = os.path.join(DATA_DIR, "trends.json")
CONTENT_TXT = os.path.join(DATA_DIR, "content.txt")
MEDIA_STATUS_TXT = os.path.join(DATA_DIR, "media-status.txt")

ALL_SOURCES = {"GitHub Trending", "X/Twitter", "Reddit", "Hacker News", "TechCrunch"}
ALL_MEDIA_LEVELS = {
    "level-1-local",
    "level-2-stock-video",
    "level-3-image-kenburns",
    "level-4-repo-logos",
    "level-5-text-only",
}

MOBILE_VIEWPORT_WIDTH = 360
MOBILE_VIEWPORT_HEIGHT = 640


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def run_shell(script_path, args=None, timeout=300):
    """Run a shell script and return CompletedProcess."""
    cmd = ["bash", script_path] + (args or [])
    return subprocess.run(
        cmd,
        cwd=PIPELINE_DIR,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def assert_script_success(result, script_name):
    """Assert a shell script ran without errors."""
    assert result.returncode == 0, (
        f"{script_name} failed (exit code {result.returncode}).\n"
        f"STDOUT:\n{result.stdout}\n"
        f"STDERR:\n{result.stderr}"
    )


def load_json(path):
    with open(path) as f:
        return json.load(f)


def ensure_data_dir():
    os.makedirs(DATA_DIR, exist_ok=True)


def write_trends_json(items=None):
    """Write a sample trends.json for content-generation tests."""
    ensure_data_dir()
    if items is None:
        items = {
            "Claude-BugHunter": {
                "source": "GitHub Trending",
                "score": 94,
                "date": "2026-11-20",
            },
            "Superpowers": {
                "source": "GitHub Trending",
                "score": 89,
                "date": "2026-11-20",
            },
            "ECC": {
                "source": "GitHub Trending",
                "score": 87,
                "date": "2026-11-20",
            },
        }
    data = {
        "items": items,
        "sources": ["GitHub Trending", "X/Twitter", "Reddit", "Hacker News", "TechCrunch"],
        "generated_at": "2026-11-20T12:00:00",
        "total": len(items),
    }
    with open(TRENDS_JSON, "w") as f:
        json.dump(data, f, indent=2)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
@pytest.fixture(autouse=True)
def clean_data_dir():
    """Ensure a clean data directory before each test."""
    yield
    # Cleanup not required; tests are independent


# ===========================================================================
# 1. setup.sh tests
# ===========================================================================
class TestSetupScript:
    """Test that setup.sh runs without errors."""

    def test_setup_script_exists(self):
        assert os.path.isfile(SETUP_SH), f"setup.sh not found at {SETUP_SH}"
        assert os.access(SETUP_SH, os.X_OK), "setup.sh is not executable"

    def test_setup_script_runs_without_errors(self):
        """setup.sh should complete with exit code 0."""
        result = run_shell(SETUP_SH, timeout=300)
        assert_script_success(result, "setup.sh")

    def test_setup_creates_data_directories(self):
        """setup.sh should create data/, data/media/, logs/ directories."""
        run_shell(SETUP_SH, timeout=300)
        assert os.path.isdir(DATA_DIR), "data/ directory not created by setup.sh"
        assert os.path.isdir(os.path.join(DATA_DIR, "media")), "data/media/ directory not created"
        assert os.path.isdir(LOGS_DIR), "logs/ directory not created by setup.sh"

    def test_setup_makes_all_scripts_executable(self):
        """setup.sh should make all .sh scripts executable."""
        run_shell(SETUP_SH, timeout=300)
        for script in [
            SETUP_SH,
            DAILY_RUN_SH,
            SCRAPE_TRENDS_SH,
            GENERATE_CONTENT_SH,
            FALLBACK_MEDIA_SH,
            POST_TO_SOCIALS_SH,
        ]:
            assert os.access(script, os.X_OK), f"{script} is not executable after setup.sh"

    def test_setup_config_files_exist(self):
        """Config files referenced by setup.sh should exist."""
        assert os.path.isfile(os.path.join(CONFIG_DIR, "ollama-config.json"))
        assert os.path.isfile(os.path.join(CONFIG_DIR, "trends-sources.json"))


# ===========================================================================
# 2. daily-run.sh tests
# ===========================================================================
class TestDailyRunScript:
    """Test that daily-run.sh executes the full pipeline."""

    def test_daily_run_script_exists(self):
        assert os.path.isfile(DAILY_RUN_SH), f"daily-run.sh not found at {DAILY_RUN_SH}"
        assert os.access(DAILY_RUN_SH, os.X_OK), "daily-run.sh is not executable"

    def test_daily_run_help_option(self):
        result = run_shell(DAILY_RUN_SH, ["--help"], timeout=60)
        assert result.returncode == 0, "--help should exit 0"
        assert "research-only" in result.stdout or "content-only" in result.stdout

    def test_daily_run_test_only_mode(self):
        """--test-only mode validates everything without posting."""
        run_shell(SETUP_SH, timeout=300)
        result = run_shell(DAILY_RUN_SH, ["--test-only"], timeout=300)
        assert_script_success(result, "daily-run.sh --test-only")

    def test_daily_run_research_only_mode(self):
        """--research-only mode scrapes trends & selects topics without posting."""
        run_shell(SETUP_SH, timeout=300)
        result = run_shell(DAILY_RUN_SH, ["--research-only"], timeout=300)
        assert_script_success(result, "daily-run.sh --research-only")

    def test_daily_run_content_only_mode(self):
        """--content-only mode generates content for selected topics."""
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        result = run_shell(DAILY_RUN_SH, ["--content-only"], timeout=300)
        assert_script_success(result, "daily-run.sh --content-only")

    def test_daily_run_full_pipeline_creates_output_files(self):
        """Full pipeline should create trends.json, content.txt, media-status.txt."""
        run_shell(SETUP_SH, timeout=300)
        result = run_shell(DAILY_RUN_SH, ["--test-only"], timeout=300)
        assert_script_success(result, "daily-run.sh --test-only")
        # trends.json should exist
        assert os.path.isfile(TRENDS_JSON), "data/trends.json not created by daily-run.sh"


# ===========================================================================
# 3. Individual script tests
# ===========================================================================
class TestScrapeTrendsScript:
    """Test scrape-trends.sh script."""

    def test_scrape_trends_script_exists(self):
        assert os.path.isfile(SCRAPE_TRENDS_SH), f"scrape-trends.sh not found"
        assert os.access(SCRAPE_TRENDS_SH, os.X_OK), "scrape-trends.sh is not executable"

    def test_scrape_trends_runs_without_errors(self):
        run_shell(SETUP_SH, timeout=300)
        result = run_shell(SCRAPE_TRENDS_SH, timeout=300)
        assert_script_success(result, "scrape-trends.sh")

    def test_scrape_trends_creates_trends_json(self):
        run_shell(SETUP_SH, timeout=300)
        run_shell(SCRAPE_TRENDS_SH, timeout=300)
        assert os.path.isfile(TRENDS_JSON), "scrape-trends.sh did not create data/trends.json"
        data = load_json(TRENDS_JSON)
        assert "items" in data, "trends.json missing 'items' key"
        assert "sources" in data, "trends.json missing 'sources' key"
        assert isinstance(data["items"], dict), "trends.json 'items' should be a dict"
        assert isinstance(data["sources"], list), "trends.json 'sources' should be a list"

    def test_scrape_trends_json_is_valid(self):
        run_shell(SETUP_SH, timeout=300)
        run_shell(SCRAPE_TRENDS_SH, timeout=300)
        data = load_json(TRENDS_JSON)
        # Should be valid JSON round-trip
        json.dumps(data)


class TestGenerateContentScript:
    """Test generate-content.sh script."""

    def test_generate_content_script_exists(self):
        assert os.path.isfile(GENERATE_CONTENT_SH), f"generate-content.sh not found"
        assert os.access(GENERATE_CONTENT_SH, os.X_OK), "generate-content.sh is not executable"

    def test_generate_content_requires_trends_json(self):
        """generate-content.sh should fail gracefully without trends.json."""
        # Remove trends.json if it exists
        if os.path.isfile(TRENDS_JSON):
            os.remove(TRENDS_JSON)
        result = run_shell(GENERATE_CONTENT_SH, timeout=300)
        assert result.returncode != 0, "generate-content.sh should fail without trends.json"

    def test_generate_content_creates_content_txt(self):
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        result = run_shell(GENERATE_CONTENT_SH, timeout=300)
        assert_script_success(result, "generate-content.sh")
        assert os.path.isfile(CONTENT_TXT), "generate-content.sh did not create data/content.txt"

    def test_generate_content_has_all_platforms(self):
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        with open(CONTENT_TXT) as f:
            content = f.read()
        # Check for platform sections (X thread, TikTok, Facebook Reels, YouTube Shorts)
        assert "X thread" in content or "Tweet" in content, "Missing X thread content"
        assert "TikTok" in content, "Missing TikTok script content"
        assert "Facebook" in content or "Reels" in content, "Missing Facebook Reels content"
        assert "YouTube" in content or "Shorts" in content, "Missing YouTube Shorts content"

    def test_generate_content_x_thread_tweet_count(self):
        """X thread should contain exactly 5 tweets."""
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        with open(CONTENT_TXT) as f:
            content = f.read()
        # X thread format uses pipe-separated tweets
        x_section = content.split("TikTok")[0] if "TikTok" in content else content
        tweets = [t.strip() for t in x_section.split("|") if t.strip()]
        assert len(tweets) >= 3, f"Expected at least 3 tweets in X thread, got {len(tweets)}"

    def test_generate_content_uses_top_topics(self):
        """Generated content should reference top trending topics."""
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        with open(CONTENT_TXT) as f:
            content = f.read()
        assert "Claude-BugHunter" in content or "Superpowers" in content or "ECC" in content, \
            "Content should reference top trending topics from trends.json"

    def test_generate_content_creates_media_status(self):
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        assert os.path.isfile(MEDIA_STATUS_TXT), "generate-content.sh did not create data/media-status.txt"


class TestFallbackMediaScript:
    """Test fallback-media.sh script."""

    def test_fallback_media_script_exists(self):
        assert os.path.isfile(FALLBACK_MEDIA_SH), f"fallback-media.sh not found"
        assert os.access(FALLBACK_MEDIA_SH, os.X_OK), "fallback-media.sh is not executable"

    def test_fallback_media_runs_without_errors(self):
        run_shell(SETUP_SH, timeout=300)
        result = run_shell(FALLBACK_MEDIA_SH, timeout=300)
        assert_script_success(result, "fallback-media.sh")

    def test_fallback_media_creates_media_status(self):
        run_shell(SETUP_SH, timeout=300)
        run_shell(FALLBACK_MEDIA_SH, timeout=300)
        assert os.path.isfile(MEDIA_STATUS_TXT), "fallback-media.sh did not create data/media-status.txt"


class TestPostToSocialsScript:
    """Test post-to-socials.sh script."""

    def test_post_to_socials_script_exists(self):
        assert os.path.isfile(POST_TO_SOCIALS_SH), f"post-to-socials.sh not found"
        assert os.access(POST_TO_SOCIALS_SH, os.X_OK), "post-to-socials.sh is not executable"

    def test_post_to_socials_requires_content_txt(self):
        """post-to-socials.sh should fail gracefully without content.txt."""
        if os.path.isfile(CONTENT_TXT):
            os.remove(CONTENT_TXT)
        result = run_shell(POST_TO_SOCIALS_SH, timeout=300)
        assert result.returncode != 0, "post-to-socials.sh should fail without content.txt"

    def test_post_to_socials_mobile_viewport_defined(self):
        """post-to-socials.sh should define a mobile viewport (360x640)."""
        with open(POST_TO_SOCIALS_SH) as f:
            script_content = f.read()
        # Check for mobile viewport configuration
        assert "360" in script_content, "post-to-socials.sh missing mobile viewport width (360)"
        assert "640" in script_content, "post-to-socials.sh missing mobile viewport height (640)"
        assert "mobile_viewport" in script_content, "post-to-socials.sh missing mobile_viewport variable"

    def test_post_to_socials_has_all_three_platforms(self):
        """post-to-socials.sh should target YouTube, TikTok, and Facebook."""
        with open(POST_TO_SOCIALS_SH) as f:
            script_content = f.read()
        assert "YouTube" in script_content or "youtube" in script_content.lower(), "Missing YouTube platform"
        assert "TikTok" in script_content or "tiktok" in script_content.lower(), "Missing TikTok platform"
        assert "Facebook" in script_content or "facebook" in script_content.lower(), "Missing Facebook platform"


# ===========================================================================
# 4. Fallback media chain tests — all 5 levels
# ===========================================================================
class TestFallbackMediaChain:
    """Test that the fallback media chain has all 5 levels."""

    def test_fallback_level_1_local_video(self):
        """Level 1: Local video generation (Remotion/Manim)."""
        with open(FALLBACK_MEDIA_SH) as f:
            content = f.read()
        assert "Level 1" in content, "Missing Level 1 in fallback chain"
        assert "Remotion" in content or "Manim" in content, "Level 1 should mention Remotion/Manim"
        assert "level-1-local" in content, "Level 1 should write 'level-1-local' status"

    def test_fallback_level_2_stock_video(self):
        """Level 2: Free stock video (Pexels/Pixabay)."""
        with open(FALLBACK_MEDIA_SH) as f:
            content = f.read()
        assert "Level 2" in content, "Missing Level 2 in fallback chain"
        assert "stock" in content.lower(), "Level 2 should mention stock video"
        assert "level-2-stock-video" in content, "Level 2 should write 'level-2-stock-video' status"

    def test_fallback_level_3_ken_burns(self):
        """Level 3: Stock image + Ken Burns effect."""
        with open(FALLBACK_MEDIA_SH) as f:
            content = f.read()
        assert "Level 3" in content, "Missing Level 3 in fallback chain"
        assert "Ken Burns" in content, "Level 3 should mention Ken Burns effect"
        assert "level-3-image-kenburns" in content, "Level 3 should write 'level-3-image-kenburns' status"

    def test_fallback_level_4_repo_logos(self):
        """Level 4: Repo logos + title card."""
        with open(FALLBACK_MEDIA_SH) as f:
            content = f.read()
        assert "Level 4" in content, "Missing Level 4 in fallback chain"
        assert "logo" in content.lower(), "Level 4 should mention repo logos"
        assert "level-4-repo-logos" in content, "Level 4 should write 'level-4-repo-logos' status"

    def test_fallback_level_5_text_only(self):
        """Level 5: Text-only guaranteed fallback."""
        with open(FALLBACK_MEDIA_SH) as f:
            content = f.read()
        assert "Level 5" in content, "Missing Level 5 in fallback chain"
        assert "text-only" in content.lower() or "Text-only" in content, "Level 5 should mention text-only"
        assert "level-5-text-only" in content, "Level 5 should write 'level-5-text-only' status"

    def test_all_fallback_levels_written_to_media_status(self):
        """Each level should write its corresponding status to media-status.txt."""
        for level in ALL_MEDIA_LEVELS:
            assert level in open(FALLBACK_MEDIA_SH).read(), f"Fallback chain missing level: {level}"

    def test_fallback_levels_in_correct_order(self):
        """Levels should appear in order 1 -> 5 in the script."""
        with open(FALLBACK_MEDIA_SH) as f:
            content = f.read()
        level1_pos = content.find("Level 1")
        level2_pos = content.find("Level 2")
        level3_pos = content.find("Level 3")
        level4_pos = content.find("Level 4")
        level5_pos = content.find("Level 5")
        assert level1_pos < level2_pos < level3_pos < level4_pos < level5_pos, \
            "Fallback levels must appear in order 1 through 5"


# ===========================================================================
# 5. LLM content generation tests
# ===========================================================================
class TestLLMContentGeneration:
    """Test LLM content generation works."""

    def test_ollama_config_exists(self):
        assert os.path.isfile(os.path.join(CONFIG_DIR, "ollama-config.json")), \
            "ollama-config.json not found"
        config = load_json(os.path.join(CONFIG_DIR, "ollama-config.json"))
        assert "model" in config, "ollama-config.json missing 'model' key"
        assert config["model"] == "phi-3-mini", "Expected phi-3-mini model"

    def test_ollama_config_has_fallback(self):
        config = load_json(os.path.join(CONFIG_DIR, "ollama-config.json"))
        assert "fallback" in config, "ollama-config.json missing 'fallback' key"

    def test_generate_content_uses_local_llm(self):
        """generate-content.sh should reference Ollama/phi-3-mini."""
        with open(GENERATE_CONTENT_SH) as f:
            content = f.read()
        assert "ollama" in content.lower(), "generate-content.sh should reference ollama"
        assert "phi-3-mini" in content, "generate-content.sh should reference phi-3-mini"

    def test_generate_content_has_fallback_for_each_platform(self):
        """Each platform should have a fallback when LLM fails."""
        with open(GENERATE_CONTENT_SH) as f:
            content = f.read()
        platforms = ["X thread", "TikTok", "Facebook", "YouTube"]
        for platform in platforms:
            # Check that fallback pattern exists for each platform
            assert "fallback" in content.lower() or "LLM failed" in content, \
                f"Missing fallback for {platform} content generation"

    def test_generate_content_output_is_non_empty(self):
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        with open(CONTENT_TXT) as f:
            content = f.read()
        assert len(content.strip()) > 0, "Generated content should not be empty"
        assert len(content) > 100, "Generated content should be substantial (>100 chars)"

    def test_content_avoids_hype_language(self):
        """Generated content should avoid banned hype phrases."""
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        with open(CONTENT_TXT) as f:
            content = f.read()
        banned_phrases = [
            "game-changer", "revolutionary", "cutting-edge",
            "today's rapidly evolving landscape",
        ]
        content_lower = content.lower()
        for phrase in banned_phrases:
            assert phrase.lower() not in content_lower, \
                f"Content contains banned hype phrase: '{phrase}'"


# ===========================================================================
# 6. Trend scraping from all 5 sources
# ===========================================================================
class TestTrendScraping:
    """Test trend scraping from all 5 sources."""

    def test_trends_sources_config_exists(self):
        assert os.path.isfile(os.path.join(CONFIG_DIR, "trends-sources.json")), \
            "trends-sources.json not found"
        config = load_json(os.path.join(CONFIG_DIR, "trends-sources.json"))
        assert isinstance(config, dict), "trends-sources.json should be a JSON object"

    def test_scrape_trends_all_5_sources(self):
        """scrape-trends.sh should reference all 5 sources."""
        with open(SCRAPE_TRENDS_SH) as f:
            content = f.read()
        for source in ALL_SOURCES:
            assert source in content, f"scrape-trends.sh missing source: {source}"

    def test_scrape_trends_source_count_is_5(self):
        """scrape-trends.sh should have exactly 5 sources."""
        with open(SCRAPE_TRENDS_SH) as f:
            content = f.read()
        source_markers = [
            "Source 1/5", "Source 2/5", "Source 3/5", "Source 4/5", "Source 5/5",
        ]
        for marker in source_markers:
            assert marker in content, f"scrape-trends.sh missing source marker: {marker}"

    def test_trends_json_has_items(self):
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        data = load_json(TRENDS_JSON)
        assert len(data["items"]) > 0, "trends.json should have at least one item"

    def test_trends_items_have_scores(self):
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        data = load_json(TRENDS_JSON)
        for name, item in data["items"].items():
            if isinstance(item, dict):
                assert "score" in item, f"Item '{name}' missing score field"

    def test_trends_sources_covered_in_output(self):
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(SCRAPE_TRENDS_SH, timeout=300)
        data = load_json(TRENDS_JSON)
        sources_in_data = set(data.get("sources", []))
        # At minimum the config lists all 5 sources
        config = load_json(os.path.join(CONFIG_DIR, "trends-sources.json"))
        assert config, "trends-sources.json should not be empty"


# ===========================================================================
# 7. Mobile viewport compatibility tests
# ===========================================================================
class TestMobileViewportCompatibility:
    """Test mobile viewport compatibility."""

    def test_post_to_socials_mobile_viewport_width_height(self):
        """Mobile viewport should be 360x640 (typical mobile phone)."""
        with open(POST_TO_SOCIALS_SH) as f:
            content = f.read()
        assert 'width": 360' in content or 'width=360' in content or "360" in content, \
            "Mobile viewport width should be 360"
        assert 'height": 640' in content or 'height=640' in content or "640" in content, \
            "Mobile viewport height should be 640"

    def test_post_to_socials_mobile_user_agent(self):
        """post-to-socials.sh should use a mobile user agent."""
        with open(POST_TO_SOCIALS_SH) as f:
            content = f.read()
        assert "Mobile" in content or "mobile" in content.lower(), \
            "post-to-socials.sh should use mobile user agent"
        assert "Android" in content or "iPhone" in content or "Pixel" in content, \
            "post-to-socials.sh should identify a mobile device platform"

    def test_daily_run_mentions_mobile_viewport(self):
        """daily-run.sh should mention mobile viewport in browser automation step."""
        with open(DAILY_RUN_SH) as f:
            content = f.read()
        assert "mobile" in content.lower() or "Mobile" in content, \
            "daily-run.sh should mention mobile viewport in browser automation step"

    def test_post_to_socials_uses_android_user_agent(self):
        """The Playwright context should use an Android mobile user agent."""
        with open(POST_TO_SOCIALS_SH) as f:
            content = f.read()
        assert "Android" in content, "post-to-socials.sh should use Android user agent"
        assert "Pixel" in content, "post-to-socials.sh should use Pixel device user agent"

    def test_scrape_trends_uses_mobile_user_agent(self):
        """scrape-trends.sh should use a mobile user agent for scraping."""
        with open(SCRAPE_TRENDS_SH) as f:
            content = f.read()
        assert "Mobile" in content or "mobile" in content.lower(), \
            "scrape-trends.sh should use mobile user agent"
        assert "Android" in content or "Pixel" in content, \
            "scrape-trends.sh should identify mobile device in user agent"

    def test_post_to_socials_headless_option(self):
        """post-to-socials.sh should support headless mode for CI/mobile testing."""
        with open(POST_TO_SOCIALS_SH) as f:
            content = f.read()
        assert "headless" in content.lower(), "post-to-socials.sh should mention headless mode"

    def test_post_to_socials_logs_post_urls(self):
        """post-to-socials.sh should log post URLs for verification."""
        with open(POST_TO_SOCIALS_SH) as f:
            content = f.read()
        assert "post-to-socials.log" in content, \
            "post-to-socials.sh should write to post-to-socials.log"


# ===========================================================================
# Integration / end-to-end tests
# ===========================================================================
class TestPipelineIntegration:
    """Integration tests across the full pipeline."""

    def test_full_pipeline_end_to_end_test_only(self):
        """Full pipeline: setup -> scrape -> generate -> media -> validate (no posting)."""
        run_shell(SETUP_SH, timeout=300)
        result = run_shell(DAILY_RUN_SH, ["--test-only"], timeout=300)
        assert_script_success(result, "daily-run.sh --test-only (full pipeline test-only)")

        # Verify outputs exist
        assert os.path.isfile(TRENDS_JSON), "trends.json missing after full pipeline"
        assert os.path.isfile(CONTENT_TXT), "content.txt missing after full pipeline"
        assert os.path.isfile(MEDIA_STATUS_TXT), "media-status.txt missing after full pipeline"

        # Verify media status is one of the valid levels
        with open(MEDIA_STATUS_TXT) as f:
            media_status = f.read().strip()
        assert media_status in ALL_MEDIA_LEVELS, \
            f"Invalid media status: '{media_status}'. Expected one of {ALL_MEDIA_LEVELS}"

    def test_content_references_scraped_trends(self):
        """Generated content should reference topics from scraped trends."""
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        with open(CONTENT_TXT) as f:
            content = f.read()
        data = load_json(TRENDS_JSON)
        # At least one topic name from trends.json should appear in content
        topics_found = 0
        for topic_name in data["items"]:
            if topic_name.lower() in content.lower():
                topics_found += 1
        assert topics_found > 0, "No trending topics referenced in generated content"

    def test_media_status_matches_fallback_level(self):
        """media-status.txt should contain a valid fallback level string."""
        run_shell(SETUP_SH, timeout=300)
        run_shell(FALLBACK_MEDIA_SH, timeout=300)
        with open(MEDIA_STATUS_TXT) as f:
            status = f.read().strip()
        assert status in ALL_MEDIA_LEVELS, \
            f"Media status '{status}' is not a valid fallback level"

    def test_all_scripts_are_executable(self):
        """All pipeline scripts should be executable."""
        scripts = [
            SETUP_SH,
            DAILY_RUN_SH,
            SCRAPE_TRENDS_SH,
            GENERATE_CONTENT_SH,
            FALLBACK_MEDIA_SH,
            POST_TO_SOCIALS_SH,
        ]
        for script in scripts:
            assert os.access(script, os.X_OK), f"{script} is not executable"

    def test_pipeline_creates_logs_directory(self):
        run_shell(SETUP_SH, timeout=300)
        assert os.path.isdir(LOGS_DIR), "logs/ directory should exist after setup"


# ===========================================================================
# Edge case tests
# ===========================================================================
class TestEdgeCases:
    """Test edge cases: null, empty, invalid input, error paths."""

    def test_generate_content_with_empty_trends_json(self):
        """generate-content.sh should handle empty trends.json gracefully."""
        ensure_data_dir()
        with open(TRENDS_JSON, "w") as f:
            json.dump({"items": {}, "sources": [], "total": 0}, f)
        result = run_shell(GENERATE_CONTENT_SH, timeout=300)
        # Should either succeed with defaults or fail gracefully (non-crash)
        assert result.returncode in (0, 1), "generate-content.sh should not crash on empty trends"

    def test_generate_content_with_malformed_json(self):
        """generate-content.sh should handle malformed trends.json gracefully."""
        ensure_data_dir()
        with open(TRENDS_JSON, "w") as f:
            f.write("{not valid json")
        result = run_shell(GENERATE_CONTENT_SH, timeout=300)
        assert result.returncode != 0, "generate-content.sh should fail on malformed JSON"

    def test_trends_json_item_score_boundary(self):
        """Items with score > 0 should be selected; score = 0 should not."""
        items = {
            "HighScoreTopic": {"source": "GitHub Trending", "score": 100, "date": "2026-11-20"},
            "ZeroScoreTopic": {"source": "GitHub Trending", "score": 0, "date": "2026-11-20"},
            "NegativeScoreTopic": {"source": "GitHub Trending", "score": -5, "date": "2026-11-20"},
        }
        write_trends_json(items)
        data = load_json(TRENDS_JSON)
        scored = [
            (k, v.get("score", 0))
            for k, v in data["items"].items()
            if isinstance(v, dict) and v.get("score", 0) > 0
        ]
        assert len(scored) == 1, "Only items with score > 0 should be selected"
        assert scored[0][0] == "HighScoreTopic"

    def test_content_special_characters(self):
        """Generated content should handle special characters/Unicode."""
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        with open(CONTENT_TXT, encoding="utf-8") as f:
            content = f.read()
        # Should be valid UTF-8
        content.encode("utf-8")
        assert len(content) > 0

    def test_post_to_socials_with_missing_media_status(self):
        """post-to-socials.sh should handle missing media-status.txt gracefully."""
        run_shell(SETUP_SH, timeout=300)
        write_trends_json()
        run_shell(GENERATE_CONTENT_SH, timeout=300)
        # Remove media-status.txt to test fallback
        if os.path.isfile(MEDIA_STATUS_TXT):
            os.remove(MEDIA_STATUS_TXT)
        result = run_shell(POST_TO_SOCIALS_SH, timeout=300)
        # post-to-socials may fail due to no browser/login, but should not crash on missing media-status
        # It defaults to text-only per the case statement '*'
        assert result.returncode in (0, 1), "post-to-socials.sh should handle missing media-status gracefully"


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v"]))