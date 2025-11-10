#!/bin/bash
# Full cleanup of environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}

# Full cleanup
main() {
    echo "🧹 Performing full cleanup..."
    echo ""
    
    # Teardown services
    "$SCRIPT_DIR/teardown.sh" "$NAMESPACE"
    
    # Delete namespace
    print_step "Deleting namespace: $NAMESPACE"
    if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        kubectl delete namespace "$NAMESPACE" --wait=true --timeout=2m 2>/dev/null || true
        print_success "Namespace deleted"
    else
        print_info "Namespace does not exist"
    fi
    
    # Clean up logs (optional)
    if [ -d ".dev/logs" ]; then
        print_step "Cleaning up log files"
        # Keep last 10 log files
        find .dev/logs -name "*.log" -type f | sort -r | tail -n +11 | xargs rm -f 2>/dev/null || true
        print_success "Logs cleaned up"
    fi
    
    echo ""
    print_success "Full cleanup complete!"
    echo ""
    echo "💡 To start fresh, run: make dev"
}

main "$@"

