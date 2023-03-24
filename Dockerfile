FROM golang:1.19 as go-tools

ARG TARGETARCH
ARG HELM_VERSION=3.9.0
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

# Install k3d
RUN curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

FROM alpine

ARG TARGETARCH
ARG KUBECTL_VERSION=1.24.1
ARG KUSTOMIZE_VERSION=v4.5.5
ARG KIND_VERSION=v0.14.0

RUN apk add --update --no-cache curl ca-certificates bash bash-completion git direnv wget net-tools tcpdump iputils nmap arp-scan bind-tools httpie jq yq gettext

COPY --from=go-tools /usr/local/bin/k3d  /usr/local/bin/helm /usr/local/bin/flux /usr/local/bin/argocd  /usr/local/bin/
COPY --from=go-tools /go/bin/crane /go/bin/cosign /go/bin/ko  /usr/local/bin/

# Helm Plugins - helm-diff, helm-unittest
RUN helm plugin install https://github.com/databus23/helm-diff \
  && helm plugin install https://github.com/quintush/helm-unittest \
  && helm plugin install https://github.com/chartmuseum/helm-push \
  && rm -rf /tmp/helm-*

# kubectl
RUN curl -sLO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

# kind
RUN curl -sLO https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${TARGETARCH} && \
    mv kind-linux-${TARGETARCH} /usr/bin/kind && \
    chmod +x /usr/bin/kind

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

# kubectl aliasses
RUN curl https://raw.githubusercontent.com/ahmetb/kubectl-aliases/master/.kubectl_aliases -o /usr/local/.kubectl_aliases

WORKDIR /apps

RUN mkdir -p /apps/.kube \ 
   && echo 'eval "$(direnv hook bash)"'  >> ~/.bashrc \
   && printf "source /usr/share/bash-completion/bash_completion\ncomplete -F __start_kubectl k\nexport do=('--dry-run=client' '-o' 'yaml')\n[ -f /usr/local/.kubectl_aliases ] && source /usr/local/.kubectl_aliases\n" >> ~/.bashrc

ENV PATH="${PATH}:/usr/local/bin"