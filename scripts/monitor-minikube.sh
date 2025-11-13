#!/bin/bash

# Monitor Minikube startup progress
# Checks status every 2 minutes and reports progress

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

print_info "Starting Minikube monitoring (checking every 2 minutes)"
print_info "Press Ctrl+C to stop monitoring"
echo ""

check_count=0
start_time=$(date +%s)

while true; do
    check_count=$((check_count + 1))
    elapsed=$(( $(date +%s) - start_time ))
    minutes=$((elapsed / 60))
    seconds=$((elapsed % 60))
    
    echo ""
    echo "=========================================="
    echo "Check #$check_count - Elapsed: ${minutes}m ${seconds}s"
    echo "=========================================="
    
    # Check Minikube status
    echo ""
    echo "📊 Minikube Status:"
    if minikube status 2>&1 | grep -q "host: Running"; then
        print_success "Minikube host is Running"
        minikube status 2>&1 | grep -E "(host|kubelet|apiserver)" || true
    else
        print_warning "Minikube host not running yet"
        minikube status 2>&1 | head -3 || echo "  Minikube not initialized"
    fi
    
    # Check for Minikube containers
    echo ""
    echo "🐳 Docker Containers:"
    minikube_containers=$(docker ps -a --filter "name=minikube" --format "{{.Names}}: {{.Status}}" 2>/dev/null)
    if [ -n "$minikube_containers" ]; then
        echo "$minikube_containers"
    else
        echo "  No Minikube containers found yet"
    fi
    
    # Check running processes
    echo ""
    echo "⚙️  Processes:"
    minikube_procs=$(ps aux | grep -E "minikube start" | grep -v grep | head -2)
    if [ -n "$minikube_procs" ]; then
        echo "$minikube_procs" | awk '{printf "  PID %s: Running for %s\n", $2, $10}'
    else
        echo "  No Minikube start process found"
    fi
    
    # Check Kubernetes API
    echo ""
    echo "☸️  Kubernetes API:"
    if kubectl cluster-info 2>&1 | grep -q "is running"; then
        print_success "Kubernetes API is accessible"
        kubectl get nodes 2>&1 | head -3 || true
    else
        echo "  API not ready yet"
    fi
    
    # Check if Minikube is fully ready
    if minikube status 2>&1 | grep -qE "host: Running.*kubelet: Running.*apiserver: Running"; then
        echo ""
        print_success "✅ Minikube is fully operational!"
        echo ""
        minikube status
        exit 0
    fi
    
    # Check if process has been running too long (10 minutes)
    if [ $elapsed -gt 600 ]; then
        echo ""
        print_error "⚠️  Minikube has been starting for over 10 minutes"
        print_warning "This may indicate an issue. Consider:"
        echo "  1. Checking Docker Desktop resources"
        echo "  2. Restarting Docker Desktop"
        echo "  3. Running: minikube delete && minikube start --memory=2048mb --cpus=2"
    fi
    
    echo ""
    print_info "Next check in 2 minutes... (Press Ctrl+C to stop)"
    sleep 120
done

