FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    MALLOC_ARENA_MAX=2

# nocache ইনস্টল করা হচ্ছে যাতে ফাইল ডাউনলোড বা কাজের সময় র‍্যামে ক্যাশ না জমে
RUN apt-get update && apt-get install -y --no-install-recommends \
    tini \
    curl \
    wget \
    ca-certificates \
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
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# OpenSSH কনফিগারেশন
RUN mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "IPQoS none" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 4" >> /etc/ssh/sshd_config && \
    echo "root:railway123" | chpasswd

# ৩২-কোরের জন্য htop অপটিমাইজেশন (র‍্যাম ও CPU বাঁচাবে)
RUN mkdir -p /root/.config/htop && \
    printf "fields=0 48 17 18 38 39 40 2 46 47 49 1\n\
hide_kernel_threads=1\n\
hide_userland_threads=1\n\
delay=20\n\
column_meters_0=CPU Memory\n\
column_meter_modes_0=1 1\n\
column_meters_1=Tasks LoadAverage Uptime\n\
column_meter_modes_1=2 2 2\n" > /root/.config/htop/htoprc

# ডিফল্টভাবে বড় কমান্ডগুলোতে nocache চালু করে দেওয়া
RUN echo 'alias wget="nocache wget"' >> /root/.bashrc && \
    echo 'alias curl="nocache curl"' >> /root/.bashrc && \
    echo 'alias cp="nocache cp"' >> /root/.bashrc && \
    echo 'alias tar="nocache tar"' >> /root/.bashrc && \
    echo 'alias unzip="nocache unzip"' >> /root/.bashrc

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/entrypoint.sh"]
