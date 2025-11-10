#!/bin/bash
# Deploy services using Helm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}
CONFIG_FILE=${2:-dev-config.yaml}

# Trap for cleanup on interrupt (set after variables are defined)
cleanup_on_interrupt() {
    echo ""
    print_warning "Deployment interrupted. Cleaning up..."
    "$SCRIPT_DIR/rollback.sh" "$NAMESPACE" "zero-to-running" 2>/dev/null || true
    exit 130
}
trap cleanup_on_interrupt INT TERM

# Check if Helm chart exists
check_helm_chart() {
    if [ ! -d "helm-charts" ] && [ ! -d "charts" ]; then
        print_warning "Helm charts directory not found"
        echo ""
        echo "Please create Helm charts for your services."
        echo "Expected structure:"
        echo "  helm-charts/"
        echo "    ├── frontend/"
        echo "    ├── backend/"
        echo "    ├── postgres/"
        echo "    └── redis/"
        echo ""
        echo "Or a single chart:"
        echo "  charts/"
        echo "    └── zero-to-running/"
        echo ""
        print_error "Helm charts are required for deployment"
        exit_with_error 3 "Helm charts not found"
    fi
}

# Deploy services with Helm
deploy_services() {
    print_step "Deploying services to namespace: $NAMESPACE"
    
    # Check for single chart or multiple charts
    if [ -d "charts/zero-to-running" ]; then
        # Single chart deployment
        print_step "Deploying zero-to-running chart"
        
        local chart_path="charts/zero-to-running"
        local release_name="zero-to-running"
        
        # Build values file from config
        local values_file=".dev/values.yaml"
        mkdir -p .dev
        build_values_file "$CONFIG_FILE" "$values_file"
        
        # Track deployment start time
        local deploy_start=$(date +%s)
        
        if helm list -n "$NAMESPACE" | grep -q "$release_name"; then
            print_info "Upgrading existing release"
            if ! helm upgrade "$release_name" "$chart_path" \
                -n "$NAMESPACE" \
                -f "$values_file" \
                --wait \
                --timeout 10m; then
                print_error "Helm upgrade failed"
                "$SCRIPT_DIR/rollback.sh" "$NAMESPACE" "$release_name"
                exit_with_error 1 "Helm upgrade failed"
            fi
        else
            if ! helm install "$release_name" "$chart_path" \
                -n "$NAMESPACE" \
                -f "$values_file" \
                --wait \
                --timeout 10m; then
                print_error "Helm install failed"
                "$SCRIPT_DIR/rollback.sh" "$NAMESPACE" "$release_name"
                exit_with_error 1 "Helm install failed"
            fi
        fi
        
        local deploy_end=$(date +%s)
        local deploy_time=$((deploy_end - deploy_start))
        print_success "Services deployed successfully (took ${deploy_time}s)"
        
        # Setup port forwarding
        print_step "Setting up port forwarding"
        "$SCRIPT_DIR/setup-port-forwarding.sh" "$NAMESPACE" || print_warning "Port forwarding setup failed (services may still be accessible via kubectl port-forward)"
        
    elif [ -d "helm-charts" ]; then
        # Multiple charts deployment
        deploy_multiple_charts
    else
        print_error "No Helm charts found"
        exit_with_error 3 "Helm charts not found"
    fi
}

# Deploy multiple charts
deploy_multiple_charts() {
    local charts_dir="helm-charts"
    local values_file=".dev/values.yaml"
    
    mkdir -p .dev
    build_values_file "$CONFIG_FILE" "$values_file"
    
    # Deploy each service
    for service in frontend backend postgres redis; do
        if [ -d "$charts_dir/$service" ]; then
            print_step "Deploying $service"
            
            local release_name="$service"
            
            if helm list -n "$NAMESPACE" | grep -q "$release_name"; then
                helm upgrade "$release_name" "$charts_dir/$service" \
                    -n "$NAMESPACE" \
                    -f "$values_file" \
                    --wait \
                    --timeout 10m || print_warning "$service upgrade failed"
            else
                helm install "$release_name" "$charts_dir/$service" \
                    -n "$NAMESPACE" \
                    -f "$values_file" \
                    --wait \
                    --timeout 10m || print_warning "$service install failed"
            fi
            
            print_success "$service deployed"
        fi
    done
}

# Build values file from config (basic YAML parsing)
build_values_file() {
    local config_file=$1
    local values_file=$2
    
    if [ ! -f "$config_file" ]; then
        # Use defaults if config doesn't exist
        cat > "$values_file" <<EOF
namespace: $NAMESPACE
ports:
  frontend: 3001
  backend: 3000
  postgres: 5432
  redis: 6379
EOF
        return
    fi
    
    # Basic YAML to values conversion
    # This is a simplified parser - for production, use yq or similar
    cp "$config_file" "$values_file" || true
}

# Main execution
main() {
    echo "Deploying services..."
    echo ""
    
    check_helm_chart
    deploy_services
    
    echo ""
    print_success "Deployment complete!"
}

main "$@"

