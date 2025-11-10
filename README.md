# Zero-to-Running CLI Tool

A CLI tool that abstracts Kubernetes complexity and enables developers to provision a fully functional multi-service development environment with a single command.

## Quick Start

```bash
# Start the development environment
make dev

# Check status
make dev-status

# View logs
make dev-logs

# Stop services
make dev-down

# Get help
make dev-help
```

## Testing

See [TESTING.md](TESTING.md) for comprehensive testing instructions.

**Quick test:**
```bash
# 1. Check dependencies (will stop if missing)
make dev

# 2. Verify services are running
make dev-status

# 3. Test service access
curl http://localhost:3001  # Frontend
curl http://localhost:3000  # Backend

# 4. Clean up
make dev-down
```

## Prerequisites

- Docker Desktop or equivalent container runtime
- Minikube (version 1.31.0+)
- Helm (version 3.12.0+)
- kubectl (version 1.27.0+)
- Make

The CLI will check for these dependencies automatically and provide installation instructions if missing.

## Project Structure

```
zero-to-running/
├── Makefile                 # Main CLI interface
├── scripts/                 # Shell scripts for operations
│   ├── check-dependencies.sh
│   ├── setup-cluster.sh
│   ├── deploy-services.sh
│   ├── wait-for-healthy.sh
│   ├── show-status.sh
│   ├── stream-logs.sh
│   ├── teardown.sh
│   ├── setup-port-forwarding.sh
│   ├── open-dashboard.sh
│   ├── show-help.sh
│   ├── cleanup.sh
│   └── utils.sh            # Utility functions
├── charts/                  # Helm charts
│   └── zero-to-running/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── config/                  # Configuration templates
│   └── dev-config.yaml.template
├── .dev/                    # Runtime files
│   └── logs/                # Error logs
└── memory-bank/             # Project documentation
```

## Configuration

Create a `dev-config.yaml` file in the project root to customize settings:

```yaml
namespace: zero-to-running

ports:
  frontend: 3001
  backend: 3000
  postgres: 5432
  redis: 6379

services:
  frontend:
    enabled: true
    image:
      repository: your-frontend-image
      tag: "latest"
  backend:
    enabled: true
    image:
      repository: your-backend-image
      tag: "latest"
```

See `config/dev-config.yaml.template` for all available options.

## Services

The default setup includes:

- **Frontend** - Web application (localhost:3001)
- **Backend** - REST API (localhost:3000)
- **PostgreSQL** - Database (localhost:5432)
- **Redis** - Cache/session store (localhost:6379)

## Customizing Service Images

The Helm charts currently use placeholder images (nginx) for frontend and backend. To use your own images:

1. Update `charts/zero-to-running/values.yaml` with your image repositories
2. Or create a `dev-config.yaml` file with your image settings
3. The deploy script will use your configuration

## Commands

### `make dev`
Start the development environment. This will:
- Check dependencies
- Start Minikube cluster
- Deploy all services via Helm
- Wait for services to be healthy
- Set up port forwarding
- Display service URLs

### `make dev-down`
Stop all services and clean up resources.

### `make dev-status`
Show the status of all running services, including ports and URLs.

### `make dev-logs [service]`
Stream logs from all services or a specific service:
```bash
make dev-logs          # All services
make dev-logs backend  # Backend only
```

### `make dev-dashboard`
Open the local dashboard in your browser (if configured).

### `make dev-reset`
Perform a full cleanup, removing all resources and resetting the environment.

### `make dev-help`
Display help information.

## Troubleshooting

### Port conflicts
If a port is already in use, the CLI will warn you. You can:
- Stop the conflicting process
- Use a different port in `dev-config.yaml`
- Run `make dev-reset` to clean up

### Services not starting
- Check logs: `make dev-logs [service]`
- Check status: `make dev-status`
- Check Minikube: `minikube status`
- Check pods: `kubectl get pods -n zero-to-running`

### Dependency issues
The CLI will check dependencies automatically. If something is missing, it will provide installation instructions.

## Development

### Adding New Services

1. Add service configuration to `charts/zero-to-running/values.yaml`
2. Create deployment and service templates in `charts/zero-to-running/templates/`
3. Update `scripts/wait-for-healthy.sh` to include the new service
4. Update port forwarding in `scripts/setup-port-forwarding.sh`

### Testing

Test the CLI on your local machine:
```bash
# Test dependency checking
make dev  # Will check dependencies first

# Test with custom config
make dev PORT=3002
```

## Notes

- Services use ClusterIP and port forwarding for localhost access
- All services are deployed in a single Kubernetes namespace
- Logs are stored in `.dev/logs/` for debugging
- Port forwarding PIDs are stored in `.dev/port-forward.pids`

## Next Steps

1. **Replace placeholder images**: Update the frontend and backend images in `values.yaml` or `dev-config.yaml`
2. **Customize health checks**: Adjust health check endpoints in the Helm templates if needed
3. **Add dashboard**: Implement the dashboard web UI (P1 feature)
4. **Add tests**: Create integration tests for the setup process

## License

[Add your license here]

