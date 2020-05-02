FROM alpine:3.10

# Setup non-root user
ARG nonroot_user
ARG nonroot_uid

RUN adduser -D -u ${nonroot_uid} -S ${nonroot_user}  \
        --home /home/${nonroot_user}                 \
 && addgroup -g ${nonroot_uid} -S ${nonroot_user}    \
 && addgroup ${nonroot_user} ${nonroot_user}

# Utils
RUN apk --no-cache --update add  \
    bash                         \
    bind-tools                   \
    build-base                   \
    cloc                         \
    curl                         \
    less                         \
    git                          \
    gnupg                        \
    groff                        \
    jq                           \
    make                         \
    netcat-openbsd               \
    openssh                      \
    openssl                      \
    sudo                         \
    tzdata                       \
    vim                          \
    yaml                         \
    zip

# Allow su to root
RUN echo "${nonroot_user} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${nonroot_user}" \
 && chmod 0440 "/etc/sudoers.d/${nonroot_user}"

# Install OpenJDK 11 (keytool)
RUN apk --no-cache --update add openjdk11

# Install scripts
COPY scripts/* /usr/local/bin

ENTRYPOINT []
CMD []
