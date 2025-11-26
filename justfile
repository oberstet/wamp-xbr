# Copyright (c) typedef int GmbH, Germany, 2025. All rights reserved.

# -----------------------------------------------------------------------------
# -- just global configuration
# -----------------------------------------------------------------------------

set unstable := true
set positional-arguments := true
set script-interpreter := ['uv', 'run', '--script']

# uv env vars (see: https://docs.astral.sh/uv/reference/environment/)

# Project base directory
PROJECT_DIR := justfile_directory()

# Tell uv to use project-local cache directory
export UV_CACHE_DIR := './.uv-cache'

# Use this common single directory for all uv venvs
VENV_DIR := './.venvs'

# Define supported Python environments
ENVS := 'cpy314 cpy313 cpy312 cpy311 pypy311'

# Default recipe: show project header and list all recipes
default:
    #!/usr/bin/env bash
    set -e
    VERSION=$(grep '^__version__' xbr/_version.py | head -1 | sed "s/.*= *'\\(.*\\)'/\\1/")
    GIT_REV=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo ""
    echo "==============================================================================="
    echo "                                   XBR                                         "
    echo ""
    echo "          XBR Protocol - Smart Contracts, ABIs, and Python Library             "
    echo ""
    echo "   Python Package:         xbr                                                 "
    echo "   Python Package Version: ${VERSION}                                          "
    echo "   Git Version:            ${GIT_REV}                                          "
    echo "   Protocol Specification: https://xbr.network/                                "
    echo "   Documentation:          https://xbr.network/docs                            "
    echo "   Package Releases:       https://pypi.org/project/xbr/                       "
    echo "   Source Code:            https://github.com/wamp-proto/wamp-xbr              "
    echo "   Copyright:              typedef int GmbH (Germany/EU)                       "
    echo "   License:                Apache 2.0 License                                  "
    echo ""
    echo "       >>>   Created by The WAMP/Autobahn/Crossbar.io OSS Project   <<<        "
    echo "==============================================================================="
    echo ""
    just --list
    echo ""

# Internal helper to map Python version short name to full uv version
_get-spec short_name:
    #!/usr/bin/env bash
    set -e
    case {{short_name}} in
        cpy314)  echo "cpython-3.14";;
        cpy313)  echo "cpython-3.13";;
        cpy312)  echo "cpython-3.12";;
        cpy311)  echo "cpython-3.11";;
        pypy311) echo "pypy-3.11";;
        *)       echo "Unknown environment: {{short_name}}" >&2; exit 1;;
    esac

# Internal helper that calculates and prints the system-matching venv name
_get-system-venv-name:
    #!/usr/bin/env bash
    set -e
    SYSTEM_VERSION=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    ENV_NAME="cpy$(echo ${SYSTEM_VERSION} | tr -d '.')"
    if ! echo "{{ ENVS }}" | grep -q -w "${ENV_NAME}"; then
        echo "Error: System Python (${SYSTEM_VERSION}) maps to '${ENV_NAME}', which is not a supported environment." >&2
        exit 1
    fi
    echo "${ENV_NAME}"

# Helper recipe to get the python executable path for a venv
_get-venv-python venv="":
    #!/usr/bin/env bash
    set -e
    VENV_NAME="{{ venv }}"
    if [ -z "${VENV_NAME}" ]; then
        VENV_NAME=$(just --quiet _get-system-venv-name)
    fi
    VENV_PATH="{{PROJECT_DIR}}/.venvs/${VENV_NAME}"
    if [[ "$OS" == "Windows_NT" ]]; then
        echo "${VENV_PATH}/Scripts/python.exe"
    else
        echo "${VENV_PATH}/bin/python3"
    fi

# -----------------------------------------------------------------------------
# -- General/global helper recipes
# -----------------------------------------------------------------------------

