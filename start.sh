#!/usr/bin/env sh
# App Runner *build* command: sh start.sh
# Python 3.11 managed runtime: no system Node at build or run — bundle Node under ./.node
set -eu
cd "$(dirname "$0")"

ensure_local_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    echo "Node already available: $(node -v)"
    return 0
  fi

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

  # Prefer .tar.gz: gzip + tar -xzf works on minimal images; .tar.xz needs xz (often missing).
  echo "Bundling Node.js v${NODE_VERSION} for ${OS}-${NODE_ARCH} (.tar.gz)..."

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
  TARBALL="node-v${NODE_VERSION}-${OS}-${NODE_ARCH}.tar.gz"
  SHASUMS="SHASUMS256.txt"

  curl -fsSLO "${BASE_URL}/${SHASUMS}"
  curl -fsSLO "${BASE_URL}/${TARBALL}"

  verify_sha256() {
    EXPECTED="$(grep -F "  ${TARBALL}" "${SHASUMS}" | head -n1 | awk '{print $1}')"
    if [ -z "${EXPECTED}" ]; then
      echo "Could not find checksum line for ${TARBALL} in ${SHASUMS}" >&2
      return 1
    fi
    if command -v sha256sum >/dev/null 2>&1; then
      printf '%s  %s\n' "${EXPECTED}" "${TARBALL}" | sha256sum -c -
      return $?
    fi
    if command -v openssl >/dev/null 2>&1; then
      ACTUAL="$(openssl dgst -sha256 "${TARBALL}" | awk '{print $NF}')"
      [ "${EXPECTED}" = "${ACTUAL}" ]
      return $?
    fi
    echo "No sha256sum or openssl available to verify Node.js download" >&2
    return 1
  }

  verify_sha256

  rm -rf "${DEST_DIR}" "node-v${NODE_VERSION}-${OS}-${NODE_ARCH}"
  tar -xzf "${TARBALL}"
  mv "node-v${NODE_VERSION}-${OS}-${NODE_ARCH}" "${DEST_DIR}"

  rm -f "${TARBALL}" "${SHASUMS}"

  export PATH="$(pwd)/${DEST_DIR}/bin:$PATH"
  echo "Bundled Node ready: $(node -v)"
}

ensure_local_node

node -v
npm -v

npm ci
npm run build
