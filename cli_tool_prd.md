# Zero-to-Running CLI Tool
## Product Requirements Document (PRD)

**Organization:** Wander  
**Project ID:** 3MCcAvCyK7F77BpbXUSI_CLI_001  
**Date:** November 2025

---

## 1. Executive Summary

The Zero-to-Running CLI Tool is the user-facing interface for the Zero-to-Running Developer Environment. This tool abstracts the complexity of Kubernetes orchestration and local environment management, enabling developers to provision a fully functional multi-service development environment with a single command. The CLI provides clear feedback, error handling, and straightforward commands (e.g., `make dev`, `make dev-down`) that shield developers from infrastructure complexity while maintaining visibility into the setup process.

---

## 2. Problem Statement

Developers need a simple, intuitive way to interact with the Zero-to-Running Developer Environment without requiring deep knowledge of Kubernetes, Helm, or Docker. While the underlying infrastructure uses these technologies, the CLI must abstract this complexity and present developers with a seamless, human-friendly interface. Poor CLI design leads to confusion, support overhead, and failed setups.

---

## 3. Goals & Success Metrics

**Goal:** Provide an intuitive, forgiving CLI interface that makes environment setup accessible to all developers regardless of their ops expertise.

**Success Metrics:**
- Time to first successful setup: under 5 minutes (including dependency checks)
- Setup success rate on first attempt: 90%+
- Support tickets related to CLI usage: fewer than 5% of total support load
- Developer satisfaction with setup process: 4.5/5 or higher (NPS score)
- Documentation page views/searches: less than 20% of users need to consult docs beyond `--help`

---

## 4. Target Users & Personas

**Target Users:** Software engineers of all experience levels, particularly new hires and developers switching between projects.

**Personas:**

**Persona 1: New Developer (Alex)**
- Fresh to the team, minimal ops experience
- Needs step-by-step guidance and clear success indicators
- Wants to avoid frustration on day one
- Reads output carefully but doesn't want excessive verbosity

**Persona 2: Experienced Developer (Jamie)**
- Strong ops background, wants efficiency
- May want to customize configuration
- Appreciates details but wants to skip unnecessary steps
- Wants to understand what's happening under the hood

**Persona 3: Frustrated Developer (Casey)**
- Tried to set up before and failed
- Suspicious that "one command" really works
- Needs reassurance and clear error messages
- Wants to know exactly what to do if something breaks

---

## 5. User Stories

**Core Setup Flow:**
- As a new developer, I want to run a single command and have my entire environment set up so that I can start coding immediately without troubleshooting.
- As a developer, I want to see clear, real-time feedback during setup so that I know progress is being made and can identify where things go wrong.
- As a developer, I want the CLI to check for and warn me about missing dependencies before attempting setup so that I can install them and try again.

**Configuration & Customization:**
- As an experienced developer, I want to customize port numbers, enable debug mode, and seed test data via a config file so that I can tailor the environment to my preferences.
- As a developer, I want to override specific settings with command-line flags so that I can run one-off experiments without editing config files.

**Troubleshooting & Error Handling:**
- As a developer, I want helpful error messages that tell me exactly what went wrong and how to fix it so that I can resolve issues without Googling or asking teammates.
- As a developer, I want to see detailed logs when something fails so that I can understand the root cause.

**Lifecycle Management:**
- As a developer, I want to stop my environment cleanly with a single command so that I can free up resources and avoid port conflicts.
- As a developer, I want a "reset" command that completely tears down and cleans up my environment so that I can start fresh if needed.
- As a developer, I want to check the status of my environment anytime so that I know which services are running and how to access them.

---

## 6. Functional Requirements

### P0: Must-Have

**Command Set:**
- `make dev` – Initialize and start all services with dependency checks and progress feedback
- `make dev-down` – Gracefully stop all services and free resources
- `make dev-status` – Display the status of all running services, port mappings, and access URLs
- `make dev-logs` – Stream real-time logs from all services or a specific service
- `make dev-dashboard` – Open the local dashboard in default browser (auto-launched after `make dev` unless disabled)

**Dependency Management:**
- Check for required tools (Docker, Minikube, Helm, kubectl) before attempting setup
- Provide clear, actionable instructions if dependencies are missing (include download links and OS-specific guidance)
- Support automatic installation of Minikube if it's missing (with user confirmation)
- Validate that all required versions meet minimum requirements

**Setup Process:**
- Start Minikube cluster if not already running
- Deploy Helm chart with all services (frontend, backend, database, Redis)
- Wait for all services to report healthy before declaring setup complete
- Display service access URLs (frontend, backend, database connection string) upon success
- Total time from first command to ready state: under 10 minutes

**Progress Feedback:**
- Show real-time status updates for each phase (checking dependencies, starting cluster, deploying services)
- Use visual indicators (checkmarks for success, spinners for in-progress, X for errors)
- Display estimated wait times during long operations
- Show completion percentage if determinable

