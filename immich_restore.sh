#!/bin/bash
set -euo pipefail

ENV_FILE="$(dirname "$0")/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo ".env file not found at $ENV_FILE"
  exit 1
fi

# Load .env file line by line
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  [[ -z "$key" || "$key" =~ ^# ]] && continue

  # Remove quotes around value if present
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"

  export "$key=$value"
done < "$ENV_FILE"

# Validate required environment variables
: "${UPLOAD_LOCATION:?UPLOAD_LOCATION not set in .env}"
: "${DB_DATA_LOCATION:?DB_DATA_LOCATION not set in .env}"
: "${DB_USERNAME:?DB_USERNAME not set in .env}"
: "${DB_DATABASE_NAME:?DB_DATABASE_NAME not set in .env}"

# Logging functions for consistent output formatting
log_info() {
  echo -e "\e[32m[INFO]\e[0m $1"
}

log_error() {
  echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# Check if the script is run as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
  fi
}

# Set the backup directory and ensure backups exist
setup_directories() {
  BACKUP_DIR="$UPLOAD_LOCATION/backups"
  
  if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup directory '$BACKUP_DIR' does not exist."
    exit 1
  fi

  # Find backup files (if none, exit)
  shopt -s nullglob
  backup_files=("$BACKUP_DIR"/*.sql.gz)
  shopt -u nullglob
  
  if [ ${#backup_files[@]} -eq 0 ]; then
    log_error "No backup files found in '$BACKUP_DIR'."
    exit 1
  fi
  }

# Extract a friendly date from the file's creation time (or modification time if necessary)
get_friendly_date() {
  local file="$1"
  local filename
  filename=$(basename "$file")

  # Try to extract ISO-style datetime (e.g. 20250731T020000)
  if [[ "$filename" =~ ([0-9]{8})T([0-9]{6}) ]]; then
    local raw_date="${BASH_REMATCH[1]}"
    local raw_time="${BASH_REMATCH[2]}"
    date -d "${raw_date} ${raw_time}" +'%d-%m-%Y %H:%M'

  # Fall back to decoding 13-digit epoch-based filenames (ms precision)
  elif [[ "$filename" =~ ([0-9]{13}) ]]; then
    local epoch_ms="${BASH_REMATCH[1]}"
    local epoch_sec=$((epoch_ms / 1000))
    date -d "@$epoch_sec" +'%d-%m-%Y %H:%M'

  else
    echo "Unknown"
  fi
}

# Present the backup selection menu with clear instructions and friendly aliases based on file creation date
select_backup() {
  log_info "Please select a backup file from the list below."
  echo "Enter the number corresponding to the backup you wish to restore."
  echo "If you don't see your desired backup, ensure that the file exists in:"
  echo "  $BACKUP_DIR"
  echo "-----------------------------------------------"

  # Create an array of friendly names based on the creation date of each file.
  friendly_names=()
  for file in "${backup_files[@]}"; do
    friendly_date=$(get_friendly_date "$file")
    friendly_names+=("Immich Backup $friendly_date")
  done

  # Use the select command to let the user choose from the friendly names.
  PS3="Enter your choice (number): "
  select option in "${friendly_names[@]}"; do
    if [ -n "${option:-}" ]; then
      # Map the selection to the corresponding backup file.
      index=$((REPLY - 1))
      BACKUP_FILE="${backup_files[$index]}"
      log_info "You selected: ${friendly_names[$index]}"
      break
    else
      log_error "Invalid selection. Please enter the number corresponding to your chosen backup."
    fi
  done
}

# Perform Docker operations and restore the backup
restore_backup() {
  log_info "Stopping Docker containers and removing volumes..."
  docker compose down -v

  log_info "Removing Postgres data directory: $DB_DATA_LOCATION"
  rm -rf "$DB_DATA_LOCATION"

  log_info "Pulling the latest Docker images..."
  docker compose pull

  log_info "Creating Docker containers..."
  docker compose create

  log_info "Starting the Postgres container..."
  docker start immich_postgres

  log_info "Waiting for Postgres to become ready..."
  local max_wait=30
  local wait_time=0
  until docker exec immich_postgres pg_isready -U "$DB_USERNAME" >/dev/null 2>&1 || [ "$wait_time" -ge "$max_wait" ]; do
    sleep 2
    wait_time=$((wait_time + 2))
  done

  if ! docker exec immich_postgres pg_isready -U "$DB_USERNAME" >/dev/null 2>&1; then
    log_error "Postgres did not become ready in time."
    exit 1
  fi

  log_info "Restoring backup from file: $BACKUP_FILE"
  gunzip < "$BACKUP_FILE" \
    | sed "s/SELECT pg_catalog.set_config('search_path', '', false);/SELECT pg_catalog.set_config('search_path', 'public, pg_catalog', true);/g" \
    | docker exec -i immich_postgres psql --dbname="$DB_DATABASE_NAME" --username="$DB_USERNAME"

  log_info "Starting remaining Docker services..."
  docker compose up -d

  log_info "Immich services have been started successfully."
}

# Main function to coordinate the script's execution
main() {
  check_root
  setup_directories
  select_backup
  restore_backup
}

# Execute the main function
main
