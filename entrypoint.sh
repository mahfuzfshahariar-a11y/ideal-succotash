#!/bin/bash
set -e

# ১. ব্যাকগ্রাউন্ড র‍্যাম ও ক্যাশ ক্লিনার (প্রতি ৩০ সেকেন্ডে অপ্রয়োজনীয় ক্যাশ মুছে র‍্যাম কমাবে)
(
  while true; do
    sleep 30
    sync
    # cgroup v2 memory reclaim (যদি পারমিশন থাকে তবে সাথে সাথে Page Cache জিরো করে দেবে)
    if [ -w /sys/fs/cgroup/memory.reclaim ]; then
      echo "500M" > /sys/fs/cgroup/memory.reclaim 2>/dev/null || true
    fi
    # অস্থায়ী ক্যাশ ফাইল পরিষ্কার
    rm -rf /var/cache/apt/archives/*.deb /var/lib/apt/lists/* /root/.cache/* 2>/dev/null || true
  done
) &

# ২. শুধুমাত্র ENABLE_TAILSCALE=true থাকলেই Tailscale চালু হবে (যাতে অযথা 300MB র‍্যাম না কাটে)
if [ "$ENABLE_TAILSCALE" = "true" ] && [ -n "$TS_AUTHKEY" ]; then
  echo "Starting Tailscale with 64MB strict RAM limit..."
  GOMEMLIMIT=64MiB GOGC=50 tailscaled \
    --tun=userspace-networking \
    --state=mem: \
    --socket=/var/run/tailscale/tailscaled.sock \
    --no-logs-no-support &

  until [ -S /var/run/tailscale/tailscaled.sock ]; do
    sleep 0.5
  done

  tailscale up \
    --authkey="${TS_AUTHKEY}" \
    --accept-dns=true \
    --hostname="${TS_HOSTNAME:-railway-ubuntu}"
fi

# ৩. OpenSSH সার্ভার চালু করা (মাত্র ১৫ মেগাবাইট র‍্যাম নেয়)
echo "Starting lightweight OpenSSH server on port 22..."
exec /usr/sbin/sshd -D -e
