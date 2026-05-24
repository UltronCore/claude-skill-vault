---
name: webscraping-anti-detection
description: Implement anti-detection techniques for web scraping — Playwright stealth with human-like mouse behavior (Bezier curves), fingerprint spoofing, proxy rotation with session persistence, CAPTCHA solving via 2captcha, and request rate management to avoid blocks.
version: 1.0.0
tags: [web-scraping, anti-detection, playwright, proxy-rotation, captcha, stealth, fingerprinting, python]
---

# Web Scraping Anti-Detection

## Overview

Modern websites deploy multi-layer bot detection: browser fingerprinting (User-Agent, canvas, WebGL, font enumeration), behavioral analysis (mouse movement patterns, click timing, scroll velocity), IP reputation scoring, and CAPTCHA challenges. Effective anti-detection requires matching human behavioral signatures at every layer simultaneously — rotating proxies without matching browser fingerprints still fails, and perfect fingerprints with robotic mouse movement still triggers behavioral analysis. The playwright-stealth ecosystem provides the strongest starting point for evasion.

## When to Use

- Scraping data from sites that block headless browsers or rate-limit aggressively
- Running price monitoring or data collection requiring sustained access without blocks
- Bypassing bot detection on JavaScript-heavy SPAs where simple HTTP requests fail
- Collecting public data that requires authenticated sessions with human-like behavior
- Testing your own site's bot detection effectiveness
- Research tasks requiring access to geo-restricted content via proxy rotation

## Step-by-Step Workflow

### 1. Stealth Playwright Setup

```python
# src/scraper/stealth_browser.py
# pip install playwright playwright-stealth

import asyncio
import random
from playwright.async_api import async_playwright, Page, BrowserContext
from playwright_stealth import stealth_async

async def create_stealth_context(
    proxy: dict | None = None,
    locale: str = "en-US",
    timezone: str = "America/New_York",
) -> tuple:
    """
    Create a Playwright browser context with stealth patches applied.
    playwright_stealth patches: navigator.webdriver, plugins, languages,
    permissions, chrome runtime, and WebGL renderer.
    """
    playwright = await async_playwright().start()

    browser = await playwright.chromium.launch(
        headless=True,
        args=[
            "--no-sandbox",
            "--disable-blink-features=AutomationControlled",
            "--disable-dev-shm-usage",
            "--disable-extensions",
            "--no-first-run",
        ],
        proxy=proxy,  # {"server": "http://ip:port", "username": "u", "password": "p"}
    )

    context = await browser.new_context(
        viewport={"width": 1920, "height": 1080},
        user_agent=(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/124.0.0.0 Safari/537.36"
        ),
        locale=locale,
        timezone_id=timezone,
        geolocation={"latitude": 40.7128, "longitude": -74.0060},  # Match proxy location
        permissions=["geolocation"],
        color_scheme="light",
        java_script_enabled=True,
        extra_http_headers={
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
        },
    )

    page = await context.new_page()
    await stealth_async(page)    # Apply stealth patches to the page

    return playwright, browser, context, page
```

### 2. Human-Like Mouse Movement

