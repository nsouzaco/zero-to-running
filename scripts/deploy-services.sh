#!/bin/bash
# Deploy services using Helm

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

NAMESPACE=${1:-zero-to-running}
CONFIG_FILE=${2:-dev-config.yaml}
PROFILE=${PROFILE:-full}  # Can be overridden via environment variable

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

# Check and clean up any existing resources before deployment
cleanup_before_deploy() {
    # Check if there are any resources still terminating
    local terminating=$(kubectl get pods -n "$NAMESPACE" 2>/dev/null | grep -c "Terminating" 2>/dev/null || echo "0")
    # Ensure it's a number
    terminating=${terminating:-0}
    if [ "$terminating" -gt 0 ] 2>/dev/null; then
        print_warning "Found $terminating pods still terminating, waiting for cleanup..."
        local max_wait=60
        local waited=0
        while [ $waited -lt $max_wait ]; do
            terminating=$(kubectl get pods -n "$NAMESPACE" 2>/dev/null | grep -c "Terminating" 2>/dev/null || echo "0")
            terminating=${terminating:-0}
            if [ "$terminating" -eq 0 ] 2>/dev/null; then
                print_success "All pods terminated"
                break
            fi
            sleep 2
            waited=$((waited + 2))
        done
        terminating=${terminating:-0}
        if [ "$terminating" -gt 0 ] 2>/dev/null; then
            print_warning "Some pods still terminating, forcing cleanup..."
            kubectl delete pods --all -n "$NAMESPACE" --grace-period=0 --force 2>/dev/null || true
            sleep 2
        fi
    fi
}

# Deploy services with Helm
deploy_services() {
    print_step "Deploying services to namespace: $NAMESPACE"
    
    # Clean up any existing resources before deployment
    cleanup_before_deploy
    
    # Check for single chart or multiple charts
    if [ -d "charts/zero-to-running" ]; then
        # Single chart deployment
        print_step "Deploying zero-to-running chart"
        
        local chart_path="charts/zero-to-running"
        local release_name="zero-to-running"
        
        # Build values file from config
        local values_file=".dev/values.yaml"
        mkdir -p .dev
        
        # Extract profile from config if not set via env var
        if [ "$PROFILE" = "full" ] && [ -f "$CONFIG_FILE" ]; then
            local config_profile=$(grep -E "^profile:" "$CONFIG_FILE" | head -1 | sed 's/^profile:[[:space:]]*//' | tr -d '"' || echo "full")
            PROFILE=${config_profile:-full}
        fi
        
        build_values_file "$CONFIG_FILE" "$values_file" "$PROFILE"
        
        # Track deployment start time
        local deploy_start=$(date +%s)
        
        # Check if namespace exists
        local namespace_exists=false
        if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
            namespace_exists=true
        fi
        
        # Check if release exists (with retry for TLS issues)
        # First check for Helm release secrets as a fallback if helm list fails
        local release_exists=false
        local helm_list_attempts=3
        local helm_list_attempt=0
        
        # If namespace doesn't exist, release definitely doesn't exist
        if [ "$namespace_exists" = "false" ]; then
            release_exists=false
        else
            # Namespace exists, check for release
            while [ $helm_list_attempt -lt $helm_list_attempts ]; do
                # Try helm list first
                local helm_list_output
                if helm_list_output=$(helm list -n "$NAMESPACE" 2>&1); then
                    # helm list succeeded, check if release is in output
                    if echo "$helm_list_output" | grep -q "$release_name"; then
                        release_exists=true
                        break
                    fi
                    # helm list succeeded but release not found - release doesn't exist
                    break
                else
                    # helm list failed (TLS error, etc.) - use fallback check
                    print_info "Helm list failed, checking for release secrets..."
                    if kubectl get secrets -n "$NAMESPACE" -l owner=helm 2>/dev/null | grep -q "sh.helm.release.v1.$release_name"; then
                        print_info "Found Helm release secrets, assuming release exists"
                        release_exists=true
                        break
                    fi
                    
                    # Retry on TLS errors
                    helm_list_attempt=$((helm_list_attempt + 1))
                    if [ $helm_list_attempt -lt $helm_list_attempts ]; then
                        print_info "Retrying Helm release check... (attempt $helm_list_attempt/$helm_list_attempts)"
                        sleep 2
                    fi
                fi
            done
        fi
        
        # Determine if we should use --create-namespace
        local create_namespace_flag=""
        if [ "$namespace_exists" = "false" ]; then
            create_namespace_flag="--create-namespace"
        fi
        
        if [ "$release_exists" = "true" ]; then
            print_info "Upgrading existing release"
            local helm_output
            helm_output=$(helm upgrade "$release_name" "$chart_path" \
                -n "$NAMESPACE" \
                $create_namespace_flag \
                -f "$values_file" \
                --wait \
                --timeout 10m 2>&1) || {
                print_error "Helm upgrade failed"
                echo ""
                echo "Helm error output:"
                echo "$helm_output"
                echo ""
                "$SCRIPT_DIR/rollback.sh" "$NAMESPACE" "$release_name"
                exit_with_error 1 "Helm upgrade failed"
            }
        else
            print_info "Installing new release"
            local helm_output
            helm_output=$(helm install "$release_name" "$chart_path" \
                -n "$NAMESPACE" \
                $create_namespace_flag \
                -f "$values_file" \
                --wait \
                --timeout 10m 2>&1) || {
                print_error "Helm install failed"
                echo ""
                echo "Helm error output:"
                echo "$helm_output"
                echo ""
                "$SCRIPT_DIR/rollback.sh" "$NAMESPACE" "$release_name"
                exit_with_error 1 "Helm install failed"
            }
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

# Apply profile settings to values
apply_profile() {
    local values_file=$1
    local profile=${2:-full}
    
    case "$profile" in
        minimal)
            # Minimal: Only postgres and backend
            print_info "Applying minimal profile (postgres, backend only)"
            # Use sed or yq to modify YAML - for now, we'll handle in build_values_file
            ;;
        debug)
            # Debug: Full stack with debug enabled
            print_info "Applying debug profile (all services + debug mode)"
            ;;
        full|*)
            # Full: All services enabled (default)
            print_info "Applying full profile (all services)"
            ;;
    esac
}