**Error Handling & Recovery:**
- Detect common errors (port conflicts, insufficient disk space, outdated dependencies) and suggest fixes
- Provide clear error messages with context and remediation steps
- Automatic rollback on setup failure: clean teardown of partially deployed services to ensure no orphaned processes
- Allow users to retry failed operations after rollback completes
- Gracefully handle interruptions (Ctrl+C) with automatic rollback and cleanup
- Provide detailed error logs in `.dev/logs/` directory for debugging

**Configuration:**
- Support a `dev-config.yaml` file in the project root for persistent customization
- Allow command-line flags to override config file settings (e.g., `make dev PORT=3002`)
- Document all configurable options with clear defaults
- Validate configuration file syntax and alert on invalid settings

### P1: Should-Have

**Enhanced Status Output:**
- `make dev-status` shows service health metrics (CPU, memory usage if available)
- Display uptime for each service
- Show last 5 lines of logs for each service inline in status output

**Advanced Commands:**
- `make dev-restart [service]` – Restart a specific service without full teardown
- `make dev-shell [service]` – Open an interactive shell into a service container for debugging
- `make dev-attach [service]` – View live logs for a specific service with filtering

**Configuration Profiles:**
- Support multiple config profiles (e.g., `dev-minimal.yaml`, `dev-full.yaml`)
- Allow users to specify which profile to use: `make dev PROFILE=minimal`
- Include pre-built profiles: minimal (no seeding), full (with test data), debug (debug ports exposed)

**Notification & Notifications:**
- Desktop notifications when setup completes or fails (macOS, Linux, Windows)
- Optional email/Slack notification for failed setups
- Health check alerts if a service stops unexpectedly

**Performance:**
- Display setup time statistics on completion
- Compare setup time to baseline and alert if significantly slower
- Suggest optimizations if setup exceeds target time

**Dashboard (Local Web UI):**
- Lightweight web dashboard running on localhost:3002 (customizable port)
- Launched automatically after successful setup (can be dismissed and re-opened with `make dev-dashboard`)
- Displays real-time status of all services (health, uptime, resource usage)
- Stream live logs from any service with filtering and search
- Quick action buttons: restart service, view details, export logs
- Shows access URLs and connection strings for all services
- Responsive design for desktop and tablet viewing

### P2: Nice-to-Have

**CI/CD Integration:**
- Automated testing of setup process across supported platforms (macOS Intel, Apple Silicon, Ubuntu, Windows WSL2)
- Scheduled nightly tests to catch regressions in Helm charts or scripts
- Automated alerts if setup success rate drops below 85% on any platform
- Test matrix for different dependency versions (Docker, Minikube, Helm versions)

**Interactive Setup Wizard:**
- Guided setup flow with prompts for first-time users (enable with `make dev-init`)
- Ask about preferred configuration options and save selections
- Provide explanations for each configuration choice

**Environment Validation:**
- Post-setup smoke tests (e.g., test API connectivity, database queries, Redis ping)
- Report any services that are running but unhealthy
- Suggest common fixes for detected issues

**Documentation Integration:**
- `make dev-help` displays comprehensive help with examples
- Link to relevant docs from error messages
- Show tips and tricks on successful setup completion

**Analytics (Privacy-Respecting):**
- Optional, anonymized tracking of setup success rates and common failure points
- Help teams understand adoption blockers without collecting sensitive data

---

## 7. Non-Functional Requirements

**Performance:**
- CLI commands must respond within 2 seconds (excluding actual service startup)
- Setup process must complete within 10 minutes on first run
- Status checks must complete within 5 seconds
- Log streaming must have minimal latency (under 1 second)

**Reliability:**
- Setup must succeed 95%+ of the time on supported platforms
- Teardown must always succeed, even if services are in an inconsistent state
- No orphaned processes or dangling resources after teardown

**Usability:**
- Output must be clear and concise (avoid wall-of-text output)
- Error messages must be actionable (not cryptic technical errors)
- All required information for troubleshooting must be available without external docs

**Portability:**
- Support macOS (Intel and Apple Silicon), Linux (Ubuntu, Fedora), and Windows (WSL2)
- Handle OS-specific PATH and installation differences transparently

**Security:**
- Never log or display sensitive data (credentials, API keys)
- Securely handle mock secrets in configuration
- Validate all user inputs to prevent injection attacks

---

## 8. User Experience & Design Considerations

**Design Principles:**

**Clarity:** Every output should be understandable to a developer seeing this for the first time. Avoid jargon without explanation.

**Progress Visibility:** Long-running operations must show progress. Users should never wonder if the CLI is stuck.

**Graceful Degradation:** If a feature isn't available (e.g., Minikube auto-install on a restricted system), the CLI should explain why and suggest alternatives.

**Discoverability:** Running `make dev --help` or `make dev-help` should provide all information needed without consulting external docs.

**Output Examples:**

