---
name: pytest-asyncio
version: 1.0.0
description: Test Python async/await code with pytest-asyncio — native coroutine tests, async fixtures, and event loop configuration
tools: [Bash, Read, Write, Edit]
category: testing
tags: [pytest, asyncio, python, async, await, fastapi, aiohttp, testing]
author: claude-skill-vault
created: 2026-05-24
---

# pytest-asyncio — Async Python Testing

## Overview

pytest-asyncio is a pytest plugin that makes it simple to test Python `async def` functions. It handles the event loop lifecycle, async fixtures, and async context managers. Works with any async framework: FastAPI, aiohttp, SQLAlchemy async, asyncpg, and more.

## When to Use

- Testing FastAPI, aiohttp, Starlette, or any async web application
- Testing async database queries (asyncpg, SQLAlchemy async, Motor)
- Testing async message consumers (Kafka, RabbitMQ via aio-pika)
- Any code that uses `async def` / `await` and needs pytest coverage
- Replacing `asyncio.run()` boilerplate in every test function

## Installation

```bash
pip install pytest-asyncio

# For FastAPI testing (includes httpx async client)
pip install pytest-asyncio httpx

# For async SQLAlchemy
pip install pytest-asyncio sqlalchemy[asyncio] asyncpg

# Verify
pytest --version
python -c "import pytest_asyncio; print(pytest_asyncio.__version__)"
```

## Key Patterns

### Configure pytest (pyproject.toml)

```toml
# pyproject.toml
[tool.pytest.ini_options]
asyncio_mode = "auto"           # all async tests run automatically, no @pytest.mark.asyncio needed
asyncio_default_fixture_loop_scope = "session"

[tool.pytest.ini_options.markers]
integration = "marks tests as integration tests (require DB/network)"
```

### Basic async test

```python
# tests/test_user_service.py
import pytest
from myapp.services.user_service import UserService

# With asyncio_mode = "auto" (recommended), no decorator needed
async def test_get_user_returns_user():
    service = UserService()
    user = await service.get_user(42)
    assert user.id == 42
    assert user.name == "Alice"

# Without asyncio_mode = "auto", use the marker explicitly
@pytest.mark.asyncio
async def test_create_user():
    service = UserService()
    user = await service.create_user("Bob", "bob@example.com")
    assert user.email == "bob@example.com"
```

### Async fixtures

```python
# tests/conftest.py
import pytest_asyncio
import asyncpg

@pytest_asyncio.fixture(scope="session")
async def db_pool():
    """Create a connection pool once for all tests."""
    pool = await asyncpg.create_pool(
        host="localhost",
        database="testdb",
        user="test",
        password="test",
        min_size=2,
        max_size=10,
    )
    yield pool
    await pool.close()

@pytest_asyncio.fixture(scope="function")
async def db_conn(db_pool):
    """Provide a transactional connection; rollback after each test."""
    async with db_pool.acquire() as conn:
        tr = conn.transaction()
        await tr.start()
        yield conn
        await tr.rollback()  # clean up — no data persists between tests
```

### FastAPI async tests with httpx

```python
# tests/test_api.py
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from myapp.main import app

@pytest_asyncio.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test"
    ) as ac:
        yield ac

async def test_get_user_endpoint(client):
    response = await client.get("/users/1")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == 1

async def test_create_user_endpoint(client):
    response = await client.post(
        "/users",
        json={"name": "Alice", "email": "alice@example.com"},
    )
    assert response.status_code == 201
    assert response.json()["name"] == "Alice"

async def test_auth_required(client):
    response = await client.get("/users/me")
    assert response.status_code == 401
```

### Testing async context managers and generators

```python
# tests/test_cache.py
import pytest_asyncio
from myapp.cache import RedisCache

@pytest_asyncio.fixture
async def cache():
    async with RedisCache("redis://localhost") as cache:
        yield cache

async def test_set_and_get(cache):
    await cache.set("key", "value", ttl=60)
    result = await cache.get("key")
    assert result == "value"

async def test_cache_miss(cache):
    result = await cache.get("nonexistent-key")
    assert result is None
```

### Mocking async dependencies

```python
# tests/test_email_service.py
from unittest.mock import AsyncMock, patch
import pytest

async def test_send_welcome_email():
    with patch("myapp.services.email.smtp_client") as mock_smtp:
        mock_smtp.send = AsyncMock(return_value=True)

        from myapp.services.user_service import UserService
        service = UserService()
        await service.register("alice@example.com")

        mock_smtp.send.assert_called_once()
        call_args = mock_smtp.send.call_args
        assert "alice@example.com" in call_args.args[0]["to"]

async def test_external_api_failure():
    with patch("myapp.integrations.payment.charge_card", new_callable=AsyncMock) as mock_charge:
        mock_charge.side_effect = TimeoutError("gateway timeout")

        from myapp.services.order_service import OrderService
        service = OrderService()
        with pytest.raises(TimeoutError):
            await service.place_order(user_id=1, amount=99.99)
```

### Parameterized async tests

```python
# tests/test_validators.py
import pytest
from myapp.validators import validate_email_async

@pytest.mark.parametrize("email,expected", [
    ("alice@example.com", True),
    ("invalid-email", False),
    ("@nodomain.com", False),
    ("user@sub.domain.org", True),
])
async def test_email_validation(email: str, expected: bool):
    result = await validate_email_async(email)
    assert result == expected
```

### Running async tests

```bash
# Run all tests
pytest

# Run only async tests
pytest -k "async"

# Run with verbose output
pytest -v tests/test_api.py

# Run with coverage
pytest --cov=myapp --cov-report=html

# Run integration tests (marked)
pytest -m integration

# Run in parallel (install pytest-xdist)
pytest -n 4
```

## Common Pitfalls

1. **`asyncio_mode = "auto"` vs explicit markers**: Set `asyncio_mode = "auto"` in `pyproject.toml` — it removes the need for `@pytest.mark.asyncio` on every async test function.
2. **Fixture scope and event loops**: If you use `scope="session"` fixtures, set `asyncio_default_fixture_loop_scope = "session"` in config too, or pytest-asyncio will warn about loop scope mismatch.
3. **`AsyncMock` for async callables**: Use `unittest.mock.AsyncMock` (Python 3.8+) for mocking coroutines — `MagicMock` does not support `await`.
4. **Database transactions in fixtures**: Wrap DB connections in a transaction and rollback after each test (not `TRUNCATE`) — rollback is faster and atomic.
5. **`pytest_asyncio.fixture` vs `pytest.fixture`**: Use `@pytest_asyncio.fixture` for async fixture functions; use `@pytest.fixture` for sync fixtures. Mixing these causes confusing errors.

## Related Skills

- hypothesis-property-testing — property-based testing for Python (works with pytest-asyncio)
- fastapi-expert — FastAPI patterns that pair with this async testing approach
- testcontainers-integration — real database containers for async integration tests

## GitNexus Index

```
domain: testing
maturity: stable
complexity: low-medium
language: python
frameworks: fastapi, aiohttp, starlette, asyncpg, sqlalchemy-async
config-file: pyproject.toml ([tool.pytest.ini_options])
asyncio_mode: auto (recommended)
```