# Build values file from config (basic YAML parsing)
build_values_file() {
    local config_file=$1
    local values_file=$2
    local profile=${3:-full}
    
    if [ ! -f "$config_file" ]; then
        # Use defaults if config doesn't exist
        cat > "$values_file" <<EOF
namespace: $NAMESPACE
ports:
  frontend: 3001
  backend: 3000
  postgres: 5432
  redis: 6379
services:
  frontend:
    enabled: true
  backend:
    enabled: true
  postgres:
    enabled: true
  redis:
    enabled: true
debug: false
seed_data: false
secrets:
  enabled: true
EOF
        apply_profile "$values_file" "$profile"
        return
    fi
    
    # Basic YAML to values conversion
    # This is a simplified parser - for production, use yq or similar
    cp "$config_file" "$values_file" || true
    
    # Apply profile overrides
    case "$profile" in
        minimal)
            # Disable frontend and redis for minimal profile
            # Note: This is a basic implementation - for production, use yq
            if grep -q "services:" "$values_file"; then
                # Simple sed-based approach (limited but works for basic cases)
                sed -i.bak 's/^  frontend:$/  frontend:/; /^  frontend:/,/^  [a-z]/ { /enabled:/ s/true/false/; }' "$values_file" 2>/dev/null || true
                sed -i.bak 's/^  redis:$/  redis:/; /^  redis:/,/^  [a-z]/ { /enabled:/ s/true/false/; }' "$values_file" 2>/dev/null || true
                rm -f "$values_file.bak" 2>/dev/null || true
            fi
            ;;
        debug)
            # Enable debug mode
            if grep -q "^debug:" "$values_file"; then
                sed -i.bak 's/^debug:.*/debug: true/' "$values_file" 2>/dev/null || true
            else
                echo "debug: true" >> "$values_file"
            fi
            rm -f "$values_file.bak" 2>/dev/null || true
            ;;
    esac
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