# Setup bash tab completion for the current user (to activate: `source ~/.config/bash_completion`).
setup-completion:
    #!/usr/bin/env bash
    set -e
    COMPLETION_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bash_completion"
    MARKER="# --- Just completion ---"
    echo "==> Setting up bash tab completion for 'just'..."
    if [ -f "${COMPLETION_FILE}" ] && grep -q "${MARKER}" "${COMPLETION_FILE}"; then
        echo "--> 'just' completion is already configured."
        exit 0
    fi
    echo "--> Configuration not found. Adding it now..."
    mkdir -p "$(dirname "${COMPLETION_FILE}")"
    echo "" >> "${COMPLETION_FILE}"
    echo "${MARKER}" >> "${COMPLETION_FILE}"
    just --completions bash >> "${COMPLETION_FILE}"
    echo "--> Successfully added completion logic to ${COMPLETION_FILE}."
    echo ""
    echo "==> Setup complete. Please restart your shell or run:"
    echo "    source \"${COMPLETION_FILE}\""

# Remove ALL generated files, including venvs, caches, and build artifacts
distclean: clean-build clean-pyc clean-test
    #!/usr/bin/env bash
    set -e
    echo "==> Performing a deep clean (distclean)..."
    rm -rf {{VENV_DIR}}
    rm -rf {{UV_CACHE_DIR}}
    echo "--> Removed all venvs and caches."

# Clean build artifacts
clean-build:
    #!/usr/bin/env bash
    set -e
    echo "==> Cleaning build artifacts..."
    rm -rf build/contracts/ dist/ *.egg-info/ .eggs/
    find . -name '*.whl' -delete
    find . -name '*.tar.gz' -delete
    echo "--> Build artifacts cleaned."

# Clean Python bytecode files
clean-pyc:
    #!/usr/bin/env bash
    set -e
    echo "==> Cleaning Python bytecode files..."
    find . -type f -name '*.py[co]' -delete
    find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
    echo "--> Python bytecode cleaned."

# Clean test and coverage artifacts
clean-test:
    #!/usr/bin/env bash
    set -e
    echo "==> Cleaning test artifacts..."
    rm -rf .pytest_cache/ .coverage htmlcov/ .tox/
    echo "--> Test artifacts cleaned."

# Clean generated documentation
docs-clean:
    #!/usr/bin/env bash
    set -e
    echo "==> Cleaning documentation..."
    rm -rf docs/_build
    echo "--> Documentation cleaned."

# -----------------------------------------------------------------------------
# -- Virtual Environment Management
# -----------------------------------------------------------------------------

# Create a single Python virtual environment (usage: `just create cpy314` or `just create`)
create venv="":
    #!/usr/bin/env bash
    set -e
    VENV_NAME="{{ venv }}"
    if [ -z "${VENV_NAME}" ]; then
        VENV_NAME=$(just --quiet _get-system-venv-name)
    fi
    PYTHON_SPEC=$(just --quiet _get-spec ${VENV_NAME})
    VENV_PATH="{{VENV_DIR}}/${VENV_NAME}"
    echo "==> Creating venv for ${VENV_NAME} (${PYTHON_SPEC})..."
    if [ ! -d "${VENV_PATH}" ]; then
        uv venv --seed --python "${PYTHON_SPEC}" "${VENV_PATH}"
        echo "--> Created venv at ${VENV_PATH}"
    else
        echo "--> Venv already exists at ${VENV_PATH}"
    fi

# Create all Python virtual environments
create-all:
    #!/usr/bin/env bash
    set -e
    for env in {{ENVS}}; do
        just create ${env}
    done

# List all Python virtual environments
list-all:
    #!/usr/bin/env bash
    set -e
    echo "==> Listing all venvs in {{VENV_DIR}}..."
    if [ -d "{{VENV_DIR}}" ]; then
        ls -1 {{VENV_DIR}}
    else
        echo "--> No venvs directory found."
    fi

# Get the version of a single virtual environment's Python
version venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    ${VENV_PYTHON} --version

