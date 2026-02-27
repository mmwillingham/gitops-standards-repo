#!/bin/bash

# Usage: ./new-app-framework.sh <app-name>
APP_NAME=$1

if [ -z "$APP_NAME" ]; then
    echo "Usage: ./new-app-framework.sh <app-name>"
    exit 1
fi

# Identify the cluster folder
if [ -z "$CLUSTER_NAME" ]; then
    CLUSTER_NAME=$(ls clusters 2>/dev/null | head -n 1)
    if [ -z "$CLUSTER_NAME" ]; then
        echo "Error: No folder found in ./clusters/. Please create your cluster directory first."
        exit 1
    fi
fi

TARGET_DIR="clusters/$CLUSTER_NAME/$APP_NAME"
REPO_URL=$(git config --get remote.origin.url || echo "https://github.com/mmwillingham/gitops-standards-repo")

echo "--- Scaffolding $APP_NAME for Cluster: $CLUSTER_NAME ---"

# 1. Create the local overlay and patches directory
mkdir -p "$TARGET_DIR/patches"

# 2. Create the local Kustomization
cat <<EOF > "$TARGET_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../components/$APP_NAME

patches:
  - path: patches/custom-patch.yaml
EOF

# 3. Create a starter patch file
cat <<EOF > "$TARGET_DIR/patches/custom-patch.yaml"
apiVersion: policy.open-cluster-management.io/v1beta1
kind: OperatorPolicy
metadata:
  name: $APP_NAME
  namespace: open-cluster-management-policies
spec:
  subscription:
    channel: stable
EOF

# 4. Create the ArgoCD Application Tile with a Sync-Wave
# Setting the wave to 1 ensures core CRDs/Namespaces can stay at 0 or below
cat <<EOF > "clusters/$CLUSTER_NAME/$APP_NAME-app.yaml"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: openshift-gitops
  annotations:
    argocd.argoproj.io/sync-wave: "1" 
spec:
  project: cluster-config
  source:
    repoURL: $REPO_URL
    targetRevision: HEAD
    path: $TARGET_DIR
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-gitops
  syncPolicy:
    automated: { prune: true, selfHeal: true }
EOF

echo "-------------------------------------------------------"
echo "✅ Scaffolding Complete!"
echo "-------------------------------------------------------"