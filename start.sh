#!/usr/bin/env sh
set -eu

ensure_local_node() {
  # If Node is already available in PATH, use it.
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Node already available: $(node -v)"
    return 0
  fi

  # Bundle Node into the app directory so it will also be present at runtime.
  # App Runner copies /app from build to runtime; system package installs do not persist.
  NODE_VERSION="${NODE_VERSION:-22.16.0}"
  OS="linux"

  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64|amd64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *)
      echo "Unsupported architecture: $ARCH" >&2
      return 1
      ;;
  esac

  DEST_DIR=".node"
  if [ -x "$DEST_DIR/bin/node" ] && [ -x "$DEST_DIR/bin/npm" ]; then
    echo "Using bundled Node: $("$DEST_DIR/bin/node" -v)"
    export PATH="$(pwd)/$DEST_DIR/bin:$PATH"
    return 0
  fi

  echo "Bundling Node.js v${NODE_VERSION} for ${OS}-${NODE_ARCH}..."

  if ! command -v curl >/dev/null 2>&1; then
    if command -v yum >/dev/null 2>&1; then
      yum -y install curl ca-certificates || true
    elif command -v dnf >/dev/null 2>&1; then
      dnf -y install curl ca-certificates || true
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update -y
      apt-get install -y curl ca-certificates
    fi
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to download Node.js" >&2
    return 1
  fi

  BASE_URL="https://nodejs.org/dist/v${NODE_VERSION}"
  TARBALL="node-v${NODE_VERSION}-${OS}-${NODE_ARCH}.tar.xz"
  SHASUMS="SHASUMS256.txt"

  # Download checksums and tarball
  curl -fsSLO "${BASE_URL}/${SHASUMS}"
  curl -fsSLO "${BASE_URL}/${TARBALL}"

  # Verify tarball checksum before extracting (supply-chain hardening)
  if command -v sha256sum >/dev/null 2>&1; then
    grep " ${TARBALL}\$" "${SHASUMS}" | sha256sum -c -
  elif command -v shasum >/dev/null 2>&1; then
    # macOS/bsd fallback; unlikely on App Runner but harmless
    EXPECTED="$(grep " ${TARBALL}\$" "${SHASUMS}" | awk '{print $1}')"
    ACTUAL="$(shasum -a 256 "${TARBALL}" | awk '{print $1}')"
    [ "$EXPECTED" = "$ACTUAL" ]
  else
    echo "No SHA-256 tool available to verify Node.js download" >&2
    return 1
  fi

  # Extract and place into .node/
  rm -rf "${DEST_DIR}" "node-v${NODE_VERSION}-${OS}-${NODE_ARCH}"
  tar -xJf "${TARBALL}"
  mv "node-v${NODE_VERSION}-${OS}-${NODE_ARCH}" "${DEST_DIR}"

  # Cleanup downloads to keep the artifact smaller
  rm -f "${TARBALL}" "${SHASUMS}"

  export PATH="$(pwd)/${DEST_DIR}/bin:$PATH"
  echo "Bundled Node ready: $(node -v)"
}

ensure_local_node

node -v
npm -v

npm ci
npm run build

