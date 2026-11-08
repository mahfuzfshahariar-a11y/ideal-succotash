FROM ubuntu:22.04

# ১. গ্লোবাল এনভায়রনমেন্ট, র‍্যাম সেভার ও ক্যাশ ব্লকার ভ্যারিয়েবল
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Dhaka \
    PATH="/root/.local/bin:/root/.bun/bin:/opt/uv-bin:/opt/nextjs-base/node_modules/.bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    NODE_PATH="/opt/nextjs-base/node_modules:/usr/local/lib/node_modules" \
    # Python, UV, NPM, Next.js ও GCloud এর রানটাইম ক্যাশ এবং টেলিমেট্রি বন্ধ
    PIP_NO_CACHE_DIR=1 \
    UV_NO_CACHE=1 \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    UV_TOOL_DIR=/opt/uv-tools \
    UV_PYTHON_INSTALL_DIR=/opt/uv-python \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    NPM_CONFIG_CACHE=/tmp/npm-cache \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_FUND=false \
    NPM_CONFIG_AUDIT=false \
    NEXT_TELEMETRY_DISABLED=1 \
    CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true \
    # Linux glibc ও Go র‍্যাম অপটিমাইজেশন
    MALLOC_ARENA_MAX=1 \
    MALLOC_MMAP_THRESHOLD_=32768 \
    MALLOC_TRIM_THRESHOLD_=32768 \
    MALLOC_TOP_PAD_=0 \
    GOMAXPROCS=2 \
    GOGC=35 \
    GOMEMLIMIT=180MiB \
    NODE_OPTIONS="--max-old-space-size=384" \
    TS_DEBUG_MTU=1100

# ২. ডিস্ক ও র‍্যাম ক্যাশ জিরো রাখার জন্য APT ও DPKG কনফিগারেশন
RUN echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/99lowram && \
    echo 'APT::Install-Suggests "false";' >> /etc/apt/apt.conf.d/99lowram && \
    echo 'Acquire::GzipIndexes "true";' >> /etc/apt/apt.conf.d/99lowram && \
    echo 'Acquire::CompressionTypes::Order:: "gz";' >> /etc/apt/apt.conf.d/99lowram && \
    echo 'DPkg::Post-Invoke { "rm -rf /var/cache/apt/archives/*.deb /var/cache/apt/*.bin /var/lib/apt/lists/* || true"; };' >> /etc/apt/apt.conf.d/99lowram && \
    echo 'path-exclude /usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo 'path-exclude /usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/01_nodoc && \
    echo 'path-exclude /usr/share/locale/*' >> /etc/dpkg/dpkg.cfg.d/01_nodoc

