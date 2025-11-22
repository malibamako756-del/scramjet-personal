# STAGE 1: Build the Scramjet Frontend
# We use the latest Node.js Alpine for a lightweight build environment
FROM node:20-alpine AS builder

# Install git to clone the repo (required as Scramjet is not on npm)
RUN apk add --no-cache git

WORKDIR /app

# 1. Clone the repository
# We use depth 1 to save bandwidth/time.
RUN git clone --depth 1 https://github.com/MercuryWorkshop/Scramjet-App .

# 2. Install dependencies
# We use 'npm ci' instead of 'install' for a clean, reproducible build
RUN npm ci

# 3. Build the static assets
# This compiles the bare-mux, epoxy, and wisp client code
RUN npm run build

# STAGE 2: The Wisp Python Backend
# Python 3.11 is explicitly recommended by Mercury Workshop for performance
FROM python:3.11-slim

# SECURITY: Create a non-root user. 
# Running as root is a security violation for public proxies.
RUN useradd -m -u 1000 scramjet

WORKDIR /app

# Install the Wisp Server
RUN pip install --no-cache-dir wisp-python

# Copy the compiled frontend from Stage 1 to the backend
COPY --from=builder /app/dist /app/client

# SECURITY: Switch to non-root user
USER scramjet

# Expose the port
EXPOSE 8080

# OPTIMAL COMMAND EXPLANATION:
# --host 0.0.0.0: Required for Docker networking.
# --port 8080: Standard non-privileged port.
# --static /app/client: Serves the Scramjet frontend DIRECTLY from Python (Zero latency overhead).
# --limits: Enables the rate limiter for safety.
# --connections 50: Prevents a single user from crashing the server by opening 1000s of sockets.
# --log-level info: Keeps logs clean but visible.
CMD ["python3", "-m", "wisp.server", "--host", "0.0.0.0", "--port", "8080", "--static", "/app/client", "--limits", "--connections", "50", "--log-level", "info"]
