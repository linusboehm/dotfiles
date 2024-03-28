#!/bin/bash

# skip first two lines (commit message and empty line)
read LINE
echo $LINE
read LINE
echo $LINE

INPUT=$(cat)

COMMENT_LINE=$(echo "$INPUT" | grep -n '^#' | head -n 1 | cut -d: -f1)

# format up until last line before first comment line
echo "$INPUT" | head -n $(($COMMENT_LINE - 1)) | prettier --parser markdown --print-width 72 --prose-wrap always

# only add empty line, if there's a commit message body
if [[ $COMMENT_LINE -ne 1 ]]; then
  echo
fi

# just echo the rest unchanged
echo "$INPUT" | tail -n +$COMMENT_LINE