# ৩. সিস্টেম ইউটিলিটি, ডাটাবেস ক্লায়েন্ট, Python 3, GitHub CLI (gh), Rclone ইনস্টল
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    tzdata \
    curl \
    wget \
    gpg \
    ca-certificates \
    iproute2 \
    iputils-ping \
    net-tools \
    dnsutils \
    psmisc \
    lsof \
    jq \
    ripgrep \
    fd-find \
    sqlite3 \
    postgresql-client \
    redis-tools \
    zip \
    unzip \
    tar \
    gzip \
    git \
    gh \
    rclone \
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
    python3 \
    python3-pip \
    python3-venv \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/*

# ৪. Node.js 20 LTS, Bun এবং Google Cloud CLI (gcloud) ইনস্টল
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" > /etc/apt/sources.list.d/nodesource.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /etc/apt/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    google-cloud-cli \
    && curl -fsSL https://bun.sh/install | bash \
    && ln -sf /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -sf /root/.bun/bin/bunx /usr/local/bin/bunx \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/cache/*

# ৫. UV, Python 3.12 ও অফিশিয়াল google-colab-cli (`colab` কমান্ড) এবং Python ওয়েব স্ট্যাক ইনস্টল
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh && \
    uv tool install --python 3.12 google-colab-cli && \
    pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir \
    fastapi \
    "uvicorn[standard]" \
    flask \
    django \
    gunicorn \
    requests \
    httpx \
    aiohttp \
    beautifulsoup4 \
    lxml \
    pydantic \
    pydantic-settings \
    sqlalchemy \
    alembic \
    psycopg2-binary \
    redis \
    pymongo \
    python-dotenv \
    python-multipart \
    websockets \
    pyjwt \
    passlib \
    bcrypt \
    gdown \
    google-genai \
    google-api-python-client \
    google-auth-httplib2 \
    google-auth-oauthlib \
    jupyter_http_over_ws \
    && find /usr/local/lib/python3* /usr/lib/python3* /opt/uv-tools /opt/uv-python -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true \
    && rm -rf /root/.cache /tmp/*

# ৬. Next.js, Tailwind CSS, TypeScript, Shadcn/UI ডিপেন্ডেন্সি ও গ্লোবাল ওয়েব টুলস প্রি-ইনস্টল
RUN npm install -g --no-audit --no-fund \
    pnpm \
    typescript \
    tsx \
    ts-node \
    vercel \
    wrangler \
    firebase-tools \
    shadcn && \
    mkdir -p /opt/nextjs-base && cd /opt/nextjs-base && \
    npm init -y && \
    npm install --no-audit --no-fund \
    next@latest \
    react@latest \
    react-dom@latest \
    typescript \
    @types/node \
    @types/react \
    @types/react-dom \
    tailwindcss \
    @tailwindcss/postcss \
    postcss \
    autoprefixer \
    lucide-react \
    clsx \
    tailwind-merge \
    class-variance-authority \
    @radix-ui/react-slot \
    @radix-ui/react-dialog \
    @radix-ui/react-dropdown-menu \
    @radix-ui/react-tabs \
    @radix-ui/react-tooltip \
    framer-motion \
    next-themes \
    sonner \
    zustand \
    swr \
    @tanstack/react-query \
    react-hook-form \
    @hookform/resolvers \
    date-fns \
    axios \
    zod \
    drizzle-orm \
    prisma \
    @prisma/client \
    eslint && \
    npm cache clean --force && \
    rm -rf /root/.npm /tmp/* /var/tmp/*

# ৭. Antigravity CLI (agy) ও Tailscale ইনস্টল
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash && \
    if [ -f /root/.local/bin/agy ]; then \
        ln -sf /root/.local/bin/agy /usr/local/bin/agy && \
        chmod +x /root/.local/bin/agy /usr/local/bin/agy; \
    fi && \
    curl -fsSL https://tailscale.com/install.sh | sh && \
    echo 'PATH="/root/.local/bin:/root/.bun/bin:/opt/nextjs-base/node_modules/.bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/environment && \
    echo 'export PATH="/root/.local/bin:/root/.bun/bin:/opt/nextjs-base/node_modules/.bin:$PATH"' >> /root/.bashrc && \
    echo 'export NODE_PATH="/opt/nextjs-base/node_modules:/usr/local/lib/node_modules"' >> /root/.bashrc && \
    rm -rf /var/lib/apt/lists/* /var/cache/* /tmp/* /root/.cache/*

# ৮. OpenSSH, tmux এবং htop কনফিগারেশন
RUN mkdir -p /var/run/sshd /var/run/tailscale /var/lib/tailscale /root/.config/htop && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config && \
    printf "IPQoS none\nUseDNS no\nMaxStartups 2:30:10\nClientAliveInterval 20\nClientAliveCountMax 3\n" >> /etc/ssh/sshd_config && \
    echo "root:railway123" | chpasswd && \
    echo "set -g history-limit 500" > /root/.tmux.conf && \
    printf "fields=0 48 17 18 38 39 40 2 46 47 49 1\nhide_kernel_threads=1\nhide_userland_threads=1\ndelay=25\ncolumn_meters_0=CPU Memory\ncolumn_meter_modes_0=1 1\ncolumn_meters_1=Tasks LoadAverage Uptime\ncolumn_meter_modes_1=2 2 2\n" > /root/.config/htop/htoprc

# ৯. শর্টকাট কমান্ড তৈরি (new-next, freeram, agy-open, agy-stop, agy-log)
RUN cat << 'EOF' > /usr/local/bin/new-next
#!/bin/bash
APP_NAME="${1:-my-next-app}"
mkdir -p "$APP_NAME/src/app"
cd "$APP_NAME"
ln -sf /opt/nextjs-base/node_modules ./node_modules
cat << 'PKG' > package.json
{
  "name": "nextjs-fast-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start"
  }
}
PKG
cat << 'TSCFG' > tsconfig.json
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
TSCFG
echo "✅ Instant Next.js + Tailwind + Shadcn-ready project created in ./$APP_NAME (0 MB download & 0 RAM cache!)"
EOF

RUN cat << 'EOF' > /usr/local/bin/freeram
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
rm -rf /tmp/* /var/tmp/* /root/.cache/* /root/.npm/* /var/cache/apt/archives/*.deb /var/lib/apt/lists/* 2>/dev/null || true
echo ""
echo "--- After RAM Cleanup ---"
free -m
EOF

RUN cat << 'EOF' > /usr/local/bin/agy-open
#!/bin/bash
if tmux has-session -t agy_session 2>/dev/null; then
    tmux attach -t agy_session
else
    tmux new-session -d -s agy_session "bash -c 'GOMAXPROCS=2 GOGC=35 GOMEMLIMIT=180MiB /usr/local/bin/agy --dangerously-skip-permissions --remote-control; exec bash'"
    tmux attach -t agy_session
fi
EOF

RUN cat << 'EOF' > /usr/local/bin/agy-stop
#!/bin/bash
tmux send-keys -t agy_session C-c 2>/dev/null || true
sleep 1
tmux kill-session -t agy_session 2>/dev/null || true
pkill -9 -f "agy" 2>/dev/null || true
/usr/local/bin/freeram
echo "agy stopped and RAM freed!"
EOF

RUN cat << 'EOF' > /usr/local/bin/agy-log
#!/bin/bash
tail -n 50 /var/log/agy-schedule.log
EOF

RUN chmod +x /usr/local/bin/new-next /usr/local/bin/freeram /usr/local/bin/agy-open /usr/local/bin/agy-stop /usr/local/bin/agy-log

# ১০. স্টার্টআপ স্ক্রিপ্ট ও বাংলাদেশ টাইম শিডিউলার (সকাল ৭টা - রাত ১২টা)
RUN cat << 'EOF' > /entrypoint.sh
#!/bin/bash
set -e

export TZ="Asia/Dhaka"
export PATH="/root/.local/bin:/root/.bun/bin:/opt/nextjs-base/node_modules/.bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export NODE_PATH="/opt/nextjs-base/node_modules:/usr/local/lib/node_modules"
export GOMAXPROCS=2
export GOGC=35
export GOMEMLIMIT=180MiB

# কন্টেইনার চালু হওয়ার সময় গ্লোবাল Page Cache ব্লকার (libnocache) সক্রিয় করা
NOCACHE_LIB=$(find /usr/lib -name "libnocache.so.1" 2>/dev/null | head -n 1)
if [ -n "$NOCACHE_LIB" ] && ! grep -q "$NOCACHE_LIB" /etc/ld.so.preload 2>/dev/null; then
  echo "$NOCACHE_LIB" > /etc/ld.so.preload
fi

# (ক) অটো র‍্যাম ও ক্যাশ ক্লিনার (প্রতি ২০ সেকেন্ডে)
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
    rm -rf /tmp/npm-* /var/cache/apt/archives/*.deb /var/lib/apt/lists/* 2>/dev/null || true
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

    if [ "$HOUR" -ge 7 ]; then
      if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S BD')] Daytime active (07:00-23:59). Starting $SESSION_NAME..."
        tmux new-session -d -s "$SESSION_NAME" "$CMD"
      fi
    else
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

# (গ) অপশনাল Tailscale
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
EOF

RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
