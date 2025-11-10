#!/bin/bash
# Setup port forwarding for services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Port forwarding PIDs file
PF_PIDS_FILE=".dev/port-forward.pids"
mkdir -p .dev

# Kill existing port forwards
kill_port_forwards() {
    if [ -f "$PF_PIDS_FILE" ]; then
        print_info "Stopping existing port forwards..."
        while read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done < "$PF_PIDS_FILE"
        rm -f "$PF_PIDS_FILE"
    fi
}

# Setup port forwarding for a service
setup_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    
    # Get service name
    local service_name=$(kubectl get svc -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$service_name" ]; then
        print_warning "Service $service not found, skipping port forward"
        return
    fi
    
    # Check if port is already in use
    if port_in_use "$local_port"; then
        print_warning "Port $local_port is already in use, skipping port forward for $service"
        return
    fi
    
    print_step "Setting up port forward for $service (localhost:$local_port -> $service_name:$remote_port)"
    
    # Start port forward in background
    kubectl port-forward -n "$NAMESPACE" "svc/$service_name" "$local_port:$remote_port" >/dev/null 2>&1 &
    local pf_pid=$!
    
    # Wait a moment to check if it started successfully
    sleep 1
    if ! kill -0 "$pf_pid" 2>/dev/null; then
        print_error "Failed to start port forward for $service"
        return 1
    fi
    
    # Save PID
    echo "$pf_pid" >> "$PF_PIDS_FILE"
    
    print_success "Port forward for $service started (PID: $pf_pid)"
}

# Main execution
main() {
    echo "Setting up port forwarding..."
    echo ""
    
    # Kill existing port forwards
    kill_port_forwards
    
    # Wait for services to be ready
    sleep 2
    
    # Setup port forwards
    # Get ports from config or use defaults
    local frontend_port=3001
    local backend_port=3000
    local postgres_port=5432
    local redis_port=6379
    
    if [ -f "dev-config.yaml" ]; then
        frontend_port=$(grep -E "^\s*frontend:" dev-config.yaml -A 1 | grep -E "^\s*port:" | awk '{print $2}' || echo "3001")
        backend_port=$(grep -E "^\s*backend:" dev-config.yaml -A 1 | grep -E "^\s*port:" | awk '{print $2}' || echo "3000")
        postgres_port=$(grep -E "^\s*postgres:" dev-config.yaml -A 1 | grep -E "^\s*port:" | awk '{print $2}' || echo "5432")
        redis_port=$(grep -E "^\s*redis:" dev-config.yaml -A 1 | grep -E "^\s*port:" | awk '{print $2}' || echo "6379")
    fi
    
    setup_port_forward "frontend" "$frontend_port" "$frontend_port"
    setup_port_forward "backend" "$backend_port" "$backend_port"
    setup_port_forward "postgres" "$postgres_port" 5432
    setup_port_forward "redis" "$redis_port" 6379
    
    echo ""
    print_success "Port forwarding setup complete!"
    print_info "Port forwards are running in the background"
    print_info "Run 'make dev-down' to stop port forwards"
}

main "$@"

