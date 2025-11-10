# Zero-to-Running CLI Tool
# Makefile for managing local development environment

.PHONY: dev dev-down dev-status dev-logs dev-dashboard dev-help dev-reset

# Default namespace for services
NAMESPACE ?= zero-to-running
# Configuration file
CONFIG_FILE ?= dev-config.yaml
# Scripts directory
SCRIPTS_DIR := scripts

# Main command: Start development environment
dev:
	@echo "🚀 Starting Zero-to-Running Developer Environment..."
	@mkdir -p .dev && echo $$(date +%s) > .dev/setup-start-time
	@$(SCRIPTS_DIR)/check-dependencies.sh
	@$(SCRIPTS_DIR)/setup-cluster.sh $(NAMESPACE)
	@$(SCRIPTS_DIR)/deploy-services.sh $(NAMESPACE) $(CONFIG_FILE)
	@$(SCRIPTS_DIR)/wait-for-healthy.sh $(NAMESPACE)
	@$(SCRIPTS_DIR)/show-summary.sh $(NAMESPACE)
	@$(SCRIPTS_DIR)/open-dashboard.sh $(CONFIG_FILE) || true

# Stop development environment
dev-down:
	@echo "🛑 Stopping Zero-to-Running Developer Environment..."
	@$(SCRIPTS_DIR)/teardown.sh $(NAMESPACE)

# Show status of all services
dev-status:
	@$(SCRIPTS_DIR)/show-status.sh $(NAMESPACE)

# Stream logs from services
dev-logs:
	@$(SCRIPTS_DIR)/stream-logs.sh $(NAMESPACE) $(filter-out $@,$(MAKECMDGOALS))

# Open dashboard in browser
dev-dashboard:
	@$(SCRIPTS_DIR)/open-dashboard.sh $(CONFIG_FILE)

# Show help
dev-help:
	@$(SCRIPTS_DIR)/show-help.sh

# Reset environment (full cleanup)
dev-reset: dev-down
	@echo "🧹 Performing full cleanup..."
	@$(SCRIPTS_DIR)/cleanup.sh $(NAMESPACE)

# Prevent make from treating log service names as targets
%:
	@:

