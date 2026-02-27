#!/bin/bash

# Usage: ./new-app-framework.sh <app-name> <cluster-name>
APP_NAME=$1
CLUSTER_NAME=$2

if [ -z "$APP_NAME" ] || [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: ./new-app-framework.sh <app-name> <cluster-name>"
    exit 1
fi

if [ ! -d "clusters/$CLUSTER_NAME" ]; then
    echo "Error: Directory 'clusters/$CLUSTER_NAME' not found."
    exit 1
fi

TARGET_DIR="clusters/$CLUSTER_NAME/$APP_NAME"
COMPONENT_DIR="components/$APP_NAME"
APP_YAML="clusters/$CLUSTER_NAME/$APP_NAME-app.yaml"
REPO_URL=$(git config --get remote.origin.url || echo "https://github.com/mmwillingham/gitops-standards-repo")

echo "--- Scaffolding $APP_NAME for Cluster: $CLUSTER_NAME ---"

# 1. Ensure the Component (Base) exists
if [ ! -d "$COMPONENT_DIR" ]; then
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

# 2. Create the Cluster Overlay
mkdir -p "$TARGET_DIR/patches"

cat <<EOF > "$TARGET_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../$COMPONENT_DIR
patches:
  - path: patches/custom-patch.yaml
EOF

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

# 3. Create the ArgoCD Application Tile
cat <<EOF > "$APP_YAML"
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
echo "-------------------------------------------------------"
echo "THE FOLLOWING FILES WERE CREATED/UPDATED:"
echo "  [Folder] $COMPONENT_DIR"
echo "  [File]   $COMPONENT_DIR/kustomization.yaml"
echo "  [File]   $COMPONENT_DIR/namespace.yaml"
echo "  [File]   $COMPONENT_DIR/operator-policy.yaml"
echo ""
echo "  [Folder] $TARGET_DIR"
echo "  [File]   $TARGET_DIR/kustomization.yaml"
echo "  [File]   $TARGET_DIR/patches/custom-patch.yaml"
echo ""
echo "  [File]   $APP_YAML"
echo "-------------------------------------------------------"
echo "NEXT STEPS:"
echo "1. Edit the manifests in $COMPONENT_DIR"
echo "2. Add $APP_NAME-app.yaml to clusters/$CLUSTER_NAME/kustomization.yaml"
echo "3. Git push"