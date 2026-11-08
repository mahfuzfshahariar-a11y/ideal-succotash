# syntax=docker/dockerfile:1
FROM ubuntu:22.04

# ১. গ্লোবাল এনভায়রনমেন্ট, র‍্যাম সেভার ও বাংলাদেশ টাইমজোন সেটআপ
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Dhaka \
    PATH="/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    MALLOC_ARENA_MAX=1 \
    MALLOC_MMAP_THRESHOLD_=32768 \
    MALLOC_TRIM_THRESHOLD_=32768 \
    MALLOC_TOP_PAD_=0 \
    GOMAXPROCS=2 \
    GOGC=35 \
    GOMEMLIMIT=180MiB \
    TS_DEBUG_MTU=1100

# ২. ডিস্ক ও র‍্যাম ক্যাশ জিরো রাখার জন্য APT ও DPKG অপটিমাইজেশন
RUN <<'EOF'
set -e
echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/99lowram
echo 'APT::Install-Suggests "false";' >> /etc/apt/apt.conf.d/99lowram
echo 'Acquire::GzipIndexes "true";' >> /etc/apt/apt.conf.d/99lowram
echo 'Acquire::CompressionTypes::Order:: "gz";' >> /etc/apt/apt.conf.d/99lowram
echo 'DPkg::Post-Invoke { "rm -rf /var/cache/apt/archives/*.deb /var/cache/apt/*.bin /var/lib/apt/lists/* || true"; };' >> /etc/apt/apt.conf.d/99lowram
echo 'path-exclude /usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/01_nodoc
echo 'path-exclude /usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/01_nodoc
echo 'path-exclude /usr/share/locale/*' >> /etc/dpkg/dpkg.cfg.d/01_nodoc
EOF