# Get versions of all Python virtual environments
version-all:
    #!/usr/bin/env bash
    set -e
    for env in {{ENVS}}; do
        echo -n "${env}: "
        just version ${env} || echo "Not installed"
    done

# -----------------------------------------------------------------------------
# -- Installation
# -----------------------------------------------------------------------------

# Install xbr with runtime dependencies
install venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Installing xbr..."
    ${VENV_PYTHON} -m pip install .
    echo "--> Installed xbr"

# Install xbr in development (editable) mode
install-dev venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Installing xbr in development mode..."
    ${VENV_PYTHON} -m pip install -e '.[dev]'
    echo "--> Installed xbr[dev] in editable mode"

# Install development tools (ruff, mypy, sphinx, etc.)
install-tools venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Installing development tools..."
    ${VENV_PYTHON} -m pip install ruff mypy pytest sphinx twine build
    echo "--> Installed development tools"

# Install minimal build tools for building wheels
install-build-tools venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Installing build tools..."
    ${VENV_PYTHON} -m pip install build wheel twine
    echo "--> Installed build tools"

# Install all environments
install-all:
    #!/usr/bin/env bash
    set -e
    for env in {{ENVS}}; do
        just install-dev ${env}
    done

# -----------------------------------------------------------------------------
# -- Code Quality
# -----------------------------------------------------------------------------

# Check code formatting with Ruff (dry run)
check-format venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Checking code formatting with Ruff..."
    ${VENV_PYTHON} -m ruff format --check xbr/
    echo "--> Format check passed"

# Auto-format code with Ruff (modifies files in-place!)
autoformat venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Auto-formatting code with Ruff..."
    ${VENV_PYTHON} -m ruff format xbr/
    echo "--> Code formatted"

# Run Ruff linter
check-lint venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Running Ruff linter..."
    ${VENV_PYTHON} -m ruff check xbr/
    echo "--> Linting passed"

# Run static type checking with mypy
check-typing venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Running type checking with mypy..."
    ${VENV_PYTHON} -m mypy xbr/ || echo "Warning: Type checking found issues"

# Run all code quality checks
check venv="": (check-format venv) (check-lint venv) (check-typing venv)

# -----------------------------------------------------------------------------
# -- Testing
# -----------------------------------------------------------------------------

# Run the test suite with pytest (requires: `just install-dev`)
test venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Running test suite with pytest..."
    ${VENV_PYTHON} -m pytest -v xbr/test/
    echo "--> Tests passed"

# Run tests in all environments
test-all:
    #!/usr/bin/env bash
    set -e
    for env in {{ENVS}}; do
        echo ""
        echo "======================================================================"
        echo "Testing with ${env}"
        echo "======================================================================"
        just test ${env}
    done

# Generate code coverage report (requires: `just install-dev`)
coverage venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Generating coverage report..."
    ${VENV_PYTHON} -m pytest --cov=xbr --cov-report=html --cov-report=term xbr/test/
    echo "--> Coverage report generated in htmlcov/"

# -----------------------------------------------------------------------------
# -- Building
# -----------------------------------------------------------------------------

# Build source distribution
build-sourcedist venv="": (install-build-tools venv)
    #!/usr/bin/env bash
    set -e
    VENV_NAME="{{ venv }}"
    if [ -z "${VENV_NAME}" ]; then
        VENV_NAME=$(just --quiet _get-system-venv-name)
    fi
    VENV_PYTHON=$(just --quiet _get-venv-python "${VENV_NAME}")
    echo "==> Building source distribution..."
    ${VENV_PYTHON} -m build --sdist
    ls -la dist/

# Build wheel package
build venv="": (install-build-tools venv)
    #!/usr/bin/env bash
    set -e
    VENV_NAME="{{ venv }}"
    if [ -z "${VENV_NAME}" ]; then
        VENV_NAME=$(just --quiet _get-system-venv-name)
    fi
    VENV_PATH="{{VENV_DIR}}/${VENV_NAME}"
    VENV_PYTHON=$(just --quiet _get-venv-python "${VENV_NAME}")
    echo "==> Building wheel package..."
    ${VENV_PYTHON} -m build --wheel
    ls -la dist/

