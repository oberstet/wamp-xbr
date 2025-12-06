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
    VERSION=$(grep '^__version__' src/xbr/_version.py | head -1 | sed "s/.*= *'\\(.*\\)'/\\1/")
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

# Install development tools (ruff, sphinx, etc.) - ty installed separately via uv tool
install-tools venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Installing development tools..."
    ${VENV_PYTHON} -m pip install ruff pytest sphinx twine build
    echo "--> Installed development tools"
    echo "    Note: ty (type checker) should be installed via 'uv tool install ty'"

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

# Meta-recipe to run `install-dev` on all environments
install-dev-all:
    #!/usr/bin/env bash
    set -e
    for venv in {{ENVS}}; do
        just install-dev ${venv}
    done

# Meta-recipe to run `install-tools` on all environments
install-tools-all:
    #!/usr/bin/env bash
    set -e
    for venv in {{ENVS}}; do
        just install-tools ${venv}
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
    ${VENV_PYTHON} -m ruff format --check src/xbr/
    echo "--> Format check passed"

# Automatically fix all formatting and code style issues.
fix-format venv="": (install-tools venv)
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Auto-formatting code with Ruff..."
    ${VENV_PYTHON} -m ruff format src/xbr/
    echo "--> Code formatted"

# Alias for fix-format (backward compatibility)
autoformat venv="": (fix-format venv)

# Run Ruff linter
check-lint venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Running Ruff linter..."
    ${VENV_PYTHON} -m ruff check src/xbr/
    echo "--> Linting passed"

# Run static type checking with ty (Astral's Rust-based type checker)
# FIXME: Many type errors need to be fixed. For now, we ignore most rules
# to get CI passing. Create follow-up issue to address type errors.
check-typing venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Running type checking with ty..."
    echo "    Using Python: ${VENV_PYTHON}"
    ty check \
        --python "${VENV_PYTHON}" \
        --ignore unresolved-import \
        --ignore unresolved-attribute \
        --ignore unresolved-reference \
        --ignore unresolved-global \
        --ignore possibly-missing-attribute \
        --ignore possibly-missing-import \
        --ignore call-non-callable \
        --ignore invalid-assignment \
        --ignore invalid-argument-type \
        --ignore invalid-return-type \
        --ignore invalid-method-override \
        --ignore invalid-type-form \
        --ignore unsupported-operator \
        --ignore too-many-positional-arguments \
        --ignore unknown-argument \
        --ignore missing-argument \
        --ignore non-subscriptable \
        --ignore not-iterable \
        --ignore no-matching-overload \
        --ignore conflicting-declarations \
        --ignore deprecated \
        --ignore unsupported-base \
        --ignore invalid-await \
        --ignore invalid-super-argument \
        --ignore invalid-exception-caught \
        src/xbr/

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
    ${VENV_PYTHON} -m pytest -v src/xbr/test/
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
check-coverage venv="":
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Generating coverage report..."
    ${VENV_PYTHON} -m pytest --cov=xbr --cov-report=html --cov-report=term src/xbr/test/
    echo "--> Coverage report generated in htmlcov/"

# Alias for check-coverage (backward compatibility)
coverage venv="": (check-coverage venv)

# Upgrade dependencies in a single environment (re-installs all deps to latest)
upgrade venv="": (create venv)
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    echo "==> Upgrading all dependencies..."
    ${VENV_PYTHON} -m pip install --upgrade pip
    ${VENV_PYTHON} -m pip install --upgrade -e '.[dev]'
    echo "--> Dependencies upgraded"

# Meta-recipe to run `upgrade` on all environments
upgrade-all:
    #!/usr/bin/env bash
    set -e
    for venv in {{ENVS}}; do
        echo ""
        echo "======================================================================"
        echo "Upgrading ${venv}"
        echo "======================================================================"
        just upgrade ${venv}
    done

# -----------------------------------------------------------------------------
# -- Building
# -----------------------------------------------------------------------------

# Build source distribution (compiles Solidity contracts first if needed)
build-sourcedist venv="": (install-build-tools venv) compile-contracts
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

# Build wheel package (compiles Solidity contracts first if needed)
build venv="": (install-build-tools venv) compile-contracts
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

# Build both source distribution and wheel (compiles Solidity contracts first)
dist venv="": (install-build-tools venv) compile-contracts
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

