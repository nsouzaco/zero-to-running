#!/bin/bash
# Utility functions for Zero-to-Running CLI

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Symbols
CHECKMARK="✓"
CROSS="✗"
SPINNER="⏳"
ROCKET="🚀"
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"

# Print success message
print_success() {
    echo -e "${GREEN}${CHECKMARK} ${1}${NC}"
}

# Print error message
print_error() {
    echo -e "${RED}${ERROR} ${1}${NC}" >&2
}

# Print warning message
print_warning() {
    echo -e "${YELLOW}${WARNING} ${1}${NC}"
}

# Print info message
print_info() {
    echo -e "${BLUE}ℹ️  ${1}${NC}"
}

# Print step message
print_step() {
    echo -e "${SPINNER} ${1}..."
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if port is in use
port_in_use() {
    local port=$1
    if command_exists lsof; then
        lsof -i :"$port" >/dev/null 2>&1
    elif command_exists netstat; then
        netstat -an | grep -q ":$port " 2>/dev/null
    else
        return 1
    fi
}

# Get OS type
get_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Get architecture
get_arch() {
    case "$(uname -m)" in
        x86_64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Log error to file
log_error() {
    local message="$1"
    local log_file=".dev/logs/errors-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p .dev/logs
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $message" >> "$log_file"
    echo "$log_file"
}

# Exit with error code and message
exit_with_error() {
    local code=${1:-1}
    local message="${2:-Unknown error}"
    print_error "$message"
    log_error "$message"
    exit "$code"
}

# Wait for service to be ready
wait_for_service() {
    local namespace=$1
    local service=$2
    local max_attempts=${3:-60}
    local attempt=0
    
    print_step "Waiting for $service to be ready"
    
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get pods -n "$namespace" -l app="$service" -o jsonpath='{.items[0].status.phase}' 2>/dev/null | grep -q "Running"; then
            if kubectl get pods -n "$namespace" -l app="$service" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"; then
                print_success "$service is ready"
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    print_error "$service failed to become ready after $((max_attempts * 2)) seconds"
    return 1
}

