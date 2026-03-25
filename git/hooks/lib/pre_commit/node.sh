#!/usr/bin/env bash

pre_commit_package_json_script() {
    local script_name="$1"

    [ -f package.json ] || return 1

    if command -v node >/dev/null 2>&1; then
        node -e "const fs = require('fs'); const data = JSON.parse(fs.readFileSync('package.json', 'utf8')); const script = (data.scripts || {})[process.argv[1]]; if (script) { console.log(script); process.exit(0); } process.exit(1);" "$script_name"
        return $?
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$script_name" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path('package.json').read_text(encoding='utf-8'))
script = data.get('scripts', {}).get(sys.argv[1])
if script:
    print(script)
    raise SystemExit(0)
raise SystemExit(1)
PY
        return $?
    fi

    return 1
}

pre_commit_package_json_has_dependency() {
    local dependency_name="$1"

    [ -f package.json ] || return 1

    if command -v node >/dev/null 2>&1; then
        node -e "const fs = require('fs'); const data = JSON.parse(fs.readFileSync('package.json', 'utf8')); const deps = Object.assign({}, data.dependencies || {}, data.devDependencies || {}, data.peerDependencies || {}); process.exit(process.argv[1] in deps ? 0 : 1);" "$dependency_name" >/dev/null 2>&1
        return $?
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$dependency_name" <<'PY' >/dev/null 2>&1
import json
import sys
from pathlib import Path

data = json.loads(Path('package.json').read_text(encoding='utf-8'))
deps = {}
deps.update(data.get('dependencies', {}))
deps.update(data.get('devDependencies', {}))
deps.update(data.get('peerDependencies', {}))

raise SystemExit(0 if sys.argv[1] in deps else 1)
PY
        return $?
    fi

    return 1
}

pre_commit_node_package_manager() {
    if [ -f package.json ]; then
        local manager

        if command -v node >/dev/null 2>&1; then
            manager=$(node -e "const fs = require('fs'); const data = JSON.parse(fs.readFileSync('package.json', 'utf8')); const packageManager = data.packageManager || ''; if (packageManager) console.log(packageManager.split('@', 1)[0]);")
        elif command -v python3 >/dev/null 2>&1; then
            manager=$(python3 <<'PY'
import json
from pathlib import Path

path = Path('package.json')
if not path.exists():
    raise SystemExit(1)

package_manager = json.loads(path.read_text(encoding='utf-8')).get('packageManager', '')
if package_manager:
    print(package_manager.split('@', 1)[0])
PY
)
        fi

        if [ -n "$manager" ]; then
            echo "$manager"
            return 0
        fi
    fi

    if [ -f yarn.lock ]; then
        echo "yarn"
    elif [ -f pnpm-lock.yaml ]; then
        echo "pnpm"
    elif [ -f package-lock.json ]; then
        echo "npm"
    elif [ -f bun.lockb ] || [ -f bun.lock ]; then
        echo "bun"
    else
        echo "npm"
    fi
}

pre_commit_ensure_node_runner() {
    local package_manager="$1"

    case "$package_manager" in
        yarn|pnpm|npm|bun)
            command -v "$package_manager" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

pre_commit_run_node_script() {
    local script_name="$1"
    local package_manager
    package_manager="$(pre_commit_node_package_manager)"

    case "$package_manager" in
        yarn)
            yarn "$script_name"
            ;;
        pnpm)
            pnpm run "$script_name"
            ;;
        npm)
            npm run "$script_name"
            ;;
        bun)
            bun run "$script_name"
            ;;
        *)
            return 127
            ;;
    esac
}

pre_commit_run_node_bin() {
    local bin_name="$1"
    shift

    local package_manager local_bin
    package_manager="$(pre_commit_node_package_manager)"
    local_bin="node_modules/.bin/$bin_name"

    case "$package_manager" in
        yarn)
            if [ -f .pnp.cjs ] || [ -f .pnp.js ]; then
                yarn exec "$bin_name" "$@"
            else
                [ -x "$local_bin" ] || return 127
                "$local_bin" "$@"
            fi
            ;;
        pnpm)
            if [ -x "$local_bin" ]; then
                "$local_bin" "$@"
            else
                pnpm exec "$bin_name" "$@"
            fi
            ;;
        *)
            [ -x "$local_bin" ] || return 127
            "$local_bin" "$@"
            ;;
    esac
}

pre_commit_node_bin_available() {
    local bin_name="$1"
    local package_manager local_bin
    package_manager="$(pre_commit_node_package_manager)"
    local_bin="node_modules/.bin/$bin_name"

    case "$package_manager" in
        yarn)
            if [ -f .pnp.cjs ] || [ -f .pnp.js ]; then
                yarn exec "$bin_name" --version >/dev/null 2>&1
            else
                [ -x "$local_bin" ]
            fi
            ;;
        pnpm)
            if [ -x "$local_bin" ]; then
                [ -x "$local_bin" ]
            else
                pnpm exec "$bin_name" --version >/dev/null 2>&1
            fi
            ;;
        *)
            [ -x "$local_bin" ]
            ;;
    esac
}

