FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install OpenSSH server, GCC compiler for SUID binary, postgres client, and system tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    gcc \
    libc6-dev \
    postgresql-client \
    procps \
    curl \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Setup OpenSSH directory and host keys
RUN mkdir -p /run/sshd && \
    ssh-keygen -A

# Copy OpenSSH daemon configuration
COPY ssh/sshd_config /etc/ssh/sshd_config

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY web/requirements.txt /app/web/requirements.txt
RUN pip install --no-cache-dir -r /app/web/requirements.txt

# Copy web application and challenge files
COPY web/ /app/web/
COPY database/ /app/database/
COPY flags/ /app/flags/
COPY linux/ /app/linux/
COPY ssh/ /app/ssh/
COPY entrypoint.sh /entrypoint.sh

# Set executable permissions on scripts
RUN chmod +x /entrypoint.sh /app/linux/*.sh /app/linux/privesc/*.sh

EXPOSE 8000 22

ENTRYPOINT ["/entrypoint.sh"]
