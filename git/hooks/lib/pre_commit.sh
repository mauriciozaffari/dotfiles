#!/usr/bin/env bash

source "$LIB_DIR/pre_commit/core.sh"
source "$LIB_DIR/pre_commit/files.sh"
source "$LIB_DIR/pre_commit/ruby.sh"
source "$LIB_DIR/pre_commit/node.sh"
source "$LIB_DIR/pre_commit/extensions.sh"

pre_commit_main() {
    pre_commit_check_yaml_syntax || return 1
    pre_commit_check_json_syntax || return 1
    pre_commit_check_rspec_failures || return 1
    pre_commit_check_rubocop || return 1
    pre_commit_check_biome || return 1
    pre_commit_check_jest || return 1
    pre_commit_run_project_extension || return 1
    pre_commit_warn_untracked_files

    echo ""
    echo "${pre_commit_green}All pre-commit checks passed${pre_commit_nc}"
    return 0
}
