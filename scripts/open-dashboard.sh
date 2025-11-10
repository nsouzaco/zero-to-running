#!/bin/bash
# Open dashboard in browser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

CONFIG_FILE=${1:-dev-config.yaml}

# Get dashboard port from config
get_dashboard_port() {
    local port=3002
    
    if [ -f "$CONFIG_FILE" ]; then
        local config_port=$(grep -E "^\s*port:" "$CONFIG_FILE" | grep -A 5 "dashboard:" | grep -E "^\s*port:" | awk '{print $2}' || echo "")
        [ -n "$config_port" ] && port="$config_port"
    fi
    
    echo "$port"
}

# Check if dashboard is running
check_dashboard() {
    local port=$(get_dashboard_port)
    
    # Check if port is accessible
    if command_exists curl; then
        if curl -s "http://localhost:$port" >/dev/null 2>&1; then
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
    
    if ! check_dashboard; then
        print_warning "Dashboard is not running on port $port"
        echo ""
        echo "The dashboard will be available after running 'make dev'"
        echo "Or start it manually if you have a dashboard service configured"
        return 1
    fi
    
    print_info "Opening dashboard at $url"
    
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
}

# Main execution
main() {
    open_dashboard
}

main "$@"

