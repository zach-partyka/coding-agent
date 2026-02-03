# Changelog

All notable changes to Ralph Starter Kit will be documented in this file.

## [1.0.0] - 2026-02-02

### Added
- Initial release of Ralph Starter Kit
- Project-specific configuration via `ralph.config.sh`
- Generic `ralph.sh` launcher script
- Interactive setup script (`scripts/setup.sh`)
- Comprehensive documentation (README, CONFIGURATION_GUIDE, EXAMPLES)
- Python/FastAPI example (Zillow standard - Flask deprecated)
- Node.js/TypeScript example (based on Marketing Copilot reference)
- Template files for new projects
- Auto-detection for project types (Python, Node.js, Go)

### Configuration Variables
- `RALPH_GIT_REMOTE` - Git remote URL (HTTPS)
- `RALPH_GIT_MAIN_BRANCH` - Main branch name
- `RALPH_STAGING_URL` - Staging environment URL
- `RALPH_DEPLOY_WAIT_SECONDS` - Deployment wait time
- `RALPH_VALIDATE_LOCAL` - Local validation command
- `RALPH_VALIDATE_STAGING` - Staging validation command
- `RALPH_HEALTH_CHECK_PATH` - Health check endpoint path
- `RALPH_TEST_ENV_VARS` - Environment variables for staging tests
- `RALPH_TASK_TIMEOUT_MINUTES` - Task timeout
- `RALPH_AUTO_ARCHIVE` - Auto-archive completed sprints

### Examples
- **Python/FastAPI**: Complete example with async patterns, Pydantic validation, SQLAlchemy 2.0
  - Specs: User API with FastAPI patterns
  - Stdlib: FastAPI patterns, testing with pytest and httpx.AsyncClient
- **Node.js/TypeScript**: Marketing Copilot reference implementation
  - Specs: Express API endpoint example
  - Stdlib: Express patterns, Playwright testing patterns

### Documentation
- Quick start guide (< 10 minute setup)
- Configuration reference
- Example projects for FastAPI and Node.js/TypeScript
- Troubleshooting guide
- Best practices for sprint planning and spec writing

---

## Migration Guide (Pre-1.0 to 1.0)

### Breaking Changes
- Ralph now requires `ralph.config.sh` in project directory
- Global skills need one-time update to read environment variables (backward compatible with fallbacks)

### Migration Steps

**For existing Marketing Copilot project:**

1. Create `ralph.config.sh` with current hardcoded values:
```bash
cat > ralph.config.sh <<'EOF'
#!/bin/bash
export RALPH_GIT_REMOTE="https://gitlab.zgtools.net/tpm_cdp_team/marketing_copilot.git"
export RALPH_GIT_MAIN_BRANCH="main"
export RALPH_STAGING_URL="https://marketing-copilot-staging.zgtools.net"
export RALPH_DEPLOY_WAIT_SECONDS=300
export RALPH_VALIDATE_LOCAL="npm run check"
export RALPH_VALIDATE_STAGING="STAGING_URL=\$RALPH_STAGING_URL npm test"
export RALPH_HEALTH_CHECK_PATH="/health"
EOF

chmod +x ralph.config.sh
```

2. Copy new generic `ralph.sh`:
```bash
cp ~/ralph-starter-kit/template/ralph.sh ./ralph.sh
chmod +x ralph.sh
```

3. Test that it works:
```bash
./ralph.sh --plan
```

**For new projects:**

Run the setup script:
```bash
~/ralph-starter-kit/scripts/setup.sh
```

---

## Future Enhancements (Planned)

### Version 1.1 (Planned)
- Validation script (`scripts/validate.sh`) to check ralph.config.sh correctness
- Migration script (`scripts/migrate.sh`) for existing Ralph projects
- Generic project example
- Go project example
- Configuration presets for common stack combinations

### Version 1.2 (Planned)
- Support for multi-environment setups (dev, staging, prod)
- Custom task hooks (pre-commit, post-deploy, etc.)
- Integration with CI/CD metrics tracking
- Sprint analytics dashboard

### Version 2.0 (Future)
- Web-based sprint planning UI
- Team collaboration features
- Shared stdlib library across projects
- Template marketplace

---

## Known Issues

### Version 1.0
- **Global skills not yet updated**: Skills still have hardcoded values. Update required for full functionality across all projects.
  - **Workaround**: Skills have fallback defaults that work for Marketing Copilot
  - **Fix**: Coming in 1.0.1 - updated skills with environment variable support
- **Setup script doesn't validate commands**: Setup accepts any validation command without checking if it works
  - **Workaround**: Test commands manually after setup
  - **Fix**: Coming in 1.1 - validate.sh script
- **No migration helper for existing projects**: Manual migration required
  - **Workaround**: Follow migration guide in CHANGELOG
  - **Fix**: Coming in 1.1 - migrate.sh script

---

## Support

Report issues or request features: [Contact your team lead]

For questions about Ralph workflow, see: README.md, CONFIGURATION_GUIDE.md, EXAMPLES.md
