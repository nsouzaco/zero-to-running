#!/bin/bash
# Kill processes using the expected service ports

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Expected ports (from config)
PORTS=(3000 3001 3002 5432 6379)

# Kill process on a specific port
kill_port() {
    local port=$1
    
    if ! command_exists lsof; then
        print_error "lsof is required but not installed"
        return 1
    fi
    
    # Find processes using the port
    local pids=$(lsof -ti :"$port" 2>/dev/null || echo "")
    
    if [ -z "$pids" ]; then
        print_info "Port $port is free"
        return 0
    fi
    
    print_warning "Found processes on port $port: $pids"
    
    # Kill each process
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            print_step "Killing process $pid on port $port"
            kill -9 "$pid" 2>/dev/null || true
            sleep 0.5
            if kill -0 "$pid" 2>/dev/null; then
                print_error "Failed to kill process $pid"
            else
                print_success "Killed process $pid on port $port"
            fi
        fi
    done
}

# Main execution
main() {
    echo "🔍 Checking for port conflicts..."
    echo ""
    
    local killed_any=false
    
    for port in "${PORTS[@]}"; do
        local pids=$(lsof -ti :"$port" 2>/dev/null || echo "")
        if [ -n "$pids" ]; then
            killed_any=true
            kill_port "$port"
        fi
    done
    
    echo ""
    
    if [ "$killed_any" = "true" ]; then
        print_success "Port conflicts resolved!"
        echo ""
        print_info "All expected ports are now free:"
        for port in "${PORTS[@]}"; do
            local pids=$(lsof -ti :"$port" 2>/dev/null || echo "")
            if [ -z "$pids" ]; then
                echo "  ✓ Port $port is free"
            else
                echo "  ✗ Port $port still in use by: $pids"
            fi
        done
    else
        print_success "No port conflicts found - all ports are free!"
    fi
    
    echo ""
    print_info "You can now run 'make dev' to start services"
}

main "$@"

