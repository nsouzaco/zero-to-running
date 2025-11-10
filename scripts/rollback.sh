#!/bin/bash
# Automatic rollback on deployment failure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Rollback Helm release
rollback_helm_release() {
    local release_name=$1
    
    print_warning "Rolling back Helm release: $release_name"
    
    if helm list -n "$NAMESPACE" | grep -q "$release_name"; then
        # Try to rollback to previous revision
        if helm history "$release_name" -n "$NAMESPACE" 2>/dev/null | grep -q "REVISION"; then
            local previous_revision=$(helm history "$release_name" -n "$NAMESPACE" --max 2 2>/dev/null | tail -1 | awk '{print $1}' || echo "")
            if [ -n "$previous_revision" ] && [ "$previous_revision" != "REVISION" ]; then
                helm rollback "$release_name" "$previous_revision" -n "$NAMESPACE" 2>/dev/null || true
                print_info "Rolled back to revision $previous_revision"
            else
                # No previous revision, uninstall
                helm uninstall "$release_name" -n "$NAMESPACE" 2>/dev/null || true
                print_info "Uninstalled release (no previous revision to rollback to)"
            fi
        else
            # New installation, just uninstall
            helm uninstall "$release_name" -n "$NAMESPACE" 2>/dev/null || true
            print_info "Uninstalled new release"
        fi
    fi
}

# Clean up partially deployed resources
cleanup_partial_deployment() {
    print_step "Cleaning up partially deployed resources"
    
    # Stop port forwards
    local pf_pids_file=".dev/port-forward.pids"
    if [ -f "$pf_pids_file" ]; then
        while read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
        done < "$pf_pids_file"
        rm -f "$pf_pids_file"
    fi
    
    # Delete any pods that might be stuck
    kubectl delete pods --all -n "$NAMESPACE" --grace-period=0 --force 2>/dev/null || true
    
    # Clean up services
    kubectl delete svc --all -n "$NAMESPACE" 2>/dev/null || true
    
    # Clean up deployments
    kubectl delete deployment --all -n "$NAMESPACE" 2>/dev/null || true
    
    # Wait for all resources to be fully terminated
    print_step "Waiting for resources to terminate"
    local max_wait=60
    local waited=0
    while [ $waited -lt $max_wait ]; do
        local terminating=$(kubectl get pods -n "$NAMESPACE" 2>/dev/null | grep -c "Terminating" || echo "0")
        if [ "$terminating" -eq 0 ]; then
            break
        fi
        sleep 2
        waited=$((waited + 2))
    done
    
    print_success "Partial deployment cleaned up"
}

# Main rollback function
main() {
    local release_name=${2:-zero-to-running}
    
    echo ""
    print_error "Deployment failed! Initiating rollback..."
    echo ""
    
    # Rollback Helm release
    rollback_helm_release "$release_name"
    
    # Clean up partial deployment
    cleanup_partial_deployment
    
    echo ""
    print_info "Rollback complete. Environment is in a clean state."
    print_info "You can retry with: make dev"
}

main "$@"

