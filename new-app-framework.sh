#!/bin/bash

# Usage: ./new-app-framework.sh <app-name> <cluster-name> <type: operator|config>
APP_NAME=$1
CLUSTER_NAME=$2
TYPE=$3

if [[ -z "$APP_NAME" || -z "$CLUSTER_NAME" || -z "$TYPE" ]]; then
    echo "Usage: ./new-app-framework.sh <app-name> <cluster-name> <operator|config>"
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

echo "--- Scaffolding $APP_NAME ($TYPE) for Cluster: $CLUSTER_NAME ---"

# 1. Ensure the Component (Base) exists
if [ ! -d "$COMPONENT_DIR" ]; then
    mkdir -p "$COMPONENT_DIR"
    
    # Logic for different types
    if [ "$TYPE" == "operator" ]; then
        MAIN_FILE="operator-policy.yaml"
    else
        MAIN_FILE="instance.yaml"
    fi

    cat <<EOF > "$COMPONENT_DIR/kustomization.yaml"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - $MAIN_FILE
EOF
    touch "$COMPONENT_DIR/namespace.yaml"
    touch "$COMPONENT_DIR/$MAIN_FILE"
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

# Create a starter patch based on the type
if [ "$TYPE" == "operator" ]; then
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
else
    cat <<EOF > "$TARGET_DIR/patches/custom-patch.yaml"
apiVersion: v1
kind: ConfigMap # Generic placeholder for config type
metadata:
  name: $APP_NAME
  namespace: default
data:
  example: "true"
EOF
fi

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
if [ "$TYPE" == "operator" ]; then
    echo "  [File]   $COMPONENT_DIR/operator-policy.yaml"
else
    echo "  [File]   $COMPONENT_DIR/instance.yaml"
fi
echo ""
echo "  [Folder] $TARGET_DIR"
echo "  [File]   $TARGET_DIR/kustomization.yaml"
echo "  [File]   $TARGET_DIR/patches/custom-patch.yaml"
echo ""
echo "  [File]   $APP_YAML"
echo "-------------------------------------------------------"