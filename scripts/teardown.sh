#!/bin/bash
# Teardown and stop services

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Uninstall Helm releases
uninstall_helm_releases() {
    print_step "Uninstalling Helm releases"
    
    # Check for single chart or multiple charts
    if helm list -n "$NAMESPACE" | grep -q "zero-to-running"; then
        local release_name="zero-to-running"
        if helm uninstall "$release_name" -n "$NAMESPACE" 2>/dev/null; then
            print_success "Uninstalled $release_name"
        else
            print_warning "Release $release_name not found or already uninstalled"
        fi
    else
        # Multiple charts
        local services=("frontend" "backend" "postgres" "redis")
        for service in "${services[@]}"; do
            if helm list -n "$NAMESPACE" | grep -q "$service"; then
                if helm uninstall "$service" -n "$NAMESPACE" 2>/dev/null; then
                    print_success "Uninstalled $service"
                fi
            fi
        done
    fi
}

# Clean up namespace
cleanup_namespace() {
    print_step "Cleaning up namespace: $NAMESPACE"
    
    # Delete remaining resources
    kubectl delete all --all -n "$NAMESPACE" 2>/dev/null || true
    
    # Wait for resources to be deleted
    sleep 5
    
    print_success "Namespace cleaned up"
}

# Stop port forwarding
stop_port_forwards() {
    local pf_pids_file=".dev/port-forward.pids"
    if [ -f "$pf_pids_file" ]; then
        print_step "Stopping port forwards"
        while read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done < "$pf_pids_file"
        rm -f "$pf_pids_file"
        print_success "Port forwards stopped"
    fi
}

# Stop Minikube (optional)
stop_minikube() {
    local stop_cluster=${STOP_CLUSTER:-false}
    
    if [ "$stop_cluster" = "true" ]; then
        print_step "Stopping Minikube cluster"
        minikube stop 2>/dev/null || true
        print_success "Minikube cluster stopped"
    else
        print_info "Minikube cluster is still running (set STOP_CLUSTER=true to stop it)"
    fi
}

# Main execution
main() {
    echo "Tearing down services..."
    echo ""
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_info "Namespace $NAMESPACE does not exist - nothing to tear down"
        exit 0
    fi
    
    stop_port_forwards
    uninstall_helm_releases
    cleanup_namespace
    
    echo ""
    print_success "Teardown complete!"
    
    # Optionally stop Minikube
    stop_minikube
}

main "$@"

