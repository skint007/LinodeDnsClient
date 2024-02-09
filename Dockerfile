FROM alpine:latest

LABEL maintainer="skint007"
LABEL build_version="0.1.0"

# Install the required packages
RUN apk update && apk add --no-cache bash curl jq coreutils tzdata

# Clean unnecessary files
RUN apk cache clean

# Copy the script files to the image from /script
COPY --chmod=+x /script /usr/local/bin/linodeDnsUpdate
# COPY functions.sh /usr/local/bin/linodeDnsUpdate/functions.sh
# COPY --chmod=+x checkForDnsUpdate.sh /usr/local/bin/linodeDnsUpdate/checkForDnsUpdate.sh

# Set the working directory
WORKDIR /usr/local/bin/linodeDnsUpdate

# Set the environment variables
ENV LINODE_API_KEY="YourKey"
ENV LINODE_DOMAIN_IDS="1234"
ENV LINODE_EXCLUDE_DOMAINS=""

ENV CHECK_INTERVAL=300
ENV LOG_LEVEL="INFO"
ENV TZ="UTC0"

# Volumes that can be mounted
VOLUME /var/log/dns-check

# Run the script.sh script using bash
ENTRYPOINT ["./script.sh"]
