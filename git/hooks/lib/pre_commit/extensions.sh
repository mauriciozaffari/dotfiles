#!/usr/bin/env bash

pre_commit_load_project_extension() {
    local repo_root git_dir candidate

    repo_root="$(pre_commit_repo_root)" || return 1
    git_dir="$(pre_commit_git_dir)" || return 1

    for candidate in \
        "$repo_root/.githooks/pre-commit.local.sh" \
        "$git_dir/pre-commit.local.sh"
    do
        if [ -f "$candidate" ]; then
            if ! bash -n "$candidate"; then
                pre_commit_fail \
                    'Failed to parse project pre-commit extension' \
                    "$candidate" \
                    'Fix the project-specific hook extension before committing.'
                return 2
            fi

            # shellcheck disable=SC1090
            source "$candidate"
            if [ "$?" -ne 0 ]; then
                pre_commit_fail \
                    'Failed to load project pre-commit extension' \
                    "$candidate" \
                    'Fix the project-specific hook extension before committing.'
                return 2
            fi

            if ! declare -F pre_commit_project_checks >/dev/null 2>&1; then
                pre_commit_fail \
                    'Project pre-commit extension is misconfigured' \
                    "$candidate" \
                    'Define pre_commit_project_checks or remove the extension file.'
                return 2
            fi

            return 0
        fi
    done

    return 1
}

pre_commit_run_project_extension() {
    local load_status=0

    unset -f pre_commit_project_checks 2>/dev/null || true
    pre_commit_load_project_extension
    load_status=$?

    if [ "$load_status" -eq 2 ]; then
        return 1
    fi

    if [ "$load_status" -ne 0 ]; then
        return 0
    fi

    if declare -F pre_commit_project_checks >/dev/null 2>&1; then
        pre_commit_project_checks
        return $?
    fi

    return 0
}
