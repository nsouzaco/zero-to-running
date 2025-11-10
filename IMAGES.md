# Docker Images Required

## Why We Need Images

Kubernetes runs containers, and containers need Docker images. Each service in your development environment needs a Docker image to run.

## Current Image Configuration

### ✅ Already Configured (Standard Images)

These are standard, publicly available images that work out of the box:

1. **PostgreSQL** - `postgres:15-alpine`
   - Standard PostgreSQL database image
   - Works immediately, no changes needed
   - Location: `charts/zero-to-running/values.yaml` line 43-44

2. **Redis** - `redis:7-alpine`
   - Standard Redis cache/session store image
   - Works immediately, no changes needed
   - Location: `charts/zero-to-running/values.yaml` line 65-66

### ⚠️ Placeholder Images (Need Your Actual Images)

These are currently using `nginx:alpine` as placeholders. You need to replace them with your actual application images:

3. **Frontend** - Currently: `nginx:alpine` (placeholder)
   - **You need**: Your frontend application image
   - Examples:
     - `your-registry/frontend:latest`
     - `ghcr.io/your-org/frontend:v1.0.0`
     - `your-frontend-image:dev`
   - Location: `charts/zero-to-running/values.yaml` line 19-20

4. **Backend** - Currently: `nginx:alpine` (placeholder)
   - **You need**: Your backend application image
   - Examples:
     - `your-registry/backend:latest`
     - `ghcr.io/your-org/backend:v1.0.0`
     - `your-backend-image:dev`
   - Location: `charts/zero-to-running/values.yaml` line 31-32

## Options for Your Application Images

### Option 1: Use Existing Images
If you already have Docker images built:
1. Update `charts/zero-to-running/values.yaml`:
   ```yaml
   services:
     frontend:
       image:
         repository: your-frontend-image
         tag: "latest"
     backend:
       image:
         repository: your-backend-image
         tag: "latest"
   ```

### Option 2: Build Images Locally
If you need to build images:
1. Build your images:
   ```bash
   docker build -t your-frontend-image:latest ./frontend
   docker build -t your-backend-image:latest ./backend
   ```
2. Load into Minikube:
   ```bash
   minikube image load your-frontend-image:latest
   minikube image load your-backend-image:latest
   ```
3. Update `values.yaml` as in Option 1

### Option 3: Use Docker Hub / Container Registry
If your images are in a registry:
1. Update `values.yaml` with full image path:
   ```yaml
   services:
     frontend:
       image:
         repository: docker.io/your-username/frontend
         tag: "latest"
   ```

### Option 4: Test with Placeholders First
You can test the CLI infrastructure with nginx placeholders:
- The CLI will work
- Services will deploy and be accessible
- But they'll just show nginx default pages (not your actual app)

## What Happens Without Images?

If you try to deploy without proper images:
- Kubernetes will try to pull the image
- If the image doesn't exist, pods will fail to start
- You'll see errors like "ImagePullBackOff" or "ErrImagePull"

## Quick Test

To test if your setup works with placeholders:
```bash
make dev
```

This will deploy nginx placeholders. Once you confirm the infrastructure works, replace with your actual images.

## Summary

**You need to provide:**
- ✅ PostgreSQL image: Already configured (`postgres:15-alpine`)
- ✅ Redis image: Already configured (`redis:7-alpine`)
- ⚠️ Frontend image: **You need to provide this**
- ⚠️ Backend image: **You need to provide this**

The infrastructure (CLI, Helm charts, port forwarding) is ready. You just need to point it to your actual application images.

