# The below image is created out of the Dockerfile.base
# It has the dependencies already installed so that codespace will boot up fast
FROM ghcr.io/chatwoot/chatwoot_codespace:latest

# Base image runs as a non-root user; COPY creates root-owned files, so bundle cannot
# update Gemfile.lock without this.
USER root

# Do the set up required for chatwoot app
WORKDIR /workspace

# Copy dependency files first for better caching
COPY package.json pnpm-lock.yaml ./
COPY Gemfile Gemfile.lock ./

# Install dependencies (will be cached if files don't change)
RUN pnpm install --frozen-lockfile && \
    gem install bundler && \
    bundle install --jobs=$(nproc)

# Copy source code after dependencies are installed
COPY . /workspace

# Match devcontainer UID so tools work when not overridden by the bind mount
RUN chown -R 1000:1000 /workspace
USER 1000
