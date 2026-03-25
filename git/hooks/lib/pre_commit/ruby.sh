#!/usr/bin/env bash

pre_commit_has_ruby_context() {
    if [ -f Gemfile ] || [ -f .rubocop.yml ] || [ -f .rubocop.yaml ] || [ -f Rakefile ] || [ -f config.ru ]; then
        return 0
    fi

    local -a ruby_files=()
    pre_commit_collect_staged_files ruby_files '*.rb' '*.rake' '*.gemspec' 'Gemfile' 'Rakefile' 'config.ru'
    [ ${#ruby_files[@]} -gt 0 ]
}

pre_commit_rubocop_configured() {
    [ -x bin/rubocop ] && return 0
    [ -f .rubocop.yml ] && return 0
    [ -f .rubocop.yaml ] && return 0

    if grep -Eq "^[[:space:]]*gem ['\"]rubocop" Gemfile 2>/dev/null; then
        return 0
    fi

    if grep -Eq "^[[:space:]]{4}rubocop \(" Gemfile.lock 2>/dev/null; then
        return 0
    fi

    return 1
}

pre_commit_check_rspec_failures() {
    local examples_file="spec/examples.txt"

    [ -f "$examples_file" ] || return 0

    local failed_count
    failed_count=$(grep -c '| failed' "$examples_file" 2>/dev/null)
    failed_count=${failed_count:-0}

    if [ "$failed_count" -gt 0 ] 2>/dev/null; then
        local failed_examples extra_failures output hint
        failed_examples=$(grep '| failed' "$examples_file" | head -10)

        extra_failures=""
        if [ "$failed_count" -gt 10 ]; then
            extra_failures=$(printf '\n... and %s more' "$((failed_count - 10))")
        fi

        output=$(printf 'Failed examples:\n%s%s' "$failed_examples" "$extra_failures")
        hint=$(printf 'Fix the failing tests before committing, or run:\n  bin/run rspec --only-failures')

        pre_commit_fail "You have $failed_count failing test(s)" "$output" "$hint"
        return 1
    fi

    echo "No failing tests detected"
}

pre_commit_check_rubocop() {
    if ! pre_commit_has_ruby_context; then
        return 0
    fi

    echo "Checking RuboCop..."

    local rubocop_output=""
    local rubocop_exit=0
    local ran_rubocop=0

    if [ -x bin/rubocop ]; then
        rubocop_output=$(bin/rubocop 2>&1)
        rubocop_exit=$?
        ran_rubocop=1
    elif command -v bin/run >/dev/null 2>&1; then
        rubocop_output=$(bin/run rubocop 2>&1)
        rubocop_exit=$?
        ran_rubocop=1
    elif [ -f Gemfile ] && command -v bundle >/dev/null 2>&1 && bundle show rubocop >/dev/null 2>&1; then
        rubocop_output=$(bundle exec rubocop 2>&1)
        rubocop_exit=$?
        ran_rubocop=1
    elif command -v rubocop >/dev/null 2>&1 && rubocop --version >/dev/null 2>&1; then
        rubocop_output=$(rubocop 2>&1)
        rubocop_exit=$?
        ran_rubocop=1
    else
        if pre_commit_rubocop_configured; then
            pre_commit_fail \
                'RuboCop is configured but not runnable' \
                '' \
                'Install project Ruby dependencies or fix the RuboCop setup before committing.'
            return 1
        fi

        echo "Skipping RuboCop: no runnable RuboCop setup found"
        return 0
    fi

    if [ "$ran_rubocop" -eq 1 ] && [ "$rubocop_exit" -ne 0 ]; then
        pre_commit_fail \
            'RuboCop offenses detected' \
            "$rubocop_output" \
            'Fix the offenses before committing, or run:
  bin/run rubocop -A  # to auto-correct'
        return 1
    fi

    echo "No RuboCop offenses detected"
}
