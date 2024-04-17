#!/bin/bash

# skip first two lines (commit message and empty line)
read -r LINE
echo "$LINE"
read -r LINE
echo "$LINE"

INPUT=$(cat)

COMMENT_LINE=$(echo "$INPUT" | grep -n '^#' | head -n 1 | cut -d: -f1)

# format up until last line before first comment line
echo "$INPUT" | head -n $(($COMMENT_LINE - 1)) | prettier --parser markdown --print-width 72 --prose-wrap always

# only add empty line, if there's a commit message body
if [[ $COMMENT_LINE -ne 1 ]]; then
  echo
fi

# just echo the rest unchanged
echo "$INPUT" | tail -n +"$COMMENT_LINE"

cat << EOF
#
# ---
# feat: (new feature for the user, not a new feature for build script)
# fix: (bug fix for the user, not a fix to a build script)
# docs: (changes to the documentation)
# style: (formatting, missing semi colons, etc; no production code change)
# refactor: (refactoring production code, eg. renaming a variable)
# test: (adding missing tests, refactoring tests; no production code change)
# chore: (updating grunt tasks etc; no production code change)"""
# ---
EOF
