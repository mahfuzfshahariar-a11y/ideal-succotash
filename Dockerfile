FROM ubuntu:22.04

# MALLOC_TRIM_THRESHOLD_=65536 দিলে প্রসেস শেষ হওয়ার সাথে সাথে র‍্যাম কার্নেলে ফেরত যায়
ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MALLOC_ARENA_MAX=1 \
    MALLOC_MMAP_THRESHOLD_=65536 \
    MALLOC_TRIM_THRESHOLD_=65536 \
    TS_DEBUG_MTU=1100

# APT যেন কখনোই ডিস্ক বা র‍্যামে ক্যাশ না জমায় তার কনফিগারেশন
RUN echo 'APT::Keep-Downloaded-Packages "false";' > /etc/apt/apt.conf.d/99custom-nocache && \
    echo 'Dir::Cache "";' >> /etc/apt/apt.conf.d/99custom-nocache && \
    echo 'Dir::Cache::archives "";' >> /etc/apt/apt.conf.d/99custom-nocache && \
    echo 'Dir::State::lists "";' >> /etc/apt/apt.conf.d/99custom-nocache

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
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/cache/*

# যদি Tailscale লাগে তার জন্য ইনস্টল করা থাকলো, তবে র‍্যাম বাঁচাতে অটো-স্টার্ট বন্ধ থাকবে
RUN curl -fsSL https://tailscale.com/install.sh | sh && \
    rm -rf /var/cache/* /tmp/*

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
