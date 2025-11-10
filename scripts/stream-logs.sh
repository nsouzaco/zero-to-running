#!/bin/bash
# Stream logs from services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}
SERVICE=${2:-""}

# Stream logs for a specific service
stream_service_logs() {
    local service=$1
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod" ]; then
        print_error "Service $service not found or not deployed"
        exit 1
    fi
    
    print_info "Streaming logs for $service (pod: $pod)"
    echo "Press Ctrl+C to stop"
    echo ""
    
    kubectl logs -n "$NAMESPACE" -f "$pod" 2>/dev/null || {
        print_error "Failed to stream logs for $service"
        exit 1
    }
}

# Stream logs for all services
stream_all_logs() {
    print_info "Streaming logs for all services"
    echo "Press Ctrl+C to stop"
    echo ""
    
    local services=("postgres" "redis" "backend" "frontend")
    local pids=()
    
    # Start log streaming for each service in background
    for service in "${services[@]}"; do
        local pod=$(kubectl get pods -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$pod" ]; then
            (
                echo "=== $service ($pod) ==="
                kubectl logs -n "$NAMESPACE" -f "$pod" 2>/dev/null || true
            ) &
            pids+=($!)
        fi
    done
    
    # Wait for all background processes
    trap "kill ${pids[*]} 2>/dev/null; exit" INT TERM
    wait
}

# Main execution
main() {
    if [ -z "$SERVICE" ] || [ "$SERVICE" = "all" ]; then
        stream_all_logs
    else
        stream_service_logs "$SERVICE"
    fi
}

main "$@"

