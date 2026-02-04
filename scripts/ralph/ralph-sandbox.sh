#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop (Docker Sandbox version)
# Usage: ./ralph-sandbox.sh [max_iterations]
#
# Examples:
#   ./ralph-sandbox.sh              # 10 iterations (default)
#   ./ralph-sandbox.sh 5            # 5 iterations
#
# Requirements:
#   - Docker Desktop 4.56+ with sandbox support
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
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
SESSION_OUTPUT_DIR="$SCRIPT_DIR/.claude-sessions"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

echo "Starting Ralph (Docker Sandbox) - Max iterations: $MAX_ITERATIONS"

# Function to cleanup Docker sandbox containers and exit
cleanup_and_exit() {
  local exit_code=$1
  echo ""
  echo "Cleaning up Docker sandbox containers..."
  docker sandbox rm $(docker sandbox ls -q) 2>/dev/null || true
  echo "Cleanup complete. Exiting with code $exit_code."
  exit $exit_code
}

# Initialize session output directory
mkdir -p "$SESSION_OUTPUT_DIR"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "==============================================================="

  # Run Claude Code in Docker Sandbox
  # Use @file syntax to pass prompt file, run in interactive mode (no -d flag)
  OUTPUT=$(docker sandbox run --credentials=none \
    -e ANTHROPIC_AUTH_TOKEN=e1a74e76d64e4f85b3311bb6a31eb2e3.GXrduWsnzfbny7oJ \
    -e ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic \
    -e API_TIMEOUT_MS=3000000 \
    -e CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 \
    -e ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air \
    -e ANTHROPIC_DEFAULT_SONNET_MODEL=glm-4.7 \
    -e ANTHROPIC_DEFAULT_OPUS_MODEL=glm-4.7 \
    claude --dangerously-skip-permissions -p "@$SCRIPT_DIR/CLAUDE.md" 2>&1) || true
  echo "$OUTPUT"

  # Save session output to file for Obsidian sync
  SESSION_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  SESSION_OUTPUT_FILE="$SESSION_OUTPUT_DIR/session-${SESSION_TIMESTAMP}-iteration-${i}.txt"
  echo "$OUTPUT" > "$SESSION_OUTPUT_FILE"
  echo "Session output saved to: $SESSION_OUTPUT_FILE"

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    cleanup_and_exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
cleanup_and_exit 1