```python
# src/scraper/human_behavior.py
# Bezier curve mouse movement — avoids robotic linear trajectories
import asyncio
import random
from playwright.async_api import Page

def bezier_curve(
    start: tuple[float, float],
    end: tuple[float, float],
    steps: int = 30,
) -> list[tuple[float, float]]:
    """
    Generate Bezier curve points between start and end.
    Two random control points create natural-looking curved paths.
    """
    cp1 = (
        random.uniform(min(start[0], end[0]), max(start[0], end[0])),
        random.uniform(min(start[1], end[1]), max(start[1], end[1])),
    )
    cp2 = (
        random.uniform(min(start[0], end[0]), max(start[0], end[0])),
        random.uniform(min(start[1], end[1]), max(start[1], end[1])),
    )

    points = []
    for t in [i / steps for i in range(steps + 1)]:
        x = ((1-t)**3 * start[0] +
             3 * (1-t)**2 * t * cp1[0] +
             3 * (1-t) * t**2 * cp2[0] +
             t**3 * end[0])
        y = ((1-t)**3 * start[1] +
             3 * (1-t)**2 * t * cp1[1] +
             3 * (1-t) * t**2 * cp2[1] +
             t**3 * end[1])
        points.append((x, y))

    return points


class HumanBehavior:
    """Simulate human-like mouse movement, clicks, and scrolling."""

    def __init__(self, page: Page):
        self.page = page
        self._current_x = 400
        self._current_y = 300

    async def move_to(self, x: float, y: float):
        """Move mouse to (x, y) via Bezier curve."""
        points = bezier_curve((self._current_x, self._current_y), (x, y))
        for px, py in points:
            await self.page.mouse.move(px, py)
            await asyncio.sleep(random.uniform(0.005, 0.015))
        self._current_x, self._current_y = x, y

    async def click(self, selector: str):
        """Click an element with human-like approach and timing."""
        element = await self.page.wait_for_selector(selector, timeout=10_000)
        box = await element.bounding_box()

        target_x = box["x"] + box["width"] * random.uniform(0.3, 0.7)
        target_y = box["y"] + box["height"] * random.uniform(0.3, 0.7)

        await self.move_to(target_x, target_y)
        await asyncio.sleep(random.uniform(0.05, 0.15))

        click_delay = random.randint(80, 200)  # ms button hold
        await self.page.mouse.click(target_x, target_y, delay=click_delay)

    async def scroll_to(self, target_y: float):
        """Scroll gradually toward target Y position."""
        current_y = await self.page.evaluate("window.scrollY")
        distance = target_y - current_y
        steps = max(5, int(abs(distance) / 200))

        for i in range(steps):
            delta = distance / steps * random.uniform(0.8, 1.2)
            await self.page.mouse.wheel(0, delta)
            await asyncio.sleep(random.uniform(0.05, 0.12))

    async def human_type(self, selector: str, text: str):
        """Type text with human-like speed."""
        await self.click(selector)
        for char in text:
            await self.page.keyboard.type(char, delay=random.randint(60, 180))
            if random.random() < 0.02:
                await self.page.keyboard.press("Backspace")
                await asyncio.sleep(random.uniform(0.1, 0.3))
                await self.page.keyboard.type(char, delay=random.randint(60, 180))
```

### 3. Proxy Rotation with Session Persistence

```python
# src/scraper/proxy_rotator.py
import random
import time
from dataclasses import dataclass, field

@dataclass
class ProxySession:
    server: str
    username: str
    password: str
    created_at: float = field(default_factory=time.time)
    requests: int = 0
    failures: int = 0

    @property
    def is_expired(self) -> bool:
        return (time.time() - self.created_at) > 600  # Rotate after 10 min

    @property
    def playwright_dict(self) -> dict:
        return {"server": self.server, "username": self.username, "password": self.password}


class ProxyRotator:
    """
    Keep the same proxy IP for a session until it expires or fails.
    Residential proxies required — datacenter IPs are typically blocked.
    """

    def __init__(self, proxy_list: list[dict]):
        self.proxies = proxy_list
        self._sessions: dict[str, ProxySession] = {}
        self._blacklist: set[str] = set()

    def get_proxy(self, session_key: str = "default") -> ProxySession:
        if session_key in self._sessions:
            session = self._sessions[session_key]
            if not session.is_expired and session.failures < 3:
                return session

        available = [p for p in self.proxies if p["server"] not in self._blacklist]
        if not available:
            self._blacklist.clear()
            available = self.proxies

        session = ProxySession(**random.choice(available))
        self._sessions[session_key] = session
        return session

    def report_failure(self, session_key: str):
        if session_key in self._sessions:
            self._sessions[session_key].failures += 1
            if self._sessions[session_key].failures >= 3:
                self._blacklist.add(self._sessions[session_key].server)
                del self._sessions[session_key]

    def report_success(self, session_key: str):
        if session_key in self._sessions:
            self._sessions[session_key].requests += 1
```

