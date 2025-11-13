#!/bin/bash
# Open dashboard in browser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE=${1:-dev-config.yaml}
NAMESPACE=${NAMESPACE:-zero-to-running}

# Get dashboard port from config
get_dashboard_port() {
    local port=3002
    
    if [ -f "$CONFIG_FILE" ]; then
        local config_port=$(grep -E "^\s*port:" "$CONFIG_FILE" | grep -A 5 "dashboard:" | grep -E "^\s*port:" | awk '{print $2}' || echo "")
        [ -n "$config_port" ] && port="$config_port"
    fi
    
    echo "$port"
}

# Wait for dashboard pod to be ready
wait_for_dashboard_ready() {
    local max_attempts=30
    local attempt=0
    
    print_info "Waiting for dashboard to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        local pod_status=$(kubectl get pods -n "$NAMESPACE" -l app=dashboard -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
        local ready_status=$(kubectl get pods -n "$NAMESPACE" -l app=dashboard -o jsonpath='{.items[0].status.containerStatuses[0].ready}' 2>/dev/null || echo "false")
        
        if [ "$pod_status" = "Running" ] && [ "$ready_status" = "true" ]; then
            print_success "Dashboard is ready!"
            return 0
        fi
        
        attempt=$((attempt + 1))
        if [ $((attempt % 5)) -eq 0 ]; then
            print_info "Still waiting... (attempt $attempt/$max_attempts)"
        fi
        sleep 2
    done
    
    print_warning "Dashboard did not become ready within timeout"
    return 1
}

# Setup port forwarding for dashboard
setup_dashboard_port_forward() {
    local port=$(get_dashboard_port)
    local service_name=$(kubectl get svc -n "$NAMESPACE" -l app=dashboard -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$service_name" ]; then
        print_warning "Dashboard service not found"
        return 1
    fi
    
    # Check if port forward already exists
    if ps aux | grep -E "kubectl port-forward.*dashboard.*$port" | grep -v grep >/dev/null 2>&1; then
        print_info "Port forward for dashboard already exists"
        return 0
    fi
    
    # Check if port is in use
    if port_in_use "$port"; then
        print_warning "Port $port is already in use"
        return 1
    fi
    
    print_info "Setting up port forward for dashboard (localhost:$port -> $service_name:$port)"
    
    # Start port forward in background and keep it alive
    kubectl port-forward -n "$NAMESPACE" "svc/$service_name" "$port:$port" >/dev/null 2>&1 &
    local pf_pid=$!
    
    # Wait a moment to check if it started successfully
    sleep 2
    if ! kill -0 "$pf_pid" 2>/dev/null; then
        print_error "Failed to start port forward for dashboard"
        return 1
    fi
    
    # Save PID to port-forward.pids file
    mkdir -p .dev
    echo "$pf_pid" >> ".dev/port-forward.pids"
    
    print_success "Port forward for dashboard started (PID: $pf_pid)"
    return 0
}

# Check if dashboard is accessible
check_dashboard() {
    local port=$(get_dashboard_port)
    
    # Check if port is accessible
    if command_exists curl; then
        if curl -s -f "http://localhost:$port" >/dev/null 2>&1; then
            return 0
        fi
    elif command_exists wget; then
        if wget -q --spider "http://localhost:$port" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Open dashboard in browser
open_dashboard() {
    local port=$(get_dashboard_port)
    local url="http://localhost:$port"
    
    # Wait for dashboard to be ready
    if ! wait_for_dashboard_ready; then
        print_warning "Dashboard is not ready yet"
        echo ""
        echo "The dashboard may still be starting. You can:"
        echo "  1. Wait a bit longer and run: make dev-dashboard"
        echo "  2. Check status: kubectl get pods -n $NAMESPACE -l app=dashboard"
        return 1
    fi
    
    # Setup port forwarding if not already set up
    if ! check_dashboard; then
        print_info "Setting up port forwarding for dashboard..."
        if ! setup_dashboard_port_forward; then
            print_warning "Failed to set up port forwarding"
            echo ""
            echo "You can manually set up port forwarding with:"
            echo "  kubectl port-forward -n $NAMESPACE svc/zero-to-running-dashboard $port:$port"
            return 1
        fi
        
        # Wait a moment for port forward to be ready
        sleep 2
        
        # Verify it's accessible
        if ! check_dashboard; then
            print_warning "Dashboard port forward is set up but not accessible yet"
            echo "Please wait a moment and try again, or check: kubectl get pods -n $NAMESPACE -l app=dashboard"
            return 1
        fi
    fi
    
    print_success "Opening dashboard at $url"
    
    case "$(get_os)" in
        macos)
            open "$url"
            ;;
        linux)
            if command_exists xdg-open; then
                xdg-open "$url"
            elif command_exists gnome-open; then
                gnome-open "$url"
            else
                print_warning "Could not open browser automatically"
                echo "Please open $url in your browser"
            fi
            ;;
        windows)
            start "$url"
            ;;
        *)
            print_warning "Could not open browser automatically"
            echo "Please open $url in your browser"
            ;;
    esac
    
    echo ""
    print_info "Dashboard is running. Port forward will stay active."
    print_info "To stop port forwarding, run: make dev-down"
}

# Main execution
main() {
    open_dashboard
}

main "$@"

