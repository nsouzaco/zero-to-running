#!/usr/bin/env node

const express = require('express');
const { exec } = require('child_process');
const { promisify } = require('util');
const WebSocket = require('ws');
const cors = require('cors');
const path = require('path');

const execAsync = promisify(exec);
const app = express();
const PORT = process.env.PORT || 3002;
const NAMESPACE = process.env.NAMESPACE || 'zero-to-running';

app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Get service status
app.get('/api/status', async (req, res) => {
  try {
    const services = ['postgres', 'redis', 'backend', 'frontend'];
    const status = {};

    for (const service of services) {
      try {
        // Get pod status
        const { stdout: podInfo } = await execAsync(
          `kubectl get pods -n ${NAMESPACE} -l app=${service} -o json`
        );
        const pods = JSON.parse(podInfo);
        
        if (pods.items && pods.items.length > 0) {
          const pod = pods.items[0];
          const phase = pod.status.phase;
          const ready = pod.status.conditions?.find(c => c.type === 'Ready')?.status === 'True';
          const startTime = pod.status.startTime;
          
          // Get resource usage if available
          let cpu = 'N/A';
          let memory = 'N/A';
          try {
            const { stdout: topInfo } = await execAsync(
              `kubectl top pod ${pod.metadata.name} -n ${NAMESPACE} 2>/dev/null || echo ""`
            );
            if (topInfo) {
              const parts = topInfo.split('\n')[1]?.split(/\s+/) || [];
              if (parts.length >= 3) {
                cpu = parts[1];
                memory = parts[2];
              }
            }
          } catch (e) {
            // Metrics not available
          }

          status[service] = {
            name: service,
            status: ready && phase === 'Running' ? 'Running' : phase,
            ready: ready,
            phase: phase,
            uptime: startTime ? calculateUptime(startTime) : 'N/A',
            cpu: cpu,
            memory: memory,
            podName: pod.metadata.name
          };
        } else {
          status[service] = {
            name: service,
            status: 'Not Found',
            ready: false
          };
        }
      } catch (error) {
        status[service] = {
          name: service,
          status: 'Error',
          error: error.message
        };
      }
    }

    // Get service URLs
    const urls = {
      frontend: `http://localhost:3001`,
      backend: `http://localhost:3000`,
      postgres: `postgresql://dev_user:dev_password@localhost:5432/dev_db`,
      redis: `redis://localhost:6379`
    };

    res.json({ services: status, urls });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get service logs
app.get('/api/logs/:service', async (req, res) => {
  const { service } = req.params;
  const lines = req.query.lines || 100;

  try {
    const { stdout } = await execAsync(
      `kubectl logs -n ${NAMESPACE} -l app=${service} --tail=${lines} 2>&1 || echo "No logs available"`
    );
    res.json({ logs: stdout });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Restart service
app.post('/api/restart/:service', async (req, res) => {
  const { service } = req.params;

  try {
    await execAsync(
      `kubectl rollout restart deployment -n ${NAMESPACE} -l app=${service}`
    );
    res.json({ success: true, message: `Restarting ${service}...` });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// WebSocket for log streaming
const wss = new WebSocket.Server({ noServer: true });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const service = url.searchParams.get('service');

  if (!service) {
    ws.close(1008, 'Service parameter required');
    return;
  }

  const logProcess = exec(`kubectl logs -n ${NAMESPACE} -l app=${service} -f 2>&1`);

  logProcess.stdout.on('data', (data) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(data.toString());
    }
  });

  logProcess.stderr.on('data', (data) => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(data.toString());
    }
  });

  logProcess.on('close', () => {
    if (ws.readyState === WebSocket.OPEN) {
      ws.close();
    }
  });

  ws.on('close', () => {
    logProcess.kill();
  });
});

// Upgrade HTTP to WebSocket
const server = app.listen(PORT, () => {
  console.log(`🚀 Zero-to-Running Dashboard running on http://localhost:${PORT}`);
  console.log(`📊 Monitoring namespace: ${NAMESPACE}`);
});

server.on('upgrade', (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

// Helper function to calculate uptime
function calculateUptime(startTime) {
  const start = new Date(startTime);
  const now = new Date();
  const diff = now - start;
  
  const seconds = Math.floor(diff / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);
  const days = Math.floor(hours / 24);
  
  if (days > 0) return `${days}d ${hours % 24}h`;
  if (hours > 0) return `${hours}h ${minutes % 60}m`;
  if (minutes > 0) return `${minutes}m ${seconds % 60}s`;
  return `${seconds}s`;
}

