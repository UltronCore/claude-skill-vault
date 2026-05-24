---
name: gatling-load-testing
version: 1.0.0
description: Write load and performance tests as code with Gatling — high-throughput simulation using Scala, Java, or Kotlin DSL
tools: [Bash, Read, Write, Edit]
category: testing
tags: [gatling, load-testing, performance, simulation, scala, java, kotlin, http]
author: claude-skill-vault
created: 2026-05-24
---

# Gatling — Load Testing as Code

## Overview

Gatling is a load testing tool where tests are written as code (Scala, Java, or Kotlin DSL). It produces detailed HTML reports with latency percentiles, throughput graphs, and error rates. Gatling uses a non-blocking, asynchronous architecture that can simulate thousands of virtual users with minimal resource usage.

## When to Use

- Performance regression testing before releases
- Finding throughput limits and latency percentiles under load
- Simulating realistic user flows (browse → search → checkout)
- Integrating load tests into CI pipelines to catch regressions early
- Comparing performance before and after infrastructure changes

## Installation

```bash
# Option 1: Download bundle (no build tool needed)
# https://gatling.io/open-source/
unzip gatling-charts-highcharts-bundle-*.zip
cd gatling-charts-highcharts-bundle-*/

# Option 2: Maven project
mvn archetype:generate \
  -DarchetypeGroupId=io.gatling.highcharts \
  -DarchetypeArtifactId=gatling-highcharts-maven-archetype \
  -DarchetypeVersion=3.11.5

# Option 3: Gradle
# See Key Patterns → build.gradle section
```

## Key Patterns

### Maven pom.xml

```xml
<dependencies>
  <dependency>
    <groupId>io.gatling.highcharts</groupId>
    <artifactId>gatling-charts-highcharts</artifactId>
    <version>3.11.5</version>
    <scope>test</scope>
  </dependency>
</dependencies>

<build>
  <plugins>
    <plugin>
      <groupId>io.gatling</groupId>
      <artifactId>gatling-maven-plugin</artifactId>
      <version>4.9.6</version>
    </plugin>
  </plugins>
</build>
```

### Simulation in Java (recommended for new projects)

```java
// src/gatling/java/simulations/UserBrowseSimulation.java
package simulations;

import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;

import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

public class UserBrowseSimulation extends Simulation {

  // HTTP config shared by all scenarios
  HttpProtocolBuilder httpProtocol = http
      .baseUrl("https://api.example.com")
      .acceptHeader("application/json")
      .contentTypeHeader("application/json")
      .header("Authorization", "Bearer #{token}");

  // Reusable chain: browse products
  ChainBuilder browseProducts = exec(
      http("List Products")
          .get("/api/products")
          .queryParam("page", "1")
          .check(status().is(200))
          .check(jsonPath("$.items[0].id").saveAs("productId"))
  ).pause(1, 3) // pause 1–3 seconds between requests
  .exec(
      http("Get Product Detail")
          .get("/api/products/#{productId}")
          .check(status().is(200))
  );

  // Reusable chain: add to cart and checkout
  ChainBuilder checkout = exec(
      http("Add to Cart")
          .post("/api/cart")
          .body(StringBody("""
              {"productId": "#{productId}", "quantity": 1}
              """)).asJson()
          .check(status().is(201))
          .check(jsonPath("$.cartId").saveAs("cartId"))
  ).pause(2)
  .exec(
      http("Checkout")
          .post("/api/orders")
          .body(StringBody("""
              {"cartId": "#{cartId}"}
              """)).asJson()
          .check(status().is(201))
  );

  // Scenario: 80% browse, 20% checkout
  ScenarioBuilder users = scenario("Browse and occasionally buy")
      .feed(csv("test-data/users.csv").circular())
      .exec(browseProducts)
      .randomSwitch()
          .on(20.0, exec(checkout));

  {
    setUp(
        users.injectOpen(
            nothingFor(5),                              // warm up pause
            atOnceUsers(10),                            // immediate burst
            rampUsers(50).during(30),                   // ramp to 50 over 30s
            constantUsersPerSec(20).during(60),         // steady state 60s
            rampUsersPerSec(20).to(0).during(10)        // ramp down
        )
    )
    .protocols(httpProtocol)
    .assertions(
        global().responseTime().percentile(95).lt(2000),  // p95 < 2s
        global().successfulRequests().percent().gt(99.0)   // 99% success
    );
  }
}
```

### Feeder (test data CSV)

```csv
// src/gatling/resources/test-data/users.csv
token,userId
abc123,user-1
def456,user-2
ghi789,user-3
```

### Gradle setup

```kotlin
// build.gradle.kts
plugins {
    id("io.gatling.gradle") version "3.11.5.2"
}

dependencies {
    gatling("io.gatling.highcharts:gatling-charts-highcharts:3.11.5")
}
```

### Running tests

```bash
# Maven — run all simulations
mvn gatling:test

# Maven — run a specific simulation
mvn gatling:test -Dgatling.simulationClass=simulations.UserBrowseSimulation

# Gradle
./gradlew gatlingRun

# Standalone bundle
bin/gatling.sh -s simulations.UserBrowseSimulation

# Set target URL via system property
mvn gatling:test -DBASE_URL=https://staging.example.com
```

### GitHub Actions CI

```yaml
# .github/workflows/load-test.yml
name: Load Tests
on:
  schedule:
    - cron: "0 2 * * 1"   # every Monday at 2am
  workflow_dispatch:

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 21
      - name: Run Gatling
        run: mvn gatling:test
        env:
          BASE_URL: ${{ vars.STAGING_URL }}
      - name: Upload report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: gatling-report
          path: target/gatling/**/index.html
```

## Common Pitfalls

1. **Session variables (EL expressions)**: Use `#{varName}` in strings (not `${varName}`) — that's Gatling's Expression Language.
2. **Shared mutable state**: Never use Java variables in `exec()` blocks — they're shared across virtual users. Use session attributes instead.
3. **`pause()` is mandatory**: Without pauses, Gatling simulates an unrealistic hammering pattern. Use `pause(1, 5)` for random pauses.
4. **`circular()` on feeders**: Without `.circular()`, Gatling throws an error when it runs out of test data rows.
5. **Assertions fail the build**: Add `.assertions(...)` to `setUp()` to fail CI when SLAs are not met — without assertions, Gatling always exits 0.

## Related Skills

- load-testing-k6 — JavaScript-based load testing (simpler scripting, good for frontend-heavy flows)
- testcontainers-integration — spin up real services for integration + load test baseline
- playwright — browser-based E2E tests (complement Gatling's HTTP-level tests)

## GitNexus Index

```
domain: testing
maturity: stable
complexity: medium
language: java, scala, kotlin
config-file: pom.xml / build.gradle.kts
report: target/gatling/*/index.html
```
