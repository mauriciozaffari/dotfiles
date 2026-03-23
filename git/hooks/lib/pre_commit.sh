#!/usr/bin/env bash

pre_commit_main() {
    local red='\033[0;31m'
    local yellow='\033[1;33m'
    local nc='\033[0m'
    local examples_file="spec/examples.txt"

    if [ -f "$examples_file" ]; then
        local failed_count
        failed_count=$(grep -c "| failed" "$examples_file" 2>/dev/null || echo "0")

        if [ "$failed_count" -gt 0 ] 2>/dev/null; then
            echo "${red}Cannot commit: You have $failed_count failing test(s)${nc}"
            echo ""
            echo "Failed examples:"
            grep "| failed" "$examples_file" | head -10
            if [ "$failed_count" -gt 10 ]; then
                echo "... and $((failed_count - 10)) more"
            fi
            echo ""
            echo "Fix the failing tests before committing, or run:"
            echo "  bin/run rspec --only-failures"
            echo ""
            echo "To bypass this check (not recommended):"
            echo "  git commit --no-verify"
            return 1
        fi

        echo "No failing tests detected"
    fi

    if command -v rubocop >/dev/null 2>&1 || [ -f "Gemfile" ]; then
        echo "Checking RuboCop..."
        local rubocop_output rubocop_exit
        if command -v bin/run >/dev/null 2>&1; then
            rubocop_output=$(bin/run rubocop 2>&1)
            rubocop_exit=$?
        elif command -v bundle >/dev/null 2>&1 && bundle show rubocop >/dev/null 2>&1; then
            rubocop_output=$(bundle exec rubocop 2>&1)
            rubocop_exit=$?
        else
            rubocop_exit=0
        fi

        if [ "${rubocop_exit:-0}" -ne 0 ]; then
            echo "${red}Cannot commit: RuboCop offenses detected${nc}"
            echo ""
            echo "$rubocop_output"
            echo ""
            echo "Fix the offenses before committing, or run:"
            echo "  bin/run rubocop -A  # to auto-correct"
            echo ""
            echo "To bypass this check (not recommended):"
            echo "  git commit --no-verify"
            return 1
        fi

        echo "No RuboCop offenses detected"
    fi

    local untracked
    untracked=$(git ls-files --others --exclude-standard)
    if [ -n "$untracked" ]; then
        local untracked_count
        untracked_count=$(echo "$untracked" | wc -l)
        echo ""
        echo "${yellow}$untracked_count untracked file(s) won't be included in this commit:${nc}"
        echo "$untracked" | head -10
        if [ "$untracked_count" -gt 10 ]; then
            echo "... and $((untracked_count - 10)) more"
        fi
        echo ""
        echo "Use ${yellow}git add${nc} to include them, or ignore this if intentional."
    fi

    return 0
}
