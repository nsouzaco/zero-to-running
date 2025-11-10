# Testing Guide: Zero-to-Running CLI Tool

## Prerequisites

Before testing, ensure you have:

1. **Docker Desktop** running
2. **Minikube** installed (or let the CLI install it)
3. **Helm** installed
4. **kubectl** installed
5. **Make** installed

The CLI will check these automatically, but you can verify manually:

```bash
docker --version
minikube version
helm version
kubectl version --client
make --version
```

## Quick Test

### 1. Test Dependency Checking

```bash
make dev
```

This will:
- Check all dependencies
- Show installation instructions if anything is missing
- Stop before deployment if dependencies aren't met

**Expected output:**
```
🚀 Starting Zero-to-Running Developer Environment...
Checking dependencies...
⏳ Checking Docker
✓ Docker installed (version X.X.X)
⏳ Checking Minikube
✓ Minikube installed (version X.X.X)
...
```

### 2. Test Full Deployment

Once dependencies are met, run:

```bash
make dev
```

**Expected flow:**
1. ✅ Dependencies checked
2. ⏳ Minikube cluster starting
3. ⏳ Services deploying
4. ⏳ Waiting for services to be healthy
5. ✅ Summary with URLs displayed

**Expected output at end:**
```
✅ All services running and healthy!

📋 Quick Links:
   Frontend:     http://localhost:3001
   Backend API:  http://localhost:3000
   Database:     postgresql://dev_user:dev_password@localhost:5432/dev_db
   Redis:        redis://localhost:6379

⏱️  Total setup time: Xm Ys
```

### 3. Test Status Check

```bash
make dev-status
```

**Expected output:**
```
📋 Service Status
==================

SERVICE         STATUS              PORT       URL
----------------------------------------------------------------
postgres        Running ✓           5432       postgresql://...
redis           Running ✓          6379       redis://...
backend         Running ✓          3000       http://localhost:3000
frontend        Running ✓          3001       http://localhost:3001
```

### 4. Test Log Streaming

```bash
# All services
make dev-logs

# Specific service
make dev-logs backend
```

**Expected:** Real-time logs streaming from services

### 5. Test Teardown

```bash
make dev-down
```

**Expected output:**
```
🛑 Stopping Zero-to-Running Developer Environment...
⏳ Stopping port forwards
✓ Port forwards stopped
⏳ Uninstalling Helm releases
✓ Uninstalled zero-to-running
⏳ Cleaning up namespace: zero-to-running
✓ Namespace cleaned up
✅ Teardown complete!
```

### 6. Test Full Reset

```bash
make dev-reset
```

**Expected:** Complete cleanup including namespace deletion

## Detailed Testing Scenarios

### Scenario 1: First-Time Setup

**Goal:** Test the complete setup flow from scratch

```bash
# 1. Ensure Minikube is stopped
minikube stop 2>/dev/null || true

# 2. Clean up any existing resources
make dev-reset 2>/dev/null || true

# 3. Run setup
make dev

# 4. Verify services are accessible
curl http://localhost:3001  # Frontend
curl http://localhost:3000  # Backend
```

**Success criteria:**
- All dependencies checked
- Minikube starts successfully
- All services deploy
- All services become healthy
- Port forwarding works
- Services are accessible on localhost

### Scenario 2: Error Handling

**Goal:** Test rollback on failure

```bash
# 1. Start deployment
make dev

# 2. Interrupt during deployment (Ctrl+C)
# Press Ctrl+C while services are deploying

# Expected: Automatic rollback and cleanup
```

**Success criteria:**
- Deployment stops gracefully
- Rollback executes
- Resources are cleaned up
- No orphaned processes

### Scenario 3: Port Conflicts

**Goal:** Test handling of port conflicts

```bash
# 1. Start a service on port 3001
python3 -m http.server 3001 &
PORT_PID=$!

# 2. Try to deploy
make dev

# Expected: Warning about port conflict, deployment continues with other ports
```

**Success criteria:**
- Port conflict detected
- Warning message displayed
- Deployment continues for other services
- Port forwarding skips conflicted port

### Scenario 4: Health Check Failure

**Goal:** Test health check timeout and diagnostics

```bash
# 1. Deploy services
make dev

# 2. Manually break a service (e.g., delete pod)
kubectl delete pod -n zero-to-running -l app=backend

# 3. Check status
make dev-status

# Expected: Shows service status, including failures
```

**Success criteria:**
- Health checks detect failures
- Detailed diagnostics shown
- Clear error messages

### Scenario 5: Configuration Override

**Goal:** Test custom configuration

```bash
# 1. Create custom config
cat > dev-config.yaml <<EOF
namespace: zero-to-running
ports:
  frontend: 3002
  backend: 3003
services:
  frontend:
    enabled: true
    image:
      repository: nginx
      tag: alpine
EOF

# 2. Deploy with custom config
make dev

# Expected: Uses custom ports from config
```

**Success criteria:**
- Config file read correctly
- Custom ports used
- Services accessible on custom ports

## Testing Checklist

- [ ] Dependency checking works
- [ ] Minikube cluster starts
- [ ] Services deploy successfully
- [ ] Health checks pass
- [ ] Port forwarding works
- [ ] Services accessible on localhost
- [ ] Status command works
- [ ] Log streaming works
- [ ] Teardown works cleanly
- [ ] Rollback works on failure
- [ ] Ctrl+C handling works
- [ ] Error messages are clear
- [ ] Configuration override works

## Troubleshooting

### Issue: Minikube won't start

```bash
# Check Minikube status
minikube status

# Check Docker
docker info

# Try starting manually
minikube start --driver=docker
```

### Issue: Services won't become healthy

```bash
# Check pod status
kubectl get pods -n zero-to-running

# Check pod logs
kubectl logs -n zero-to-running -l app=backend

# Check events
kubectl get events -n zero-to-running --sort-by='.lastTimestamp'
```

### Issue: Port forwarding fails

```bash
# Check if ports are in use
lsof -i :3000
lsof -i :3001

# Check port forward PIDs
cat .dev/port-forward.pids

# Manually forward ports
kubectl port-forward -n zero-to-running svc/zero-to-running-frontend 3001:3001
```

### Issue: Helm deployment fails

```bash
# Check Helm releases
helm list -n zero-to-running

# Check Helm history
helm history zero-to-running -n zero-to-running

# Try manual deployment
helm install zero-to-running charts/zero-to-running -n zero-to-running
```

## Performance Testing

### Test Setup Time

```bash
# Time the setup
time make dev

# Expected: Under 10 minutes on first run
```

### Test Resource Usage

```bash
# Check Minikube resources
minikube ssh -- df -h
minikube ssh -- free -h

# Check pod resources
kubectl top pods -n zero-to-running
```

## Next Steps After Testing

1. **Replace placeholder images** with your actual frontend/backend images
2. **Customize configuration** for your specific needs
3. **Add custom health checks** if needed
4. **Test with your actual application code**
5. **Set up CI/CD** for automated testing

## Getting Help

- Check logs: `.dev/logs/`
- Run help: `make dev-help`
- Check status: `make dev-status`
- View logs: `make dev-logs [service]`

