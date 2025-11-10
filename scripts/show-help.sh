#!/bin/bash
# Show help information

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main() {
    cat <<EOF
Zero-to-Running CLI Tool - Help
================================

USAGE:
  make <command> [options]

COMMANDS:
  dev              Start the development environment
  dev-down         Stop all services and free resources
  dev-status       Show status of all running services
  dev-logs         Stream logs from all services
  dev-logs <svc>   Stream logs from a specific service
  dev-dashboard    Open the local dashboard in browser
  dev-help         Show this help message
  dev-reset        Full cleanup and reset (stops and removes everything)

EXAMPLES:
  make dev                    # Start all services
  make dev PORT=3002          # Start with custom port
  make dev-status             # Check service status
  make dev-logs backend       # View backend logs
  make dev-down               # Stop all services
  make dev-reset              # Full cleanup

CONFIGURATION:
  Create dev-config.yaml in the project root to customize settings.
  See config/dev-config.yaml.template for available options.

TROUBLESHOOTING:
  - If setup fails, check .dev/logs/ for error logs
  - Run 'make dev-status' to see service health
  - Run 'make dev-reset' to start fresh
  - Ensure Docker and Minikube are running

For more information, see the project documentation.

EOF
}

main "$@"

