#!/bin/bash
# Setup and start Minikube cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Check if Minikube is running and healthy
check_minikube_status() {
    if minikube status >/dev/null 2>&1; then
        local host_status=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "unknown")
        local apiserver_status=$(minikube status --format='{{.APIServer}}' 2>/dev/null || echo "unknown")
        
        if [ "$host_status" = "Running" ] && [ "$apiserver_status" = "Running" ]; then
            # Verify API server is actually responding
            if kubectl cluster-info >/dev/null 2>&1; then
                print_success "Minikube cluster is already running and healthy"
                return 0
            else
                print_warning "Minikube is running but API server not responding, will restart"
                return 1
            fi
        elif [ "$host_status" = "Running" ] && [ "$apiserver_status" != "Running" ]; then
            print_warning "Minikube container is running but API server is not, will restart"
            return 1
        fi
    fi
    return 1
}

# Get available Docker memory
get_docker_memory() {
    # Try to get Docker Desktop memory limit
    if command_exists docker; then
        # Try to get from Docker info
        local docker_info=$(docker info 2>/dev/null | grep -i "total memory" || echo "")
        if [ -n "$docker_info" ]; then
            # Parse memory value (handles formats like "3.827GiB", "4096MiB", "4GB", etc.)
            local mem_line=$(echo "$docker_info" | awk '{print $3}')
            local mem_value=$(echo "$mem_line" | sed 's/[^0-9.]//g' || echo "")
            local mem_unit=$(echo "$mem_line" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]' || echo "")
            
            if [ -n "$mem_value" ]; then
                local mem_mb=0
                
                # Convert to MB based on unit (using integer arithmetic)
                case "$mem_unit" in
                    *GB|*GIB)
                        # Convert GB to MB (multiply by 1024)
                        # Handle decimal: 3.827 * 1024 = 3918 (approximate)
                        local int_part=$(echo "$mem_value" | cut -d. -f1)
                        local dec_part=$(echo "$mem_value" | cut -d. -f2 | cut -c1-2)  # First 2 decimal digits
                        if [ -z "$dec_part" ]; then
                            dec_part=0
                        fi
                        # Approximate: int_part * 1024 + (dec_part * 1024 / 100)
                        mem_mb=$((int_part * 1024 + dec_part * 10))
                        ;;
                    *MB|*MIB)
                        # Already in MB, just get integer part
                        mem_mb=$(echo "$mem_value" | cut -d. -f1 || echo "0")
                        ;;
                    *)
                        # Assume bytes, convert to MB (divide by 1024*1024)
                        # For large numbers, just divide by 1048576
                        mem_mb=$((mem_value / 1048576))
                        ;;
                esac
                
                # Use 75% of available, ensure minimum 2048MB
                if [ "$mem_mb" -gt 0 ] 2>/dev/null; then
                    local available_mb=$((mem_mb * 75 / 100))
                    if [ "$available_mb" -lt 2048 ]; then
                        available_mb=2048
                    fi
                    echo "$available_mb"
                    return
                fi
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
    local memory=2048  # Default to 2GB (recommended for reliable operation)
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
    
    # Ensure minimum memory (Minikube requires at least 1800MB, but 2GB is recommended)
    if [ "$memory" -lt 1800 ]; then
        print_warning "Memory too low (${memory}MB), using minimum 1800MB (Minikube requirement)"
        memory=1800
    fi
    
    print_info "Configuring cluster with ${cpus} CPUs, ${memory}MB memory"
    
    # Check if Minikube cluster exists and if we need to recreate it
    local need_recreate=false
    if minikube status >/dev/null 2>&1; then
        local apiserver_status=$(minikube status --format='{{.APIServer}}' 2>/dev/null || echo "unknown")
        
        # Check if cluster is in bad state
        if [ "$apiserver_status" != "Running" ]; then
            print_info "Minikube is in a bad state (API server stopped), will recreate..."
            need_recreate=true
        else
            # Check if memory/CPU settings match (Minikube doesn't allow changing these on existing clusters)
            # Try to get existing config, but if it fails, we'll handle it during start
            local existing_memory=$(minikube config get memory 2>/dev/null | grep -v "does not exist" || echo "")
            local existing_cpus=$(minikube config get cpus 2>/dev/null | grep -v "does not exist" || echo "")
            
            # If settings don't match, we need to recreate
            if [ -n "$existing_memory" ] && [ "$existing_memory" != "${memory}" ]; then
                print_warning "Existing Minikube cluster has different memory (${existing_memory}MB vs ${memory}MB)"
                print_info "Minikube doesn't allow changing memory on existing clusters"
                print_info "Will delete and recreate cluster with new settings"
                need_recreate=true
            fi
            
            if [ -n "$existing_cpus" ] && [ "$existing_cpus" != "${cpus}" ]; then
                print_warning "Existing Minikube cluster has different CPUs (${existing_cpus} vs ${cpus})"
                print_info "Will delete and recreate cluster with new settings"
                need_recreate=true
            fi
            
            # If we can't determine existing settings, we'll try to start and handle the error
            # This is a fallback in case minikube config get doesn't work
        fi
        
        if [ "$need_recreate" = "true" ]; then
            print_info "Deleting existing Minikube cluster to apply new settings..."
            minikube delete >/dev/null 2>&1 || true
            sleep 3
        fi
    fi
    
    # Start Minikube with retry logic
    local max_attempts=2
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        print_info "Starting Minikube (attempt $((attempt + 1))/$max_attempts)..."
        
        local minikube_start_output
        local start_success=false
        
        if minikube_start_output=$(minikube start \
            --cpus="$cpus" \
            --memory="${memory}mb" \
            --driver="$driver" \
            --wait=all \
            --wait-timeout=6m 2>&1); then
            start_success=true
        else
            # Check if error is about not being able to change memory/CPU
            if echo "$minikube_start_output" | grep -qi "cannot change.*memory\|cannot change.*cpu\|you cannot change"; then
                print_warning "Minikube cannot change memory/CPU on existing cluster"
                print_info "Deleting cluster to apply new settings..."
                minikube delete >/dev/null 2>&1 || true
                sleep 3
                # Retry without counting as an attempt
                continue
            fi
        fi
        
        if [ "$start_success" = "true" ]; then
            # Verify it's actually working
            sleep 3
            if kubectl cluster-info >/dev/null 2>&1; then
                print_success "Minikube cluster started and verified"
                return 0
            else
                print_warning "Minikube started but API server not responding yet"
                # Give it a bit more time
                local verify_attempts=10
                local verify_attempt=0
                while [ $verify_attempt -lt $verify_attempts ]; do
                    sleep 3
                    if kubectl cluster-info >/dev/null 2>&1; then
                        print_success "Minikube cluster is now ready"
                        return 0
                    fi
                    verify_attempt=$((verify_attempt + 1))
                done
                print_warning "API server slow to respond, but continuing..."
                return 0
            fi
        else
            attempt=$((attempt + 1))
            if [ $attempt -lt $max_attempts ]; then
                # If it failed, try to clean up and retry
                print_warning "Minikube start failed, cleaning up and retrying..."
                minikube delete >/dev/null 2>&1 || true
                sleep 3
                
                # Try with slightly less memory if possible
                if [ "$memory" -gt 2048 ]; then
                    local new_memory=$((memory * 90 / 100))
                    if [ "$new_memory" -ge 2048 ]; then
                        print_info "Retrying with slightly reduced memory: ${new_memory}MB"
                        memory="$new_memory"
                    fi
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

# Wait for cluster to be fully ready
wait_for_cluster_ready() {
    print_step "Waiting for cluster to be fully ready"
    
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if API server is responding
        if kubectl cluster-info >/dev/null 2>&1; then
            # Check if nodes are ready
            local node_status=$(kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
            if [ "$node_status" = "True" ]; then
                print_success "Cluster is ready"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        if [ $((attempt % 5)) -eq 0 ]; then
            print_info "Still waiting for cluster... (attempt ${attempt}/${max_attempts})"
        fi
        sleep 2
    done
    
    print_warning "Cluster may not be fully ready, but proceeding anyway"
    return 0
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
    wait_for_cluster_ready
    
    echo ""
    print_success "Cluster setup complete!"
    print_info "Namespace will be created by Helm during deployment"
}

main "$@"

