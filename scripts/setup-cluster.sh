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

# Get available Docker memory
get_docker_memory() {
    # Try to get Docker Desktop memory limit
    if command_exists docker; then
        # On macOS, check Docker Desktop settings
        if [ "$(get_os)" = "macos" ]; then
            # Try to get from Docker info (may not always work)
            local docker_mem=$(docker info 2>/dev/null | grep -i "total memory" | awk '{print $3}' | sed 's/[^0-9]//g' || echo "")
            if [ -n "$docker_mem" ] && [ "$docker_mem" -gt 0 ]; then
                # Convert to MB and use 75% of available
                local available_mb=$((docker_mem / 1024 / 1024 * 75 / 100))
                echo "$available_mb"
                return
            fi
        fi
    fi
    
    # Default fallback: use 3072MB (3GB) which works on most systems
    echo "3072"
}

# Start Minikube cluster
start_minikube() {
    print_step "Starting Minikube cluster"
    
    # Load config if available
    local cpus=2
    local memory=3072  # Default to 3GB (more reasonable)
    local driver="docker"
    
    if [ -f "dev-config.yaml" ]; then
        # Try to read config (basic parsing)
        local config_cpus=$(grep -E "^\s*cpus:" dev-config.yaml -A 1 | grep -E "^\s*cpus:" | awk '{print $2}' || \
                           grep -E "^\s*cpus:" dev-config.yaml | head -1 | awk '{print $2}' || echo "")
        local config_memory=$(grep -E "^\s*memory:" dev-config.yaml -A 1 | grep -E "^\s*memory:" | awk '{print $2}' || \
                             grep -E "^\s*memory:" dev-config.yaml | head -1 | awk '{print $2}' || echo "")
        local config_driver=$(grep -E "^\s*driver:" dev-config.yaml -A 1 | grep -E "^\s*driver:" | awk '{print $2}' || \
                             grep -E "^\s*driver:" dev-config.yaml | head -1 | awk '{print $2}' || echo "")
        
        [ -n "$config_cpus" ] && cpus="$config_cpus"
        [ -n "$config_memory" ] && memory="$config_memory"
        [ -n "$config_driver" ] && driver="$config_driver"
    fi
    
    # Check available Docker memory and adjust if needed
    local available_mem=$(get_docker_memory)
    if [ "$memory" -gt "$available_mem" ]; then
        print_warning "Requested memory (${memory}MB) exceeds available Docker memory (${available_mem}MB)"
        print_info "Adjusting to ${available_mem}MB"
        memory="$available_mem"
    fi
    
    # Ensure minimum memory (at least 2GB)
    if [ "$memory" -lt 2048 ]; then
        print_warning "Memory too low (${memory}MB), using minimum 2048MB"
        memory=2048
    fi
    
    print_info "Configuring cluster with ${cpus} CPUs, ${memory}MB memory"
    
    # Start Minikube with retry logic
    local max_attempts=2
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if minikube start \
            --cpus="$cpus" \
            --memory="${memory}mb" \
            --driver="$driver" \
            --wait=all \
            --wait-timeout=5m 2>&1; then
            print_success "Minikube cluster started"
            return 0
        else
            attempt=$((attempt + 1))
            if [ $attempt -lt $max_attempts ]; then
                # If it failed due to memory, try with less
                if echo "$(minikube start --help 2>&1)" | grep -q "memory"; then
                    local new_memory=$((memory * 75 / 100))
                    if [ "$new_memory" -ge 2048 ]; then
                        print_warning "Retrying with reduced memory: ${new_memory}MB"
                        memory="$new_memory"
                    else
                        print_error "Cannot allocate sufficient memory for Minikube"
                        print_info "Please increase Docker Desktop memory allocation or reduce memory in dev-config.yaml"
                        exit_with_error 1 "Insufficient memory for Minikube"
                    fi
                else
                    break
                fi
            fi
        fi
    done
    
    print_error "Failed to start Minikube cluster after $max_attempts attempts"
    print_info "Try:"
    print_info "  1. Increase Docker Desktop memory allocation"
    print_info "  2. Reduce memory in dev-config.yaml"
    print_info "  3. Start manually: minikube start --memory=${memory}mb --cpus=$cpus"
    exit_with_error 1 "Minikube startup failed"
}

# Note: Namespace will be created by Helm with --create-namespace flag
# No need to check or create it here

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
    
    echo ""
    print_success "Cluster setup complete!"
    print_info "Namespace will be created by Helm during deployment"
}

main "$@"

