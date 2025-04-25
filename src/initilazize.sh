#!/bin/bash
set -e

# Log function for debugging
log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  # echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /tmp/envio_init.log
}

log_message "Script started with arguments: $@"

# Parse arguments
NAME=""
LANGUAGE=""
OUTPUT_DIR=""
CONTRACT_ADDRESS=""
NETWORK=""
API_TOKEN=""

# Process arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --name|-n)
      NAME="$2"
      shift 2
      ;;
    --language|-l)
      LANGUAGE="$2"
      shift 2
      ;;
    --output-dir|-d)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --contract-address|-c)
      CONTRACT_ADDRESS="$2"
      shift 2
      ;;
    --network|-b)
      NETWORK="$2"
      shift 2
      ;;
    --api-token)
      API_TOKEN="$2"
      shift 2
      ;;
    *)
      log_message "Unknown argument: $1"
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$NAME" ]]; then
  log_message "Error: name is required"
  echo "Error: name is required"
  exit 1
fi

if [[ -z "$LANGUAGE" ]]; then
  log_message "Error: language is required"
  echo "Error: language is required"
  exit 1
fi

if [[ -z "$CONTRACT_ADDRESS" ]]; then
  log_message "Error: contract address is required"
  echo "Error: contract address is required"
  exit 1
fi

if [[ -z "$NETWORK" ]]; then
  log_message "Error: network is required"
  echo "Error: network is required"
  exit 1
fi

if [[ -z "$API_TOKEN" ]]; then
  log_message "Error: API token is required"
  echo "Error: API token is required"
  exit 1
fi

# Set default output directory if not provided
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="$HOME/envio/$NAME"
  log_message "Using default output directory: $OUTPUT_DIR"
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
log_message "Created directory: $OUTPUT_DIR"

# Build the command
### TODO: add --all-events and --single-contract back once they work (and simplify this script at ton!)
COMMAND="pnpx envio init contract-import explorer -n $NAME -l $LANGUAGE -d $OUTPUT_DIR -c $CONTRACT_ADDRESS -b $NETWORK --api-token $API_TOKEN"
log_message "Command: $COMMAND"

# Execute with expect-like behavior using temporary fifo
FIFO="/tmp/envio_fifo_$$"
mkfifo "$FIFO"

# Start the command in background with input redirected from FIFO
$COMMAND < "$FIFO" > /tmp/envio_output_manual.log 2>&1 &
# $COMMAND < "$FIFO" > /tmp/envio_output_$$.log 2>&1 &
PID=$!
log_message "Started command with PID: $PID"

# Function to send newline after delay
send_enter_with_delay() {
  sleep $1
  echo >> "$FIFO"
  log_message "Sent Enter keypress after $1 seconds"
}

# Send multiple Enter keypresses with delays
send_enter_with_delay 3
send_enter_with_delay 3
# send_enter_with_delay 3
# send_enter_with_delay 3
# send_enter_with_delay 3

# Close the FIFO (this is important!)
exec 3>"$FIFO"
exec 3>&-
rm "$FIFO"

# Wait for the process to complete
wait $PID || true
EXIT_CODE=$?
log_message "Command completed with exit code: $EXIT_CODE"

# Check if the process succeeded
if [[ $EXIT_CODE -ne 0 ]]; then
  log_message "Command failed with exit code: $EXIT_CODE"
  echo "Failed to initialize Envio indexer. Check the log at /tmp/envio_output_$$.log for details."
  cat /tmp/envio_output_$$.log >> /tmp/envio_init.log
  exit $EXIT_CODE
fi

# Verify that the initialization was successful
if grep -q "Initialization complete" /tmp/envio_output_$$.log || grep -q "Successfully" /tmp/envio_output_$$.log; then
  log_message "Initialization successful"
  echo "Successfully initialized Envio indexer \"$NAME\" in $OUTPUT_DIR"
  cat /tmp/envio_output_$$.log >> /tmp/envio_init.log
  exit 0
else
  # Try alternative approach if the command appears to have stalled
  log_message "Initialization not confirmed, trying alternative approach"
  
  # Kill any remaining processes
  kill $PID 2>/dev/null || true
  
  # Try the alternative approach using 'yes'
  log_message "Running alternative approach with 'yes'"
  yes "" | head -n 10 | (sleep 2 && cat) | $COMMAND > /tmp/envio_output_alt_$$.log 2>&1
  
  # Check if the alternative approach succeeded
  if grep -q "Initialization complete" /tmp/envio_output_alt_$$.log || grep -q "Successfully" /tmp/envio_output_alt_$$.log; then
    log_message "Alternative approach successful"
    echo "Successfully initialized Envio indexer \"$NAME\" in $OUTPUT_DIR"
    cat /tmp/envio_output_alt_$$.log >> /tmp/envio_init.log
    exit 0
  else
    log_message "All approaches failed"
    echo "Failed to initialize Envio indexer. Check the logs at /tmp/envio_output_$$.log and /tmp/envio_output_alt_$$.log for details."
    cat /tmp/envio_output_alt_$$.log >> /tmp/envio_init.log
    exit 1
  fi
fi

