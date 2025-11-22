# STAGE 1: Build the Scramjet Frontend
FROM node:20-alpine AS builder

# Install git to clone the repo
RUN apk add --no-cache git

WORKDIR /app

# 1. Clone the repository
RUN git clone --depth 1 https://github.com/MercuryWorkshop/Scramjet-App .

# 2. Install pnpm (Required because the repo uses pnpm-lock.yaml)
# We install it globally first so we can use it for the project dependencies
RUN npm install -g pnpm

# 3. Install dependencies using pnpm
# This respects the upstream lockfile for exact reproducibility
RUN pnpm install

# 4. Build the static assets
RUN pnpm run build

# STAGE 2: The Wisp Python Backend
FROM python:3.11-slim

# SECURITY: Create a non-root user
RUN useradd -m -u 1000 scramjet

WORKDIR /app

# Install the Wisp Server
RUN pip install --no-cache-dir wisp-python

# Copy the compiled frontend from Stage 1
COPY --from=builder /app/dist /app/client

# SECURITY: Switch to non-root user
USER scramjet

# Expose the port
EXPOSE 8080

# OPTIMAL COMMAND:
# Runs the Wisp server and serves the static client files directly
CMD ["python3", "-m", "wisp.server", "--host", "0.0.0.0", "--port", "8080", "--static", "/app/client", "--limits", "--connections", "50", "--log-level", "info"]
