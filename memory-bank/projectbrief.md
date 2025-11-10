# Project Brief: Zero-to-Running CLI Tool

## Project Overview
The Zero-to-Running CLI Tool is a user-facing interface for the Zero-to-Running Developer Environment. It abstracts Kubernetes orchestration and local environment management complexity, enabling developers to provision a fully functional multi-service development environment with a single command.

## Core Purpose
Provide an intuitive, forgiving CLI interface that makes environment setup accessible to all developers regardless of their ops expertise. Developers should be able to run `make dev` and have everything work without deep knowledge of Kubernetes, Helm, or Docker.

## Key Requirements

### Primary Goals
- **Simplicity**: Single command setup (`make dev`)
- **Clarity**: Clear, real-time feedback during setup
- **Reliability**: 90%+ setup success rate on first attempt
- **Speed**: Under 5 minutes to first successful setup
- **Self-Service**: Minimal need for external documentation

### Core Commands (P0)
- `make dev` - Initialize and start all services
- `make dev-down` - Gracefully stop all services
- `make dev-status` - Display status of all services
- `make dev-logs` - Stream real-time logs
- `make dev-dashboard` - Open local dashboard

### Technology Stack
- Makefile or shell script as CLI entry point
- Bash/POSIX shell for portability
- Helm for Kubernetes deployment
- Minikube for local Kubernetes cluster
- kubectl for cluster interaction
- YAML for configuration files

### Target Platforms
- macOS (Intel and Apple Silicon)
- Linux (Ubuntu, Fedora)
- Windows (WSL2)

### Success Metrics
- Time to first successful setup: under 5 minutes
- Setup success rate on first attempt: 90%+
- Support tickets related to CLI usage: fewer than 5% of total support load
- Developer satisfaction: 4.5/5 or higher
- Documentation page views: less than 20% of users need to consult docs beyond `--help`

## Project Constraints
- Must work with Minikube (only supported K8s distribution for local dev)
- Requires Docker Desktop or equivalent
- Requires Helm 3+, kubectl
- Minimum 8GB RAM, 10GB disk space
- Each project runs in isolated Kubernetes namespace

## Out of Scope
- Production deployment
- Integration with external CI/CD systems
- Advanced Kubernetes resource management
- Custom networking or firewall configuration
- Support for OS beyond macOS, Linux, Windows WSL2

