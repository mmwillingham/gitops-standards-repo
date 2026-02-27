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
COMPONENT_DIR="components/$APP_NAME"
REPO_URL=$(git config --get remote.origin.url || echo "https://github.com/mmwillingham/gitops-standards-repo")

echo "--- Scaffolding $APP_NAME for Cluster: $CLUSTER_NAME ---"

# 1. Ensure the Component (Base) exists
if [ ! -d "$COMPONENT_DIR" ]; then
    echo "Creating new component base at $COMPONENT_DIR..."
    mkdir -p "$COMPONENT_DIR"
    cat <<EOF > "$COMPONENT_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - operator-policy.yaml
EOF
    touch "$COMPONENT_DIR/namespace.yaml"
    touch "$COMPONENT_DIR/operator-policy.yaml"
fi

# 2. Create the Cluster Overlay and patches directory
mkdir -p "$TARGET_DIR/patches"

# 3. Create the local Kustomization
cat <<EOF > "$TARGET_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../../$COMPONENT_DIR

patches:
  - path: patches/custom-patch.yaml
EOF

# 4. Create a starter patch file
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

# 5. Create the ArgoCD Application Tile
cat <<EOF > "clusters/$CLUSTER_NAME/$APP_NAME-app.yaml"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: openshift-gitops
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
echo "Component: $COMPONENT_DIR"
echo "Cluster App: $TARGET_DIR"
echo "-------------------------------------------------------"