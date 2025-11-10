#!/bin/bash
# Show deployment summary with URLs and next steps

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Get service URLs
get_service_url() {
    local service=$1
    local port
    
    case "$service" in
        frontend)
            port=3001
            echo "http://localhost:$port"
            ;;
        backend)
            port=3000
            echo "http://localhost:$port"
            ;;
        postgres)
            port=5432
            echo "postgresql://dev_user:dev_password@localhost:$port/dev_db"
            ;;
        redis)
            port=6379
            echo "redis://localhost:$port"
            ;;
    esac
}

# Get setup time
get_setup_time() {
    if [ -f ".dev/setup-start-time" ]; then
        local start_time=$(cat .dev/setup-start-time)
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        echo "${minutes}m ${seconds}s"
    else
        echo "N/A"
    fi
}

# Main execution
main() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    print_success "All services running and healthy!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    echo "📋 Quick Links:"
    printf "   %-15s %s\n" "Frontend:" "$(get_service_url frontend)"
    printf "   %-15s %s\n" "Backend API:" "$(get_service_url backend)"
    printf "   %-15s %s\n" "Database:" "$(get_service_url postgres)"
    printf "   %-15s %s\n" "Redis:" "$(get_service_url redis)"
    echo ""
    
    local setup_time=$(get_setup_time)
    if [ "$setup_time" != "N/A" ]; then
        echo "⏱️  Total setup time: $setup_time"
        echo ""
    fi
    
    echo "💡 Next steps:"
    echo "   1. Open $(get_service_url frontend) in your browser"
    echo "   2. Start coding! Your changes will auto-reload"
    echo "   3. Run 'make dev-status' anytime to check service health"
    echo "   4. Run 'make dev-logs' to view logs from all services"
    echo "   5. Run 'make dev-down' when you're done"
    echo ""
    
    echo "💬 Need help? Run 'make dev-help' or check README.md"
    echo ""
}

main "$@"

