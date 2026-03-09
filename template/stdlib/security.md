# Security Patterns

## Credentials & Secrets

**Rule: Never hardcode secrets — not even as fallbacks.**

### TypeScript / JavaScript

```typescript
// ✅ CORRECT — fail fast if missing
const token = process.env.API_TOKEN;
if (!token) throw new Error("API_TOKEN is required");

// ✅ CORRECT — undefined propagates, caller handles
apiToken: process.env.API_TOKEN,

// ❌ WRONG — hardcoded fallback
apiToken: process.env.API_TOKEN || "sk-abc123...",

// ❌ WRONG — placeholder that looks harmless but trains the pattern
secret: process.env.SESSION_SECRET || "change-me-in-production",
```

### Python

```python
# ✅ CORRECT — KeyError if missing
self.api_token = os.environ["API_TOKEN"]

# ❌ WRONG — silent fallback to hardcoded value
self.api_token = os.getenv("API_TOKEN", "sk-abc123...")
```

### Go

```go
// ✅ CORRECT — explicit check
token := os.Getenv("API_TOKEN")
if token == "" {
    log.Fatal("API_TOKEN is required")
}

// ❌ WRONG — empty string silently used
token := os.Getenv("API_TOKEN")  // empty string if unset, no error
```

## Where Secrets Are Defined

| File | Purpose |
|---|---|
| `.env` | Local development (gitignored) |
| `.env.example` | Template with placeholder values (committed) |
| CI/CD secret management | Platform-specific (K8s secrets, GitHub Actions secrets, etc.) |

## Adding a New Secret

1. Add the placeholder to `.env.example` with a descriptive comment
2. Add to your CI/CD secret management (deployment manifests, secret manager, etc.)
3. Reference via environment variable — **no fallback value**
4. Document in RALPH.md if it's required at boot

If the secret doesn't exist in `.env.example` yet, **stop and ask** — don't invent a value.

## Pre-commit Hook

Set up a git pre-commit hook that scans staged files for patterns matching known secret formats (API keys, tokens, passwords, connection strings). If it fires, the commit is blocked. Fix the code; don't bypass with `--no-verify`.

## What Counts as a Secret

- API keys and tokens (cloud providers, AI services, third-party APIs)
- Session secrets and signing keys
- Database connection strings with credentials
- OAuth client secrets
- Any value that would need rotation if exposed

**Non-secrets** that are fine to hardcode: hostnames, HTTP paths, port numbers, feature flags, schema names, warehouse/resource IDs.