# ৩. দৈনন্দিন সকল কাজের টুলস ও নেটওয়ার্ক ইউটিলিটি ইনস্টল
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    tzdata \
    curl \
    wget \
    ca-certificates \
    iproute2 \
    iputils-ping \
    net-tools \
    dnsutils \
    psmisc \
    lsof \
    jq \
    zip \
    unzip \
    tar \
    gzip \
    git \
    sudo \
    bash \
    htop \
    tmux \
    nano \
    less \
    ncurses-term \
    openssh-server \
    procps \
    nocache \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/* /usr/share/man/* /usr/share/doc/*

# ৪. Antigravity CLI (agy) ইনস্টল এবং গ্লোবাল PATH কনফিগারেশন
RUN <<'EOF'
set -e
curl -fsSL https://antigravity.google/cli/install.sh | bash
if [ -f /root/.local/bin/agy ]; then
    ln -sf /root/.local/bin/agy /usr/local/bin/agy
    chmod +x /root/.local/bin/agy /usr/local/bin/agy
fi
echo 'PATH="/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' >> /etc/environment
grep -qxF 'export PATH="/root/.local/bin:$PATH"' /root/.bashrc || echo 'export PATH="/root/.local/bin:$PATH"' >> /root/.bashrc
rm -rf /tmp/* /root/.cache/* /var/cache/*
EOF

# ৫. অপশনাল Tailscale ইনস্টল এবং গ্লোবাল Page Cache ব্লকার (libnocache) সেটআপ
RUN <<'EOF'
set -e
curl -fsSL https://tailscale.com/install.sh | sh
rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/*
NOCACHE_LIB=$(find /usr/lib -name "libnocache.so.1" | head -n 1)
if [ -n "$NOCACHE_LIB" ]; then
    echo "$NOCACHE_LIB" > /etc/ld.so.preload
fi
EOF

# ৬. লাইটওয়েট OpenSSH, tmux এবং htop কনফিগারেশন
RUN <<'EOF'
set -e
mkdir -p /var/run/sshd /var/run/tailscale /var/lib/tailscale /root/.config/htop
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
cat << 'SSHEOF' >> /etc/ssh/sshd_config
IPQoS none
UseDNS no
MaxStartups 2:30:10
ClientAliveInterval 20
ClientAliveCountMax 3
SetEnv PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SSHEOF
echo "root:railway123" | chpasswd
echo "set -g history-limit 500" > /root/.tmux.conf

cat << 'HTOPEOF' > /root/.config/htop/htoprc
fields=0 48 17 18 38 39 40 2 46 47 49 1
hide_kernel_threads=1
hide_userland_threads=1
delay=25
column_meters_0=CPU Memory
column_meter_modes_0=1 1
column_meters_1=Tasks LoadAverage Uptime
column_meter_modes_1=2 2 2
HTOPEOF
EOF

# ৭. শর্টকাট কমান্ড তৈরি (freeram, agy-open, agy-stop, agy-start, agy-log)
RUN <<'EOF'
set -e

# ম্যানুয়ালি সাথে সাথে র‍্যাম ও ক্যাশ ফ্রি করার কমান্ড: freeram
cat << 'FREEEOF' > /usr/local/bin/freeram
#!/bin/bash
echo "--- Before RAM Cleanup ---"
free -m
sync
if [ -w /sys/fs/cgroup/memory.reclaim ]; then
    echo "900M" > /sys/fs/cgroup/memory.reclaim 2>/dev/null || true
fi
if [ -w /sys/fs/cgroup/memory/memory.force_empty ]; then
    echo 1 > /sys/fs/cgroup/memory/memory.force_empty 2>/dev/null || true
fi
rm -rf /tmp/* /var/tmp/* /root/.cache/* /var/cache/apt/archives/*.deb /var/lib/apt/lists/* 2>/dev/null || true
echo ""
echo "--- After RAM Cleanup ---"
free -m
FREEEOF

# agy সেশনে সরাসরি ঢোকার কমান্ড: agy-open
cat << 'OPENEOF' > /usr/local/bin/agy-open
#!/bin/bash
if tmux has-session -t agy_session 2>/dev/null; then
    tmux attach -t agy_session
else
    echo "Starting agy_session now..."
    tmux new-session -d -s agy_session "bash -c 'GOMAXPROCS=2 GOGC=35 GOMEMLIMIT=180MiB /usr/local/bin/agy --dangerously-skip-permissions --remote-control; exec bash'"
    tmux attach -t agy_session
fi
OPENEOF

# যেকোনো সময় agy বন্ধ করে র‍্যাম খালি করার কমান্ড: agy-stop
cat << 'STOPEOF' > /usr/local/bin/agy-stop
#!/bin/bash
tmux send-keys -t agy_session C-c 2>/dev/null || true
sleep 1
tmux kill-session -t agy_session 2>/dev/null || true
pkill -9 -f "agy" 2>/dev/null || true
/usr/local/bin/freeram
echo "agy stopped and RAM freed!"
STOPEOF

# লগ দেখার কমান্ড: agy-log
cat << 'LOGEOF' > /usr/local/bin/agy-log
#!/bin/bash
tail -n 50 /var/log/agy-schedule.log
LOGEOF

chmod +x /usr/local/bin/freeram /usr/local/bin/agy-open /usr/local/bin/agy-stop /usr/local/bin/agy-log
EOF

# ৮. মেইন অটো-স্টার্টআপ, র‍্যাম স্কুইজার ও বাংলাদেশ টাইম শিডিউলার (সকাল ৭টা - রাত ১২টা)
RUN <<'EOF'
set -e
cat << 'ENTRYEOF' > /entrypoint.sh
#!/bin/bash
set -e

export TZ="Asia/Dhaka"
export PATH="/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export GOMAXPROCS=2
export GOGC=35
export GOMEMLIMIT=180MiB

# (ক) অটো র‍্যাম ও ক্যাশ ক্লিনার (প্রতি ২০ সেকেন্ডে অপ্রয়োজনীয় Page Cache রিমুভ করবে)
(
  while true; do
    sleep 20
    sync
    if [ -w /sys/fs/cgroup/memory.reclaim ]; then
      echo "800M" > /sys/fs/cgroup/memory.reclaim 2>/dev/null || true
    fi
    if [ -w /sys/fs/cgroup/memory/memory.force_empty ]; then
      echo 1 > /sys/fs/cgroup/memory/memory.force_empty 2>/dev/null || true
    fi
    rm -rf /var/cache/apt/archives/*.deb /var/lib/apt/lists/* 2>/dev/null || true
    if [ -f /var/log/agy-schedule.log ] && [ $(stat -c%s /var/log/agy-schedule.log 2>/dev/null || echo 0) -gt 102400 ]; then
      tail -n 50 /var/log/agy-schedule.log > /var/log/agy-schedule.log.tmp && mv /var/log/agy-schedule.log.tmp /var/log/agy-schedule.log
    fi
  done
) &

# (খ) বাংলাদেশ টাইম শিডিউলার (সকাল 07:00 চালু, রাত 12:00 বন্ধ)
(
  SESSION_NAME="agy_session"
  CMD="bash -c 'GOMAXPROCS=2 GOGC=35 GOMEMLIMIT=180MiB /usr/local/bin/agy --dangerously-skip-permissions --remote-control; exec bash'"
  sleep 3

  while true; do
    HOUR=$(TZ="Asia/Dhaka" date +%H)

    # সকাল ৭:০০ (07) থেকে রাত ১১:৫৯ (23) পর্যন্ত চালু থাকবে
    if [ "$HOUR" -ge 7 ]; then
      if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S BD')] Daytime active (07:00-23:59). Starting $SESSION_NAME..."
        tmux new-session -d -s "$SESSION_NAME" "$CMD"
      fi
    else
      # রাত ১২:০০ (00) থেকে সকাল ৬:৫৯ (06) পর্যন্ত বন্ধ থাকবে ও র‍্যাম জিরো করবে
      if tmux has-session -t "$SESSION_NAME" 2>/dev/null || pgrep -f "/usr/local/bin/agy" >/dev/null 2>&1; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S BD')] 12:00 AM Midnight reached! Stopping $SESSION_NAME to save RAM..."
        tmux send-keys -t "$SESSION_NAME" C-c 2>/dev/null || true
        sleep 2
        tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
        pkill -9 -f "agy" 2>/dev/null || true

        sync
        if [ -w /sys/fs/cgroup/memory.reclaim ]; then
          echo "900M" > /sys/fs/cgroup/memory.reclaim 2>/dev/null || true
        fi
        echo "[$(date '+%Y-%m-%d %H:%M:%S BD')] Stopped and RAM reclaimed."
      fi
    fi
    sleep 30
  done
) > /var/log/agy-schedule.log 2>&1 &

# (গ) অপশনাল Tailscale (যদি কখনো ENABLE_TAILSCALE=true দেওয়া হয়)
if [ "$ENABLE_TAILSCALE" = "true" ] && [ -n "$TS_AUTHKEY" ]; then
  GOMEMLIMIT=64MiB GOGC=50 tailscaled \
    --tun=userspace-networking \
    --state=mem: \
    --socket=/var/run/tailscale/tailscaled.sock \
    --no-logs-no-support &
  until [ -S /var/run/tailscale/tailscaled.sock ]; do sleep 0.5; done
  tailscale up --authkey="${TS_AUTHKEY}" --accept-dns=true --hostname="${TS_HOSTNAME:-railway-ubuntu}"
fi

echo "Starting ultra-lightweight OpenSSH server on port 22..."
exec /usr/sbin/sshd -D -e
ENTRYEOF

chmod +x /entrypoint.sh
EOF

EXPOSE 22

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