## Key Commands Reference

```bash
# Install
pip install playwright playwright-stealth httpx
playwright install chromium

# Test stealth effectiveness
python -c "
import asyncio
from playwright.async_api import async_playwright
from playwright_stealth import stealth_async

async def test():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await stealth_async(page)
        await page.goto('https://bot.sannysoft.com')
        await page.screenshot(path='stealth_test.png')
        await browser.close()

asyncio.run(test())
"

# Check proxy connectivity
curl --proxy http://user:pass@proxy-ip:port http://httpbin.org/ip

# Verify stealth: navigate to https://pixelscan.net/
# Look for: navigator.webdriver=false, consistent timezone/locale/UA
```

## Common Patterns

### Pattern 1: CAPTCHA Solving Integration

```python
# src/scraper/captcha_solver.py
# 2captcha API: ~$2.99/1000 reCAPTCHA v2 solves, 20-60s solve time
import httpx
import asyncio
import time

class TwoCaptchaSolver:
    BASE_URL = "https://2captcha.com"

    def __init__(self, api_key: str):
        self.api_key = api_key

    async def solve_recaptcha_v2(
        self,
        site_key: str,
        page_url: str,
        timeout: int = 120,
    ) -> str:
        """Returns g-recaptcha-response token to inject into the form."""
        async with httpx.AsyncClient() as client:
            # Submit task
            resp = await client.post(f"{self.BASE_URL}/in.php", data={
                "key": self.api_key,
                "method": "userrecaptcha",
                "googlekey": site_key,
                "pageurl": page_url,
                "json": 1,
            })
            result = resp.json()
            if result["status"] != 1:
                raise RuntimeError(f"2captcha error: {result}")
            task_id = result["request"]

            # Poll for result
            start = time.time()
            while time.time() - start < timeout:
                await asyncio.sleep(15)
                poll = (await client.get(f"{self.BASE_URL}/res.php", params={
                    "key": self.api_key, "action": "get", "id": task_id, "json": 1,
                })).json()
                if poll["status"] == 1:
                    return poll["request"]
                if poll["request"] != "CAPCHA_NOT_READY":
                    raise RuntimeError(f"2captcha error: {poll}")

        raise TimeoutError(f"CAPTCHA not solved within {timeout}s")

    async def inject_token(self, page, token: str):
        await page.evaluate(f"""
            document.getElementById('g-recaptcha-response').innerHTML = '{token}';
            ___grecaptcha_cfg.clients[0].K.K.callback('{token}');
        """)
```

### Pattern 2: Human-Like Rate Limiting

```python
# src/scraper/rate_limiter.py
import asyncio
import random

class HumanLikeRateLimiter:
    """
    Simulate human browsing pace — bursts, reading pauses, normal navigation.
    Not uniform intervals — uniform timing is a bot signal.
    """

    def __init__(
        self,
        min_delay: float = 1.5,
        max_delay: float = 4.0,
        burst_prob: float = 0.15,   # 15% chance of quick follow-up
        reading_prob: float = 0.20, # 20% chance of long reading pause
    ):
        self.min_delay = min_delay
        self.max_delay = max_delay
        self.burst_prob = burst_prob
        self.reading_prob = reading_prob

    async def wait(self):
        r = random.random()
        if r < self.burst_prob:
            delay = random.uniform(0.3, 0.8)         # Burst
        elif r < self.burst_prob + self.reading_prob:
            delay = random.uniform(5.0, 15.0)        # Reading pause
        else:
            delay = random.uniform(self.min_delay, self.max_delay)  # Normal

        jitter = delay * random.uniform(-0.1, 0.1)
        await asyncio.sleep(delay + jitter)
```