pre_commit_script_is_biome_command() {
    local script="$1"

    case "$script" in
        biome|biome\ *|@biomejs/biome\ *|npx\ biome\ *|npx\ @biomejs/biome\ *|pnpm\ biome\ *|pnpm\ exec\ biome\ *|pnpm\ exec\ @biomejs/biome\ *|yarn\ biome\ *|yarn\ exec\ biome\ *|yarn\ exec\ @biomejs/biome\ *|bunx\ biome\ *|bunx\ @biomejs/biome\ *|bun\ x\ biome\ *|bun\ x\ @biomejs/biome\ *)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

pre_commit_check_biome() {
    [ -f package.json ] || return 0

    local package_manager
    package_manager="$(pre_commit_node_package_manager)"

    local lint_script=""
    local biome_command=""

    if lint_script=$(pre_commit_package_json_script 'lint:ci' 2>/dev/null); then
        if pre_commit_script_is_biome_command "$lint_script"; then
            biome_command='lint:ci'
        fi
    fi

    if [ -z "$biome_command" ] && lint_script=$(pre_commit_package_json_script 'lint' 2>/dev/null); then
        if pre_commit_script_is_biome_command "$lint_script"; then
            biome_command='lint'
        fi
    fi

    if [ -z "$biome_command" ] && ! pre_commit_package_json_has_dependency '@biomejs/biome'; then
        return 0
    fi

    echo "Checking Biome..."

    local biome_output=""
    local biome_exit=0

    if [ "$biome_command" = 'lint:ci' ]; then
        if ! pre_commit_ensure_node_runner "$package_manager"; then
            pre_commit_fail \
                "Cannot run Node checks with $package_manager" \
                '' \
                "Install $package_manager or update package.json/packageManager before committing."
            return 1
        fi

        biome_output=$(pre_commit_run_node_script 'lint:ci' 2>&1)
        biome_exit=$?
    elif [ "$biome_command" = 'lint' ]; then
        if ! pre_commit_ensure_node_runner "$package_manager"; then
            pre_commit_fail \
                "Cannot run Node checks with $package_manager" \
                '' \
                "Install $package_manager or update package.json/packageManager before committing."
            return 1
        fi

        biome_output=$(pre_commit_run_node_script 'lint' 2>&1)
        biome_exit=$?
    else
        if { [ "$package_manager" = 'pnpm' ] || { [ "$package_manager" = 'yarn' ] && { [ -f .pnp.cjs ] || [ -f .pnp.js ]; }; }; } \
            && ! pre_commit_ensure_node_runner "$package_manager"; then
            pre_commit_fail \
                "Cannot run Node checks with $package_manager" \
                '' \
                "Install $package_manager or update package.json/packageManager before committing."
            return 1
        fi

        if ! pre_commit_node_bin_available 'biome'; then
            pre_commit_fail \
                'Biome is configured but not runnable in this repo' \
                '' \
                'Run your project install command or fix the local Biome setup before committing.'
            return 1
        fi

        biome_output=$(pre_commit_run_node_bin biome check --error-on-warnings --no-errors-on-unmatched --staged 2>&1)
        biome_exit=$?
    fi

    if [ "$biome_exit" -ne 0 ]; then
        pre_commit_fail \
            'Biome reported errors' \
            "$biome_output" \
            'Fix the lint errors before committing.'
        return 1
    fi

    echo "No Biome issues detected"
}

pre_commit_check_jest() {
    [ -f package.json ] || return 0

    local -a js_files=()
    pre_commit_collect_staged_files js_files '*.js' '*.jsx' '*.ts' '*.tsx'

    [ ${#js_files[@]} -eq 0 ] && return 0

    if ! pre_commit_package_json_has_dependency 'jest'; then
        local detected_jest=0
        local script_name test_script

        if [ -f jest.config.js ] || [ -f jest.config.ts ] || [ -f jest.config.cjs ] || [ -f jest.config.mjs ] || [ -f jest.config.json ]; then
            detected_jest=1
        fi

        for script_name in test test:ci unit unit:ci; do
            if test_script=$(pre_commit_package_json_script "$script_name" 2>/dev/null); then
                case "$test_script" in
                    *jest*)
                        detected_jest=1
                        break
                        ;;
                esac
            fi
        done

        if [ "$detected_jest" -eq 0 ] && ! pre_commit_node_bin_available 'jest'; then
            return 0
        fi
    fi

    local package_manager
    package_manager="$(pre_commit_node_package_manager)"

    if { [ "$package_manager" = 'pnpm' ] || { [ "$package_manager" = 'yarn' ] && { [ -f .pnp.cjs ] || [ -f .pnp.js ]; }; }; } \
        && ! pre_commit_ensure_node_runner "$package_manager"; then
        pre_commit_fail \
            "Cannot run Node checks with $package_manager" \
            '' \
            "Install $package_manager or update package.json/packageManager before committing."
        return 1
    fi

    if ! pre_commit_node_bin_available 'jest'; then
        pre_commit_fail \
            'Jest is configured but not runnable in this repo' \
            '' \
            'Run your project install command or fix the local Jest setup before committing.'
        return 1
    fi

    echo "Running related Jest tests..."

    local jest_output=""
    local jest_exit=0
    jest_output=$(pre_commit_run_node_bin jest --bail --findRelatedTests --passWithNoTests "${js_files[@]}" 2>&1)
    jest_exit=$?

    if [ "$jest_exit" -ne 0 ]; then
        pre_commit_fail \
            'Related Jest tests failed' \
            "$jest_output" \
            'Fix the failing tests before committing.'
        return 1
    fi

    echo "Related Jest tests passed"
}
