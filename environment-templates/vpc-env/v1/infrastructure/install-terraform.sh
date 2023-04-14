#!/bin/bash
set -e

curl -Os https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
curl -Os https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS && \
curl https://keybase.io/hashicorp/pgp_keys.asc | gpg --import && \
curl -Os https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS.sig && \
gpg --verify terraform_${TF_VERSION}_SHA256SUMS.sig terraform_${TF_VERSION}_SHA256SUMS && \
shasum -a 256 -c terraform_${TF_VERSION}_SHA256SUMS 2>&1 | grep "${TF_VERSION}_linux_amd64.zip:\sOK" && \
unzip -o terraform_${TF_VERSION}_linux_amd64.zip -d /usr/local/bin && \
terraform --version