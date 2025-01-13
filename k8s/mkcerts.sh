#!/usr/bin/env bash

# args: bucket-name access-key secret-key ingress-hostname
if [ $# -ne 4 ]; then
  echo "Usage: $0 <bucket-name> <access-key> <secret-key> <ingress-hostname>"
  exit 1
fi

export BUCKET_NAME=$1
export ACCESS_KEY=$2
export SECRET_KEY=$3
export INGRESS_HOSTNAME=$4

# INGRESS_HOSTNAME must be a fully qualified domain name
if ! echo $INGRESS_HOSTNAME | grep -qE '^[a-z0-9.-]+\.[a-z]+$'; then
  echo "Invalid hostname: $INGRESS_HOSTNAME"
  exit 1
fi

if [ ! -d certs ]; then
  mkdir -p certs
fi

(cd certs && openssl req -x509 -nodes -new -sha256 -days 36500 -newkey rsa:4096 -keyout anu.key -out anu.pem -subj "/C=US/CN=Registry Auth CA")

echo "Creating secrets and configmaps..."

rm -rf auth-endpoint.env registry.env registry-secrets.env toplevel.env 2>/dev/null
echo "BUCKET_NAME=$BUCKET_NAME" >> auth-endpoint.env
echo "REGISTRY_STORAGE_S3_BUCKET=$BUCKET_NAME" >> registry.env
echo "INGRESS_HOSTNAME=$INGRESS_HOSTNAME" > toplevel.env

echo "REGISTRY_HTTP_SECRET=$(uuidgen)" >> registry-secrets.env
echo "REGISTRY_AUTH_TOKEN_REALM=https://$INGRESS_HOSTNAME/auth" >> registry-secrets.env
echo "REGISTRY_STORAGE_S3_ACCESSKEY=$ACCESS_KEY" >> registry-secrets.env
echo "REGISTRY_STORAGE_S3_SECRETKEY=$SECRET_KEY" >> registry-secrets.env

echo "Applying to Kubernetes..."
kubectl apply -k .
echo "Done."