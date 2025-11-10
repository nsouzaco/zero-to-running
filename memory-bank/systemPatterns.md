# System Patterns: Zero-to-Running CLI Tool

## Architecture Overview

### High-Level Architecture
```
Developer → Makefile/CLI → Shell Scripts → kubectl/Helm → Minikube → Services
```

### Component Relationships
1. **CLI Entry Point**: Makefile or shell script wrapper
2. **Dependency Checker**: Validates required tools before proceeding
3. **Cluster Manager**: Handles Minikube cluster lifecycle
4. **Deployment Manager**: Orchestrates Helm chart deployment
5. **Health Checker**: Monitors service health and readiness
6. **Status Reporter**: Aggregates and displays service status
7. **Log Aggregator**: Collects and streams logs from services
8. **Dashboard Server**: Lightweight web UI for visual monitoring

## Key Technical Decisions

### CLI Implementation
- **Makefile as primary interface**: Familiar to developers, easy to extend
- **Bash/POSIX shell scripts**: Maximum portability across platforms
- **Modular script design**: Separate scripts for each major operation

### Deployment Strategy
- **Helm charts**: Standard Kubernetes deployment mechanism
- **Namespace isolation**: Each project gets its own namespace
- **Service dependencies**: Wait for dependencies (DB, Redis) before starting dependent services

### Error Handling Pattern
- **Automatic rollback**: On setup failure, clean teardown of partially deployed services
- **Graceful interruption**: Handle Ctrl+C with cleanup
- **Detailed error logs**: Store in `.dev/logs/` for debugging
- **Actionable error messages**: Every error includes remediation steps

### Configuration Management
- **YAML config file**: `dev-config.yaml` in project root
- **CLI flag overrides**: Command-line flags override config file
- **Profile support**: Multiple config profiles (minimal, full, debug)
- **Validation**: Schema validation with clear error messages

### Progress Feedback Pattern
- **Real-time status updates**: Show progress for each phase
- **Visual indicators**: Checkmarks (✓), spinners (⏳), X (✗)
- **Estimated wait times**: Display during long operations
- **Completion percentage**: When determinable

## Design Patterns

### Dependency Injection
- Scripts check for dependencies before use
- Provide clear installation instructions if missing

### Retry Logic
- Allow users to retry failed operations after rollback
- Automatic retry for transient failures (with limits)

### Resource Cleanup
- Always clean up on failure or interruption
- No orphaned processes or dangling resources

### Status Aggregation
- Collect status from all services
- Present unified view to user
- Show health metrics when available

## Service Architecture
- **Frontend**: Web application (port 3001)
- **Backend API**: REST API (port 3000)
- **PostgreSQL**: Database (port 5432)
- **Redis**: Cache/session store (port 6379)
- **Dashboard**: Local web UI (port 3002)

## Communication Patterns
- **kubectl commands**: Direct cluster interaction
- **Helm commands**: Chart deployment and management
- **Port forwarding**: Expose services to localhost
- **Log streaming**: Real-time log aggregation

