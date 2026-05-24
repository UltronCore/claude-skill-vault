---
name: mockery-go-mocking
version: 1.0.0
description: Generate type-safe interface mocks for Go tests with Mockery — no hand-written boilerplate, full testify integration
tools: [Bash, Read, Write, Edit]
category: testing
tags: [mockery, go, golang, mocking, testify, interfaces, unit-testing, codegen]
author: claude-skill-vault
created: 2026-05-24
---

# Mockery — Go Interface Mock Generation

## Overview

Mockery is a mock generator for Go that automatically generates mock implementations of interfaces using `testify/mock`. Instead of writing verbose mock structs by hand, you annotate interfaces with a `//go:generate mockery` comment and run `go generate`. The result is a fully type-safe mock that integrates with testify assertions.

## When to Use

- Unit testing Go code that depends on interfaces (repositories, HTTP clients, services)
- Replacing real implementations with controlled doubles in tests
- Verifying that methods were called with specific arguments
- Setting up expected return values and errors in service-layer tests
- Avoiding network/database calls in fast unit tests

## Installation

```bash
# Install mockery CLI
go install github.com/vektra/mockery/v2@latest

# Or with Homebrew
brew install mockery

# Add to go.mod (for go generate)
# mockery is a dev tool — invoke via go generate, not imported as a package

# Verify
mockery --version
```

## Key Patterns

### Configure mockery (.mockery.yaml)

```yaml
# .mockery.yaml (project root)
with-expecter: true        # generate type-safe Expecter helpers
mockname: "Mock{{.InterfaceName}}"
filename: "mock_{{.InterfaceName | snakecase}}.go"
outpkg: mocks
dir: "{{.InterfaceDir}}/mocks"
packages:
  github.com/myorg/myapp/internal/repo:
    interfaces:
      UserRepository:
  github.com/myorg/myapp/internal/services:
    interfaces:
      EmailService:
      PaymentService:
```

### Annotate interfaces for generation

```go
// internal/repo/user_repository.go
package repo

//go:generate mockery --name=UserRepository
type UserRepository interface {
    GetByID(ctx context.Context, id int64) (*User, error)
    Save(ctx context.Context, user *User) error
    Delete(ctx context.Context, id int64) error
    ListActive(ctx context.Context) ([]*User, error)
}
```

```bash
# Generate mocks (run from project root)
go generate ./...

# Or run mockery directly
mockery --config .mockery.yaml
```

### Use mocks in tests (with Expecter — recommended)

```go
// internal/services/user_service_test.go
package services_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/myorg/myapp/internal/repo/mocks"
    "github.com/myorg/myapp/internal/services"
)

func TestUserService_GetUser_Success(t *testing.T) {
    ctx := context.Background()

    // Create mock
    mockRepo := mocks.NewMockUserRepository(t)

    // Set expectation using type-safe Expecter
    mockRepo.EXPECT().
        GetByID(ctx, int64(42)).
        Return(&repo.User{ID: 42, Name: "Alice", Email: "alice@example.com"}, nil).
        Once()

    // Inject mock into service
    svc := services.NewUserService(mockRepo)

    // Execute
    user, err := svc.GetUser(ctx, 42)

    // Assert
    assert.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
    // mockRepo.AssertExpectations is called automatically when t is passed to NewMock
}

func TestUserService_GetUser_NotFound(t *testing.T) {
    ctx := context.Background()
    mockRepo := mocks.NewMockUserRepository(t)

    mockRepo.EXPECT().
        GetByID(ctx, int64(99)).
        Return(nil, repo.ErrNotFound).
        Once()

    svc := services.NewUserService(mockRepo)
    _, err := svc.GetUser(ctx, 99)

    assert.ErrorIs(t, err, services.ErrUserNotFound)
}
```

### Match any argument with matchers

```go
import "github.com/stretchr/testify/mock"

func TestUserService_Save_AnyUser(t *testing.T) {
    ctx := context.Background()
    mockRepo := mocks.NewMockUserRepository(t)

    // Match any *repo.User argument
    mockRepo.EXPECT().
        Save(ctx, mock.AnythingOfType("*repo.User")).
        Return(nil).
        Once()

    svc := services.NewUserService(mockRepo)
    err := svc.CreateUser(ctx, "Bob", "bob@example.com")
    assert.NoError(t, err)
}
```

### Multiple calls and call ordering

```go
func TestEmailService_SendWelcomeAndFollowUp(t *testing.T) {
    mockEmail := mocks.NewMockEmailService(t)

    // Expect 2 calls in order
    call1 := mockEmail.EXPECT().
        SendEmail(mock.Anything, "welcome", mock.Anything).
        Return(nil).Once()

    mockEmail.EXPECT().
        SendEmail(mock.Anything, "follow-up", mock.Anything).
        Return(nil).Once().
        NotBefore(call1)  // must be called after call1

    svc := services.NewOnboardingService(mockEmail)
    err := svc.OnboardUser(context.Background(), "alice@example.com")
    assert.NoError(t, err)
}
```

### Mock returning a function (dynamic responses)

```go
func TestRetryOnFailure(t *testing.T) {
    mockRepo := mocks.NewMockUserRepository(t)
    callCount := 0

    // Fail first call, succeed second
    mockRepo.EXPECT().
        GetByID(mock.Anything, int64(1)).
        RunAndReturn(func(ctx context.Context, id int64) (*repo.User, error) {
            callCount++
            if callCount == 1 {
                return nil, errors.New("temporary error")
            }
            return &repo.User{ID: 1, Name: "Alice"}, nil
        }).
        Times(2)

    svc := services.NewUserService(mockRepo)
    user, err := svc.GetUserWithRetry(context.Background(), 1)
    assert.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
}
```

### Makefile integration

```makefile
# Makefile
.PHONY: mocks test

mocks:
	go generate ./...

test: mocks
	go test ./... -race -cover

lint:
	golangci-lint run
```

## Common Pitfalls

1. **Pass `t` to `NewMock`**: Using `mocks.NewMockUserRepository(t)` (not `new(mocks.MockUserRepository)`) automatically calls `AssertExpectations(t)` at end of test.
2. **`EXPECT()` vs `On()`**: Prefer the type-safe `EXPECT()` Expecter API — it catches wrong argument types at compile time. `On()` is stringly-typed and error-prone.
3. **Regenerate after interface changes**: Mocks go stale when interfaces change. Add `go generate ./...` to your pre-commit hook or CI.
4. **Commit generated mocks**: Generated mock files should be committed so CI doesn't require mockery installed. Regenerate locally after changes.
5. **Don't mock types you don't own**: Only mock interfaces defined in your own codebase. For third-party types, wrap them in your own interface first.

## Related Skills

- vitest-testing — JavaScript/TypeScript mocking (Vitest's `vi.fn()`)
- testcontainers-integration — when mocks aren't enough and you need a real database
- go-microservices — Go service patterns that pair with mockery testing

## GitNexus Index

```
domain: testing
maturity: stable
complexity: low-medium
language: go
integrates-with: testify/mock, go generate
config-file: .mockery.yaml
output-dir: <package>/mocks/
```
