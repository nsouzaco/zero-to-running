#!/bin/bash
# Wait for all services to be healthy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Services to check (adjust based on your Helm chart)
SERVICES=("postgres" "redis" "backend" "frontend")

# Check service health
check_service_health() {
    local service=$1
    local max_attempts=60
    local attempt=0
    local start_time=$(date +%s)
    
    print_step "Waiting for $service to be healthy"
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if pod exists and is running
        local pod_status=$(kubectl get pods -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
        
        # Check for error states
        if [ "$pod_status" = "Error" ] || [ "$pod_status" = "CrashLoopBackOff" ]; then
            print_error "$service is in error state: $pod_status"
            show_pod_details "$service"
            return 1
        fi
        
        if [ "$pod_status" = "Running" ]; then
            # Check if pod is ready
            local ready=$(kubectl get pods -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
            
            if [ "$ready" = "True" ]; then
                local elapsed=$(($(date +%s) - start_time))
                print_success "$service is healthy (took ${elapsed}s)"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        if [ $((attempt % 10)) -eq 0 ]; then
            local elapsed=$(($(date +%s) - start_time))
            print_info "Still waiting for $service... (${elapsed}s elapsed, attempt ${attempt}/${max_attempts})"
        fi
        sleep 2
    done
    
    local elapsed=$(($(date +%s) - start_time))
    print_error "$service failed to become healthy after ${elapsed}s"
    
    # Show pod status for debugging
    show_pod_details "$service"
    
    return 1
}

# Show pod details for debugging
show_pod_details() {
    local service=$1
    
    echo ""
    print_info "Pod status for $service:"
    kubectl get pods -n "$NAMESPACE" -l app="$service" 2>/dev/null || true
    echo ""
    print_info "Recent events:"
    kubectl get events -n "$NAMESPACE" --field-selector involvedObject.kind=Pod --sort-by='.lastTimestamp' | grep "$service" | tail -5 || true
    echo ""
    print_info "Pod description:"
    kubectl describe pods -n "$NAMESPACE" -l app="$service" 2>/dev/null | tail -30 || true
}

# Main execution
main() {
    echo "Waiting for services to be healthy..."
    echo ""
    
    local failed_services=()
    
    for service in "${SERVICES[@]}"; do
        # Check if service is enabled (skip if not deployed)
        if ! kubectl get pods -n "$NAMESPACE" -l app="$service" >/dev/null 2>&1; then
            print_info "Skipping $service (not deployed)"
            continue
        fi
        
        if ! check_service_health "$service"; then
            failed_services+=("$service")
        fi
    done
    
    echo ""
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_success "All services are healthy!"
        return 0
    else
        print_error "Some services failed to become healthy: ${failed_services[*]}"
        exit_with_error 4 "Service health check failed"
    fi
}

main "$@"

