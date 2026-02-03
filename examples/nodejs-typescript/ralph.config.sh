#!/bin/bash
# Ralph Project Configuration - Node.js/TypeScript Example
# Based on Zillow Marketing Copilot reference implementation

# =============================================================================
# REQUIRED CONFIGURATION
# =============================================================================

# Git Configuration
export RALPH_GIT_REMOTE="https://gitlab.zgtools.net/your-team/your-app.git"
export RALPH_GIT_MAIN_BRANCH="main"

# Deployment Configuration
export RALPH_STAGING_URL="https://your-app-staging.zgtools.net"
export RALPH_DEPLOY_WAIT_SECONDS=300  # Node apps typically take 3-5 minutes

# Validation Commands
# Local validation: TypeScript type checking (fast, catches most issues)
export RALPH_VALIDATE_LOCAL="npm run check"

# Staging validation: E2E tests with Playwright
export RALPH_VALIDATE_STAGING="STAGING_URL=\$RALPH_STAGING_URL npm test"

# Health check endpoint
export RALPH_HEALTH_CHECK_PATH="/health"

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================

# Environment variables for staging tests
export RALPH_TEST_ENV_VARS="STAGING_URL=$RALPH_STAGING_URL"

# Node.js projects often need longer task timeout for npm install
export RALPH_TASK_TIMEOUT_MINUTES=15

# =============================================================================
# NODE.JS/TYPESCRIPT NOTES
# =============================================================================

# Common validation patterns for Node.js/TypeScript:
#
# Minimal (type checking only):
#   export RALPH_VALIDATE_LOCAL="npm run check"
#
# With linting:
#   export RALPH_VALIDATE_LOCAL="npm run lint && npm run check"
#
# With unit tests:
#   export RALPH_VALIDATE_LOCAL="npm run check && npm run test:unit"
#
# Full local validation:
#   export RALPH_VALIDATE_LOCAL="npm run lint && npm run check && npm run test:unit"

# Testing patterns:
#
# Playwright E2E tests against staging:
#   export RALPH_VALIDATE_STAGING="STAGING_URL=\$RALPH_STAGING_URL npm test"
#
# Jest unit tests (no staging needed):
#   export RALPH_VALIDATE_LOCAL="npm run test:unit"
#
# Mixed (unit + integration):
#   export RALPH_VALIDATE_LOCAL="npm run test:unit"
#   export RALPH_VALIDATE_STAGING="npm run test:integration"

# Common Node.js/TypeScript stacks supported:
# - Express + React (monorepo with client/ and server/)
# - Next.js (app/ directory or pages/)
# - NestJS (src/ with modules)
# - Pure Express API (src/ or server/)
# - React SPA (src/ with Vite or CRA)
