#!/usr/bin/env bash
# Build AI prompt for commit message generation

build_prompt() {
    local diff="$1" excluded_context="${2:-}"

    cat <<EOF
Write ONLY the commit message in this exact format (no explanations, no preamble):

Brief summary of main change (50-72 chars max)

- Key change 1
- Key change 2
- Key change 3 (if needed)

Requirements:
- Start immediately with the summary line
- Use present tense
- Focus on WHAT/WHY not HOW
- Max 3-5 bullet points
- NO ticket numbers
- NO extra text or explanations

Staged changes:
${diff}${excluded_context}
EOF
}