**Successful Setup:**
```
$ make dev

🚀 Starting Zero-to-Running Developer Environment...

Checking dependencies...
✓ Docker installed (version 24.0.5)
✓ Minikube installed (version 1.31.0)
✓ Helm installed (version 3.12.0)
✓ kubectl installed (version 1.27.0)

Starting Minikube cluster...
⏳ Initializing cluster (this takes ~30 seconds on first run)...
✓ Cluster ready (4 CPUs, 8GB memory)

Deploying services...
⏳ PostgreSQL starting...
✓ PostgreSQL ready (port 5432)

⏳ Redis starting...
✓ Redis ready (port 6379)

⏳ Backend API starting...
⏳ Waiting for database to be healthy...
✓ Backend API ready (http://localhost:3000)

⏳ Frontend starting...
✓ Frontend ready (http://localhost:3001)

✅ All services running and healthy!

📋 Quick Links:
   Frontend:     http://localhost:3001
   Backend API:  http://localhost:3000
   Database:     postgresql://user:pass@localhost:5432/dev_db
   Redis:        redis://localhost:6379

⏱️  Total setup time: 4 minutes 23 seconds

💡 Next steps:
   1. Open http://localhost:3001 in your browser
   2. Start coding! Your changes will auto-reload
   3. Run 'make dev-status' anytime to check service health
   4. Run 'make dev-down' when you're done

💬 Need help? Run 'make dev-help' or check docs/SETUP.md
```

**Error with Guidance:**
```
❌ Error: Port 3001 is already in use

This usually means another process is using that port. Here are your options:

Option 1 (Recommended): Stop the other process
   $ lsof -i :3001
   $ kill -9 <PID>

Option 2: Use a different port
   $ make dev PORT=3002

Option 3: Full cleanup and restart
   $ make dev-reset
   $ make dev
```

---

## 9. Technical Requirements

**Technology Stack:**
- Makefile or shell script as CLI entry point
- Bash/POSIX shell for portability
- Helm for Kubernetes deployment
- Minikube for local Kubernetes cluster
- kubectl for cluster interaction

**Output Formatting:**
- Color-coded output (green for success, red for errors, yellow for warnings)
- Unicode symbols (✓, ✗, ⏳) for visual clarity
- Structured logging for machine parsing if needed

**Configuration File Format:**
- YAML for `dev-config.yaml` (human-readable and editable)
- Schema validation with clear error messages for invalid configs

**Exit Codes:**
- 0: Success
- 1: General error
- 2: Dependency missing
- 3: Configuration error
- 4: Service health check failed

---

## 10. Dependencies & Assumptions

**Hard Dependencies:**
- Minikube (local Kubernetes cluster) – Only supported K8s distribution for local development
- Docker Desktop or equivalent container runtime
- Helm 3+
- kubectl

**Assumptions:**
- Developers have basic command-line familiarity
- At least 8GB of RAM available on developer machines
- 10GB of free disk space
- Internet connectivity for initial downloads
- Users run on supported platforms (macOS, Linux, Windows with WSL2)
- Each project runs in its own isolated Kubernetes namespace within a single Minikube cluster
- Automatic rollback on setup failure ensures clean state (no orphaned services)

**Out of Scope:**
- Production deployment of this environment
- Integration with external CI/CD systems
- Advanced Kubernetes resource management
- Custom networking or firewall configuration
- Support for operating systems beyond macOS, Linux, and Windows WSL2

---

## 11. Success Criteria & Rollout

**Phase 1: Soft Launch (Internal Testing)**
- Deploy to 5-10 internal developers
- Measure setup success rate, time, and support requests
- Gather feedback on clarity of output and error messages
- Target: 85%+ success rate on first attempt

**Phase 2: Wider Launch (Team Rollout)**
- Deploy to full engineering team
- Monitor adoption and identify usage patterns
- Iterate on error messages and output based on real usage
- Target: 90%+ success rate, < 30 minutes total support time per developer

**Phase 3: Public Release (If Applicable)**
- Final polish and documentation
- Create video tutorial for setup process
- Set up dedicated support channel
- Target: 95%+ success rate, self-service resolution for 80%+ of issues

---

## 12. Metrics & Monitoring

**Key Metrics to Track:**
- Setup success rate (first attempt and eventual success)
- Average setup time (track improvements over versions)
- Most common failure points
- Support ticket volume related to CLI
- User satisfaction (via brief post-setup survey)
- Platform-specific success rates (macOS vs. Linux vs. Windows)

**Logging & Analytics:**
- Log all CLI commands executed (anonymized, opt-in)
- Track error rates and types
- Monitor for performance regressions
- Alert if success rate drops below 85%

---

---

## Conclusion

The Zero-to-Running CLI Tool must be the epitome of simplicity and clarity. Developers should feel confident running a single command and trusting that the environment will be set up correctly. Every error message, every line of output, and every design decision should reflect a commitment to making developer life easier. Success is measured not by feature richness, but by how quickly developers can start writing code.