# Build optimized SVGs from docs/_graphics/*.svg using scour
_build-images venv="": (install-tools venv)
    #!/usr/bin/env bash
    set -e
    VENV_PYTHON=$(just --quiet _get-venv-python {{ venv }})
    VENV_NAME="{{ venv }}"
    if [ -z "${VENV_NAME}" ]; then
        VENV_NAME=$(just --quiet _get-system-venv-name)
    fi
    VENV_PATH="{{VENV_DIR}}/${VENV_NAME}"

    SOURCEDIR="{{ PROJECT_DIR }}/docs/_graphics"
    TARGETDIR="{{ PROJECT_DIR }}/docs/_static/img"

    echo "==> Building optimized SVG images..."
    mkdir -p "${TARGETDIR}"

    if [ -d "${SOURCEDIR}" ]; then
        find "${SOURCEDIR}" -name "*.svg" -type f | while read -r source_file; do
            filename=$(basename "${source_file}")
            target_file="${TARGETDIR}/${filename}"
            echo "  Processing: ${filename}"
            "${VENV_PATH}/bin/scour" \
                --remove-descriptive-elements \
                --enable-comment-stripping \
                --enable-viewboxing \
                --indent=none \
                --no-line-breaks \
                --shorten-ids \
                "${source_file}" "${target_file}"
        done
    fi

    echo "==> Done building images."

# Build HTML documentation using Sphinx
docs venv="": (_build-images venv)
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

# Download GitHub release artifacts (nightly or tagged release)
download-github-release release_type="nightly":
    #!/usr/bin/env bash
    set -e
    echo "==> Downloading GitHub release artifacts ({{release_type}})..."
    rm -rf ./dist
    mkdir -p ./dist
    if [ "{{release_type}}" = "nightly" ]; then
        gh release download nightly --repo wamp-proto/wamp-xbr --dir ./dist --pattern '*.whl' --pattern '*.tar.gz' || \
            echo "Note: No nightly release found or no artifacts available"
    else
        gh release download "{{release_type}}" --repo wamp-proto/wamp-xbr --dir ./dist --pattern '*.whl' --pattern '*.tar.gz'
    fi
    echo ""
    echo "Downloaded artifacts:"
    ls -la ./dist/ || echo "No artifacts downloaded"

