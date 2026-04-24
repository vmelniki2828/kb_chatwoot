#!/usr/bin/env bash
# Run ON THE VPS as root. DNS for chatwoot.qodeq.net must already point to this server.
set -euo pipefail

DOMAIN="chatwoot.qodeq.net"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_SRC="${REPO_ROOT}/deployment/nginx_chatwoot.qodeq.net.conf"
NGINX_DST="/etc/nginx/sites-available/${DOMAIN}"

echo "Prerequisites:"
echo "  - A-record: ${DOMAIN} -> this server's IP"
echo "  - Port 80 (and 443 after SSL) open in firewall"
echo "  - Chatwoot Docker/Rails will listen on 127.0.0.1:3000"
echo ""

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y nginx certbot

mkdir -p /var/www/html

# --- First-time TLS: get certificate before enabling full HTTPS config ---
if [[ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
  echo "==> Obtaining Let's Encrypt certificate (standalone; needs port 80 free) ..."
  systemctl stop nginx 2>/dev/null || true
  certbot certonly --standalone -d "${DOMAIN}" \
    --non-interactive --agree-tos --register-unsafely-without-email \
    || {
      echo "Certbot failed. Start nginx manually, open :80, fix DNS, then run:"
      echo "  sudo certbot certonly --webroot -w /var/www/html -d ${DOMAIN}"
      exit 1
    }
  systemctl start nginx
fi

if [[ ! -f "${NGINX_SRC}" ]]; then
  echo "Missing ${NGINX_SRC}" >&2
  exit 1
fi

echo "==> Installing Nginx site ${DOMAIN} ..."
cp -a "${NGINX_SRC}" "${NGINX_DST}"
ln -sf "${NGINX_DST}" "/etc/nginx/sites-enabled/${DOMAIN}"
[[ -L /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

echo ""
echo "Open: https://${DOMAIN}"
echo "Ensure .env has FRONTEND_URL=https://${DOMAIN} and restart Chatwoot containers."