# Build both source distribution and wheel
dist venv="": (install-build-tools venv)
    #!/usr/bin/env bash
    set -e
    VENV_NAME="{{ venv }}"
    if [ -z "${VENV_NAME}" ]; then
        VENV_NAME=$(just --quiet _get-system-venv-name)
    fi
    VENV_PYTHON=$(just --quiet _get-venv-python "${VENV_NAME}")
    echo "==> Building distribution packages..."
    ${VENV_PYTHON} -m build
    echo ""
    echo "Built packages:"
    ls -lh dist/

# Build wheels for all environments (pure Python - only needs one build)
build-all: (build "cpy311")
    echo "==> Pure Python package: single universal wheel built."

# Verify wheels using twine check (pure Python package - auditwheel not applicable)
verify-wheels venv="": (install-tools venv)
    #!/usr/bin/env bash
    set -e
    VENV_NAME="{{ venv }}"
    if [ -z "${VENV_NAME}" ]; then
        VENV_NAME=$(just --quiet _get-system-venv-name)
    fi
    VENV_PATH="{{VENV_DIR}}/${VENV_NAME}"
    echo "==> Verifying wheels with twine check..."
    "${VENV_PATH}/bin/twine" check dist/*
    echo ""
    echo "==> Note: This is a pure Python package (py3-none-any wheel)."
    echo "    auditwheel verification is not applicable (no native extensions)."
    echo ""
    echo "==> Wheel verification complete."

# -----------------------------------------------------------------------------
# -- Documentation
# -----------------------------------------------------------------------------

# Build HTML documentation using Sphinx
docs venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Building documentation..."
    cd docs
    ${VENV_PYTHON} -m sphinx -b html . _build/html
    echo "--> Documentation built in docs/_build/html/"

# View built documentation
docs-view venv="":
    #!/usr/bin/env bash
    set -e
    if [ ! -f "docs/_build/html/index.html" ]; then
        echo "Error: Documentation not built yet. Run 'just docs' first."
        exit 1
    fi
    xdg-open docs/_build/html/index.html 2>/dev/null || \
        open docs/_build/html/index.html 2>/dev/null || \
        echo "Could not open browser. Open docs/_build/html/index.html manually."

# -----------------------------------------------------------------------------
# -- Publishing
# -----------------------------------------------------------------------------

# Publish to PyPI using twine
publish venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Publishing to PyPI..."
    echo ""
    echo "WARNING: This will upload to PyPI!"
    echo "Press Ctrl+C to cancel, or Enter to continue..."
    read
    ${VENV_PYTHON} -m twine upload dist/*
    echo "--> Published to PyPI"

# Publish to Test PyPI
publish-test venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Publishing to Test PyPI..."
    ${VENV_PYTHON} -m twine upload --repository testpypi dist/*
    echo "--> Published to Test PyPI"

# -----------------------------------------------------------------------------
# -- Makefile Integration (Solidity/Truffle targets)
# -----------------------------------------------------------------------------

# Run a Makefile target (for Solidity/Truffle targets)
make target:
    #!/usr/bin/env bash
    set -e
    echo "==> Running Makefile target: {{target}}"
    make {{target}}

# Compile Solidity smart contracts (wrapper for `make compile`)
truffle-compile:
    just make compile

# Run Solidity tests (wrapper for `make test`)
truffle-test:
    just make test

# Deploy contracts to Ganache (wrapper for `make deploy_ganache`)
truffle-deploy:
    just make deploy_ganache

# Run Ganache blockchain (wrapper for `make run_ganache`)
ganache-run:
    just make run_ganache

# Initialize Ganache with test data (wrapper for `make init_ganache`)
ganache-init:
    just make init_ganache
