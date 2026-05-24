---
name: webscraping-anti-detection-security-stub
description: Implement anti-detection techniques for web scraping — browser fingerprint spoofing, rate limiting, proxy rotation, CAPTCHA handling, and stealth browser patterns — while operating within ethical and legal boundaries.
tags: [web-scraping, anti-detection, playwright, puppeteer, proxies]
version: 1.0.0
---

## Overview

Modern anti-bot systems (Cloudflare, DataDome, PerimeterX, Akamai Bot Manager) detect scrapers through fingerprinting, behavioral analysis, and traffic patterns. This skill covers the techniques to appear as a legitimate browser — and when to use managed services instead.

## When to Use

- Scraping public data that blocks automated requests
- Debugging why a scraper is getting blocked or CAPTCHAs
- Building a resilient production pipeline that survives anti-bot updates
- Choosing between DIY stealth, Playwright/Puppeteer plugins, or managed services (Firecrawl, ScrapingBee, Apify)

**Ethical boundary**: only scrape public data, respect `robots.txt`, don't bypass authentication walls, and check ToS before building.

## Browser Fingerprint Hardening

Anti-bot systems collect 50+ signals. The most detectable:

```javascript
// Playwright with playwright-extra + stealth plugin
import { chromium } from 'playwright-extra';
import StealthPlugin from 'puppeteer-extra-plugin-stealth';

chromium.use(StealthPlugin());

const browser = await chromium.launch({
  headless: true,    // stealth plugin patches headless detection
  args: [
    '--disable-blink-features=AutomationControlled',
    '--disable-dev-shm-usage',
    '--no-sandbox',
  ],
});

const page = await browser.newPage();

// Set realistic viewport + user agent (match actual device)
await page.setViewportSize({ width: 1440, height: 900 });
await page.setExtraHTTPHeaders({
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate, br',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
  'Sec-Fetch-Dest': 'document',
  'Sec-Fetch-Mode': 'navigate',
  'Sec-Fetch-Site': 'none',
  'Upgrade-Insecure-Requests': '1',
});
```

Key fingerprint signals to mask:

| Signal | Detection method | Countermeasure |
|--------|-----------------|----------------|
| `navigator.webdriver` | JS property check | Stealth plugin overrides to `undefined` |
| Chrome DevTools Protocol | `window.cdc_*` globals | Stealth plugin removes them |
| Canvas fingerprint | `canvas.toDataURL()` | Add slight canvas noise |
| WebGL renderer | GPU string | Spoof to common GPU |
| Screen resolution | `window.screen` | Match viewport exactly |
| Plugin list | `navigator.plugins` | Mock realistic plugin array |
| Timezone | `Intl.DateTimeFormat()` | Match proxy geolocation |

## Behavioral Mimicry

Bots move instantly and scroll perfectly. Real users are irregular.

```javascript
// Human-like delays between actions
const humanDelay = (min = 500, max = 2000) =>
  new Promise(r => setTimeout(r, Math.random() * (max - min) + min));

// Mouse movement before clicking (avoids "no mouse movement" signal)
async function humanClick(page, selector) {
  const element = await page.$(selector);
  const box = await element.boundingBox();
  
  // Move to element gradually
  await page.mouse.move(
    box.x + box.width * 0.5 + (Math.random() - 0.5) * 10,
    box.y + box.height * 0.5 + (Math.random() - 0.5) * 10,
    { steps: 10 + Math.floor(Math.random() * 20) }
  );
  await humanDelay(100, 300);
  await page.mouse.click(
    box.x + box.width * 0.5,
    box.y + box.height * 0.5
  );
}

// Human-like typing (variable WPM, occasional typos)
async function humanType(page, selector, text) {
  await page.click(selector);
  for (const char of text) {
    await page.keyboard.type(char);
    await humanDelay(50, 150);
  }
}

// Realistic scroll behavior
async function humanScroll(page, scrollAmount = 800) {
  await page.evaluate(async (amount) => {
    await new Promise(resolve => {
      let scrolled = 0;
      const step = () => {
        const increment = Math.random() * 100 + 20;
        window.scrollBy(0, increment);
        scrolled += increment;
        if (scrolled < amount) setTimeout(step, Math.random() * 50 + 20);
        else resolve();
      };
      step();
    });
  }, scrollAmount);
}
```

## Proxy Rotation

