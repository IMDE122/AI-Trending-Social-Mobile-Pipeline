#!/usr/bin/env python3
"""
Mobile Phone Environment Simulation
===================================
Simulates a mobile phone running the AI-Trending-Social-Mobile-Pipeline
inside the AI system. Captures "screen" states, logs pipeline execution,
and provides a virtual environment for testing.
"""

import json
import time
import random
from datetime import datetime
from dataclasses import dataclass, field, asdict
from typing import List, Dict, Optional, Any
from enum import Enum


class PhoneState(Enum):
    IDLE = "idle"
    BOOTING = "booting"
    TERMUX_OPEN = "termux_open"
    PIPELINE_RUNNING = "pipeline_running"
    SCRAPING = "scraping"
    GENERATING = "generating"
    MEDIA_FALLBACK = "media_fallback"
    BROWSER_AUTOMATION = "browser_automation"
    POSTING = "posting"
    COMPLETE = "complete"
    ERROR = "error"


@dataclass
class ScreenCapture:
    """Represents a single screen capture from the mobile phone"""
    timestamp: str
    state: str
    screen_content: str
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class PipelineStep:
    """Represents one step in the pipeline execution"""
    step_name: str
    start_time: str
    end_time: Optional[str] = None
    status: str = "running"
    output: str = ""
    duration_seconds: float = 0.0


class MobilePhoneEnv:
    """
    Simulated mobile phone environment for AI-Trending-Social-Mobile-Pipeline.
    Provides screen capture, state tracking, and pipeline simulation.
    """

    def __init__(
        self,
        width: int = 360,
        height: int = 640,
        ram_mb: int = 4096,
        storage_gb: int = 64,
        os_version: str = "Android 14",
        termux_version: str = "0.118.0",
        ollama_model: str = "phi-3-mini",
        ollama_ram_mb: int = 2048,
    ):
        # Hardware specs
        self.width = width
        self.height = height
        self.ram_mb = ram_mb
        self.storage_gb = storage_gb
        self.os_version = os_version
        self.termux_version = termux_version

        # Software specs
        self.ollama_model = ollama_model
        self.ollama_ram_mb = ollama_ram_mb

        # State tracking
        self.state = PhoneState.IDLE
        self.screen_captures: List[ScreenCapture] = []
        self.pipeline_steps: List[PipelineStep] = []
        self.current_step: Optional[PipelineStep] = None
        self.post_results: List[Dict] = []
        self.errors: List[str] = []

        # Simulated filesystem
        self.filesystem: Dict[str, str] = {}

        # Start simulation
        self._capture_screen("Phone initialized", PhoneState.IDLE)

    def _capture_screen(self, message: str, state: PhoneState, metadata: Dict = None):
        """Capture current screen state"""
        self.state = state
        capture = ScreenCapture(
            timestamp=datetime.now().isoformat(),
            state=state.value,
            screen_content=message,
            metadata=metadata or {}
        )
        self.screen_captures.append(capture)
        return capture

    def start_step(self, step_name: str, metadata: Dict = None) -> PipelineStep:
        """Start a new pipeline step"""
        step = PipelineStep(
            step_name=step_name,
            start_time=datetime.now().isoformat(),
            status="running"
        )
        self.pipeline_steps.append(step)
        self.current_step = step
        meta = {"step": step_name}
        if metadata:
            meta.update(metadata)
        self._capture_screen(
            f"Running: {step_name}",
            PhoneState.PIPELINE_RUNNING,
            meta
        )
        return step

    def end_step(self, step_name: str, status: str = "success", output: str = ""):
        """End the current pipeline step"""
        if self.current_step and self.current_step.step_name == step_name:
            self.current_step.end_time = datetime.now().isoformat()
            self.current_step.status = status
            self.current_step.output = output
            if self.current_step.start_time and self.current_step.end_time:
                start = datetime.fromisoformat(self.current_step.start_time)
                end = datetime.fromisoformat(self.current_step.end_time)
                self.current_step.duration_seconds = (end - start).total_seconds()
            self._capture_screen(
                f"Step '{step_name}' {status}: {output[:100]}",
                PhoneState.PIPELINE_RUNNING,
                {"step": step_name, "status": status}
            )
            self.current_step = None

    def capture_screen(self, message: str = "", metadata: Dict = None) -> ScreenCapture:
        """Manual screen capture"""
        return self._capture_screen(
            message or self.state.value,
            self.state,
            metadata
        )

    def run_pipeline_step(self, step_name: str, duration_range: tuple = (1, 5),
                          success_rate: float = 0.95, output: str = "") -> bool:
        """Simulate running a pipeline step"""
        self.start_step(step_name)

        # Simulate duration
        duration = random.uniform(*duration_range)
        time.sleep(min(duration, 0.1))  # Fast simulation

        # Determine success
        success = random.random() < success_rate

        if success:
            self.end_step(step_name, "success", output or f"{step_name} completed successfully")
        else:
            error_msg = f"{step_name} failed after {duration:.1f}s"
            self.end_step(step_name, "failed", error_msg)
            self.errors.append(error_msg)

        return success

    def simulate_daily_run(self) -> Dict:
        """Simulate the complete daily pipeline run"""
        self._capture_screen("Starting daily pipeline run", PhoneState.PIPELINE_RUNNING)

        # Define pipeline steps
        steps = [
            ("Environment Check", PhoneState.IDLE, 0.5, 1.0, 1.0, "Environment ready"),
            ("Scraping Trends (5 sources)", PhoneState.SCRAPING, 2.0, 5.0, 0.95, "Scraped 5 sources, 23 items"),
            ("Scoring & Ranking Topics", PhoneState.SCRAPING, 1.0, 3.0, 0.98, "Top 5 topics ranked"),
            ("Generating Content (4 platforms)", PhoneState.GENERATING, 3.0, 8.0, 0.90, "Content for X, TikTok, FB, YT"),
            ("Fallback Media Chain (Level 1→5)", PhoneState.MEDIA_FALLBACK, 1.0, 4.0, 0.99, "Media: Level 2 (stock video)"),
            ("Browser Automation (3 platforms)", PhoneState.BROWSER_AUTOMATION, 5.0, 15.0, 0.85, "Posted to YT, TT, FB"),
            ("Logging & Summary", PhoneState.COMPLETE, 0.5, 1.0, 1.0, "Pipeline complete"),
        ]

        total_start = time.time()
        results = {
            "steps_completed": 0,
            "steps_failed": 0,
            "total_duration": 0,
            "post_results": [],
            "screen_log": [],
            "final_state": None
        }

        for step_name, state, min_dur, max_dur, success_rate, output in steps:
            self.state = state
            success = self.run_pipeline_step(step_name, (min_dur, max_dur), success_rate, output)

            if success:
                results["steps_completed"] += 1
            else:
                results["steps_failed"] += 1
                if step_name in ["Scraping Trends", "Generating Content", "Browser Automation"]:
                    # Critical failure - but we continue with fallbacks
                    pass

        total_duration = time.time() - total_start
        results["total_duration"] = total_duration

        # Simulate post results
        results["post_results"] = [
            {"platform": "YouTube Shorts", "url": "https://youtube.com/shorts/abc123", "status": "published"},
            {"platform": "TikTok", "url": "https://tiktok.com/@user/video/789", "status": "published"},
            {"platform": "Facebook Reels", "url": "https://facebook.com/reels/123", "status": "published"},
        ]

        # Capture final screen
        self._capture_screen("Pipeline Complete - All posts published", PhoneState.COMPLETE)
        results["final_state"] = PhoneState.COMPLETE.value
        results["screen_log"] = [asdict(c) for c in self.screen_captures]
        results["pipeline_steps"] = [asdict(s) for s in self.pipeline_steps]

        return results

    def get_screen_log(self) -> List[Dict]:
        """Return all screen captures as dicts"""
        return [asdict(c) for c in self.screen_captures]

    def read_screen(self) -> str:
        """Read current screen content (simulated)"""
        if self.screen_captures:
            return self.screen_captures[-1].screen_content
        return "Screen empty"

    def save_simulation_log(self, filepath: str = None) -> str:
        """Save complete simulation log to JSON file"""
        if filepath is None:
            filepath = f"simulation_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

        log_data = {
            "phone_specs": {
                "width": self.width,
                "height": self.height,
                "ram_mb": self.ram_mb,
                "storage_gb": self.storage_gb,
                "os_version": self.os_version,
                "termux_version": self.termux_version,
                "ollama_model": self.ollama_model,
                "ollama_ram_mb": self.ollama_ram_mb,
            },
            "simulation_time": datetime.now().isoformat(),
            "final_state": self.state.value,
            "total_captures": len(self.screen_captures),
            "total_steps": len(self.pipeline_steps),
            "errors": self.errors,
            "screen_captures": [asdict(c) for c in self.screen_captures],
            "pipeline_steps": [asdict(s) for s in self.pipeline_steps],
        }

        with open(filepath, 'w') as f:
            json.dump(log_data, f, indent=2)

        return filepath

    def print_status(self):
        """Print current phone status to console"""
        print(f"\n{'='*50}")
        print(f"MOBILE PHONE SIMULATION STATUS")
        print(f"{'='*50}")
        print(f"State: {self.state.value}")
        print(f"Screen: {self.read_screen()}")
        print(f"Screen Captures: {len(self.screen_captures)}")
        print(f"Pipeline Steps: {len(self.pipeline_steps)}")
        print(f"Errors: {len(self.errors)}")
        print(f"{'='*50}\n")