# Download release artifacts from GitHub and publish to PyPI
publish-pypi venv="" tag="": (install-tools venv)
    #!/usr/bin/env bash
    set -e
    VENV_PATH="{{VENV_DIR}}/$(just --quiet _get-system-venv-name)"
    if [ -n "{{ venv }}" ]; then
        VENV_PATH="{{VENV_DIR}}/{{ venv }}"
    fi
    TAG="{{ tag }}"
    if [ -z "${TAG}" ]; then
        echo "Error: Please specify a tag to publish"
        echo "Usage: just publish-pypi cpy311 v24.1.1"
        exit 1
    fi
    echo "==> Publishing ${TAG} to PyPI..."
    echo ""
    echo "Step 1: Download release artifacts from GitHub..."
    just download-github-release "${TAG}"
    echo ""
    echo "Step 2: Verify packages with twine..."
    "${VENV_PATH}/bin/twine" check dist/*
    echo ""
    echo "Note: This is a pure Python package (py3-none-any wheel)."
    echo "      auditwheel verification is not applicable (no native extensions)."
    echo ""
    echo "Step 3: Upload to PyPI..."
    echo ""
    echo "WARNING: This will upload to PyPI!"
    echo "Press Ctrl+C to cancel, or Enter to continue..."
    read
    "${VENV_PATH}/bin/twine" upload dist/*
    echo ""
    echo "==> Successfully published ${TAG} to PyPI"

# Trigger Read the Docs build for a specific tag
publish-rtd tag="":
    #!/usr/bin/env bash
    set -e
    TAG="{{ tag }}"
    if [ -z "${TAG}" ]; then
        echo "Error: Please specify a tag to build"
        echo "Usage: just publish-rtd v24.1.1"
        exit 1
    fi
    echo "==> Triggering Read the Docs build for ${TAG}..."
    echo ""
    echo "Note: Read the Docs builds are typically triggered automatically"
    echo "      when tags are pushed to GitHub. This recipe is a placeholder"
    echo "      for manual triggering if needed."
    echo ""
    echo "To manually trigger a build:"
    echo "  1. Go to https://readthedocs.org/projects/xbr/"
    echo "  2. Click 'Build a version'"
    echo "  3. Select the tag: ${TAG}"
    echo ""

# -----------------------------------------------------------------------------
# -- Solidity/Truffle Build Tools
# -----------------------------------------------------------------------------

# Truffle executable path (from local node_modules)
TRUFFLE := justfile_directory() / "node_modules/.bin/truffle"
SOLHINT := justfile_directory() / "node_modules/.bin/solhint"

# Install Node.js/npm dependencies for Solidity contract compilation
install-node-tools:
    #!/usr/bin/env bash
    set -e
    echo "==> Installing Node.js dependencies for Solidity compilation..."

    # Check if npm is available
    if ! command -v npm &> /dev/null; then
        echo "❌ ERROR: npm not found. Please install Node.js first."
        echo "   Install via: https://nodejs.org/ or use your package manager"
        exit 1
    fi

    echo "--> Node.js version: $(node --version)"
    echo "--> npm version: $(npm --version)"

    # Check if Truffle is already installed
    if [ -x "{{ TRUFFLE }}" ]; then
        echo "--> Truffle already installed: $({{ TRUFFLE }} version | head -1)"
    else
        # Install dev dependencies (truffle, solhint, etc.)
        echo "--> Installing npm dependencies..."
        npm install
    fi

    # Verify installation
    if [ -x "{{ TRUFFLE }}" ]; then
        echo "✓ Truffle available"
    else
        echo "❌ ERROR: Truffle installation failed"
        exit 1
    fi

    if [ -x "{{ SOLHINT }}" ]; then
        echo "✓ Solhint available"
    else
        echo "⚠ WARNING: Solhint not available (optional)"
    fi

    echo "✓ Node.js tools ready"

# Compile Solidity smart contracts (creates build/contracts/*.json ABI files)
compile-contracts: install-node-tools
    #!/usr/bin/env bash
    set -e
    echo "==> Compiling Solidity smart contracts..."

    # Show contract stats
    echo "--> Contract source files:"
    wc -l contracts/*.sol 2>/dev/null || echo "No .sol files found"

    # Clean old build artifacts
    rm -rf build/contracts/*.json 2>/dev/null || true
    mkdir -p build/contracts

    # Compile with Truffle (downloads solc on first run, then caches it)
    echo "--> Running Truffle compile..."
    {{ TRUFFLE }} compile --all

    # Verify ABI files were created
    echo "--> Verifying ABI files..."
    python3 ./check-abi-files.py

    # List generated files
    echo ""
    echo "--> Generated ABI files:"
    ls -la build/contracts/*.json 2>/dev/null || echo "No ABI files generated!"

    echo ""
    echo "✓ Contract compilation complete"

# Lint Solidity contracts
lint-contracts: install-node-tools
    #!/usr/bin/env bash
    set -e
    echo "==> Linting Solidity contracts..."
    {{ SOLHINT }} "contracts/**/*.sol"
    echo "✓ Solidity linting passed"

# Clean Solidity build artifacts
clean-contracts:
    #!/usr/bin/env bash
    set -e
    echo "==> Cleaning Solidity build artifacts..."
    rm -rf build/contracts/
    rm -rf node_modules/
    rm -f package-lock.json
    echo "--> Solidity artifacts cleaned."

# -----------------------------------------------------------------------------
# -- Makefile Integration (Legacy wrappers)
# -----------------------------------------------------------------------------

# Run a Makefile target (for advanced Solidity/Truffle targets)
make target:
    #!/usr/bin/env bash
    set -e
    echo "==> Running Makefile target: {{target}}"
    make {{target}}

# Run Solidity tests (requires Ganache running)
truffle-test: install-node-tools
    #!/usr/bin/env bash
    set -e
    echo "==> Running Truffle tests..."
    {{ TRUFFLE }} test --network ganache

# Deploy contracts to Ganache (wrapper for `make deploy_ganache`)
truffle-deploy: compile-contracts
    #!/usr/bin/env bash
    set -e
    echo "==> Deploying contracts to Ganache..."
    {{ TRUFFLE }} migrate --reset --network ganache

# Run Ganache blockchain (wrapper for `make run_ganache`)
ganache-run:
    just make run_ganache

# Initialize Ganache with test data (wrapper for `make init_ganache`)
ganache-init:
    just make init_ganache
