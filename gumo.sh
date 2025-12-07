#!/usr/bin/env bash

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

# 3. Define a cleanup function to handle Ctrl+C or script exit
cleanup() {
  echo ""
  echo "Exiting..."

  # If the process is currently paused, we must resume it
  # before we can kill it gracefully with SIGTERM.
  if [ "$paused" = true ]; then
    kill -SIGCONT "$cmd_pid" 2>/dev/null
  fi

  # Kill the process if it is still running
  if kill -0 "$cmd_pid" 2>/dev/null; then
    kill "$cmd_pid" 2>/dev/null
    wait "$cmd_pid" 2>/dev/null # Wait to prevent zombies
  fi

  # Restore cursor visibility just in case
  tput cnorm
  exit
}

# Fix: Split the traps
# 1. On Ctrl+C or Terminate, just force an exit.
trap "exit 1" SIGINT SIGTERM

# 2. On ANY exit (including the one caused above), run cleanup.
trap cleanup EXIT

# 4. Main Loop
while true; do
  # Check if the child process has finished naturally
  if ! kill -0 "$cmd_pid" 2>/dev/null; then
    echo ""
    echo "Command finished."
    break
  fi

  # Read input with a timeout (-t) so we can keep checking if the process died
  # -t 0.5 waits 0.5 seconds for input, then loops again
  read -t 0.5 -n1 -s key

  case "$key" in
    p)
      if [ "$paused" = false ]; then
        kill -SIGSTOP "$cmd_pid"
        paused=true
        printf "Status: Paused \n"
      fi
      ;;
    r)
      if [ "$paused" = true ]; then
        kill -SIGCONT "$cmd_pid"
        paused=false
        # Move up 1 line and clear it
        printf "\033[1A\033[K"
      fi
      ;;
    q)
      # The 'trap' logic will handle the actual killing when we exit
      exit 0
      ;;
  esac
done