#!/bin/bash
# Ralph Business - Long-running AI agent loop for business tasks
# Usage: ./ralph-business.sh [max_iterations]
#
# Examples:
#   ./ralph-business.sh              # 10 iterations (default)
#   ./ralph-business.sh 5            # 5 iterations
#
# Requirements:
#   - Claude Code installed
#   - jq installed
#   - Run from your project directory

set -e

# Parse arguments
MAX_ITERATIONS=10

while [[ $# -gt 0 ]]; do
  case $1 in
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_PROJECT_FILE="$SCRIPT_DIR/.last-project"
SESSION_OUTPUT_DIR="$SCRIPT_DIR/.claude-sessions"
OUTPUT_DIR="$SCRIPT_DIR/outputs"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Archive previous run if project changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_PROJECT_FILE" ]; then
  CURRENT_PROJECT=$(jq -r '.projectName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_PROJECT=$(cat "$LAST_PROJECT_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_PROJECT" ] && [ -n "$LAST_PROJECT" ] && [ "$CURRENT_PROJECT" != "$LAST_PROJECT" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$LAST_PROJECT"

    echo "Archiving previous run: $LAST_PROJECT"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    [ -d "$OUTPUT_DIR" ] && cp -r "$OUTPUT_DIR" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Business Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
    
    # Clear outputs for new project
    rm -rf "$OUTPUT_DIR"/*
  fi
fi

# Track current project
if [ -f "$PRD_FILE" ]; then
  CURRENT_PROJECT=$(jq -r '.projectName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_PROJECT" ]; then
    echo "$CURRENT_PROJECT" > "$LAST_PROJECT_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Business Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph Business - Max iterations: $MAX_ITERATIONS"
echo "PRD: $PRD_FILE"
echo "Outputs: $OUTPUT_DIR"

# Initialize session output directory
mkdir -p "$SESSION_OUTPUT_DIR"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Business Iteration $i of $MAX_ITERATIONS"
  echo "==============================================================="

  # Run Claude Code
  OUTPUT=$(claude --dangerously-skip-permissions -p "@$SCRIPT_DIR/CLAUDE.md" 2>&1) || true
  echo "$OUTPUT"

  # Save session output to file
  SESSION_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  SESSION_OUTPUT_FILE="$SESSION_OUTPUT_DIR/session-${SESSION_TIMESTAMP}-iteration-${i}.txt"
  echo "$OUTPUT" > "$SESSION_OUTPUT_FILE"
  echo "Session output saved to: $SESSION_OUTPUT_FILE"

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph Business completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    echo "Outputs saved to: $OUTPUT_DIR"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph Business reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
