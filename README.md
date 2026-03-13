# Ralph

Ralph is an AI agent that builds software for you. You describe what you want, Ralph implements it, deploys it to your test environment, and lets you review the live result — all in one sitting.

---

## Get started

**Step 1 — Set up Ralph** (choose your platform):

- **[Mac users → docs/README-MAC.md](docs/README-MAC.md)**
- **[Windows users → docs/README-WINDOWS.md](docs/README-WINDOWS.md)**

**Step 2 — Get your app infrastructure ready:**

- **[New app setup guide → ONBOARDING.md](ONBOARDING.md)** — deploy your app, wire up CI/CD, add tests

---

Config: one file, `ralph-config.md`. See **docs/RALPH_CONFIG.md**.

Questions? Open an issue at [github.com/zach-partyka/coding-agent](https://github.com/zach-partyka/coding-agent/issues).

---

**Two-repo note:** This is the universal core — no org-specific tooling, registries, or infrastructure. If your org has specific CI/CD, secret management, or deployment patterns, fork this repo and add an org layer on top (your own `ONBOARDING.md`, platform-specific README guides, stack patterns). The universal core gets periodic updates; pull them in as needed.
