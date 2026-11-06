FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MALLOC_ARENA_MAX=1 \
    MALLOC_MMAP_THRESHOLD_=65536 \
    MALLOC_TRIM_THRESHOLD_=65536 \
    TS_DEBUG_MTU=1100

# APT যেন র‍্যামে বা ডিস্কে কোনো ক্যাশ এবং ইনডেক্স জমা না রাখে তার সঠিক কনফিগারেশন
RUN echo 'APT::Install-Recommends "false";' > /etc/apt/apt.conf.d/99custom-nocache && \
    echo 'APT::AutoRemove::SuggestsImportant "false";' >> /etc/apt/apt.conf.d/99custom-nocache && \
    echo 'Acquire::GzipIndexes "true";' >> /etc/apt/apt.conf.d/99custom-nocache && \
    echo 'Acquire::CompressionTypes::Order:: "gz";' >> /etc/apt/apt.conf.d/99custom-nocache

# প্যাকেজ ইনস্টল (Acquire::GzipIndexes থাকার কারণে এখন 49MB এর বদলে মাত্র 8-10MB ডাউনলোড হবে)
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    curl \
    wget \
    ca-certificates \
    iptables \
    iproute2 \
    iputils-ping \
    net-tools \
    dnsutils \
    sudo \
    bash \
    htop \
    tmux \
    nano \
    git \
    unzip \
    locales \
    ncurses-term \
    openssh-server \
    procps \
    nocache \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/apt/archives/*.deb

# Tailscale ইনস্টল (শুধু ENABLE_TAILSCALE=true দিলে চালু হবে)
RUN curl -fsSL https://tailscale.com/install.sh | sh && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb /tmp/*

# সিস্টেমের সকল প্রসেসের জন্য গ্লোবালি ফাইল ক্যাশিং (Page Cache) বন্ধ করা
RUN NOCACHE_LIB=$(find /usr/lib -name "libnocache.so.1" | head -n 1) && \
    if [ -n "$NOCACHE_LIB" ]; then echo "$NOCACHE_LIB" >> /etc/ld.so.preload; fi

# OpenSSH কনফিগারেশন
RUN mkdir -p /var/run/sshd /var/run/tailscale /var/lib/tailscale && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "IPQoS none" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 15" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 4" >> /etc/ssh/sshd_config && \
    echo "root:railway123" | chpasswd

# ৩২-কোরের জন্য htop অপটিমাইজেশন
RUN mkdir -p /root/.config/htop && \
    printf "fields=0 48 17 18 38 39 40 2 46 47 49 1\n\
hide_kernel_threads=1\n\
hide_userland_threads=1\n\
delay=20\n\
column_meters_0=CPU Memory\n\
column_meter_modes_0=1 1\n\
column_meters_1=Tasks LoadAverage Uptime\n\
column_meter_modes_1=2 2 2\n" > /root/.config/htop/htoprc

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
