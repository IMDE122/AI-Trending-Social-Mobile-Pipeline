# AI-Trending-Social-Mobile-Pipeline

Self-hosted, mobile-first, zero-cost trending → social media pipeline. Runs entirely on your mobile phone (Termux). No external SaaS. No API keys. Zero credentials shared.

## Quick Start (One Command)

```bash
# 1. Install Termux (Android - F-Droid or Play Store)
# 2. Install Python + Git + Node + Ollama + Playwright
pkg install python python-pip git wget curl nodejs npm -y
curl -fsSL https://ollama.com/install.sh | sh
pip install playwright && python -m playwright install chromium

# 3. Clone repo
git clone https://github.com/Anthropic-Projects/AI-Trending-Social-Mobile-Pipeline.git
cd AI-Trending-Social-Mobile-Pipeline

# 4. Run setup (one-time)
bash scripts/setup.sh

# 5. Run pipeline (daily)
bash scripts/daily-run.sh
```

## What This System Does

Each run, the pipeline:

1. **Scrapes trends** from 5 free sources (GitHub Trending, X/Twitter, Reddit, Hacker News, TechCrunch)
2. **Ranks topics** by virality potential using local LLM (Phi-3-mini, runs on your phone)
3. **Selects top 3-5 diverse topics** (viral anything — not one niche)
4. **Generates platform-native content** (X threads, TikTok scripts, FB Reels, YouTube Shorts)
5. **Creates media** via 5-level fallback chain:
   - Level 1: Local video (Remotion/Manim) — may fail on low-RAM phones
   - Level 2: Free stock video (Pexels/Pixabay)
   - Level 3: Stock image + Ken Burns effect
   - Level 4: Repo logos + title card (from trending research — always works)
   - Level 5: Text-only (guaranteed fastest fallback)
6. **Posts to 3 platforms** via Playwright browser automation (mobile viewport)
7. **Logs everything** and schedules the next run

**Total cost: $0/month. All on your phone.**

## Repository Structure

```
AI-Trending-Social-Mobile-Pipeline/
├── config/
│   ├── ollama-config.json      # Local LLM configuration (Phi-3-mini)
│   └── trends-sources.json     # 5 trend sources configuration
├── scripts/
│   ├── setup.sh                # One-time install + validation
│   ├── daily-run.sh            # Main orchestrator (full/research-only/content-only/test-only)
│   ├── scrape-trends.sh        # Trend scraping from 5 free sources
│   ├── generate-content.sh     # Local LLM content generation (4 platforms)
│   ├── fallback-media.sh       # 5-level media fallback chain
│   └── post-to-socials.sh      # Playwright browser automation (mobile viewport)
├── tests/
│   └── test_pipeline.py        # 733-line test suite
├── data/                       # Runtime data (created on first run)
├── logs/                       # Execution logs
└── templates/                  # Platform posting HTML templates
```

## How It Works (Mobile Phone Screen View)

```
┌─────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════╗ │
│  ║  TRENDING AI TOPICS — DAILY UPDATE                    ║ │
│  ║  ====================                                ║ │
│  ║  1. Claude-BugHunter — +10.5K ⭐ this week           ║ │
│  ║  2. Superpowers — +6.1K ⭐ — Agent dev framework      ║ │
│  ║  3. Ponytail — +5.4K ⭐ — Code graphs + tooling        ║ │
│  ║  4. ECC — +5.1K ⭐ — Enterprise code-review agent      ║ │
│  ║  5. HTML-Anything — +4.8K ⭐ — DOM manipulation agent  ║ │
│  ║                                                     ║ │
│  ║  📡 Scraping: GitHub + X + Reddit + HN + TechCrunch  ║ │
│  ║  🤖 LLM: Phi-3-mini local (2.7B params, 2GB RAM)    ║ │
│  ║  📤 Posting: YouTube Studio, TikTok, Facebook         ║ │
│  ║  🔄 Fallback: 5-level media chain (guaranteed output)║ │
│  ╚══════════════════════════════════════════════════════╝ │
│  ║  Last run: 2026-11-23 08:00  |  Next: 2026-11-24 08:00 ║ │
│  ║  Posts: YT ✓  TT ✓  FB ✓  (see logs for URLs)       ║ │
│  ╚══════════════════════════════════════════════════════╝ │
└─────────────────────────────────────────────────────────┘
```

## Test Suite

733-line comprehensive test suite:

```bash
pytest tests/test_pipeline.py -v
```

Tests cover: setup.sh, daily-run.sh modes, each individual script, fallback media chain (all 5 levels), LLM content generation, trend scraping from all 5 sources, mobile viewport compatibility.

## Posting Methods

| Method | How | Cost |
|--------|-----|------|
| **Browser Automation** | Playwright controls your mobile browser → navigates to YouTube Studio/TikTok/FB Creator → posts | Free |
| **Official APIs** | API tokens stored locally in `.env` → post via platform APIs | Free (quota limits) |
| **Manual Upload** | I generate content + metadata → you paste & upload in 3 min | Free |

## Privacy & Security

Complete local processing — nothing leaves your phone:

| Data | Stored | Sent External |
|------|--------|---------------|
| Trend data | `data/trends.json` (your phone) | No |
| Generated content | `data/content.txt` (your phone) | No |
| Media files | `data/media/` (your phone) | No |
| Post history | `logs/post-history.log` (your phone) | No |
| API tokens / credentials | Never requested | N/A |

**You control everything.**

## Media Fallback Chain (Guaranteed Output)

| Level | Method | Status |
|-------|--------|--------|
| 1 | Local video (Remotion/Manim) | May fail on low-RAM phones → Level 2 |
| 2 | Free stock video (Pexels/Pixabay) | Download + use → Level 3 |
| 3 | Stock image + Ken Burns | Create video from image → Level 4 |
| 4 | Repo logos + title card | Always works (public URLs) → Level 5 |
| 5 | Text-only | Guaranteed fastest fallback |

## License

MIT License — do whatever you want.

---

**Thank you** for full creative control — this system is designed to work without any permission prompts or approval requests. All actions execute automatically.