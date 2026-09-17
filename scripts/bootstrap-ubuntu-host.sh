#!/usr/bin/env bash
# One-shot host setup for Ubuntu Server with an Intel iGPU. Idempotent.
# sudo bash scripts/bootstrap-ubuntu-host.sh   (NO_REBOOT=1 to skip the final reboot)
set -euo pipefail

TARGET_USER="${TARGET_USER:-edson}"
TZ_NAME="${TZ_NAME:-Europe/Berlin}"
DATA_ROOT="${DATA_ROOT:-/mnt/data}"

[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
export DEBIAN_FRONTEND=noninteractive

echo "== packages"
apt-get update -q
apt-get full-upgrade -y -q
apt-get install -y -q rsync curl ca-certificates gnupg vainfo intel-gpu-tools htop smartmontools hdparm

echo "== timezone $TZ_NAME"
timedatectl set-timezone "$TZ_NAME"

echo "== i915 GuC/HuC (Alder Lake-N low-power encoder)"
echo 'options i915 enable_guc=2' > /etc/modprobe.d/i915.conf
update-initramfs -u -k all

echo "== docker engine (official repo)"
if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  CODENAME="$VERSION_CODENAME"
  if ! curl -fsSL "https://download.docker.com/linux/ubuntu/dists/${CODENAME}/Release" >/dev/null; then
    echo "   no docker repo for ${CODENAME}, using noble"
    CODENAME=noble
  fi
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
usermod -aG docker "$TARGET_USER"

echo "== docker waits for $DATA_ROOT mount (USB HDD)"
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/wait-data.conf <<UNIT
[Unit]
RequiresMountsFor=$DATA_ROOT
UNIT
systemctl daemon-reload

echo "== data root"
mkdir -p "$DATA_ROOT"
chown "$TARGET_USER:$TARGET_USER" "$DATA_ROOT"

echo "== summary"
echo "render GID : $(getent group render | cut -d: -f3)   -> RENDER_GID in .env"
echo "user       : $(id "$TARGET_USER")"
echo "docker     : $(docker --version) / $(docker compose version)"
echo "kernel     : $(uname -r)"

if [[ "${NO_REBOOT:-0}" != 1 ]]; then
  echo "== rebooting in 5s to load i915 with GuC (Ctrl-C to abort)"
  sleep 5
  reboot
fi
