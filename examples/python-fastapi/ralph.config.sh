#!/bin/bash
# Ralph Project Configuration - Python/FastAPI Example
# FastAPI is Zillow's standard Python web framework (Flask is deprecated)

# =============================================================================
# REQUIRED CONFIGURATION
# =============================================================================

# Git Configuration
export RALPH_GIT_REMOTE="https://gitlab.zgtools.net/your-team/your-fastapi-app.git"
export RALPH_GIT_MAIN_BRANCH="main"

# Deployment Configuration
export RALPH_STAGING_URL="https://your-fastapi-app-staging.zgtools.net"
export RALPH_DEPLOY_WAIT_SECONDS=180  # FastAPI apps typically deploy faster

# Validation Commands
# Local validation: Run linting, type checking, and unit tests
export RALPH_VALIDATE_LOCAL="python -m ruff check src/ && python -m mypy src/ && python -m pytest tests/unit/"

# Staging validation: Run integration tests against deployed staging
export RALPH_VALIDATE_STAGING="python -m pytest tests/integration/ -v"

# Health check endpoint
export RALPH_HEALTH_CHECK_PATH="/health"

# =============================================================================
# OPTIONAL CONFIGURATION
# =============================================================================

# Set staging URL as environment variable for integration tests
export RALPH_TEST_ENV_VARS="STAGING_URL=$RALPH_STAGING_URL"

# Python projects may need longer task timeout for dependency installation
export RALPH_TASK_TIMEOUT_MINUTES=20

# =============================================================================
# FASTAPI-SPECIFIC NOTES
# =============================================================================

# Virtual Environment:
# Ralph expects you to activate your virtual environment BEFORE running ralph.sh
#
# Example workflow:
#   source venv/bin/activate
#   ./ralph.sh --plan
#
# If you see "command not found" errors, make sure:
# 1. Virtual environment is activated
# 2. Dependencies are installed: pip install -r requirements.txt
# 3. Dev dependencies are installed: pip install -r requirements-dev.txt

# Common FastAPI validation patterns:
#
# Minimal (just tests):
#   export RALPH_VALIDATE_LOCAL="python -m pytest tests/unit/"
#
# Standard (lint + type + test) - using Ruff (replaces flake8/black/isort):
#   export RALPH_VALIDATE_LOCAL="python -m ruff check src/ && python -m mypy src/ && python -m pytest tests/unit/"
#
# With Ruff formatting:
#   export RALPH_VALIDATE_LOCAL="python -m ruff format --check src/ && python -m ruff check src/ && python -m pytest tests/unit/"
#
# With coverage:
#   export RALPH_VALIDATE_LOCAL="python -m pytest tests/unit/ --cov=src --cov-report=term-missing --cov-fail-under=80"

# FastAPI Testing Patterns:
#
# Unit tests (fast, no external dependencies):
#   python -m pytest tests/unit/ -v
#
# Integration tests (against staging):
#   STAGING_URL=https://app-staging.zgtools.net python -m pytest tests/integration/ -v
#
# All tests with coverage:
#   python -m pytest tests/ --cov=src --cov-report=html