### Pattern 3: Full Anti-Detection Session

```python
async def scrape_with_anti_detection(
    url: str,
    proxy_rotator: ProxyRotator,
    captcha_solver: TwoCaptchaSolver | None = None,
    session_key: str = "default",
) -> str:
    proxy_session = proxy_rotator.get_proxy(session_key)
    rate_limiter = HumanLikeRateLimiter()

    playwright, browser, context, page = await create_stealth_context(
        proxy=proxy_session.playwright_dict,
    )
    human = HumanBehavior(page)

    try:
        await rate_limiter.wait()
        response = await page.goto(url, wait_until="networkidle", timeout=30_000)

        if response.status == 429:
            proxy_rotator.report_failure(session_key)
            raise RuntimeError(f"Rate limited on {url}")

        # Check for CAPTCHA
        if await page.query_selector('[class*="captcha"]') and captcha_solver:
            site_key = await page.get_attribute('[data-sitekey]', 'data-sitekey')
            token = await captcha_solver.solve_recaptcha_v2(site_key, url)
            await captcha_solver.inject_token(page, token)
            await rate_limiter.wait()

        await human.scroll_to(500)
        await asyncio.sleep(random.uniform(0.5, 1.5))

        content = await page.content()
        proxy_rotator.report_success(session_key)
        return content

    except Exception:
        proxy_rotator.report_failure(session_key)
        raise
    finally:
        await browser.close()
        await playwright.stop()
```

## Pitfalls to Avoid

1. **Using datacenter IPs instead of residential proxies**: Datacenter IP ranges (AWS, GCP, Hetzner, OVH) are catalogued in IP reputation databases and blocked by Cloudflare, Akamai, and PerimeterX regardless of your browser fingerprint. Use residential proxies (Brightdata, Oxylabs, Smartproxy) for production scraping — they use real ISP IP addresses. Datacenter IPs are 10x cheaper but have near-zero success rates on modern anti-bot systems.

2. **Inconsistent fingerprint signals across detection vectors**: Stealth patches navigator.webdriver to false, but if your User-Agent says Windows and your canvas fingerprint shows Linux rendering, or your timezone is UTC and your geolocation is New York, the inconsistency triggers detection. All fingerprint signals must be internally consistent: User-Agent OS = typical screen resolution for that OS = timezone = geolocation = language headers = WebGL vendor string.

3. **Uniform request timing patterns**: Scraping 1,000 pages with exactly 2.0s between each request is statistically impossible for a human. Bot detection systems analyze timing distributions — a perfectly uniform delay is an immediate signal. Use random delays from a distribution that matches human variance (log-normal works well), include occasional bursts (0.3-0.8s) and reading pauses (5-15s), and vary the distribution based on page type.

## Related Skills

- `web-scraping-pipeline` — End-to-end scraping pipeline architecture and storage
- `playwright` — Playwright API patterns and selectors
- `firecrawl` — Managed scraping service (no anti-detection needed)
- `async-python-patterns` — Asyncio patterns for concurrent scraping

## GitNexus Index

```json
{
  "skill": "webscraping-anti-detection",
  "category": "infrastructure",
  "triggers": ["web scraping anti-detection", "Playwright stealth", "proxy rotation scraping", "CAPTCHA solving", "bot detection bypass", "human-like mouse movement", "Bezier curve scraping", "fingerprint spoofing", "2captcha integration", "residential proxy", "rate limiting scraping"],
  "outputs": ["create_stealth_context()", "HumanBehavior", "bezier_curve()", "ProxyRotator", "TwoCaptchaSolver", "HumanLikeRateLimiter", "scrape_with_anti_detection()", "stealth_async()"],
  "complexity": "high",
  "tools": ["python", "playwright", "playwright-stealth", "2captcha", "asyncio", "httpx"]
}
```
