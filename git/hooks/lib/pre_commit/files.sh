#!/usr/bin/env bash

pre_commit_collect_staged_files() {
    local -n output_files="$1"
    shift

    local file
    output_files=()

    while IFS= read -r -d '' file; do
        [ -f "$file" ] && output_files+=("$file")
    done < <(git diff --cached --name-only --diff-filter=ACMR -z -- "$@")
}

pre_commit_validate_json_file() {
    local file="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 -m json.tool "$file" >/dev/null 2>&1
        return $?
    fi

    if command -v ruby >/dev/null 2>&1; then
        ruby -rjson -e 'JSON.parse(File.read(ARGV[0]))' "$file" >/dev/null 2>&1
        return $?
    fi

    return 2
}

pre_commit_validate_yaml_file() {
    local file="$1"

    if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
        python3 - "$file" <<'PY' >/dev/null 2>&1
import sys
import yaml


class PermissiveLoader(yaml.SafeLoader):
    pass


PermissiveLoader.add_multi_constructor('!', lambda loader, suffix, node: None)

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    yaml.load(handle, Loader=PermissiveLoader)
PY
        return $?
    fi

    if command -v ruby >/dev/null 2>&1; then
        ruby -rpsych -e 'Psych.parse_stream(File.read(ARGV[0]))' "$file" >/dev/null 2>&1
        return $?
    fi

    return 2
}

pre_commit_check_json_syntax() {
    local -a json_files=()
    pre_commit_collect_staged_files json_files '*.json'

    [ ${#json_files[@]} -eq 0 ] && return 0

    echo "Checking JSON syntax..."

    local json_error=0 validation_status file
    for file in "${json_files[@]}"; do
        pre_commit_validate_json_file "$file"
        validation_status=$?

        if [ "$validation_status" -eq 2 ]; then
            echo "${pre_commit_yellow}Skipping JSON syntax check: python3 or ruby is required${pre_commit_nc}"
            return 0
        fi

        if [ "$validation_status" -ne 0 ]; then
            echo "${pre_commit_red}✗ Invalid JSON: $file${pre_commit_nc}"
            json_error=1
        fi
    done

    if [ "$json_error" -eq 1 ]; then
        echo ""
        echo "Fix the JSON syntax errors before committing."
        pre_commit_print_bypass_help
        return 1
    fi

    echo "${pre_commit_green}✓ JSON syntax valid${pre_commit_nc}"
}

pre_commit_check_yaml_syntax() {
    local -a yaml_files=()
    pre_commit_collect_staged_files yaml_files '*.yml' '*.yaml'

    [ ${#yaml_files[@]} -eq 0 ] && return 0

    echo "Checking YAML syntax..."

    local yaml_error=0 validation_status file
    for file in "${yaml_files[@]}"; do
        pre_commit_validate_yaml_file "$file"
        validation_status=$?

        if [ "$validation_status" -eq 2 ]; then
            echo "${pre_commit_yellow}Skipping YAML syntax check: python3+PyYAML or ruby is required${pre_commit_nc}"
            return 0
        fi

        if [ "$validation_status" -ne 0 ]; then
            echo "${pre_commit_red}✗ Invalid YAML: $file${pre_commit_nc}"
            yaml_error=1
        fi
    done

    if [ "$yaml_error" -eq 1 ]; then
        echo ""
        echo "Fix the YAML syntax errors before committing."
        pre_commit_print_bypass_help
        return 1
    fi

    echo "${pre_commit_green}✓ YAML syntax valid${pre_commit_nc}"
}

pre_commit_warn_untracked_files() {
    local untracked
    untracked=$(git ls-files --others --exclude-standard)

    [ -n "$untracked" ] || return 0

    local untracked_count
    untracked_count=$(printf '%s\n' "$untracked" | wc -l)

    echo ""
    echo "${pre_commit_yellow}$untracked_count untracked file(s) won't be included in this commit:${pre_commit_nc}"
    printf '%s\n' "$untracked" | head -10
    if [ "$untracked_count" -gt 10 ]; then
        echo "... and $((untracked_count - 10)) more"
    fi
    echo ""
    echo "Use ${pre_commit_yellow}git add${pre_commit_nc} to include them, or ignore this if intentional."
}