```python
import random
import requests
from itertools import cycle

class ProxyRotator:
    def __init__(self, proxies: list[str]):
        """
        proxies: list of "http://user:pass@host:port" strings
        """
        self._pool = cycle(proxies)
        self._current = None
        self._fail_counts: dict[str, int] = {}
        self._max_fails = 3

    def get(self) -> str:
        proxy = next(self._pool)
        # Skip proxies that have failed too many times
        while self._fail_counts.get(proxy, 0) >= self._max_fails:
            proxy = next(self._pool)
        self._current = proxy
        return proxy

    def report_failure(self, proxy: str):
        self._fail_counts[proxy] = self._fail_counts.get(proxy, 0) + 1

    def make_request(self, url: str, **kwargs) -> requests.Response:
        proxy = self.get()
        proxies = {"http": proxy, "https": proxy}
        try:
            response = requests.get(url, proxies=proxies, timeout=15, **kwargs)
            response.raise_for_status()
            return response
        except Exception:
            self.report_failure(proxy)
            raise

# Proxy providers: Bright Data, Oxylabs, IPRoyal, Smartproxy
# Residential > Datacenter for avoiding blocks (but 10x more expensive)
```

## Rate Limiting and Request Spacing

```python
import time
import random
from dataclasses import dataclass

@dataclass
class RateLimiter:
    min_delay: float = 1.0    # seconds between requests to same domain
    max_delay: float = 5.0
    burst_limit: int = 10     # max requests before forced long pause
    burst_delay: float = 30.0

    def __post_init__(self):
        self._request_count = 0

    def wait(self):
        self._request_count += 1
        if self._request_count % self.burst_limit == 0:
            # Occasional long pause mimics human taking a break
            time.sleep(self.burst_delay + random.uniform(-5, 10))
        else:
            time.sleep(random.uniform(self.min_delay, self.max_delay))
```

**Domain-specific guidance:**
- News/media sites: 2-5s delay, max 100 req/hour
- E-commerce: 1-3s delay, rotate user agents per session
- Social platforms: don't — they have aggressive legal teams and bot detection
- APIs with rate limits: always honor `Retry-After` headers

## CAPTCHA Handling

```python
# Option 1: 2captcha API (cheapest, human-solved)
import requests

def solve_recaptcha_v2(site_key: str, page_url: str, api_key: str) -> str:
    # Submit
    resp = requests.post("http://2captcha.com/in.php", data={
        "key": api_key,
        "method": "userrecaptcha",
        "googlekey": site_key,
        "pageurl": page_url,
        "json": 1
    }).json()
    task_id = resp["request"]

    # Poll for result (typically 15-30 seconds)
    for _ in range(20):
        time.sleep(5)
        result = requests.get(
            f"http://2captcha.com/res.php?key={api_key}&action=get&id={task_id}&json=1"
        ).json()
        if result["status"] == 1:
            return result["request"]  # token to inject
    raise TimeoutError("CAPTCHA solving timed out")

# Option 2: Inject solved token into page
await page.evaluate(f"""
    document.getElementById('g-recaptcha-response').innerHTML = '{token}';
    ___grecaptcha_cfg.clients[0].aa.l.click();
""")
```

**When to use managed services instead:**
- Budget exists: Firecrawl, Apify, ScrapingBee handle all anti-detection automatically
- You're scraping Cloudflare-protected sites: DIY is very hard; managed services maintain their own fingerprint pools
- You need JavaScript rendering at scale: headless browsers are expensive to operate

## Session Management

```python
class SessionManager:
    """Maintain cookie jars and session state per target domain."""

    def __init__(self):
        self._sessions: dict[str, requests.Session] = {}

    def get_session(self, domain: str, proxy: str | None = None) -> requests.Session:
        if domain not in self._sessions:
            session = requests.Session()
            session.headers.update({
                "User-Agent": self._random_ua(),
                "Accept-Language": "en-US,en;q=0.9",
            })
            if proxy:
                session.proxies = {"http": proxy, "https": proxy}
            # Warm up the session (visit homepage first)
            session.get(f"https://{domain}", timeout=10)
            self._sessions[domain] = session
        return self._sessions[domain]

    def _random_ua(self) -> str:
        uas = [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        ]
        return random.choice(uas)
```

## Anti-Detection Checklist

- [ ] Use playwright-extra with stealth plugin (removes all CDP artifacts)
- [ ] Set realistic viewport and UA matching real Chrome version
- [ ] Add human-like delays between actions (500ms-3s, randomized)
- [ ] Use residential proxies for geo-restricted or high-protection targets
- [ ] Warm sessions by visiting homepage before deep scraping
- [ ] Respect Retry-After headers; back off on 429/503
- [ ] Rotate user agents from current Chrome/Firefox versions only
- [ ] Match Accept-Language and timezone to proxy geolocation
- [ ] Never reuse browser fingerprint across different target domains

## Related Skills

- `web-scraping-pipeline` — end-to-end pipeline architecture and data storage
- `firecrawl` — managed scraping service (handles anti-detection automatically)
- `playwright` — Playwright fundamentals and test automation
