#!/usr/bin/env sh
set -eu

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Node already installed: $(node -v)"
    return 0
  fi

  echo "Node not found; installing Node.js 22..."

  if command -v yum >/dev/null 2>&1; then
    # Amazon Linux 2/2023
    yum -y update || true
    yum -y install curl ca-certificates || true
    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
    yum -y install nodejs
    return 0
  fi

  if command -v dnf >/dev/null 2>&1; then
    # Some newer RPM distros
    dnf -y install curl ca-certificates || true
    curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
    dnf -y install nodejs
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    # Debian/Ubuntu
    apt-get update -y
    apt-get install -y curl ca-certificates
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
    return 0
  fi

  echo "No supported package manager found to install Node.js." >&2
  return 1
}

ensure_node
node -v
npm -v

npm ci
npm run build

