#!/usr/bin/env bash
set -Eeuo pipefail

COUNT="${COUNT:-1}"
SNI_DOMAIN="${SNI_DOMAIN:-yandex.ru}"
INSTALL_DIR="${INSTALL_DIR:-/opt/MTProxy}"
POOL_DIR="${POOL_DIR:-/etc/mtproxy-pool}"
INST_DIR="$POOL_DIR/instances"
RUNNER="${RUNNER:-/usr/local/bin/mtproxy-instance-run.sh}"
SERVICE_TMPL="${SERVICE_TMPL:-/etc/systemd/system/mtproxy@.service}"
REFRESH_SCRIPT="${REFRESH_SCRIPT:-/usr/local/bin/mtproxy-pool-refresh.sh}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI_SRC="$SCRIPT_DIR/mtproxy-pool"
CLI_DEST="/usr/local/bin/mtproxy-pool"
BINARY="$INSTALL_DIR/objs/bin/mtproto-proxy"

die() { echo "ERROR: $*" >&2; exit 1; }

fetch() {
  local url="$1" dest="$2"
  curl -fsS --max-time 15 "$url" -o "$dest" && return 0
  echo "WARN: failed to fetch $url (network may block Telegram)" >&2
  return 1
}

[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run installer as root"
[[ -f "$CLI_SRC" ]] || die "CLI script not found: $CLI_SRC"
[[ "$COUNT" =~ ^[0-9]+$ ]] || die "COUNT must be a number"

apt-get update -y
apt-get install -y git curl ca-certificates build-essential libssl-dev zlib1g-dev iproute2 openssl

sysctl -w kernel.pid_max=65535 >/dev/null || true
echo 'kernel.pid_max = 65535' >/etc/sysctl.d/99-mtproxy-pidmax.conf
sysctl --system >/dev/null || true

id -u mtproxy >/dev/null 2>&1 \
  || useradd --system --home-dir "$INSTALL_DIR" --shell /usr/sbin/nologin mtproxy

if [[ ! -d "$INSTALL_DIR/.git" ]]; then
  [[ -e "$INSTALL_DIR" ]] && die "$INSTALL_DIR exists but is not a git checkout"
  git clone https://github.com/TelegramMessenger/MTProxy "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"
git pull --ff-only || true

if [[ -f "$BINARY" ]]; then
  echo "Binary already exists, skipping build."
else
  echo "Building MTProxy (this may take a few minutes)..."
  make clean >/dev/null 2>&1 || true
  make -j1
fi

echo "Downloading Telegram config files..."
fetch https://core.telegram.org/getProxySecret proxy-secret \
  || { [[ -f proxy-secret ]] && echo "Using existing proxy-secret." || die "proxy-secret missing and could not be fetched."; }
fetch https://core.telegram.org/getProxyConfig proxy-multi.conf \
  || { [[ -f proxy-multi.conf ]] && echo "Using existing proxy-multi.conf." || die "proxy-multi.conf missing and could not be fetched."; }

chown -R mtproxy:mtproxy "$INSTALL_DIR"

mkdir -p "$INST_DIR"
install -m 0755 "$CLI_SRC" "$CLI_DEST"

cat >"$RUNNER" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

inst="${1:?instance required}"
# shellcheck source=/dev/null
source "/etc/mtproxy-pool/instances/${inst}.env"

args=(
  -u mtproxy
  -p "$STATS_PORT"
  -H "$PORT"
  -S "$SECRET"
  -D "$SNI_DOMAIN"
  --aes-pwd /opt/MTProxy/proxy-secret /opt/MTProxy/proxy-multi.conf
  -M "$WORKERS"
)

[[ -n "${PROXY_TAG:-}" ]] && args+=(-P "$PROXY_TAG")

exec /opt/MTProxy/objs/bin/mtproto-proxy "${args[@]}"
EOF
chmod +x "$RUNNER"

cat >"$SERVICE_TMPL" <<'EOF'
[Unit]
Description=Telegram MTProxy instance %i
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mtproxy-instance-run.sh %i
Restart=always
RestartSec=2
LimitNOFILE=262144
StartLimitIntervalSec=0

[Install]
WantedBy=multi-user.target
EOF

cat >"$REFRESH_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
exec /usr/local/bin/mtproxy-pool refresh
EOF
chmod +x "$REFRESH_SCRIPT"

cat >/etc/systemd/system/mtproxy-pool-refresh.service <<'EOF'
[Unit]
Description=Refresh MTProxy telegram config

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mtproxy-pool-refresh.sh
EOF

cat >/etc/systemd/system/mtproxy-pool-refresh.timer <<'EOF'
[Unit]
Description=Refresh MTProxy config every 6h

[Timer]
OnBootSec=10m
OnUnitActiveSec=6h
RandomizedDelaySec=20m
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now mtproxy-pool-refresh.timer

if [[ "$COUNT" -gt 0 ]]; then
  "$CLI_DEST" add --count "$COUNT" --sni "$SNI_DOMAIN"
else
  echo "Installed MTProxy pool without creating instances."
fi

echo ""
echo "✓ Installation complete."
echo ""
echo "  sudo mtproxy-pool links     — get Telegram proxy links"
echo "  sudo mtproxy-pool list      — show all instances"
echo "  sudo mtproxy-pool doctor    — check everything is working"
