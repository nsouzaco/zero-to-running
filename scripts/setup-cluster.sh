#!/bin/bash
# Setup and start Minikube cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Check if Minikube is running
check_minikube_status() {
    if minikube status >/dev/null 2>&1; then
        local status=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "unknown")
        if [ "$status" = "Running" ]; then
            print_success "Minikube cluster is already running"
            return 0
        fi
    fi
    return 1
}

# Start Minikube cluster
start_minikube() {
    print_step "Starting Minikube cluster"
    
    # Load config if available
    local cpus=4
    local memory=8192
    local driver="docker"
    
    if [ -f "dev-config.yaml" ]; then
        # Try to read config (basic parsing)
        local config_cpus=$(grep -E "^\s*cpus:" dev-config.yaml | head -1 | awk '{print $2}' || echo "")
        local config_memory=$(grep -E "^\s*memory:" dev-config.yaml | head -1 | awk '{print $2}' || echo "")
        local config_driver=$(grep -E "^\s*driver:" dev-config.yaml | head -1 | awk '{print $2}' || echo "")
        
        [ -n "$config_cpus" ] && cpus="$config_cpus"
        [ -n "$config_memory" ] && memory="$config_memory"
        [ -n "$config_driver" ] && driver="$config_driver"
    fi
    
    print_info "Configuring cluster with ${cpus} CPUs, ${memory}MB memory"
    
    # Start Minikube
    if ! minikube start \
        --cpus="$cpus" \
        --memory="${memory}mb" \
        --driver="$driver" \
        --wait=all \
        --wait-timeout=5m; then
        print_error "Failed to start Minikube cluster"
        exit_with_error 1 "Minikube startup failed"
    fi
    
    print_success "Minikube cluster started"
}

# Create namespace
create_namespace() {
    print_step "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_info "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE" || exit_with_error 1 "Failed to create namespace"
        print_success "Namespace $NAMESPACE created"
    fi
}

# Set kubectl context
set_context() {
    print_step "Setting kubectl context"
    kubectl config use-context minikube >/dev/null 2>&1 || true
}

# Main execution
main() {
    echo "Setting up Minikube cluster..."
    echo ""
    
    if check_minikube_status; then
        print_info "Using existing Minikube cluster"
    else
        start_minikube
    fi
    
    set_context
    create_namespace
    
    echo ""
    print_success "Cluster setup complete!"
}

main "$@"

