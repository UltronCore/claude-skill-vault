---
name: testcontainers-integration
version: 1.0.0
description: Run integration tests against real databases, message brokers, and services using Docker containers managed by Testcontainers
tools: [Bash, Read, Write, Edit]
category: testing
tags: [testcontainers, integration-testing, docker, postgres, redis, kafka, java, python, go]
author: claude-skill-vault
created: 2026-05-24
---

# Testcontainers — Real Dependencies for Integration Tests

## Overview

Testcontainers is a library that starts real Docker containers (PostgreSQL, Redis, Kafka, etc.) as part of your test setup and tears them down when tests finish. Unlike mocks or in-memory alternatives, Testcontainers lets you test against the exact same database engine or message broker version you use in production.

## When to Use

- Integration tests that need a real database (not H2/SQLite in-memory approximation)
- Testing SQL features, JSON operators, or extensions specific to PostgreSQL/MySQL/etc.
- Testing Kafka consumers/producers with real partition and offset semantics
- Ensuring compatibility with the exact Docker image version used in production
- Replacing fragile shared dev/staging databases in CI

## Installation

```bash
# Java / Kotlin (Maven)
# Add to pom.xml — BOM manages all module versions
# <dependency>
#   <groupId>org.testcontainers</groupId>
#   <artifactId>testcontainers-bom</artifactId>
#   <version>1.20.4</version>
#   <type>pom</type>
#   <scope>import</scope>
# </dependency>

# Python
pip install testcontainers

# Go
go get github.com/testcontainers/testcontainers-go

# Node.js
npm install --save-dev testcontainers
```

## Key Patterns

### Java: PostgreSQL with JUnit 5

```java
// src/test/java/com/example/UserRepositoryTest.java
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;

import static org.assertj.core.api.Assertions.assertThat;

@Testcontainers  // Manages container lifecycle via JUnit 5 extension
class UserRepositoryTest {

  // Static: one container shared across all tests in the class
  @Container
  static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
      .withDatabaseName("testdb")
      .withUsername("test")
      .withPassword("test")
      .withInitScript("schema.sql");  // runs schema.sql from test/resources

  private UserRepository repo;

  @BeforeAll
  static void setupDataSource() {
    // Testcontainers provides the mapped port automatically
    System.setProperty("DB_URL", postgres.getJdbcUrl());
    System.setProperty("DB_USER", postgres.getUsername());
    System.setProperty("DB_PASS", postgres.getPassword());
  }

  @Test
  void shouldFindUserById() throws Exception {
    try (Connection conn = DriverManager.getConnection(
        postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {

      conn.prepareStatement(
          "INSERT INTO users (id, name, email) VALUES (1, 'Alice', 'alice@example.com')"
      ).execute();

      ResultSet rs = conn.prepareStatement("SELECT name FROM users WHERE id = 1").executeQuery();
      assertThat(rs.next()).isTrue();
      assertThat(rs.getString("name")).isEqualTo("Alice");
    }
  }
}
```

### Java: Kafka producer + consumer test

```java
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.testcontainers.containers.KafkaContainer;
import org.testcontainers.utility.DockerImageName;

@Testcontainers
class OrderEventTest {

  @Container
  static KafkaContainer kafka = new KafkaContainer(
      DockerImageName.parse("confluentinc/cp-kafka:7.6.1")
  );

  @Test
  void shouldPublishAndConsumeOrderEvent() {
    String bootstrapServers = kafka.getBootstrapServers();

    // Produce
    OrderEvent event = new OrderEvent("order-123", "PLACED");
    OrderProducer producer = new OrderProducer(bootstrapServers);
    producer.send(event);

    // Consume
    OrderConsumer consumer = new OrderConsumer(bootstrapServers, "test-group");
    List<ConsumerRecord<String, OrderEvent>> records = consumer.pollFor(5, TimeUnit.SECONDS);

    assertThat(records).hasSize(1);
    assertThat(records.get(0).value().orderId()).isEqualTo("order-123");
  }
}
```

### Python: PostgreSQL with pytest

```python
# tests/conftest.py
import pytest
from testcontainers.postgres import PostgresContainer
import psycopg2

@pytest.fixture(scope="session")
def postgres():
    """Start a PostgreSQL container for the whole test session."""
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg

@pytest.fixture(scope="session")
def db_conn(postgres):
    conn = psycopg2.connect(postgres.get_connection_url())
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE users (
                id SERIAL PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT UNIQUE NOT NULL
            )
        """)
    conn.commit()
    yield conn
    conn.close()

# tests/test_user_repo.py
def test_insert_and_fetch_user(db_conn):
    with db_conn.cursor() as cur:
        cur.execute("INSERT INTO users (name, email) VALUES (%s, %s)", ("Alice", "alice@example.com"))
        db_conn.commit()
        cur.execute("SELECT name FROM users WHERE email = %s", ("alice@example.com",))
        row = cur.fetchone()
    assert row[0] == "Alice"
```

### Go: PostgreSQL with testcontainers-go

```go
// user_repo_test.go
package repo_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"
    "github.com/testcontainers/testcontainers-go/wait"
)

func TestUserRepository(t *testing.T) {
    ctx := context.Background()

    pgContainer, err := postgres.RunContainer(ctx,
        testcontainers.WithImage("postgres:16-alpine"),
        postgres.WithDatabase("testdb"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
        testcontainers.WithWaitStrategy(
            wait.ForLog("database system is ready to accept connections").
                WithOccurrence(2),
        ),
    )
    if err != nil {
        t.Fatal(err)
    }
    t.Cleanup(func() { pgContainer.Terminate(ctx) })

    connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
    assert.NoError(t, err)

    repo := NewUserRepository(connStr)
    err = repo.CreateUser(ctx, "Alice", "alice@example.com")
    assert.NoError(t, err)

    user, err := repo.GetUserByEmail(ctx, "alice@example.com")
    assert.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
}
```

### GitHub Actions CI (Docker-in-Docker)

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: 21 }
      - name: Run integration tests
        run: mvn test -Dtest=*IntegrationTest
        # Docker is available on GitHub-hosted ubuntu runners by default
        # Testcontainers pulls images automatically
```

## Common Pitfalls

1. **Docker not running locally**: Testcontainers requires Docker Desktop (macOS/Windows) or Docker Engine (Linux). Colima is also supported.
2. **Slow test startup**: Use `@Container` on a `static` field (JUnit 5) so the container is shared across all tests in the class, not restarted per test.
3. **Port collisions**: Never hardcode ports — use `container.getMappedPort(5432)` to get the dynamically assigned host port.
4. **Image pull in CI**: First CI run pulls Docker images. Use GitHub Actions cache or pre-pull images to avoid timeout.
5. **Ryuk (resource reaper)**: Testcontainers uses Ryuk to clean up orphaned containers. If Ryuk is blocked by your container runtime, set `TESTCONTAINERS_RYUK_DISABLED=true`.

## Related Skills

- vitest-testing — unit tests for non-integration logic
- msw-api-mocking — mock external HTTP APIs (complement Testcontainers for DB-level tests)
- pact-contract-testing — contract tests for services that talk to each other

## GitNexus Index

```
domain: testing
maturity: stable
complexity: medium
language: java, kotlin, python, go, node.js
requires: docker
containers: postgres, mysql, redis, kafka, mongodb, elasticsearch, localstack
config-file: pom.xml / build.gradle / pyproject.toml / go.mod
```
