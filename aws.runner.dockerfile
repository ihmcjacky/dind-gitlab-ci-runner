# Use the official Docker image as a base. It includes the Docker CLI.
FROM docker:24.0.7

# Install dependencies using the Alpine package manager (apk)
# openssh-client: Provides 'ssh' and 'scp'
# python3 and py3-pip: Required to install aws-cli
# curl: Required to download Docker Compose binary
RUN apk add --no-cache \
    openssh-client \
    python3 \
    py3-pip \
    curl

# Install Docker Compose v2 (standalone binary) - Modern approach
# This avoids the pip externally-managed-environment issue
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose \
    && ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install the AWS CLI using pip with virtual environment to avoid PEP 668 restrictions
RUN python3 -m venv /opt/aws-cli-venv \
    && /opt/aws-cli-venv/bin/pip install --upgrade pip \
    && /opt/aws-cli-venv/bin/pip install awscli \
    && ln -s /opt/aws-cli-venv/bin/aws /usr/local/bin/aws