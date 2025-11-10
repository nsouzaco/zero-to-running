# Technical Context: Zero-to-Running CLI Tool

## Technologies Used

### Core Technologies
- **Makefile**: Primary CLI interface and command orchestration
- **Bash/POSIX Shell**: Scripting language for portability
- **Helm 3+**: Kubernetes package manager for service deployment
- **Minikube**: Local Kubernetes cluster for development
- **kubectl**: Kubernetes command-line tool for cluster interaction
- **Docker**: Container runtime (via Docker Desktop or equivalent)

### Configuration
- **YAML**: Configuration file format (`dev-config.yaml`)
- **JSON**: Optional structured logging output

### Output Formatting
- **ANSI color codes**: Color-coded output (green success, red errors, yellow warnings)
- **Unicode symbols**: Visual indicators (✓, ✗, ⏳, 🚀, ✅, ❌)
- **Structured logging**: Machine-parseable logs when needed

## Development Setup

### Required Tools
- **Docker Desktop** or equivalent container runtime
- **Minikube** (version 1.31.0+)
- **Helm** (version 3.12.0+)
- **kubectl** (version 1.27.0+)
- **Make** (standard on macOS/Linux, available on Windows via WSL2)

### Platform Support
- **macOS**: Intel and Apple Silicon
- **Linux**: Ubuntu, Fedora (and other distributions with Docker support)
- **Windows**: WSL2 only

### System Requirements
- **RAM**: Minimum 8GB available
- **Disk Space**: 10GB free space
- **Internet**: Required for initial downloads and image pulls

## Technical Constraints

### Hard Dependencies
- Minikube is the only supported Kubernetes distribution for local development
- Docker Desktop or equivalent is required (no alternative container runtimes)
- Helm 3+ required (Helm 2 not supported)
- kubectl must be configured and accessible

### Platform-Specific Considerations
- **macOS**: Handle both Intel and Apple Silicon architectures
- **Linux**: Handle different package managers and PATH configurations
- **Windows WSL2**: Ensure proper PATH handling and file system access

### Resource Constraints
- Each project runs in isolated Kubernetes namespace
- Single Minikube cluster shared across projects
- Port conflicts must be detected and handled gracefully

## Dependencies

### External Tools
- Docker (container runtime)
- Minikube (Kubernetes cluster)
- Helm (package manager)
- kubectl (cluster client)

### Internal Dependencies
- Helm charts for service deployment
- Service definitions and configurations
- Health check scripts
- Log aggregation utilities

## Development Workflow

### Local Development
1. Write/update Makefile targets
2. Create/update shell scripts
3. Test on local Minikube cluster
4. Validate error handling and rollback
5. Test on multiple platforms

### Testing Strategy
- Test dependency checking
- Test setup and teardown flows
- Test error scenarios and recovery
- Test configuration file handling
- Test platform-specific behaviors

## Performance Requirements
- CLI commands respond within 2 seconds (excluding service startup)
- Setup completes within 10 minutes on first run
- Status checks complete within 5 seconds
- Log streaming latency under 1 second

## Security Considerations
- Never log or display sensitive data (credentials, API keys)
- Securely handle mock secrets in configuration
- Validate all user inputs to prevent injection attacks
- Store error logs securely in `.dev/logs/` directory

