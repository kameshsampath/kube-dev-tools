FROM golang:1.19 as go-tools

ARG TARGETARCH
ARG HELM_VERSION=3.11.2
ARG CRANE_VERSION=latest

## Helm 
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
  && chmod 700 get_helm.sh \
  && ./get_helm.sh

## cosign 
RUN go install github.com/sigstore/cosign/cmd/cosign@latest

## Crane
RUN go install github.com/google/go-containerregistry/cmd/crane@latest

## ko
RUN go install github.com/google/ko@latest

## fluxcd

RUN curl -s https://fluxcd.io/install.sh |  bash

# Argo CD CLI
RUN <<EOT
  if [ $TARGETARCH = "x86_64" ] || [ $TARGETARCH = "amd64" ];
  then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  elif [ $TARGETARCH = "aarch64" ] || [ $TARGETARCH = "arm64" ];
  then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-arm64
  fi
  chmod +x /usr/local/bin/argocd
EOT

FROM alpine

ARG TARGETARCH
ARG KUBECTL_VERSION=1.24.12
ARG KUSTOMIZE_VERSION=v5.0.1

RUN apk add --update --no-cache curl ca-certificates bash bash-completion git direnv wget net-tools tcpdump iputils nmap arp-scan bind-tools jq yq gettext

COPY --from=go-tools /usr/local/bin/k3d  /usr/local/bin/helm /usr/local/bin/flux /usr/local/bin/argocd  /usr/local/bin/
COPY --from=go-tools /go/bin/crane /go/bin/cosign /go/bin/ko  /usr/local/bin/

# kubectl
RUN curl -sLO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

# kustomize (latest release)
RUN curl -sLO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz && \
    tar xvzf kustomize_${KUSTOMIZE_VERSION}_linux_${TARGETARCH}.tar.gz && \
    mv kustomize /usr/bin/kustomize && \
    chmod +x /usr/bin/kustomize

# kubens
RUN curl -sL -o /usr/local/bin/kubens https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens \
  && chmod +x /usr/local/bin/kubens

# kubectx
RUN curl -sL -o /usr/local/bin/kubectx https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx \
  && chmod +x /usr/local/bin/kubectx

WORKDIR /apps

ENV PATH="${PATH}:/usr/local/bin"