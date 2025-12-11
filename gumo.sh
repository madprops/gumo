#!/usr/bin/env bash

# Enable job control.
# This ensures the background process starts in its own Process Group.
set -m

# 1. Check arguments
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <command> [args...]"
  exit 1
fi

# 2. Run the command directly in the background
"$@" &
cmd_pid=$!

# Initialize state
paused=false

# 3. Define a cleanup function
cleanup() {
  echo ""
  echo "Exiting..."

  # Resume the process group if paused so it can receive the kill signal
  if [ "$paused" = true ]; then
    kill -SIGCONT -- "-$cmd_pid" 2>/dev/null
  fi

  # Kill the entire process group (note the negative PID)
  if kill -0 "$cmd_pid" 2>/dev/null; then
    # Using negative PID targets the process group
    kill -- "-$cmd_pid" 2>/dev/null
    wait "$cmd_pid" 2>/dev/null
  fi

  tput cnorm
  exit
}

# Fix: Split the traps
trap "exit 1" SIGINT SIGTERM
trap cleanup EXIT

# 4. Main Loop
while true; do
  # Check if the process has finished naturally
  if ! kill -0 "$cmd_pid" 2>/dev/null; then
    echo ""
    echo "Command finished."
    break
  fi

  # Read input with timeout
  read -t 0.5 -n1 -s key

  case "$key" in
    p)
      if [ "$paused" = false ]; then
        # Send SIGSTOP to the Process Group (negative PID)
        kill -SIGSTOP -- "-$cmd_pid"
        paused=true
        printf "Status: Paused \n"
      fi
      ;;
    r)
      if [ "$paused" = true ]; then
        # Send SIGCONT to the Process Group (negative PID)
        kill -SIGCONT -- "-$cmd_pid"
        paused=false
        printf "\033[1A\033[K"
      fi
      ;;
    q)
      exit 0
      ;;
  esac
done