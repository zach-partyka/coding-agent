#!/bin/bash
# Ralph task wrapper - provides clean terminal UI
# Called by ralph-continuous.sh for each task

TASK_NUM=$1
PROJECT_DIR=$2
TASK_START_TS=$3
MARKER_DIR=$4

# Clear screen immediately
clear

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

# Display clean banner
PROJECT_NAME=$(basename "$PROJECT_DIR")
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Ralph Task #${TASK_NUM}${NC}"
echo -e "${BLUE}  Project: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}  Started: $(date -r $TASK_START_TS '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Change to project directory
cd "$PROJECT_DIR" || exit 1

# Invoke Ralph with clean prompt
claude --dangerously-skip-permissions --max-turns 50 "/ralph

Project directory: $PROJECT_DIR
Task start timestamp: $TASK_START_TS

When done: touch $MARKER_DIR/task-done
If sprint complete: touch $MARKER_DIR/sprint-complete"

# Capture end time and calculate duration
TASK_END_TS=$(date +%s)
TASK_DURATION=$(( (TASK_END_TS - TASK_START_TS) / 60 ))

# Show completion summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Task Complete${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "  Started:  $(date -r $TASK_START_TS '+%Y-%m-%d %H:%M:%S')"
echo -e "  Ended:    $(date -r $TASK_END_TS '+%Y-%m-%d %H:%M:%S')"
echo -e "  Duration: ${TASK_DURATION} minutes"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Close tab when ready${NC}"
echo ""
