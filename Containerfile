# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.9
FROM docker.io/library/ruby:$RUBY_VERSION-slim

# Rails app lives here
WORKDIR /app

# Install system dependencies and PostgreSQL 17 client
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    gnupg2 \
    lsb-release \
    ca-certificates && \
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    libjemalloc2 \
    imagemagick \
    postgresql-client-17 \
    git \
    chromium \
    chromium-driver \
    build-essential \
    libpq-dev \
    libyaml-dev \
    pkg-config \
    autoconf \
    automake \
    libtool && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_21.x | bash - && \
    apt-get install --no-install-recommends -y nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install bundler
RUN gem install bundler --no-document && \
    BUNDLER_BIN_PATH=$(ruby -e "require 'rubygems'; print Gem.bindir")/bundle && \
    if [ -f "$BUNDLER_BIN_PATH" ]; then \
        ln -sf "$BUNDLER_BIN_PATH" /usr/local/bin/bundle; \
    fi

# Set environment
ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    PATH="/usr/local/bundle/bin:${PATH}"

# Copy dependency files
COPY Gemfile Gemfile.lock ./
COPY package.json package-lock.json* ./

# Install gems and npm packages
RUN bundle config set with 'development test' && \
    bundle install && \
    npm install

# Copy entire application
COPY . .

# Expose port
EXPOSE 3000

# Default command
CMD ["rails", "server", "-b", "0.0.0.0"]