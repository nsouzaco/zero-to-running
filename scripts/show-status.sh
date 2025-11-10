#!/bin/bash
# Show status of all services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Get service status
get_service_status() {
    local service=$1
    local pod=$(kubectl get pods -n "$NAMESPACE" -l app="$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$pod" ]; then
        echo "Not deployed"
        return
    fi
    
    local phase=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    local ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    
    if [ "$phase" = "Running" ] && [ "$ready" = "True" ]; then
        echo "Running ✓"
    else
        echo "$phase"
    fi
}

# Get service port (from config or default)
get_service_port() {
    local service=$1
    local default_port
    
    case "$service" in
        frontend)
            default_port=3001
            ;;
        backend)
            default_port=3000
            ;;
        postgres)
            default_port=5432
            ;;
        redis)
            default_port=6379
            ;;
        dashboard)
            default_port=3002
            ;;
        *)
            default_port="N/A"
            ;;
    esac
    
    # Try to get from config
    if [ -f "dev-config.yaml" ]; then
        local config_port=$(grep -E "^\s*$service:" dev-config.yaml -A 1 | grep -E "^\s*port:" | awk '{print $2}' || echo "")
        [ -n "$config_port" ] && default_port="$config_port"
    fi
    
    echo "$default_port"
}

# Get service URL
get_service_url() {
    local service=$1
    local port=$(get_service_port "$service")
    
    case "$service" in
        frontend)
            echo "http://localhost:$port"
            ;;
        backend)
            echo "http://localhost:$port"
            ;;
        postgres)
            echo "postgresql://dev_user:dev_password@localhost:$port/dev_db"
            ;;
        redis)
            echo "redis://localhost:$port"
            ;;
        dashboard)
            echo "http://localhost:$port"
            ;;
        *)
            echo "http://localhost:$port"
            ;;
    esac
}

# Show status
main() {
    echo "📋 Service Status"
    echo "=================="
    echo ""
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        print_warning "Namespace $NAMESPACE does not exist"
        echo "Run 'make dev' to start the environment"
        exit 0
    fi
    
    # Check if Minikube is running
    if ! minikube status >/dev/null 2>&1; then
        print_warning "Minikube cluster is not running"
        echo "Run 'make dev' to start the environment"
        exit 0
    fi
    
    printf "%-15s %-20s %-10s %s\n" "SERVICE" "STATUS" "PORT" "URL"
    echo "----------------------------------------------------------------"
    
    local services=("postgres" "redis" "backend" "frontend" "dashboard")
    
    for service in "${services[@]}"; do
        local status=$(get_service_status "$service")
        local port=$(get_service_port "$service")
        local url=$(get_service_url "$service")
        
        printf "%-15s %-20s %-10s %s\n" "$service" "$status" "$port" "$url"
    done
    
    echo ""
    echo "💡 Quick Links:"
    echo "   Frontend:     $(get_service_url frontend)"
    echo "   Backend API:  $(get_service_url backend)"
    echo "   Database:     $(get_service_url postgres)"
    echo "   Redis:        $(get_service_url redis)"
    echo ""
    echo "Run 'make dev-logs' to view logs"
    echo "Run 'make dev-down' to stop all services"
}

main "$@"

