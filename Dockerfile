FROM alpine as tools

ARG TARGETARCH

COPY Taskfile.yaml Taskfile.yaml

RUN apk add -U curl busybox && \
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin \
  && task

FROM alpine

ARG TARGETARCH
ARG KUBECTL_VERSION=1.24.12
ARG KUSTOMIZE_VERSION=v5.0.1

RUN apk add --update --no-cache curl ca-certificates bash bash-completion git direnv wget net-tools tcpdump iputils nmap arp-scan bind-tools jq yq gettext

COPY --from=tools  /tools/bin/ /usr/local/bin/
COPY --from=tools  /usr/local/bin/task /usr/local/bin/task

WORKDIR /apps

ENV PATH="${PATH}:/usr/local/bin"