# ============================================================================
# Demo / Test Functions
# ============================================================================

def demo_simulation():
    """Run a demonstration of the mobile phone simulation"""
    print("\n🎬 Starting Mobile Phone Pipeline Simulation\n")

    # Create phone with typical mid-range Android specs
    phone = MobilePhoneEnv(
        width=360,
        height=640,
        ram_mb=4096,
        storage_gb=128,
        os_version="Android 14",
        termux_version="0.118.0",
        ollama_model="phi-3-mini",
        ollama_ram_mb=2048
    )

    # Run the full daily pipeline simulation
    results = phone.simulate_daily_run()

    # Print summary
    print(f"\n{'='*60}")
    print("SIMULATION COMPLETE - RESULTS SUMMARY")
    print(f"{'='*60}")
    print(f"Steps Completed: {results['steps_completed']}/7")
    print(f"Steps Failed: {results['steps_failed']}")
    print(f"Total Duration: {results['total_duration']:.2f}s")
    print(f"Final State: {results['final_state']}")
    print(f"Screen Captures: {len(results['screen_log'])}")
    print(f"\nPost Results:")
    for post in results['post_results']:
        print(f"  ✅ {post['platform']}: {post['url']}")

    # Save log
    log_file = phone.save_simulation_log()
    print(f"\nSimulation log saved to: {log_file}")

    # Print final screen
    print(f"\nFinal Screen:")
    print(phone.read_screen())

    phone.print_status()

    return phone, results


def quick_test():
    """Quick test of the simulation"""
    phone = MobilePhoneEnv()
    phone.run_pipeline_step("Test Step", (0.1, 0.5), 1.0, "Test passed")
    phone.print_status()
    return phone


if __name__ == "__main__":
    # Run demo
    demo_simulation()